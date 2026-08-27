<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Profile;
use App\Models\Role;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

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

    /**
     * PUT /api/v1/users/{id}/role
     */
    public function updateRole(Request $request, string $id): JsonResponse
    {
        $request->validate(['role_id' => 'required|exists:roles,id']);

        Profile::where('id', $id)->update(['role_id' => $request->role_id]);
        User::where('id', $id)->update(['role_id' => $request->role_id]);

        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => 'Role updated',
            'details' => "Updated role of user ID $id",
        ]);

        return response()->json(['status' => 'success', 'message' => 'Role updated']);
    }

    /**
     * PUT /api/v1/users/{id}/verify
     */
    public function updateVerification(Request $request, string $id): JsonResponse
    {
        $request->validate(['is_verified' => 'required|boolean']);

        Profile::where('id', $id)->update(['is_verified' => $request->is_verified]);
        User::where('id', $id)->update(['is_verified' => $request->is_verified]);

        $action = $request->is_verified ? 'User verified' : 'User unverified';
        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => $action,
            'details' => "Updated verification state of user ID $id",
        ]);

        return response()->json(['status' => 'success', 'message' => $action]);
    }

    /**
     * DELETE /api/v1/users/{id}
     */
    public function destroy(Request $request, string $id): JsonResponse
    {
        $profile = Profile::findOrFail($id);
        $profile->delete(); // Soft delete profile

        // Soft delete user record as well so user cannot authenticate
        User::where('id', $id)->delete();

        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => 'User soft deleted',
            'details' => "Soft deleted user ID $id",
        ]);

        return response()->json(['status' => 'success', 'message' => 'User deleted successfully']);
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
}
