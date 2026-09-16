<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Notification;
use App\Models\Reservation;
use App\Models\ReservationMessage;
use App\Models\ReservationStatus;
use App\Models\ReservationStatusHistory;
use App\Models\TourismListing;
use App\Models\TouristSpot;
use App\Models\TouristSpotPartnerAssignment;
use App\Services\EmailNotificationService;
use App\Support\ReservationStatusTransitions;
use App\Support\StaleRecordGuard;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\Rule;

class PartnerReservationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'status_filter' => ['nullable', Rule::in(['pending', 'approved', 'confirmed', 'rejected', 'completed', 'cancelled'])],
            'search' => 'nullable|string|max:200',
            'scope' => ['nullable', Rule::in(['today', 'upcoming'])],
            'from' => 'nullable|date',
            'to' => 'nullable|date|after_or_equal:from',
            'sort' => ['nullable', Rule::in(['visit_asc', 'visit_desc', 'newest'])],
        ]);
        [$spotIds, $listingIds] = $this->ownedTargetIds($request);
        $relations = ['user:id,name,phone', 'status'];
        if (Schema::hasTable('reservation_items')) {
            $relations[] = 'items';
        }
        $query = Reservation::with($relations);
        $this->scopeOwned($query, $spotIds, $listingIds);

        if (! empty($validated['status_filter'])) {
            $query->whereHas('status', fn ($status) => $status
                ->where('name', $validated['status_filter']));
        }
        if (! empty($validated['search'])) {
            $needle = '%'.strtolower(trim($validated['search'])).'%';
            $query->where(function (Builder $search) use ($needle): void {
                $search->whereRaw('LOWER(COALESCE(public_reference, ?)) LIKE ?', ['', $needle])
                    ->orWhereHas('user', fn ($user) => $user->whereRaw('LOWER(name) LIKE ?', [$needle]));
            });
        }
        if (($validated['scope'] ?? null) === 'today') {
            $query->whereDate('reservation_date', now()->toDateString());
        } elseif (($validated['scope'] ?? null) === 'upcoming') {
            $query->whereDate('reservation_date', '>=', now()->toDateString());
        }
        if (! empty($validated['from'])) {
            $query->whereDate('reservation_date', '>=', $validated['from']);
        }
        if (! empty($validated['to'])) {
            $query->whereDate('reservation_date', '<=', $validated['to']);
        }

        match ($validated['sort'] ?? 'visit_asc') {
            'visit_desc' => $query->orderByDesc('reservation_date'),
            'newest' => $query->latest('created_at'),
            default => $query->orderBy('reservation_date'),
        };

        return response()->json([
            'status' => 'success',
            'data' => $query->get()
                ->map(fn (Reservation $reservation) => $this->payload($reservation)),
            'meta' => ['summary' => $this->summary($request)],
        ]);
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $relations = ['user:id,name,phone', 'status', 'statusHistory.status', 'statusHistory.changedBy:id,name'];
        if (Schema::hasTable('reservation_items')) {
            $relations[] = 'items';
        }
        $reservation = Reservation::with($relations)->findOrFail($id);
        $this->authorizeOwnership($request, $reservation);

        return response()->json(['status' => 'success', 'data' => $this->payload($reservation)]);
    }

    public function updateStatus(Request $request, string $id, EmailNotificationService $emailDelivery): JsonResponse
    {
        $validated = $request->validate([
            'status_name' => 'required|string|in:approved,confirmed,rejected,completed,cancelled',
            'reason' => 'nullable|required_if:status_name,rejected|string|max:1000',
        ]);
        $expectedUpdatedAt = StaleRecordGuard::expectedUpdatedAt($request);

        $reservation = DB::transaction(function () use ($request, $id, $validated, $expectedUpdatedAt): Reservation {
            $reservation = Reservation::with('status')->lockForUpdate()->findOrFail($id);
            $this->authorizeOwnership($request, $reservation);
            StaleRecordGuard::assertCurrent($reservation, $expectedUpdatedAt, [
                'status' => $reservation->status?->name,
            ], 'This reservation was updated in another session. Refresh and try again.');
            $status = ReservationStatus::where('name', $validated['status_name'])->firstOrFail();

            if (! ReservationStatusTransitions::allows($reservation->status?->name, $status->name)) {
                abort(response()->json([
                    'status' => 'error',
                    'message' => "A {$reservation->status?->name} reservation cannot transition to {$status->name}.",
                    'allowed_statuses' => ReservationStatusTransitions::allowedFrom($reservation->status?->name),
                ], 422));
            }

            $reservation->update(['status_id' => $status->id]);
            if (Schema::hasTable('reservation_messages')) {
                ReservationMessage::create([
                    'reservation_id' => $reservation->id,
                    'sender_user_id' => null,
                    'sender_role_at_time' => 'system',
                    'message' => 'Reservation '.ucfirst($status->name),
                    'message_type' => 'system_update',
                    'is_internal' => false,
                ]);
            }
            if (Schema::hasTable('reservation_status_history')) {
                ReservationStatusHistory::create([
                    'reservation_id' => $reservation->id,
                    'status_id' => $status->id,
                    'changed_by' => $request->user()->id,
                    'notes' => $validated['status_name'] === 'rejected'
                        ? 'Rejected by assigned Tourism Partner: '.trim($validated['reason'])
                        : 'Status updated by assigned Tourism Partner',
                ]);
            }

            $name = $this->targetName($reservation);
            Notification::create([
                'user_id' => $reservation->user_id,
                'type' => "reservation_{$status->name}",
                'title' => 'Reservation '.ucfirst($status->name),
                'body' => "Your reservation for {$name} has been {$status->name}.",
                'data' => [
                    'reservation_id' => $reservation->id,
                    'status' => $status->name,
                    'reason' => $validated['status_name'] === 'rejected' ? trim($validated['reason']) : null,
                    'route' => "/reservations/{$reservation->id}",
                ],
            ]);
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'Partner reservation updated',
                'details' => json_encode([
                    'reservation_id' => $reservation->id,
                    'reservable_type' => $reservation->reservable_type,
                    'reservable_id' => $reservation->reservable_id,
                    'status' => $status->name,
                    'reason' => $validated['status_name'] === 'rejected' ? trim($validated['reason']) : null,
                ], JSON_THROW_ON_ERROR),
            ]);

            return $reservation;
        }, 3);

        if (in_array($validated['status_name'], ['approved', 'confirmed', 'rejected', 'cancelled'], true)) {
            $emailDelivery->reservation(
                $reservation,
                $validated['status_name'],
                $validated['status_name'] === 'rejected' ? trim($validated['reason']) : null,
            );
        }

        return response()->json(['status' => 'success', 'message' => 'Reservation status updated']);
    }

    private function authorizeOwnership(Request $request, Reservation $reservation): void
    {
        [$spotIds, $listingIds] = $this->ownedTargetIds($request);
        $owned = ($reservation->reservable_type === 'spot' && $spotIds->contains($reservation->reservable_id))
            || ($reservation->reservable_type === 'tourism_listing' && $listingIds->contains($reservation->reservable_id));
        if (! $owned) {
            abort(
                $reservation->reservable_type === 'spot' ? 403 : 404,
                'This reservation does not belong to one of your managed destinations.',
            );
        }
    }

    /** @return array{0: Collection, 1: Collection} */
    private function ownedTargetIds(Request $request): array
    {
        return [
            Schema::hasTable('tourist_spot_partner_assignments')
                ? TouristSpotPartnerAssignment::where('partner_profile_id', $request->user()->id)
                    ->pluck('tourist_spot_id')
                : collect(),
            TourismListing::where('owner_id', $request->user()->id)->pluck('id'),
        ];
    }

    private function scopeOwned(Builder $query, $spotIds, $listingIds): void
    {
        $query->where(function (Builder $owned) use ($spotIds, $listingIds): void {
            $owned->where(fn (Builder $spots) => $spots
                ->where('reservable_type', 'spot')
                ->whereIn('reservable_id', $spotIds))
                ->orWhere(fn (Builder $listings) => $listings
                    ->where('reservable_type', 'tourism_listing')
                    ->whereIn('reservable_id', $listingIds));
        });
    }

    private function payload(Reservation $reservation): array
    {
        return array_merge($reservation->toArray(), [
            'reservable_name' => $this->targetName($reservation),
            'allowed_transitions' => ReservationStatusTransitions::allowedFrom($reservation->status?->name),
            'customer' => [
                'name' => $reservation->customer_name_snapshot ?? $reservation->user?->name,
                'email' => $reservation->customer_email_snapshot,
                'phone' => $reservation->customer_phone_snapshot ?? $reservation->user?->phone,
            ],
            'unread_message_count' => Schema::hasTable('reservation_messages')
                ? $reservation->messages()->where('is_internal', false)->where('sender_user_id', '!=', $reservation->partner_id)->whereDoesntHave('readers', fn ($q) => $q->where('users.id', $reservation->partner_id))->count()
                : 0,
        ]);
    }

    /** @return array<string, int> */
    private function summary(Request $request): array
    {
        [$spotIds, $listingIds] = $this->ownedTargetIds($request);
        $query = Reservation::query();
        $this->scopeOwned($query, $spotIds, $listingIds);
        $counts = (clone $query)
            ->join('reservation_status', 'reservation_status.id', '=', 'reservations.status_id')
            ->selectRaw('reservation_status.name as status_name, COUNT(*) as total')
            ->groupBy('reservation_status.name')
            ->pluck('total', 'status_name');

        return [
            'total' => (clone $query)->count(),
            'pending' => (int) ($counts['pending'] ?? 0),
            'confirmed' => (int) (($counts['confirmed'] ?? 0) + ($counts['approved'] ?? 0)),
            'completed' => (int) ($counts['completed'] ?? 0),
            'cancelled' => (int) ($counts['cancelled'] ?? 0),
            'rejected' => (int) ($counts['rejected'] ?? 0),
        ];
    }

    private function targetName(Reservation $reservation): string
    {
        return match ($reservation->reservable_type) {
            'spot' => TouristSpot::withTrashed()->whereKey($reservation->reservable_id)->value('name') ?? 'Tourist Spot',
            'tourism_listing' => TourismListing::withTrashed()->whereKey($reservation->reservable_id)->value('listing_name') ?? 'Tourism Listing',
            default => 'Destination',
        };
    }
}
