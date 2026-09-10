<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Msme;
use App\Models\Notification;
use App\Models\PartnerNotification;
use App\Models\Profile;
use App\Models\Role;
use App\Models\Setting;
use App\Models\TouristSpot;
use App\Models\TouristSpotPartnerAssignment;
use App\Models\User;
use App\Models\UserPreference;
use App\Services\EmailNotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

class UserController extends Controller
{
    private const MANAGEABLE_ROLES = ['tourist', 'msme_owner', 'tourism_partner', 'lgu_staff', 'admin'];

    /**
     * GET /api/v1/users
     */
    public function index(Request $request): JsonResponse
    {
        // Use the authentication source of truth so registration method and
        // suspended accounts are visible without exposing auth credentials.
        $relations = ['role', 'profile'];
        if (Schema::hasTable('msmes')) {
            $relations[] = 'msmes:id,profile_id,name';
        }
        if (Schema::hasTable('tourist_spot_partner_assignments') && Schema::hasTable('tourist_spots')) {
            $relations[] = 'managedTouristSpots:id,name';
        }
        $query = User::withTrashed()->with($relations);
        if ($request->filled('search')) {
            $search = '%'.strtolower($request->string('search')).'%';
            $query->where(fn ($q) => $q
                ->whereRaw('LOWER(name) LIKE ?', [$search])
                ->orWhereRaw('LOWER(email) LIKE ?', [$search]));
        }
        if ($request->filled('role')) {
            $query->whereHas('role', fn ($q) => $q->where('name', $request->string('role')));
        }
        if ($request->has('verified')) {
            $query->where('is_verified', $request->boolean('verified'));
        }
        if ($request->string('status')->toString() === 'active') {
            $query->whereNull('deleted_at');
        }
        if ($request->string('status')->toString() === 'disabled') {
            $query->onlyTrashed();
        }

        $users = $query
            ->orderBy('created_at', 'desc')
            ->get()
            ->map(fn (User $user) => $this->userPayload($user));

        return response()->json(['status' => 'success', 'data' => $users]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|max:255|unique:users,email',
            'password' => ['required', Password::min(8)],
            'role_id' => ['required', Rule::exists('roles', 'id')->where(fn ($q) => $q->whereIn('name', self::MANAGEABLE_ROLES))],
            'is_verified' => 'sometimes|boolean',
        ]);

        $user = DB::transaction(function () use ($request, $validated): User {
            $user = User::create([
                'name' => trim($validated['name']),
                'email' => strtolower(trim($validated['email'])),
                'password' => $validated['password'],
                'role_id' => $validated['role_id'],
                'is_verified' => $validated['is_verified'] ?? false,
                'auth_provider' => 'admin',
            ]);

            Profile::create([
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role_id' => $user->role_id,
                'is_verified' => $user->is_verified,
                'language' => $user->language ?: 'en',
            ]);
            Setting::firstOrCreate(['user_id' => $user->id]);

            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'User created',
                'details' => "Created account {$user->email}",
            ]);

