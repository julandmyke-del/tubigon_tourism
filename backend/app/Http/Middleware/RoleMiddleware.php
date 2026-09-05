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

        // Resolve the role from the authoritative database for every request.
        // This makes an approved application's role effective on the next API
        // call even when a long-lived Sanctum user instance cached the old role.
        $userRole = $user->role()->value('name');

        if (!$userRole || !in_array($userRole, $roles)) {
            return response()->json(['message' => 'Access denied. Insufficient permissions.'], 403);
        }

        return $next($request);
    }
}
