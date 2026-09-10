<?php

namespace App\Policies;

use App\Models\Concern;
use App\Models\User;

class ConcernPolicy
{
    public function view(User $user, Concern $concern): bool
    {
        $user->loadMissing('role');
        $role = $user->role?->name;

        return (string) $concern->user_id === (string) $user->id
            || $role === 'admin'
            || ($role === 'lgu_staff' && $concern->assigned_role === 'lgu_staff');
    }

    public function manage(User $user, Concern $concern): bool
    {
        $user->loadMissing('role');
        $role = $user->role?->name;

        return $role === 'admin'
            || ($role === 'lgu_staff' && $concern->assigned_role === 'lgu_staff');
    }

    public function reply(User $user, Concern $concern): bool
    {
        return $this->view($user, $concern);
    }
}
