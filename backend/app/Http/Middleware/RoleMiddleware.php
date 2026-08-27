<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class RoleMiddleware
{
    /**
     * Handle an incoming request.
     * Usage: ->middleware('role:admin,tourism_partner')
     */
    public function handle(Request $request, Closure $next, ...$roles): mixed
    {
        $user = $request->user();

        if (!$user) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        // Load the user's role name
        $user->loadMissing('role');
        $userRole = $user->role?->name;

        if (!$userRole || !in_array($userRole, $roles)) {
            return response()->json(['message' => 'Access denied. Insufficient permissions.'], 403);
        }

        return $next($request);
    }
}
