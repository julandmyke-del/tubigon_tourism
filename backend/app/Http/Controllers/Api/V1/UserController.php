<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Profile;
use App\Models\Role;
use App\Models\Setting;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

class UserController extends Controller
{
    /**
     * GET /api/v1/users
     */
    public function index(): JsonResponse
    {
        // Use the authentication source of truth so registration method and
        // suspended accounts are visible without exposing auth credentials.
        $users = User::withTrashed()->with('role')
            ->orderBy('created_at', 'desc')
            ->get()
            ->map(function ($user) {
                return [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'role_id' => $user->role_id,
                    'role' => $user->role?->name ?? 'tourist',
                    'role_name' => $user->role?->name ?? 'tourist',
                    'is_verified' => (bool) $user->is_verified,
                    'registration_method' => $user->auth_provider ?: 'email',
                    'status' => $user->deleted_at ? 'Suspended' : 'Active',
                    'created_at' => $user->created_at?->toIso8601String(),
                    'avatar_url' => $user->avatar_url,
                    'phone' => $user->phone,
                ];
            });

        return response()->json(['status' => 'success', 'data' => $users]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|max:255|unique:users,email',
            'password' => ['required', Password::min(8)],
            'role_id' => 'required|exists:roles,id',
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
        $user = Profile::with('role')->findOrFail($id);
        return response()->json(['status' => 'success', 'data' => $user]);
    }

    /**
     * PUT /api/v1/users/{id}
     */
    public function update(Request $request, string $id): JsonResponse
    {
        $this->authorizeProfileAccess($request, $id);
        $profile = Profile::findOrFail($id);

        $validated = $request->validate([
            'name' => 'sometimes|string|max:255',
            'phone' => 'nullable|string|max:255',
            'bio' => 'nullable|string',
            'avatar_url' => 'nullable|string',
            'language' => 'sometimes|string|max:50',
        ]);

        $profile->update($validated);

        if (isset($validated['name'])) {
            User::where('id', $id)->update(['name' => $validated['name']]);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'Profile updated successfully',
            'data' => $profile->fresh()->load('role'),
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
            'role_id' => 'sometimes|required|exists:roles,id',
        ]);

        $user = User::with('role')->findOrFail($id);
        $profile = Profile::findOrFail($id);
        $newRole = isset($validated['role_id'])
            ? Role::findOrFail($validated['role_id'])
            : null;
        if ($newRole !== null) {
            $this->guardLastAdmin($user, $newRole);
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
        $request->validate(['role_id' => 'required|exists:roles,id']);

        $target = User::with('role')->findOrFail($id);
        $newRole = Role::findOrFail($request->role_id);
        $this->guardLastAdmin($target, $newRole);

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
            Profile::where('id', $target->id)->firstOrFail()->delete();
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
        $roles = Role::select('id', 'name')->get();
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
}
