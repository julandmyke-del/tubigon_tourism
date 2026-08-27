<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Reservation;
use App\Models\ReservationStatus;
use App\Models\Notification;
use App\Models\PartnerNotification;
use App\Models\ActivityLog;
use App\Models\Msme;
use App\Models\TourismListing;
use App\Models\TouristSpot;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReservationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Reservation::with(['user', 'status']);

        // Filter for current user's reservations if not admin
        $user = $request->user();
        $user->loadMissing('role');
        $role = $user->role?->name;

        if ($role !== 'admin') {
            $query->where('user_id', $user->id);
        }

        if ($request->has('status')) {
            $query->whereHas('status', function ($q) use ($request) {
                $q->where('name', $request->status);
            });
        }

        $reservations = $query->orderBy('reservation_date', 'desc')->get();
        return response()->json(['status' => 'success', 'data' => $reservations]);
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $reservation = Reservation::with(['user', 'status', 'listing'])->findOrFail($id);
        $this->authorizeReservationAccess($request, $reservation);
        return response()->json(['status' => 'success', 'data' => $reservation]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'reservable_type' => 'required|in:spot,msme,tourism_listing',
            'reservable_id' => 'required|uuid',
            'reservation_date' => 'required|date|after_or_equal:today',
            'start_time' => 'nullable|date_format:H:i',
            'end_time' => 'nullable|date_format:H:i|after:start_time',
            'guests' => 'required|integer|min:1|max:100',
            'notes' => 'nullable|string|max:1000',
        ]);

        $reservable = match ($validated['reservable_type']) {
            'spot' => TouristSpot::where('is_active', true)->findOrFail($validated['reservable_id']),
            'msme' => Msme::where('is_verified', true)->findOrFail($validated['reservable_id']),
            'tourism_listing' => TourismListing::where('is_active', true)->findOrFail($validated['reservable_id']),
        };

        $hasConflict = Reservation::where('user_id', $request->user()->id)
            ->where('reservable_type', $validated['reservable_type'])
            ->where('reservable_id', $validated['reservable_id'])
            ->whereDate('reservation_date', $validated['reservation_date'])
            ->where('start_time', $validated['start_time'] ?? null)
            ->whereHas('status', fn ($query) => $query->whereNotIn('name', ['cancelled', 'rejected']))
            ->exists();
        if ($hasConflict) {
            return response()->json([
                'status' => 'error',
                'message' => 'You already have a reservation for this place and time.',
            ], 422);
        }

        $pendingStatus = ReservationStatus::where('name', 'pending')->first();
        $validated['user_id'] = $request->user()->id;
        $validated['status_id'] = $pendingStatus?->id;
        $validated['partner_id'] = $validated['reservable_type'] === 'tourism_listing'
            ? $reservable->owner_id
            : null;
        $validated['total_amount'] = $validated['reservable_type'] === 'spot'
            ? ((float) $reservable->entrance_fee * (int) $validated['guests'])
            : 0;

        $reservation = Reservation::create($validated);

        // Notify partner if applicable
        if (!empty($validated['partner_id'])) {
            PartnerNotification::create([
                'user_id' => $validated['partner_id'],
                'type' => 'new_reservation',
                'title' => 'New Reservation',
                'body' => 'You have a new reservation request.',
                'data' => ['reservation_id' => $reservation->id],
            ]);
        }

        return response()->json([
            'status' => 'success',
            'data' => $reservation->load(['user', 'status']),
        ], 201);
    }

    public function updateStatus(Request $request, string $id): JsonResponse
    {
        $request->validate(['status_id' => 'required|exists:reservation_status,id']);

        $reservation = Reservation::findOrFail($id);
        $reservation->update(['status_id' => $request->status_id]);

        // Get status name for notification
        $status = ReservationStatus::find($request->status_id);

        // Notify tourist
        Notification::create([
            'user_id' => $reservation->user_id,
            'type' => 'reservation_' . ($status?->name ?? 'updated'),
            'title' => 'Reservation ' . ucfirst($status?->name ?? 'Updated'),
            'body' => "Your reservation has been {$status?->name}.",
            'data' => ['reservation_id' => $id, 'status' => $status?->name],
        ]);

        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => 'Reservation updated',
            'details' => "Updated reservation status for ID $id",
        ]);

        return response()->json(['status' => 'success', 'message' => 'Reservation status updated']);
    }

    public function cancel(Request $request, string $id): JsonResponse
    {
        $reservation = Reservation::with('status')->findOrFail($id);
        $this->authorizeReservationAccess($request, $reservation);
        if (in_array($reservation->status?->name, ['completed', 'cancelled', 'rejected'], true)) {
            return response()->json([
                'status' => 'error',
                'message' => 'This reservation can no longer be cancelled.',
            ], 422);
        }
        $cancelledStatus = ReservationStatus::where('name', 'cancelled')->first();
        $reservation->update(['status_id' => $cancelledStatus?->id]);

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
        if ($user->role?->name !== 'admin' && (string) $reservation->user_id !== (string) $user->id) {
            abort(403, 'You may only access your own reservations.');
        }
    }
}
