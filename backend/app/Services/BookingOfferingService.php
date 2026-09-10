<?php

namespace App\Services;

use App\Models\BookingOffering;
use App\Models\Notification;
use App\Models\PartnerNotification;
use App\Models\Reservation;
use App\Models\ReservationItem;
use App\Models\ReservationMessage;
use App\Models\ReservationStatus;
use App\Models\ReservationStatusHistory;
use App\Models\TouristSpot;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class BookingOfferingService
{
    public function __construct(private readonly TouristSpotBookingService $spotBooking) {}

    public function create(User $tourist, array $data): Reservation
    {
        return DB::transaction(function () use ($tourist, $data): Reservation {
            if (! empty($data['client_submission_id'])) {
                $existing = Reservation::where('user_id', $tourist->id)->where('client_submission_id', $data['client_submission_id'])->first();
                if ($existing) {
                    return $existing->load(['items', 'status', 'messages']);
                }
            }
            $spot = TouristSpot::whereKey($data['tourist_spot_id'])->lockForUpdate()->firstOrFail();
            abort_unless($spot->is_active && $spot->is_published && $spot->is_bookable && $spot->booking_enabled, 422, 'Booking is unavailable for this destination.');
            $requested = collect($data['items'])->keyBy('offering_id');
            $offerings = BookingOffering::with('fields')->whereIn('id', $requested->keys())->orderBy('id')->lockForUpdate()->get();
            abort_if($offerings->count() !== $requested->count(), 422, 'One or more booking offerings are unavailable.');
            $total = 0.0;
            $guestCount = 1;
            $lines = [];
            foreach ($offerings as $offering) {
                abort_unless((string) $offering->tourist_spot_id === (string) $spot->id && $offering->is_active, 422, 'Every offering must be active and belong to the selected destination.');
                $input = $requested[$offering->id];
                $quantity = (int) $input['quantity'];
                $details = $input['booking_details'] ?? [];
                abort_if($quantity < $offering->min_quantity || ($offering->max_quantity && $quantity > $offering->max_quantity), 422, "Invalid quantity for {$offering->display_name}.");
                $date = Carbon::parse($data['reservation_date']);
                $day = strtolower($date->format('l'));
                abort_if($offering->available_days && ! in_array($day, $offering->available_days, true), 422, "{$offering->display_name} is unavailable on that day.");
                abort_if(in_array($date->toDateString(), $offering->blackout_dates ?? [], true), 422, "{$offering->display_name} is unavailable on that date.");
                if ($offering->max_advance_days) {
                    abort_if($date->gt(now()->addDays($offering->max_advance_days)), 422, 'The booking date is outside the allowed window.');
                }
                if ($offering->lead_time_minutes) {
                    abort_if(Carbon::parse($date->toDateString().' '.($data['start_time'] ?? '23:59'))->lt(now()->addMinutes($offering->lead_time_minutes)), 422, 'The booking does not meet the required lead time.');
                }
                if ($offering->time_slots) {
                    abort_unless(collect($offering->time_slots)->contains(fn ($s) => ($s['start'] ?? null) === ($data['start_time'] ?? null)), 422, 'Select an available offering time slot.');
                }
                foreach ($offering->fields->where('is_active', true) as $field) {
                    $value = $details[$field->field_key] ?? null;
                    if ($field->is_required && ($value === null || $value === '' || $value === [])) {
                        throw ValidationException::withMessages(["items.{$offering->id}.{$field->field_key}" => ["{$field->label} is required."]]);
                    }
                    if ($value !== null && in_array($field->field_type, ['select', 'multi_select'], true)) {
                        $values = is_array($value) ? $value : [$value];
                        abort_if(array_diff($values, $field->options_json ?? []) !== [], 422, "Invalid option for {$field->label}.");
                    }
                }
                $people = isset($details['guest_count'])
                    ? (int) $details['guest_count']
                    : max(1, (int) ($details['adult_count'] ?? 0) + (int) ($details['child_count'] ?? 0));
                if ($offering->capacity_per_unit) {
                    abort_if($people > $offering->capacity_per_unit * $quantity, 422, "Guest count exceeds the capacity for {$offering->display_name}.");
                }
                $used = ReservationItem::where('offering_id', $offering->id)->whereHas('reservation', fn ($q) => $q->whereDate('reservation_date', $date->toDateString())->where('start_time', $data['start_time'] ?? null)->whereHas('status', fn ($s) => $s->whereIn('name', ['pending', 'approved', 'confirmed'])))->sum('quantity');
                if ($offering->quantity_available) {
                    abort_if($used + $quantity > $offering->quantity_available, 422, "{$offering->display_name} no longer has enough availability.");
                }
                $multiplier = match ($offering->pricing_mode) {
                    'per_person' => (int) ($details['guest_count'] ?? $details['persons'] ?? $quantity),'per_adult' => (int) ($details['adult_count'] ?? $quantity),'per_child' => (int) ($details['child_count'] ?? $quantity),'per_room_per_night' => (int) ($details['nights'] ?? 1) * $quantity,'per_hour' => (int) ($details['hours'] ?? 1) * $quantity,'per_day' => (int) ($details['days'] ?? 1) * $quantity,default => $quantity
                };
                $guestCount = max($guestCount, $people);
                $subtotal = round($offering->price * $multiplier, 2);
                $total += $subtotal;
                $lines[] = [$offering, $quantity, $details, $subtotal];
            }
            $spotRules = $this->spotBooking->validate(
                $spot,
                $data['reservation_date'],
                $data['start_time'] ?? null,
                $guestCount,
            );
            $partnerId = $spot->partnerAssignments()->where('is_primary', true)->orderBy('assigned_at')->value('partner_profile_id') ?? $spot->partnerAssignments()->orderBy('assigned_at')->value('partner_profile_id');
            abort_unless($partnerId, 422, 'This destination does not have an assigned booking Partner.');
            $status = ReservationStatus::where('name', 'pending')->firstOrFail();
            $reservation = Reservation::create(['user_id' => $tourist->id, 'partner_id' => $partnerId, 'tourist_spot_id' => $spot->id, 'reservable_type' => 'spot', 'reservable_id' => $spot->id, 'reservation_date' => $spotRules['reservation_date'], 'start_time' => $spotRules['start_time'], 'end_time' => $spotRules['end_time'] ?? ($data['end_time'] ?? null), 'guests' => $guestCount, 'status_id' => $status->id, 'notes' => $data['notes'] ?? null, 'total_amount' => round($total, 2), 'customer_name_snapshot' => $tourist->name, 'customer_email_snapshot' => $tourist->email, 'customer_phone_snapshot' => $tourist->phone, 'client_submission_id' => $data['client_submission_id'] ?? null]);
            foreach ($lines as [$o,$q,$details,$subtotal]) {
                ReservationItem::create(['reservation_id' => $reservation->id, 'offering_id' => $o->id, 'offering_name_snapshot' => $o->display_name, 'offering_type_snapshot' => $o->type, 'quantity' => $q, 'unit_price_snapshot' => $o->price, 'pricing_mode_snapshot' => $o->pricing_mode, 'subtotal' => $subtotal, 'booking_details' => $details]);
            }
            ReservationStatusHistory::create(['reservation_id' => $reservation->id, 'status_id' => $status->id, 'changed_by' => $tourist->id, 'notes' => 'Reservation submitted with authoritative offering price snapshots']);
            ReservationMessage::create(['reservation_id' => $reservation->id, 'sender_role_at_time' => 'system', 'message' => 'Reservation submitted', 'message_type' => 'system_update', 'is_internal' => false]);
            Notification::create(['user_id' => $tourist->id, 'type' => 'reservation_submitted', 'title' => 'Reservation Submitted', 'body' => "Your reservation for {$spot->name} is pending review.", 'data' => ['reservation_id' => $reservation->id, 'route' => "/reservations/{$reservation->id}"]]);
            PartnerNotification::create(['user_id' => $partnerId, 'type' => 'new_reservation', 'title' => 'New Reservation', 'body' => "A new reservation was requested for {$spot->name}.", 'data' => ['reservation_id' => $reservation->id, 'route' => '/tourism-partner/reservations']]);

            return $reservation->load(['items', 'status', 'messages']);
        }, 3);
    }
}