            return $user;
        });

        return response()->json([
            'status' => 'success',
            'message' => 'User created successfully.',
            'data' => $user->fresh()->load('role'),
        ], 201);
    }

    /**
     * GET /api/v1/users/{id}
     */
    public function show(Request $request, string $id): JsonResponse
    {
        $this->authorizeProfileAccess($request, $id);
        $user = User::withTrashed()->with($this->profileRelations())->findOrFail($id);
        $payload = $this->userPayload($user, true);
        if ((string) $request->user()->id === (string) $id && Schema::hasTable('user_preferences')) {
            $payload['preferences'] = $user->preferences?->toArray() ?? $this->defaultPreferences();
        }

        return response()->json(['status' => 'success', 'data' => $payload]);
    }

    /**
     * PUT /api/v1/users/{id}
     */
    public function update(Request $request, string $id): JsonResponse
    {
        $this->authorizeProfileAccess($request, $id);
        $profile = Profile::findOrFail($id);
        $editingSelf = (string) $request->user()->id === (string) $id;
        if (! $editingSelf && $request->has('preferences')) {
            abort(403, 'Private preferences may only be changed by their owner.');
        }

        $validated = $request->validate([
            'name' => 'sometimes|required|string|min:2|max:255',
            'phone' => ['nullable', 'string', 'max:30', 'regex:/^[0-9+()\-\s]*$/'],
            'address' => 'nullable|string|max:1000',
            'barangay' => 'nullable|string|max:120',
            'bio' => 'nullable|string|max:2000',
            'language' => ['sometimes', Rule::in(['en', 'ceb'])],
            'preferences' => 'sometimes|array',
            'preferences.personalization_enabled' => 'sometimes|boolean',
            'preferences.preferred_destination_category_ids' => 'sometimes|array|max:20',
            'preferences.preferred_destination_category_ids.*' => 'uuid|distinct|exists:spot_categories,id',
            'preferences.travel_interests' => 'sometimes|array|max:12',
            'preferences.travel_interests.*' => ['string', 'distinct', Rule::in(['beaches', 'heritage', 'nature', 'food', 'adventure', 'culture', 'shopping', 'wellness'])],
            'preferences.travel_pace' => ['nullable', Rule::in(['relaxed', 'balanced', 'packed'])],
            'preferences.group_type' => ['nullable', Rule::in(['solo', 'couple', 'family', 'friends', 'business'])],
            'preferences.preferred_transport_mode' => ['nullable', Rule::in(['walking', 'bicycle', 'motorcycle', 'car', 'public_transport', 'boat', 'mixed'])],
            'preferences.eco_tourism_interest' => 'sometimes|boolean',
            'preferences.nearby_suggestions' => 'sometimes|boolean',
            'preferences.wheelchair_friendly' => 'sometimes|boolean',
            'preferences.limited_walking' => 'sometimes|boolean',
            'preferences.senior_friendly' => 'sometimes|boolean',
            'preferences.child_friendly' => 'sometimes|boolean',
            'preferences.accessibility_notes' => 'nullable|string|max:500',
            'preferences.reservation_updates' => 'sometimes|boolean',
            'preferences.tourism_announcements' => 'sometimes|boolean',
            'preferences.eco_tips' => 'sometimes|boolean',
            'preferences.ferry_alerts' => 'sometimes|boolean',
            'preferences.waste_report_updates' => 'sometimes|boolean',
            'preferences.application_updates' => 'sometimes|boolean',
            'preferences.location_recommendations' => 'sometimes|boolean',
            'preferences.remember_last_map_location' => 'sometimes|boolean',
        ]);

        $user = User::with($this->profileRelations())->findOrFail($id);
        DB::transaction(function () use ($request, $id, $profile, $user, $validated, $editingSelf): void {
            $profileChanges = collect($validated)->only(['name', 'phone', 'address', 'barangay', 'bio', 'language'])->all();
            if (isset($profileChanges['name'])) {
                $profileChanges['name'] = trim($profileChanges['name']);
            }
            $profile->update($profileChanges);

            $userChanges = collect($validated)->only(['name', 'phone', 'bio', 'language'])->all();
            if (isset($userChanges['name'])) {
                $userChanges['name'] = trim($userChanges['name']);
            }
            if ($userChanges !== []) {
                $user->update($userChanges);
            }

            if ($editingSelf && isset($validated['preferences']) && Schema::hasTable('user_preferences')) {
                UserPreference::updateOrCreate(['user_id' => $id], $validated['preferences']);
            }

            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'Profile updated',
                'details' => json_encode(['target_type' => 'user', 'target_id' => $id]),
            ]);
        }, 3);

        return response()->json([
            'status' => 'success',
            'message' => 'Profile updated successfully',
            'data' => $this->userPayload($user->fresh()->load($this->profileRelations()), true)
                + ($editingSelf && Schema::hasTable('user_preferences')
                    ? ['preferences' => UserPreference::where('user_id', $id)->first()?->toArray() ?? $this->defaultPreferences()]
                    : []),
        ]);
    }

    /** Update an account from the Admin portal as one audited transaction. */
    public function updateManaged(Request $request, string $id): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'phone' => 'nullable|string|max:255',
            'bio' => 'nullable|string|max:2000',
            'language' => 'sometimes|required|string|max:50',
            'role_id' => ['sometimes', 'required', Rule::exists('roles', 'id')->where(fn ($q) => $q->whereIn('name', self::MANAGEABLE_ROLES))],
        ]);

        $user = User::with('role')->findOrFail($id);
        $profile = Profile::findOrFail($id);
        $newRole = isset($validated['role_id'])
            ? Role::findOrFail($validated['role_id'])
            : null;
        if ($newRole !== null) {
            $this->guardSelfDemotion($request, $user, $newRole);
            $this->guardLastAdmin($user, $newRole);
            $this->guardOwnership($user, $newRole);
        }

        DB::transaction(function () use ($request, $user, $profile, $newRole, $validated): void {
            $userChanges = [];
            if (array_key_exists('name', $validated)) {
                $userChanges['name'] = trim($validated['name']);
            }
            if ($newRole !== null) {
                $userChanges['role_id'] = $newRole->id;
            }
            if ($userChanges !== []) {
                $user->update($userChanges);
            }

            $profileChanges = collect($validated)
                ->only(['name', 'phone', 'bio', 'language', 'role_id'])
                ->all();
            if (array_key_exists('name', $profileChanges)) {
                $profileChanges['name'] = trim($profileChanges['name']);
            }
            $profile->update($profileChanges);

            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'User account updated',
                'details' => "Updated account ID {$user->id}",
            ]);
        });

        return response()->json([
            'status' => 'success',
            'message' => 'User account updated.',
            'data' => $profile->fresh()->load('role'),
        ]);
    }

    /**
     * PUT /api/v1/users/{id}/role
     */
    public function updateRole(Request $request, string $id): JsonResponse
    {
        $request->validate([
            'role_id' => ['required', Rule::exists('roles', 'id')->where(fn ($q) => $q->whereIn('name', self::MANAGEABLE_ROLES))],
        ]);

        $target = User::with('role')->findOrFail($id);
        $newRole = Role::findOrFail($request->role_id);
        $this->guardSelfDemotion($request, $target, $newRole);
        $this->guardLastAdmin($target, $newRole);
        $this->guardOwnership($target, $newRole);

        DB::transaction(function () use ($request, $target, $newRole): void {
            $target->update(['role_id' => $newRole->id]);
            Profile::where('id', $target->id)->update(['role_id' => $newRole->id]);
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'Role updated',
                'details' => "Updated role of user ID {$target->id} to {$newRole->name}",
            ]);
        });

        return response()->json(['status' => 'success', 'message' => 'Role updated']);
    }

    public function updatePartnerAssignment(Request $request, string $id, EmailNotificationService $emailDelivery): JsonResponse
    {
        $validated = $request->validate([
            'tourist_spot_id' => 'nullable|uuid|exists:tourist_spots,id',
        ]);
        $target = User::with('role')->findOrFail($id);
        abort_unless($target->role?->name === 'tourism_partner', 422, 'Only Tourism Partner accounts can receive a destination assignment.');

        [$assignment, $changed] = DB::transaction(function () use ($request, $target, $validated): array {
            $current = TouristSpotPartnerAssignment::where('partner_profile_id', $target->id)
                ->lockForUpdate()->first();
            $spotId = $validated['tourist_spot_id'] ?? null;
            if ($spotId) {
                TouristSpot::whereKey($spotId)->lockForUpdate()->firstOrFail();
                $conflict = TouristSpotPartnerAssignment::where('tourist_spot_id', $spotId)
                    ->where('partner_profile_id', '!=', $target->id)->lockForUpdate()->exists();
                abort_if($conflict, 422, 'This Tourist Spot is already assigned to another Partner.');
            }
            $previousSpotId = $current?->tourist_spot_id;
            if ($current && (string) $current->tourist_spot_id !== (string) $spotId) {
                $current->delete();
            }
            $newAssignment = $spotId
                ? TouristSpotPartnerAssignment::updateOrCreate(
                    ['partner_profile_id' => $target->id],
                    ['tourist_spot_id' => $spotId, 'is_primary' => true, 'assigned_by' => $request->user()->id, 'assigned_at' => now()],
                )
                : null;
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => $spotId ? 'Tourism Partner destination assigned' : 'Tourism Partner destination unassigned',
                'details' => json_encode([
                    'partner_user_id' => $target->id,
                    'previous_tourist_spot_id' => $previousSpotId,
                    'tourist_spot_id' => $spotId,
                ], JSON_THROW_ON_ERROR),
            ]);
            PartnerNotification::create([
                'user_id' => $target->id,
                'type' => 'admin_assignment_changed',
                'title' => $spotId ? 'Destination Assignment Updated' : 'Destination Assignment Removed',
                'body' => $spotId
                    ? 'Admin updated your assigned destination. Your portal now reflects the new assignment.'
                    : 'Your destination assignment was removed. Contact the Tourism Office for assistance.',
                'data' => ['tourist_spot_id' => $spotId, 'route' => '/tourism-partner/listings'],
            ]);
            User::whereHas('role', fn ($query) => $query->where('name', 'lgu_staff'))
                ->pluck('id')->each(fn (string $lguId) => Notification::create([
                    'user_id' => $lguId,
                    'type' => 'partner_assignment_changed',
                    'title' => 'Tourism Partner Assignment Updated',
                    'body' => "{$target->name}'s destination assignment was updated by Admin.",
                    'data' => ['partner_user_id' => $target->id, 'tourist_spot_id' => $spotId, 'route' => '/lgu/tourist-spots'],
                ]));

            return [
                $newAssignment?->load(['touristSpot:id,name,slug', 'assignedBy:id,name']),
                (string) $previousSpotId !== (string) $spotId,
            ];
        }, 3);

        if ($changed) {
            $emailDelivery->partnerAssignment(
                $target->fresh(),
                $assignment?->touristSpot,
                (string) Str::uuid(),
            );
        }

        return response()->json(['status' => 'success', 'message' => 'Partner destination assignment updated.', 'data' => $assignment]);
    }

    /**
     * PUT /api/v1/users/{id}/verify
     */
    public function updateVerification(Request $request, string $id): JsonResponse
    {
        $request->validate(['is_verified' => 'required|boolean']);

        $target = User::findOrFail($id);
        $action = $request->is_verified ? 'User verified' : 'User unverified';
        DB::transaction(function () use ($request, $target, $action): void {
            $target->update(['is_verified' => $request->boolean('is_verified')]);
            Profile::where('id', $target->id)->update(['is_verified' => $request->boolean('is_verified')]);
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => $action,
                'details' => "Updated verification state of user ID {$target->id}",
            ]);
        });

        return response()->json(['status' => 'success', 'message' => $action]);
    }

    /**
     * DELETE /api/v1/users/{id}
     */
    public function destroy(Request $request, string $id): JsonResponse
    {
        if ((string) $request->user()->id === $id) {
            throw ValidationException::withMessages([
                'user' => ['You cannot archive your own Admin account.'],
            ]);
        }

        $target = User::with('role')->findOrFail($id);
        $this->guardLastAdmin($target, null);

        DB::transaction(function () use ($request, $target): void {
            $target->tokens()->delete();
            $target->delete();
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'User archived',
                'details' => "Archived user ID {$target->id}",
            ]);
        });

        return response()->json(['status' => 'success', 'message' => 'User archived successfully.']);
    }

    /**
     * GET /api/v1/roles
     */
    public function roles(): JsonResponse
    {
        $roles = Role::select('id', 'name')->whereIn('name', self::MANAGEABLE_ROLES)->get();

        return response()->json(['status' => 'success', 'data' => $roles]);
    }

    /**
     * POST /api/v1/users/{id}/avatar
     */
    public function uploadAvatar(Request $request, string $id): JsonResponse
    {
        $this->authorizeProfileAccess($request, $id);
        $request->validate(['avatar' => 'required|image|max:2048']);

        $path = $request->file('avatar')->store("avatars/$id", 'public');
        $url = asset("storage/$path");

        Profile::where('id', $id)->update(['avatar_url' => $url]);
        User::where('id', $id)->update(['avatar_url' => $url]);
        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => 'Profile avatar updated',
            'details' => json_encode(['target_type' => 'user', 'target_id' => $id]),
        ]);

        return response()->json([
            'status' => 'success',
            'data' => ['avatar_url' => $url],
        ]);
    }

    private function authorizeProfileAccess(Request $request, string $id): void
    {
        $user = $request->user();
        $user->loadMissing('role');
        if ($user->role?->name !== 'admin' && (string) $user->id !== $id) {
            abort(403, 'You may only access your own profile.');
        }
    }

    private function guardLastAdmin(User $target, ?Role $newRole): void
    {
        if ($target->role?->name !== 'admin' || $newRole?->name === 'admin') {
            return;
        }

        $adminRoleId = Role::where('name', 'admin')->value('id');
        if ($adminRoleId && User::where('role_id', $adminRoleId)->count() <= 1) {
            throw ValidationException::withMessages([
                'role_id' => ['The last active Admin cannot be demoted or archived.'],
            ]);
        }
    }

    public function updateStatus(Request $request, string $id): JsonResponse
    {
        $validated = $request->validate(['active' => 'required|boolean']);
        $target = User::withTrashed()->with('role')->findOrFail($id);
        if ((string) $request->user()->id === $id && ! $validated['active']) {
            throw ValidationException::withMessages(['active' => ['You cannot disable your own Admin account.']]);
        }
        if (! $validated['active']) {
            $this->guardLastAdmin($target, null);
        }

        DB::transaction(function () use ($request, $target, $validated): void {
            if ($validated['active']) {
                $target->restore();
                Profile::withTrashed()->where('id', $target->id)->restore();
            } else {
                $target->tokens()->delete();
                $target->delete();
            }
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => $validated['active'] ? 'User activated' : 'User deactivated',
                'details' => json_encode(['target_type' => 'user', 'target_id' => $target->id]),
            ]);
        });

        return response()->json(['status' => 'success', 'message' => $validated['active'] ? 'User activated.' : 'User deactivated.']);
    }

    public function revokeSessions(Request $request, string $id): JsonResponse
    {
        $target = User::withTrashed()->findOrFail($id);
        $target->tokens()->delete();
        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => 'User sessions revoked',
            'details' => json_encode(['target_type' => 'user', 'target_id' => $target->id]),
        ]);

        return response()->json(['status' => 'success', 'message' => 'User sessions revoked.']);
    }

    private function guardSelfDemotion(Request $request, User $target, Role $newRole): void
    {
        if ((string) $request->user()->id === (string) $target->id
            && $target->role?->name === 'admin' && $newRole->name !== 'admin') {
            throw ValidationException::withMessages(['role_id' => ['You cannot demote your own Admin account.']]);
        }
    }

    private function guardOwnership(User $target, Role $newRole): void
    {
        if ($target->role?->name === 'msme_owner' && $newRole->name !== 'msme_owner'
            && Msme::where('profile_id', $target->id)->exists()) {
            throw ValidationException::withMessages(['role_id' => ['Reassign the linked MSME before changing this owner role.']]);
        }
        if ($target->role?->name === 'tourism_partner' && $newRole->name !== 'tourism_partner'
            && ($target->managedTouristSpots()->exists()
                || (Schema::hasTable('tourism_listings')
                    && DB::table('tourism_listings')->where('owner_id', $target->id)->whereNull('deleted_at')->exists()))) {
            throw ValidationException::withMessages(['role_id' => ['Reassign linked Tourist Spots before changing this partner role.']]);
        }
    }

    private function userPayload(User $user, bool $detail = false): array
    {
        $payload = [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'role_id' => $user->role_id,
            'role' => $user->role?->name ?? 'tourist',
            'role_name' => $user->role?->name ?? 'tourist',
            'is_verified' => (bool) $user->is_verified,
            'registration_method' => $user->auth_provider ?: 'email',
            'status' => $user->trashed() ? 'Disabled' : 'Active',
            'created_at' => $user->created_at?->toIso8601String(),
            'avatar_url' => $user->avatar_url,
            'phone' => $user->phone ?? $user->profile?->phone,
            'address' => $user->profile?->address,
            'barangay' => $user->profile?->barangay,
            'linked_msmes' => $user->relationLoaded('msmes')
                ? $user->msmes->map->only(['id', 'name'])
                : [],
            'linked_tourist_spots' => $user->relationLoaded('managedTouristSpots')
                ? $user->managedTouristSpots->map->only(['id', 'name'])
                : [],
        ];
        if (! $detail) {
            return $payload;
        }

        $payload['bio'] = $user->bio ?? $user->profile?->bio;
        $payload['language'] = $user->language ?? $user->profile?->language;
        $payload['linked_msmes'] = Schema::hasTable('msmes')
            ? Msme::where('profile_id', $user->id)->get(['id', 'name', 'verification_status'])
            : [];
        $payload['linked_tourist_spots'] = $user->relationLoaded('managedTouristSpots')
            ? $user->managedTouristSpots->map->only(['id', 'name'])
            : [];
        $payload['recent_activity'] = ActivityLog::where('user_id', $user->id)
            ->latest()->limit(10)->get(['id', 'action', 'details', 'created_at']);

        return $payload;
    }

    private function defaultPreferences(): array
    {
        return [
            'personalization_enabled' => false,
            'preferred_destination_category_ids' => [], 'travel_interests' => [],
            'travel_pace' => null, 'group_type' => null, 'preferred_transport_mode' => null,
            'eco_tourism_interest' => false, 'nearby_suggestions' => false,
            'wheelchair_friendly' => false, 'limited_walking' => false,
            'senior_friendly' => false, 'child_friendly' => false, 'accessibility_notes' => null,
            'reservation_updates' => true, 'tourism_announcements' => true,
            'eco_tips' => true, 'ferry_alerts' => true, 'waste_report_updates' => true,
            'application_updates' => true, 'location_recommendations' => false,
            'remember_last_map_location' => false,
        ];
    }

    /** @return array<int, string> */
    private function profileRelations(): array
    {
        $relations = ['role', 'profile'];
        if (Schema::hasTable('tourist_spot_partner_assignments') && Schema::hasTable('tourist_spots')) {
            $relations[] = 'managedTouristSpots';
        }

        return $relations;
    }
}
