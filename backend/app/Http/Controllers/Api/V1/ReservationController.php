<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Msme;
use App\Models\Notification;
use App\Models\PartnerNotification;
use App\Models\Reservation;
use App\Models\ReservationStatus;
use App\Models\ReservationStatusHistory;
use App\Models\SystemSetting;
use App\Models\TourismListing;
use App\Models\TouristSpot;
use App\Services\EmailNotificationService;
use App\Services\TouristSpotBookingService;
use App\Support\ReservationStatusTransitions;
use App\Support\StaleRecordGuard;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class ReservationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Reservation::with(['user', 'status']);

        // Filter for current user's reservations if not admin
        $user = $request->user();
        $user->loadMissing('role');
        $role = $user->role?->name;

        if ($role === 'lgu_staff') {
            $query->where('reservable_type', 'spot');
        } elseif ($role !== 'admin') {
            $query->where('user_id', $user->id);
        }

        if ($request->has('status')) {
            $query->whereHas('status', function ($q) use ($request) {
                $q->where('name', $request->status);
            });
        }

        $reservations = $query->orderBy('reservation_date', 'desc')->get()
            ->map(fn (Reservation $reservation) => $this->reservationPayload($reservation));

        return response()->json(['status' => 'success', 'data' => $reservations]);
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $relations = ['user', 'status', 'listing'];
        if (Schema::hasTable('reservation_items')) {
            $relations[] = 'items';
        }
        if (Schema::hasTable('reservation_status_history')) {
            $relations[] = 'statusHistory.status';
        }
        $reservation = Reservation::with($relations)->findOrFail($id);
        $this->authorizeReservationAccess($request, $reservation);

        return response()->json([
            'status' => 'success',
            'data' => $this->reservationPayload($reservation),
        ]);
    }

    public function store(
        Request $request,
        TouristSpotBookingService $spotBooking,
        EmailNotificationService $emailDelivery,
    ): JsonResponse {
        abort_unless(SystemSetting::enabled('global_booking_enabled'), 403, 'Booking is currently disabled.');
        $validated = $request->validate([
            'reservable_type' => 'required|in:spot,msme,tourism_listing',
            'reservable_id' => 'required|uuid',
            'reservation_date' => 'required|date|after_or_equal:today',
            'start_time' => 'nullable|date_format:H:i',
            'end_time' => 'nullable|date_format:H:i|after:start_time',
            'guests' => 'required|integer|min:1|max:100',
            'notes' => 'nullable|string|max:1000',
        ]);

        [$reservation, $reservable] = DB::transaction(function () use ($request, $validated, $spotBooking): array {
            $reservable = match ($validated['reservable_type']) {
                'spot' => TouristSpot::whereKey($validated['reservable_id'])->lockForUpdate()->firstOrFail(),
                'msme' => Msme::where('is_verified', true)
                    ->where('verification_status', 'verified')
                    ->lockForUpdate()->findOrFail($validated['reservable_id']),
                'tourism_listing' => TourismListing::where('is_active', true)
                    ->where('approval_status', 'approved')
                    ->lockForUpdate()->findOrFail($validated['reservable_id']),
            };

            if ($reservable instanceof Msme) {
                abort_unless(
                    $reservable->booking_enabled && $reservable->operational_status === 'open',
                    422,
                    'Reservations are currently unavailable for this business.',
                );
            }

            if ($validated['reservable_type'] === 'spot') {
                $serverBooking = $spotBooking->validate(
                    $reservable,
                    $validated['reservation_date'],
                    $validated['start_time'] ?? null,
                    (int) $validated['guests'],
                );
                $validated['reservation_date'] = $serverBooking['reservation_date'];
                $validated['start_time'] = $serverBooking['start_time'];
                $validated['end_time'] = $serverBooking['end_time'];
            } else {
                $bookingMoment = Carbon::parse($validated['reservation_date'].' '.($validated['start_time'] ?? '00:00'));
                abort_if($bookingMoment->isPast(), 422, 'The selected booking time has already passed.');
                if ($validated['reservable_type'] === 'msme') {
                    abort_if(in_array($validated['reservation_date'], $reservable->unavailable_dates ?? [], true), 422, 'The business is unavailable on the selected date.');
                    $hours = $reservable->opening_hours[strtolower($bookingMoment->format('l'))] ?? null;
                    abort_if(is_array($hours) && ($hours['closed'] ?? false), 422, 'The business is closed on the selected day.');
                    if (is_array($hours) && ($validated['start_time'] ?? null) !== null) {
                        $time = substr($validated['start_time'], 0, 5);
                        abort_if(($hours['open'] ?? null) && $time < $hours['open'], 422, 'The selected time is before opening.');
                        abort_if(($hours['close'] ?? null) && $time >= $hours['close'], 422, 'The selected time is after closing.');
                    }
                }
                if ($reservable instanceof TourismListing) {
                    abort_if($reservable->capacity !== null && (int) $validated['guests'] > $reservable->capacity, 422, 'Guest count exceeds this listing\'s capacity.');
                    $day = strtolower($bookingMoment->format('l'));
                    abort_if(! empty($reservable->available_days) && ! in_array($day, $reservable->available_days, true), 422, 'This listing is not available on the selected day.');
                    abort_if($reservable->booking_cutoff_hours !== null && $bookingMoment->lt(now()->addHours($reservable->booking_cutoff_hours)), 422, 'This booking is inside the listing cutoff period.');
                }
            }

            $hasConflict = Reservation::where('user_id', $request->user()->id)
                ->where('reservable_type', $validated['reservable_type'])
                ->where('reservable_id', $validated['reservable_id'])
                ->whereDate('reservation_date', $validated['reservation_date'])
                ->where('start_time', $validated['start_time'] ?? null)
                ->whereHas('status', fn ($query) => $query->whereNotIn('name', ['cancelled', 'rejected']))
                ->exists();
            abort_if($hasConflict, 422, 'You already have a reservation for this place and time.');

            $pendingStatus = ReservationStatus::where('name', 'pending')->firstOrFail();
            $validated['user_id'] = $request->user()->id;
            $validated['status_id'] = $pendingStatus->id;
            $validated['partner_id'] = match ($validated['reservable_type']) {
                'tourism_listing' => $reservable->owner_id,
                'msme' => $reservable->profile_id,
                'spot' => $reservable->partnerAssignments()
                    ->where('is_primary', true)
                    ->orderBy('assigned_at')
                    ->value('partner_profile_id')
                    ?? $reservable->partnerAssignments()->orderBy('assigned_at')->value('partner_profile_id'),
            };
            $validated['total_amount'] = match ($validated['reservable_type']) {
                'spot' => $reservable->reservation_fee === null
                    ? 0
                    : (float) $reservable->reservation_fee * (int) $validated['guests'],
                'tourism_listing' => (float) ($reservable->price ?? 0) * (int) $validated['guests'],
                default => 0,
            };

            $reservation = Reservation::create($validated);
            $this->recordStatusHistory($reservation, $pendingStatus->id, (string) $request->user()->id, 'Reservation submitted');
            Notification::create([
                'user_id' => $request->user()->id,
                'type' => 'reservation_submitted',
                'title' => 'Reservation Submitted',
                'body' => "Your reservation for {$this->reservableName($validated['reservable_type'], $reservable)} is pending review.",
                'data' => ['reservation_id' => $reservation->id, 'route' => "/reservations/{$reservation->id}"],
            ]);

            return [$reservation, $reservable];
        }, 3);

        // Notify partner if applicable
        if (in_array($validated['reservable_type'], ['tourism_listing', 'spot'], true)
            && ! empty($validated['partner_id'])) {
            PartnerNotification::create([
                'user_id' => $validated['partner_id'],
                'type' => 'new_reservation',
                'title' => 'New Reservation',
                'body' => "A new reservation was requested for {$this->reservableName($validated['reservable_type'], $reservable)}.",
                'data' => [
                    'reservation_id' => $reservation->id,
                    'tourist_spot_id' => $validated['reservable_type'] === 'spot' ? $reservable->id : null,
                    'route' => '/tourism-partner/reservations',
                ],
            ]);
        }
        if ($validated['reservable_type'] === 'msme' && ! empty($validated['partner_id'])) {
            Notification::create([
                'user_id' => $validated['partner_id'],
                'type' => 'new_reservation',
                'title' => 'New Reservation',
                'body' => "A new reservation was requested for {$reservable->name}.",
                'data' => ['reservation_id' => $reservation->id, 'route' => '/msme-portal/reservations'],
            ]);
        }

        // Send only after the reservation and its in-app notifications committed.
        $emailDelivery->reservation($reservation, 'submitted');

        return response()->json([
            'status' => 'success',
            'data' => $this->reservationPayload($reservation->load(
                Schema::hasTable('reservation_status_history')
                    ? ['user', 'status', 'statusHistory.status']
                    : ['user', 'status'],
            )),
        ], 201);
    }

    public function updateStatus(Request $request, string $id, EmailNotificationService $emailDelivery): JsonResponse
    {
        $request->validate(['status_id' => 'required|exists:reservation_status,id']);
        $expectedUpdatedAt = StaleRecordGuard::expectedUpdatedAt($request);

        $status = ReservationStatus::findOrFail($request->status_id);
        $request->user()->loadMissing('role');
        $reservation = DB::transaction(function () use ($request, $id, $status, $expectedUpdatedAt): Reservation {
            $reservation = Reservation::with('status')->lockForUpdate()->findOrFail($id);
            if ($request->user()->role?->name === 'lgu_staff' && $reservation->reservable_type !== 'spot') {
                abort(403, 'LGU staff may only manage municipal tourist-spot reservations.');
            }
            StaleRecordGuard::assertCurrent($reservation, $expectedUpdatedAt, [
                'status' => $reservation->status?->name,
            ], 'This reservation was updated in another session. Refresh and try again.');
            if (! ReservationStatusTransitions::allows($reservation->status?->name, $status->name)) {
                abort(response()->json([
                    'status' => 'error',
                    'message' => "A {$reservation->status?->name} reservation cannot transition to {$status->name}.",
                    'allowed_statuses' => ReservationStatusTransitions::allowedFrom($reservation->status?->name),
                ], 422));
            }
            $reservation->update(['status_id' => $request->status_id]);
            $this->recordStatusHistory(
                $reservation,
                $status->id,
                (string) $request->user()->id,
                'Status updated by authorized staff',
            );
            Notification::create([
                'user_id' => $reservation->user_id,
                'type' => 'reservation_'.($status?->name ?? 'updated'),
                'title' => 'Reservation '.ucfirst($status?->name ?? 'Updated'),
                'body' => "Your reservation has been {$status?->name}.",
                'data' => [
                    'reservation_id' => $id,
                    'status' => $status?->name,
                    'route' => "/reservations/{$id}",
                ],
            ]);
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'Reservation updated',
                'details' => "Updated reservation status for ID $id",
            ]);

            return $reservation;
        });

        if (in_array($status->name, ['approved', 'confirmed', 'rejected', 'cancelled'], true)) {
            $emailDelivery->reservation($reservation, $status->name);
        }

        return response()->json(['status' => 'success', 'message' => 'Reservation status updated']);
    }

    public function cancel(Request $request, string $id, EmailNotificationService $emailDelivery): JsonResponse
    {
        $expectedUpdatedAt = StaleRecordGuard::expectedUpdatedAt($request);
        $reservation = DB::transaction(function () use ($request, $id, $expectedUpdatedAt): Reservation {
            $reservation = Reservation::with('status')->lockForUpdate()->findOrFail($id);
            $this->authorizeReservationAccess($request, $reservation);
            StaleRecordGuard::assertCurrent($reservation, $expectedUpdatedAt, [
                'status' => $reservation->status?->name,
            ], 'This reservation was updated in another session. Refresh and try again.');
            abort_if(
                in_array($reservation->status?->name, ['completed', 'cancelled', 'rejected'], true),
                422,
                'This reservation can no longer be cancelled.',
            );

            if ($reservation->reservable_type === 'spot') {
                $spot = TouristSpot::withTrashed()->find($reservation->reservable_id);
                if ($spot?->cancellation_notice_hours !== null) {
                    $time = $reservation->start_time ?: '00:00';
                    $bookingMoment = Carbon::parse($reservation->reservation_date->toDateString().' '.$time);
                    abort_if(
                        $bookingMoment->lt(now()->addHours($spot->cancellation_notice_hours)),
                        422,
                        'This reservation is inside the configured cancellation notice period.',
                    );
                }
            }

            $cancelledStatus = ReservationStatus::where('name', 'cancelled')->firstOrFail();
            $reservation->update(['status_id' => $cancelledStatus->id]);
            $this->recordStatusHistory(
                $reservation,
                $cancelledStatus->id,
                (string) $request->user()->id,
                'Cancelled by tourist',
            );
            Notification::create([
                'user_id' => $reservation->user_id,
                'type' => 'reservation_cancelled',
                'title' => 'Reservation Cancelled',
                'body' => 'Your reservation has been cancelled.',
                'data' => ['reservation_id' => $id, 'route' => "/reservations/{$id}"],
            ]);

            return $reservation;
        });

        $emailDelivery->reservation($reservation, 'cancelled');

        return response()->json(['status' => 'success', 'message' => 'Reservation cancelled']);
    }

    public function statuses(): JsonResponse
    {
        $statuses = ReservationStatus::select('id', 'name')->get();

        return response()->json(['status' => 'success', 'data' => $statuses]);
    }

    private function authorizeReservationAccess(Request $request, Reservation $reservation): void
    {
        $user = $request->user();
        $user->loadMissing('role');
        if ($user->role?->name === 'lgu_staff' && $reservation->reservable_type === 'spot') {
            return;
        }
        if ($user->role?->name !== 'admin' && (string) $reservation->user_id !== (string) $user->id) {
            abort(403, 'You may only access your own reservations.');
        }
    }

    private function reservationPayload(Reservation $reservation): array
    {
        $reservable = match ($reservation->reservable_type) {
            'spot' => TouristSpot::withTrashed()->find($reservation->reservable_id),
            'msme' => Msme::withTrashed()->find($reservation->reservable_id),
            'tourism_listing' => TourismListing::withTrashed()->find($reservation->reservable_id),
            default => null,
        };
        $name = $reservable ? $this->reservableName($reservation->reservable_type, $reservable) : null;
        $images = is_array($reservable?->images) ? $reservable->images : [];

        return array_merge($reservation->toArray(), [
            'reservable_name' => $name,
            'reservable_image' => $images[0] ?? null,
            'latitude' => $reservable?->latitude,
            'longitude' => $reservable?->longitude,
            'booking_instructions' => $reservation->reservable_type === 'spot'
                ? $reservable?->booking_instructions
                : null,
            'cancellation_policy' => $reservation->reservable_type === 'spot'
                ? $reservable?->cancellation_policy
                : null,
            'fee_configured' => $reservation->reservable_type === 'spot'
                ? $reservable?->reservation_fee !== null
                : true,
            'allowed_transitions' => ReservationStatusTransitions::allowedFrom(
                $reservation->status?->name,
            ),
            'unread_message_count' => Schema::hasTable('reservation_messages')
                ? $reservation->messages()->where('is_internal', false)->where('sender_user_id', '!=', $reservation->user_id)->whereDoesntHave('readers', fn ($q) => $q->where('users.id', $reservation->user_id))->count()
                : 0,
        ]);
    }

    private function recordStatusHistory(
        Reservation $reservation,
        string $statusId,
        ?string $changedBy,
        ?string $notes,
    ): void {
        if (! Schema::hasTable('reservation_status_history')) {
            return;
        }
        ReservationStatusHistory::create([
            'reservation_id' => $reservation->id,
            'status_id' => $statusId,
            'changed_by' => $changedBy,
            'notes' => $notes,
        ]);
    }

    private function reservableName(string $type, object $reservable): string
    {
        return $type === 'tourism_listing'
            ? (string) $reservable->listing_name
            : (string) $reservable->name;
    }
}
