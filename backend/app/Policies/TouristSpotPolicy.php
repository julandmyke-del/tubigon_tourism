<?php

namespace App\Policies;

use App\Models\TouristSpot;
use App\Models\User;

class TouristSpotPolicy
{
    public function viewManaged(User $user, TouristSpot $spot): bool
    {
        return $this->isLgu($user) || $this->isAssignedPartner($user, $spot);
    }

    public function updateManagedContent(User $user, TouristSpot $spot): bool
    {
        return $this->viewManaged($user, $spot);
    }

    public function manageBookingAvailability(User $user, TouristSpot $spot): bool
    {
        // Deliberately no Admin shortcut: this authority is restricted by policy.
        return $this->isLgu($user) || $this->isAssignedPartner($user, $spot);
    }

    private function isLgu(User $user): bool
    {
        $user->loadMissing('role');

        return $user->role?->name === 'lgu_staff';
    }

    private function isAssignedPartner(User $user, TouristSpot $spot): bool
    {
        $user->loadMissing('role');
        if ($user->role?->name !== 'tourism_partner') {
            return false;
        }

        return $spot->partnerAssignments()
            ->where('partner_profile_id', $user->id)
            ->exists();
    }
}
