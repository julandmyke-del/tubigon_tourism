<?php

namespace App\Actions;

use App\Models\ActivityLog;
use App\Models\Favorite;
use App\Models\Notification;
use App\Models\PartnerNotification;
use App\Models\Reservation;
use App\Models\TouristSpot;
use App\Models\TouristSpotBookingAvailabilityHistory;
use App\Models\User;
use App\Support\StaleRecordGuard;
use Illuminate\Support\Facades\DB;

class UpdateTouristSpotBookingAvailabilityAction
{
    public function execute(
        TouristSpot $spot,
        User $actor,
        bool $enabled,
        ?string $reasonCode,
        ?string $reason,
        ?string $expectedUpdatedAt = null,
    ): TouristSpot {
        return DB::transaction(function () use ($spot, $actor, $enabled, $reasonCode, $reason, $expectedUpdatedAt): TouristSpot {
            /** @var TouristSpot $locked */
            $locked = TouristSpot::query()->lockForUpdate()->findOrFail($spot->id);
            StaleRecordGuard::assertCurrent($locked, $expectedUpdatedAt, [
                'booking_enabled' => (bool) $locked->booking_enabled,
            ]);

            abort_if($enabled && ! $locked->is_bookable, 422, 'This destination is not configured to support reservations.');

            $changed = (bool) $locked->booking_enabled !== $enabled
                || $locked->booking_unavailable_reason_code !== ($enabled ? null : $reasonCode)
                || $locked->booking_unavailable_reason !== ($enabled ? null : $reason);

            $locked->forceFill([
                'booking_enabled' => $enabled,
                'booking_unavailable_reason_code' => $enabled ? null : $reasonCode,
                'booking_unavailable_reason' => $enabled ? null : $reason,
                'booking_availability_updated_at' => now(),
                'booking_availability_updated_by' => $actor->id,
            ])->save();

            if ($changed) {
                TouristSpotBookingAvailabilityHistory::create([
                    'tourist_spot_id' => $locked->id,
                    'booking_enabled' => $enabled,
                    'reason_code' => $enabled ? null : $reasonCode,
                    'reason' => $enabled ? null : $reason,
                    'changed_by' => $actor->id,
                    'changed_at' => now(),
                ]);
                ActivityLog::create([
                    'user_id' => $actor->id,
                    'action' => $enabled ? 'Tourist Spot booking enabled' : 'Tourist Spot booking disabled',
                    'details' => json_encode([
                        'tourist_spot_id' => $locked->id,
                        'tourist_spot_name' => $locked->name,
                        'booking_enabled' => $enabled,
                        'reason_code' => $enabled ? null : $reasonCode,
                        'reason' => $enabled ? null : $reason,
                    ], JSON_THROW_ON_ERROR),
                ]);
                $this->notifyRelevantTourists($locked, $actor, $enabled, $reasonCode, $reason);
                $this->notifyOperationalCounterparts($locked, $actor, $enabled, $reasonCode);
            }

            return $locked->fresh(['category', 'bookingAvailabilityUpdatedBy']);
        }, 3);
    }

    private function notifyRelevantTourists(
        TouristSpot $spot,
        User $actor,
        bool $enabled,
        ?string $reasonCode,
        ?string $reason,
    ): void {
        $profileIds = Reservation::query()
            ->where('reservable_type', 'spot')
            ->where('reservable_id', $spot->id)
            ->whereHas('status', fn ($query) => $query->whereIn('name', ['pending', 'approved', 'confirmed']))
            ->pluck('user_id')
            ->merge(
                Favorite::query()
                    ->where('favoritable_type', 'spot')
                    ->where('favoritable_id', $spot->id)
                    ->pluck('user_id'),
            )
            ->unique()
            ->reject(fn ($id) => (string) $id === (string) $actor->id);

        $label = $reasonCode ? str($reasonCode)->replace('_', ' ')->title()->toString() : null;
        foreach ($profileIds as $profileId) {
            Notification::create([
                'user_id' => $profileId,
                'type' => 'booking_availability_changed',
                'title' => $enabled ? 'Booking Available Again' : 'Booking Temporarily Unavailable',
                'body' => $enabled
                    ? "{$spot->name} is accepting new reservations again."
                    : "{$spot->name} is not accepting new reservations. Reason: ".($label ?: 'Temporarily unavailable').($reason ? " — {$reason}" : ''),
                'data' => [
                    'tourist_spot_id' => $spot->id,
                    'booking_enabled' => $enabled,
                    'reason_code' => $enabled ? null : $reasonCode,
                    'reason' => $enabled ? null : $reason,
                    'route' => "/tourist-spots/{$spot->id}",
                ],
            ]);
        }
    }

    private function notifyOperationalCounterparts(
        TouristSpot $spot,
        User $actor,
        bool $enabled,
        ?string $reasonCode,
    ): void {
        $actor->loadMissing('role');
        $label = $reasonCode ? str($reasonCode)->replace('_', ' ')->title()->toString() : null;
        $body = $enabled
            ? "{$spot->name} is accepting reservations again."
            : "{$spot->name} booking was closed".($label ? " ({$label})" : '').'.';

        if ($actor->role?->name === 'tourism_partner') {
            User::whereHas('role', fn ($query) => $query->where('name', 'lgu_staff'))
                ->pluck('id')
                ->reject(fn ($id) => (string) $id === (string) $actor->id)
                ->each(fn (string $id) => Notification::create([
                    'user_id' => $id,
                    'type' => 'partner_booking_availability_changed',
                    'title' => 'Partner Updated Booking Availability',
                    'body' => $body,
                    'data' => ['tourist_spot_id' => $spot->id, 'booking_enabled' => $enabled, 'route' => '/lgu/tourist-spots'],
                ]));

            return;
        }

        if ($actor->role?->name === 'lgu_staff') {
            $spot->partnerAssignments()->pluck('partner_profile_id')->each(
                fn (string $id) => PartnerNotification::create([
                    'user_id' => $id,
                    'type' => 'lgu_booking_availability_changed',
                    'title' => 'LGU Updated Booking Availability',
                    'body' => $body,
                    'data' => ['tourist_spot_id' => $spot->id, 'booking_enabled' => $enabled, 'route' => '/tourism-partner'],
                ]),
            );
        }
    }
}
