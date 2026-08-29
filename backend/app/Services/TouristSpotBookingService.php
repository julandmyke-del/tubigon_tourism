<?php

namespace App\Services;

use App\Models\Reservation;
use App\Models\TouristSpot;
use Illuminate\Support\Carbon;
use Illuminate\Validation\ValidationException;

class TouristSpotBookingService
{
    public const DEFAULT_ADVANCE_BOOKING_DAYS = 365;

    /** @return array{date: string, booking_mode: string, available: bool, remaining_capacity: ?int, slots: list<array<string, mixed>>} */
    public function availability(TouristSpot $spot, string $date): array
    {
        if ($spot->booking_mode === 'date_time_slot') {
            $slots = [];
            foreach ($spot->booking_time_slots ?? [] as $slot) {
                if (! is_array($slot) || ! isset($slot['start'])) {
                    continue;
                }
                try {
                    $result = $this->validate($spot, $date, (string) $slot['start'], 1);
                    $slots[] = [
                        'start' => $result['start_time'],
                        'end' => $result['end_time'],
                        'available' => $result['remaining_capacity'] === null || $result['remaining_capacity'] > 0,
                        'remaining_capacity' => $result['remaining_capacity'],
                    ];
                } catch (ValidationException) {
                    $slots[] = [
                        'start' => (string) $slot['start'],
                        'end' => $slot['end'] ?? null,
                        'available' => false,
                        'remaining_capacity' => 0,
                    ];
                }
            }

            return [
                'date' => $date,
                'booking_mode' => $spot->booking_mode,
                'available' => collect($slots)->contains('available', true),
                'remaining_capacity' => null,
                'slots' => $slots,
            ];
        }

        $result = $this->validate($spot, $date, null, 1);

        return [
            'date' => $date,
            'booking_mode' => $spot->booking_mode,
            'available' => $result['remaining_capacity'] === null || $result['remaining_capacity'] > 0,
            'remaining_capacity' => $result['remaining_capacity'],
            'slots' => [],
        ];
    }

    /**
     * Validate authoritative spot rules and return server-selected booking data.
     * Call this while holding a lock on the tourist_spots row.
     *
     * @return array{reservation_date: string, start_time: ?string, end_time: ?string, capacity: ?int, remaining_capacity: ?int}
     */
    public function validate(
        TouristSpot $spot,
        string $dateValue,
        ?string $startTime,
        int $guests,
    ): array {
        $this->ensurePublicAndBookable($spot);

        $date = Carbon::createFromFormat('Y-m-d', substr($dateValue, 0, 10), config('app.timezone'))->startOfDay();
        $today = now()->startOfDay();
        $this->reject($date->lt($today), 'The selected booking date has already passed.');

        $availableDays = array_map('strtolower', $spot->booking_available_days ?? []);
        $this->reject(
            $availableDays !== [] && ! in_array(strtolower($date->format('l')), $availableDays, true),
            'The destination is not available on the selected day.',
        );

        $advanceBookingDays = $spot->advance_booking_days
            ?? self::DEFAULT_ADVANCE_BOOKING_DAYS;
        $this->reject(
            $date->gt($today->copy()->addDays($advanceBookingDays)),
            'The selected date is outside the advance booking window.',
        );

        if ($spot->max_guests_per_reservation !== null) {
            $this->reject(
                $guests > $spot->max_guests_per_reservation,
                'Guest count exceeds the maximum allowed per reservation.',
            );
        }

        $normalizedStart = null;
        $endTime = null;
        $slotCapacity = null;
        if ($spot->booking_mode === 'date_time_slot') {
            $normalizedStart = $startTime ? substr($startTime, 0, 5) : null;
            $this->reject($normalizedStart === null, 'Select an available time slot.');
            $slot = collect($spot->booking_time_slots ?? [])->first(
                fn ($item) => is_array($item) && ($item['start'] ?? null) === $normalizedStart,
            );
            $this->reject($slot === null, 'The selected time slot is not available.');
            $endTime = isset($slot['end']) ? substr((string) $slot['end'], 0, 5) : null;
            $slotCapacity = isset($slot['capacity']) ? (int) $slot['capacity'] : null;
        } else {
            $this->reject($startTime !== null, 'This destination accepts date-only reservations.');
        }

        $bookingMoment = $normalizedStart
            ? Carbon::parse($date->toDateString().' '.$normalizedStart, config('app.timezone'))
            : $date->copy()->endOfDay();
        $this->reject($bookingMoment->isPast(), 'The selected booking time has already passed.');
        if ($spot->minimum_notice_hours !== null) {
            $this->reject(
                $bookingMoment->lt(now()->addHours($spot->minimum_notice_hours)),
                'The booking does not meet the minimum notice period.',
            );
        }

        $capacity = $slotCapacity ?? $spot->capacity_per_slot;
        $remaining = null;
        if ($capacity !== null) {
            $reservedGuests = Reservation::where('reservable_type', 'spot')
                ->where('reservable_id', $spot->id)
                ->whereDate('reservation_date', $date->toDateString())
                ->where('start_time', $normalizedStart)
                ->whereHas('status', fn ($query) => $query->whereIn('name', ['pending', 'approved', 'confirmed']))
                ->sum('guests');
            $remaining = max(0, (int) $capacity - (int) $reservedGuests);
            $this->reject($guests > $remaining, 'The selected date or time slot does not have enough capacity.');
        }

        return [
            'reservation_date' => $date->toDateString(),
            'start_time' => $normalizedStart,
            'end_time' => $endTime,
            'capacity' => $capacity,
            'remaining_capacity' => $remaining,
        ];
    }

    public function ensurePublicAndBookable(TouristSpot $spot): void
    {
        $this->reject(! $spot->is_active, 'This destination is inactive.');
        $this->reject(! $spot->is_published, 'This destination is not published.');
        $this->reject(! $spot->is_bookable, 'This destination is not configured to support reservations.');
        if (! $spot->booking_enabled) {
            $label = $spot->booking_unavailable_reason_code
                ? str($spot->booking_unavailable_reason_code)->replace('_', ' ')->title()->toString()
                : 'Temporarily unavailable';
            $detail = $spot->booking_unavailable_reason
                ? " {$spot->booking_unavailable_reason}"
                : '';
            $this->reject(true, "Booking is currently unavailable. Reason: {$label}.{$detail}");
        }
        $this->reject(
            ! in_array($spot->booking_mode, ['date_only', 'date_time_slot'], true),
            'This destination does not have a valid reservation mode.',
        );
    }

    private function reject(bool $condition, string $message): void
    {
        if ($condition) {
            throw ValidationException::withMessages(['reservation' => [$message]]);
        }
    }
}
