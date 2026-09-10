<?php

namespace App\Policies;

use App\Models\Reservation;
use App\Models\User;

class ReservationPolicy
{
    public function communicate(User $user, Reservation $reservation): bool
    {
        return (string) $reservation->user_id === (string) $user->id
            || (string) $reservation->partner_id === (string) $user->id;
    }

    public function createInternalNote(User $user, Reservation $reservation): bool
    {
        $user->loadMissing('role');

        return $user->role?->name === 'tourism_partner'
            && (string) $reservation->partner_id === (string) $user->id;
    }
}
