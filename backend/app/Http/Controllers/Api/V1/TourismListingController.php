<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\ValidatesTubigonCoordinates;
use App\Http\Controllers\Controller;
use App\Models\Notification;
use App\Models\PartnerNotification;
use App\Models\Profile;
use App\Models\Reservation;
use App\Models\ReservationStatus;
use App\Models\Review;
use App\Models\TourismListing;
use App\Models\TouristSpot;
use App\Models\TouristSpotPartnerAssignment;
use App\Models\User;
use App\Models\ActivityLog;
use App\Support\ReservationStatusTransitions;
use App\Support\StaleRecordGuard;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Carbon;
use Illuminate\Validation\Rule;

class TourismListingController extends Controller
{
    use ValidatesTubigonCoordinates;

    public function publicIndex(Request $request): JsonResponse
    {
        $query = TourismListing::where('approval_status', 'approved')->where('is_active', true);
        if ($request->filled('type')) $query->where('listing_type', $request->type);
        if ($request->filled('search')) $query->where('listing_name', 'like', '%'.$request->search.'%');
        return response()->json(['status' => 'success', 'data' => $query->latest('published_at')->get()]);
    }

    public function publicShow(string $id): JsonResponse
    {
        $listing = TourismListing::where('approval_status', 'approved')->where('is_active', true)->findOrFail($id);
        return response()->json(['status' => 'success', 'data' => $listing]);
    }

    public function managementIndex(Request $request): JsonResponse
    {
        $query = TourismListing::with('owner');
        if ($request->filled('status')) $query->where('approval_status', $request->status);
        return response()->json(['status' => 'success', 'data' => $query->latest()->get()]);
    }

    // ─── Dashboard Stats ────────────────────────────────────────────────
    public function dashboardStats(Request $request): JsonResponse
    {
        $userId = $request->user()->id;
        $today = now()->toDateString();
        $monthStart = now()->startOfMonth()->toDateString();

        $managedDestinations = TouristSpot::with(['category', 'bookingAvailabilityUpdatedBy:id,name'])
            ->whereHas('partnerAssignments', fn ($query) => $query
                ->where('partner_profile_id', $userId))
            ->orderBy('name')
            ->get();
        $managedSpotIds = $managedDestinations->pluck('id');

        if ($managedSpotIds->isEmpty()) {
            return response()->json([
                'status' => 'success',
                'data' => [
                    'todayReservations' => 0,
                    'pendingReservations' => 0,
                    'approvedReservations' => 0,
                    'rejectedReservations' => 0,
                    'completedReservations' => 0,
                    'monthlyReservations' => 0,
                    'totalManagedDestinations' => 0,
                    'managedDestinations' => [],
                    'averageRating' => 0,
                    'totalReviews' => 0,
                    'unreadNotifications' => PartnerNotification::where('user_id', $userId)->where('is_read', false)->count(),
                    'recentNotifications' => [],
                    'recentActivity' => [],
                    'needsAttention' => [],
                ],
            ]);
        }

        $allReservations = Reservation::with('status')
            ->where('reservable_type', 'spot')
            ->whereIn('reservable_id', $managedSpotIds)
            ->get();

        $todayCount = $pendingCount = $approvedCount = $rejectedCount = $completedCount = $monthlyCount = 0;

        foreach ($allReservations as $r) {
            $date = $r->reservation_date?->toDateString() ?? '';
            $statusName = $r->status?->name ?? 'pending';

            if ($date === $today) {
                $todayCount++;
            }
            if ($date >= $monthStart) {
                $monthlyCount++;
            }

            match ($statusName) {
                'pending' => $pendingCount++,
                'approved', 'confirmed' => $approvedCount++,
                'rejected' => $rejectedCount++,
                'completed' => $completedCount++,
                default => null,
            };
        }

        $notifications = PartnerNotification::where('user_id', $userId)
            ->orderBy('created_at', 'desc')
            ->limit(5)
            ->get();
        $reviews = Review::where('reviewable_type', 'spot')
            ->whereIn('reviewable_id', $managedSpotIds)->whereNull('deleted_at')->get();
        $needsAttention = [];
        if ($pendingCount > 0) $needsAttention[] = ['type' => 'reservation', 'message' => "{$pendingCount} reservation(s) await a decision.", 'route' => '/tourism-partner/reservations'];
        foreach ($managedDestinations as $spot) {
            if (! $spot->booking_enabled) $needsAttention[] = ['type' => 'availability', 'message' => "Booking is paused for {$spot->name}.", 'route' => '/tourism-partner/listings'];
            if (! $spot->is_published || ! $spot->is_active) $needsAttention[] = ['type' => 'status', 'message' => "{$spot->name} is not currently public and active.", 'route' => '/tourism-partner/listings'];
            if (blank($spot->description) || blank($spot->opening_hours) || blank($spot->contact_information)) $needsAttention[] = ['type' => 'content', 'message' => "{$spot->name} has missing visitor information.", 'route' => '/tourism-partner/listings'];
        }
        $lowRatings = $reviews->where('rating', '<=', 2)->count();
        if ($lowRatings > 0) $needsAttention[] = ['type' => 'review', 'message' => "{$lowRatings} low-rated review(s) may need attention.", 'route' => '/tourism-partner/reviews'];

        return response()->json([
            'status' => 'success',
            'data' => [
                'todayReservations' => $todayCount,
                'pendingReservations' => $pendingCount,
                'approvedReservations' => $approvedCount,
                'rejectedReservations' => $rejectedCount,
                'completedReservations' => $completedCount,
                'monthlyReservations' => $monthlyCount,
                'totalManagedDestinations' => $managedDestinations->count(),
                'managedDestinations' => $managedDestinations,
                'averageRating' => $reviews->isEmpty() ? 0 : round((float) $reviews->avg('rating'), 2),
                'totalReviews' => $reviews->count(),
                'unreadNotifications' => PartnerNotification::where('user_id', $userId)->where('is_read', false)->count(),
                'recentNotifications' => $notifications,
                'recentActivity' => ActivityLog::where('user_id', $userId)->latest()->limit(8)->get(['id', 'action', 'details', 'created_at']),
                'needsAttention' => array_slice($needsAttention, 0, 8),
            ],
        ]);
    }

    // ─── Listings CRUD ──────────────────────────────────────────────────
    public function index(Request $request): JsonResponse
    {
        $listings = TourismListing::where('owner_id', $request->user()->id)
            ->whereNull('deleted_at')
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json(['status' => 'success', 'data' => $listings]);
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $listing = TourismListing::where('id', $id)
            ->where('owner_id', $request->user()->id)
            ->firstOrFail();

        return response()->json(['status' => 'success', 'data' => $listing]);
    }

    public function store(Request $request): JsonResponse
    {
        abort_if(
            Schema::hasTable('tourist_spot_partner_assignments') &&
                TouristSpotPartnerAssignment::where('partner_profile_id', $request->user()->id)->exists(),
            409,
            'This account already manages an authoritative Tourist Spot. Use My Destination instead of creating a duplicate listing.',
        );
        $validated = $request->validate([
            'listing_name' => 'required|string|max:255',
            'listing_type' => 'nullable|string|max:255',
            'description' => 'nullable|string',
            'address' => 'nullable|string',
            'latitude' => 'nullable|numeric|between:-90,90',
            'longitude' => 'nullable|numeric|between:-180,180',
            'contact_number' => 'nullable|string|max:255',
            'email' => 'nullable|email|max:255',
            'operating_hours' => 'nullable|string|max:255',
            'images' => 'nullable|array',
            'price' => 'nullable|numeric|min:0|max:9999999999',
            'capacity' => 'nullable|integer|min:1|max:10000',
            'duration_minutes' => 'nullable|integer|min:1|max:10080',
            'available_days' => 'nullable|array',
            'available_days.*' => 'in:monday,tuesday,wednesday,thursday,friday,saturday,sunday',
            'booking_cutoff_hours' => 'nullable|integer|min:0|max:720',
        ]);
        $this->validateTubigonCoordinates($validated);

        $validated['owner_id'] = $request->user()->id;
        $validated['approval_status'] = 'draft';
        $validated['status'] = 'draft';
        $validated['is_active'] = false;
        $listing = TourismListing::create($validated);

        $this->log($request->user()->id, 'Partner listing created', $listing->id, null, $listing->toArray());

        return response()->json(['status' => 'success', 'data' => $listing], 201);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $listing = TourismListing::where('id', $id)
            ->where('owner_id', $request->user()->id)
            ->firstOrFail();

        $validated = $request->validate([
            'listing_name' => 'sometimes|string|max:255',
            'listing_type' => 'nullable|string|max:255',
            'description' => 'nullable|string',
            'address' => 'nullable|string',
            'latitude' => 'nullable|numeric|between:-90,90',
            'longitude' => 'nullable|numeric|between:-180,180',
            'contact_number' => 'nullable|string|max:255',
            'email' => 'nullable|email|max:255',
            'operating_hours' => 'nullable|string|max:255',
            'images' => 'nullable|array',
            'price' => 'nullable|numeric|min:0|max:9999999999',
            'capacity' => 'nullable|integer|min:1|max:10000',
            'duration_minutes' => 'nullable|integer|min:1|max:10080',
            'available_days' => 'nullable|array',
            'available_days.*' => 'in:monday,tuesday,wednesday,thursday,friday,saturday,sunday',
            'booking_cutoff_hours' => 'nullable|integer|min:0|max:720',
        ]);
        $expectedUpdatedAt = StaleRecordGuard::expectedUpdatedAt($request);
        $this->validateTubigonCoordinates(
            $validated,
            $listing->latitude !== null ? (float) $listing->latitude : null,
            $listing->longitude !== null ? (float) $listing->longitude : null,
        );

        $before = $listing->toArray();
        $sensitive = collect(['listing_name', 'listing_type', 'description', 'address', 'latitude', 'longitude', 'contact_number', 'email'])
            ->contains(fn (string $field) => array_key_exists($field, $validated) && (string) $validated[$field] !== (string) $listing->{$field});
        if ($listing->approval_status === 'approved' && $sensitive) {
            $validated['approval_status'] = 'draft';
            $validated['status'] = 'draft';
            $validated['is_active'] = false;
            $validated['review_notes'] = null;
            $validated['reviewed_at'] = null;
            $validated['reviewed_by'] = null;
            $validated['published_at'] = null;
        }
        DB::transaction(function () use ($request, $listing, $validated, $before, $expectedUpdatedAt): void {
            $locked = TourismListing::whereKey($listing->id)
                ->where('owner_id', $request->user()->id)
                ->lockForUpdate()->firstOrFail();
            StaleRecordGuard::assertCurrent($locked, $expectedUpdatedAt);
            $locked->update($validated);
            $this->log($request->user()->id, 'Partner listing updated', $locked->id, $before, $locked->fresh()->toArray());
        });

        return response()->json(['status' => 'success', 'data' => $listing]);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        $listing = TourismListing::where('id', $id)
            ->where('owner_id', $request->user()->id)
            ->firstOrFail();

        $listing->update(['deleted_at' => now(), 'is_active' => false]);

        return response()->json(['status' => 'success', 'message' => 'Listing deleted']);
    }

    public function submit(Request $request, string $id): JsonResponse
    {
        $listing = TourismListing::where('owner_id', $request->user()->id)->findOrFail($id);
        abort_unless(in_array($listing->approval_status, ['draft', 'needs_changes', 'rejected'], true), 422, 'This listing cannot be submitted from its current state.');
        abort_if(blank($listing->listing_name) || blank($listing->listing_type) || blank($listing->description) || blank($listing->address) || $listing->latitude === null || $listing->longitude === null, 422, 'Complete the listing name, type, description, address, and map location before submitting.');
        $before = $listing->toArray();
        DB::transaction(function () use ($request, $listing, $before): void {
            $listing->update(['approval_status' => 'submitted', 'status' => 'pending', 'is_active' => false, 'submitted_at' => now(), 'review_notes' => null]);
            $this->log($request->user()->id, 'Partner listing submitted', $listing->id, $before, $listing->fresh()->toArray());
            User::with('role')->whereHas('role', fn ($query) => $query->whereIn('name', ['admin', 'lgu_staff']))->get()->each(fn (User $reviewer) => Notification::create([
                'user_id' => $reviewer->id,
                'type' => 'partner_listing_submitted',
                'title' => 'Partner Listing Awaiting Review',
                'body' => "{$listing->listing_name} was submitted for review.",
                'data' => [
                    'listing_id' => $listing->id,
                    'route' => $reviewer->role?->name === 'admin' ? '/admin/tourism' : '/lgu/tourism-monitoring',
                ],
            ]));
        });
        return response()->json(['status' => 'success', 'message' => 'Listing submitted for review.', 'data' => $listing->fresh()]);
    }

    public function review(Request $request, string $id): JsonResponse
    {
        $validated = $request->validate([
            'approval_status' => 'required|in:approved,needs_changes,rejected,suspended,archived',
            'notes' => 'nullable|string|max:2000',
        ]);
        $expectedUpdatedAt = StaleRecordGuard::expectedUpdatedAt($request);
        if (in_array($validated['approval_status'], ['needs_changes', 'rejected', 'suspended'], true)) {
            abort_if(blank($validated['notes'] ?? null), 422, 'Review notes are required for this decision.');
        }
        $listing = TourismListing::findOrFail($id);
        abort_if($validated['approval_status'] === 'approved' && $listing->approval_status !== 'submitted', 422, 'Only a submitted listing can be approved.');
        $before = $listing->toArray();
        $isApproved = $validated['approval_status'] === 'approved';
        DB::transaction(function () use ($request, $validated, $listing, $before, $isApproved, $expectedUpdatedAt): void {
            $locked = TourismListing::whereKey($listing->id)->lockForUpdate()->firstOrFail();
            StaleRecordGuard::assertCurrent($locked, $expectedUpdatedAt, [
                'approval_status' => $locked->approval_status,
            ]);
            abort_if($validated['approval_status'] === 'approved' && $locked->approval_status !== 'submitted', 422, 'Only a submitted listing can be approved.');
            $locked->update([
                'approval_status' => $validated['approval_status'],
                'status' => $isApproved ? 'approved' : $validated['approval_status'],
                'is_active' => $isApproved,
                'review_notes' => $validated['notes'] ?? null,
                'reviewed_at' => now(),
                'reviewed_by' => $request->user()->id,
                'published_at' => $isApproved ? now() : null,
            ]);
            $this->log($request->user()->id, 'Partner listing '.$validated['approval_status'], $locked->id, $before, $locked->fresh()->toArray());
            PartnerNotification::create([
                'user_id' => $locked->owner_id,
                'type' => 'listing_'.$validated['approval_status'],
                'title' => $isApproved ? 'Listing Approved' : 'Listing Review Updated',
                'body' => $isApproved ? "{$locked->listing_name} is now public." : ($validated['notes'] ?? 'Your listing review status changed.'),
                'data' => ['listing_id' => $locked->id, 'route' => '/tourism-partner/listings'],
            ]);
        });
        return response()->json(['status' => 'success', 'message' => 'Listing review saved.', 'data' => $listing->fresh()]);
    }

    // ─── Partner Reservations ───────────────────────────────────────────
    public function reservations(Request $request): JsonResponse
    {
        $query = Reservation::with(['user:id,name,phone', 'status', 'listing'])
            ->where('partner_id', $request->user()->id);

        if ($request->has('status_filter') && $request->status_filter) {
            $query->whereHas('status', fn ($q) => $q->where('name', $request->status_filter));
        }

        $reservations = $query->orderBy('reservation_date', 'desc')->get();

        return response()->json(['status' => 'success', 'data' => $reservations]);
    }

    public function showReservation(Request $request, string $id): JsonResponse
    {
        $reservation = Reservation::with(['user:id,name,phone', 'status', 'listing'])
            ->where('partner_id', $request->user()->id)
            ->findOrFail($id);

        return response()->json(['status' => 'success', 'data' => $reservation]);
    }

    public function updateReservationStatus(Request $request, string $id): JsonResponse
    {
        $request->validate(['status_name' => 'required|string|in:approved,confirmed,rejected,completed,cancelled']);
        $statusName = $request->status_name;

        $statusRecord = ReservationStatus::where('name', $statusName)->firstOrFail();
        $reservation = Reservation::with('status')
            ->where('partner_id', $request->user()->id)
            ->findOrFail($id);
        if (! ReservationStatusTransitions::allows($reservation->status?->name, $statusName)) {
            return response()->json([
                'status' => 'error',
                'message' => "A {$reservation->status?->name} reservation cannot transition to {$statusName}.",
                'allowed_statuses' => ReservationStatusTransitions::allowedFrom($reservation->status?->name),
            ], 422);
        }
        $reservation->update(['status_id' => $statusRecord->id]);

        // Notify tourist
        $listing = TourismListing::find($reservation->reservable_id);
        $listingName = $listing?->listing_name ?? 'Listing';

        Notification::create([
            'user_id' => $reservation->user_id,
            'type' => "reservation_$statusName",
            'title' => 'Reservation '.ucfirst($statusName),
            'body' => "Your reservation at $listingName has been $statusName.",
            'data' => ['reservation_id' => $id, 'status' => $statusName],
        ]);

        return response()->json(['status' => 'success', 'message' => 'Reservation status updated']);
    }

    // ─── Partner Reviews ────────────────────────────────────────────────
    public function reviews(Request $request): JsonResponse
    {
        [$listingIds, $spotIds] = $this->ownedReviewTargetIds($request);

        if ($listingIds->isEmpty() && $spotIds->isEmpty()) {
            return response()->json(['status' => 'success', 'data' => []]);
        }

        $reviews = Review::with('user:id,name')
            ->where(function ($query) use ($listingIds, $spotIds): void {
                $query->where(fn ($listings) => $listings
                    ->where('reviewable_type', 'tourism_listing')
                    ->whereIn('reviewable_id', $listingIds))
                    ->orWhere(fn ($spots) => $spots
                        ->where('reviewable_type', 'spot')
                        ->whereIn('reviewable_id', $spotIds));
            })
            ->whereNull('deleted_at')
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json(['status' => 'success', 'data' => $reviews]);
    }

    public function reviewStats(Request $request): JsonResponse
    {
        [$listingIds, $spotIds] = $this->ownedReviewTargetIds($request);

        $reviews = Review::where(function ($query) use ($listingIds, $spotIds): void {
            $query->where(fn ($listings) => $listings
                ->where('reviewable_type', 'tourism_listing')
                ->whereIn('reviewable_id', $listingIds))
                ->orWhere(fn ($spots) => $spots
                    ->where('reviewable_type', 'spot')
                    ->whereIn('reviewable_id', $spotIds));
        })
            ->whereNull('deleted_at')
            ->get();

        $distribution = collect(range(1, 5))->mapWithKeys(
            fn (int $rating) => [(string) $rating => $reviews->where('rating', $rating)->count()],
        );
        $monthly = $reviews->groupBy(fn (Review $review) => $review->created_at?->format('Y-m'))
            ->map(fn ($group, $month) => [
                'month' => $month,
                'average' => round((float) $group->avg('rating'), 2),
                'total' => $group->count(),
            ])->values();

        return response()->json([
            'status' => 'success',
            'data' => [
                'averageRating' => $reviews->isEmpty() ? 0.0 : round((float) $reviews->avg('rating'), 2),
                'totalReviews' => $reviews->count(),
                'lowRatedReviews' => $reviews->where('rating', '<=', 2)->count(),
                'ratingDistribution' => $distribution,
                'monthlyTrend' => $monthly,
            ],
        ]);
    }

    // ─── Partner Analytics ──────────────────────────────────────────────
    public function analytics(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'period' => ['nullable', Rule::in(['7_days', '30_days', '3_months', 'this_year', 'custom'])],
            'from' => 'nullable|required_if:period,custom|date',
            'to' => 'nullable|required_if:period,custom|date|after_or_equal:from',
        ]);
        [$start, $end] = $this->partnerAnalyticsPeriod($validated);
        $spotIds = TouristSpotPartnerAssignment::where('partner_profile_id', $request->user()->id)
            ->pluck('tourist_spot_id');
        $reservationQuery = Reservation::with('status')
            ->where('reservable_type', 'spot')->whereIn('reservable_id', $spotIds)
            ->whereBetween('reservation_date', [$start, $end]);
        $allReservations = $reservationQuery->get();
        $statusDistribution = collect(['pending', 'approved', 'confirmed', 'rejected', 'completed', 'cancelled'])
            ->mapWithKeys(fn (string $status) => [$status => $allReservations->where('status.name', $status)->count()]);
        $reservationTrend = $allReservations
            ->groupBy(fn (Reservation $reservation) => $reservation->reservation_date?->format('Y-m-d'))
            ->map(fn ($group, $date) => ['date' => $date, 'total' => $group->count()])
            ->values();
        $reviews = Review::where('reviewable_type', 'spot')->whereIn('reviewable_id', $spotIds)
            ->whereBetween('created_at', [$start, $end])->whereNull('deleted_at')->get();
        $ratingDistribution = collect(range(1, 5))->mapWithKeys(
            fn (int $rating) => [(string) $rating => $reviews->where('rating', $rating)->count()],
        );
        $duration = max(1, $start->diffInSeconds($end));
        $previousEnd = $start->copy()->subSecond();
        $previousStart = $previousEnd->copy()->subSeconds($duration);
        $previousTotal = Reservation::where('reservable_type', 'spot')->whereIn('reservable_id', $spotIds)
            ->whereBetween('reservation_date', [$previousStart, $previousEnd])->count();
        $comparison = $previousTotal === 0 ? null : round((($allReservations->count() - $previousTotal) / $previousTotal) * 100, 1);

        return response()->json([
            'status' => 'success',
            'data' => [
                'period' => ['from' => $start->toDateString(), 'to' => $end->toDateString()],
                'monthlyData' => $reservationTrend->pluck('total', 'date'),
                'reservationTrend' => $reservationTrend,
                'statusDistribution' => $statusDistribution,
                'averageRating' => $reviews->isEmpty() ? 0 : round((float) $reviews->avg('rating'), 2),
                'totalReviews' => $reviews->count(),
                'ratingDistribution' => $ratingDistribution,
                'totalVisitors' => $allReservations->sum('guests'),
                'totalReservations' => $allReservations->count(),
                'comparisonPercent' => $comparison,
            ],
        ]);
    }

    /** @param array<string, mixed> $validated
     *  @return array{0: Carbon, 1: Carbon}
     */
    private function partnerAnalyticsPeriod(array $validated): array
    {
        $end = isset($validated['to']) ? Carbon::parse($validated['to'])->endOfDay() : now()->endOfDay();
        $start = match ($validated['period'] ?? '30_days') {
            '7_days' => $end->copy()->subDays(6)->startOfDay(),
            '3_months' => $end->copy()->subMonths(3)->startOfDay(),
            'this_year' => $end->copy()->startOfYear(),
            'custom' => Carbon::parse($validated['from'])->startOfDay(),
            default => $end->copy()->subDays(29)->startOfDay(),
        };

        return [$start, $end];
    }

    // ─── Profile ────────────────────────────────────────────────────────
    public function profile(Request $request): JsonResponse
    {
        $profile = Profile::with('role')
            ->where('id', $request->user()->id)
            ->firstOrFail();

        $payload = $profile->toArray();
        $assignment = TouristSpotPartnerAssignment::with(['touristSpot:id,name,slug', 'assignedBy:id,name'])
            ->where('partner_profile_id', $profile->id)->first();
        $payload['assignment'] = $assignment ? [
            'id' => $assignment->id,
            'status' => 'active',
            'assigned_at' => $assignment->assigned_at?->toIso8601String(),
            'assigned_by' => $assignment->assignedBy?->only(['id', 'name']),
            'destination' => $assignment->touristSpot,
        ] : null;
        $payload['managed_destinations'] = $assignment?->touristSpot ? [$assignment->touristSpot] : [];

        return response()->json(['status' => 'success', 'data' => $payload]);
    }

    public function updateProfile(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'sometimes|string|max:255',
            'phone' => 'nullable|string|max:255',
            'bio' => 'nullable|string',
            'avatar_url' => 'nullable|string',
        ]);

        $profile = Profile::findOrFail($request->user()->id);
        $profile->update($validated);

        if (isset($validated['name'])) {
            User::where('id', $request->user()->id)->update(['name' => $validated['name']]);
        }

        return response()->json(['status' => 'success', 'data' => $profile->fresh()->load('role')]);
    }

    public function updatePassword(Request $request): JsonResponse
    {
        $request->validate([
            'password' => 'required|string|min:6|confirmed',
        ]);

        $request->user()->update(['password' => $request->password]);

        return response()->json(['status' => 'success', 'message' => 'Password updated']);
    }

    /** @return array{0: \Illuminate\Support\Collection, 1: \Illuminate\Support\Collection} */
    private function ownedReviewTargetIds(Request $request): array
    {
        return [
            TourismListing::where('owner_id', $request->user()->id)
                ->whereNull('deleted_at')
                ->pluck('id'),
            $request->user()->managedTouristSpots()->pluck('tourist_spots.id'),
        ];
    }

    // ─── Image Upload ───────────────────────────────────────────────────
    public function uploadListingImage(Request $request): JsonResponse
    {
        $request->validate(['image' => 'required|image|max:5120']);

        $userId = $request->user()->id;
        $path = $request->file('image')->store("listings/$userId", 'public');
        $url = asset("storage/$path");

        return response()->json(['status' => 'success', 'data' => ['url' => $url]]);
    }

    private function log(string $actor, string $action, string $entityId, ?array $before, ?array $after): void
    {
        ActivityLog::create(['user_id' => $actor, 'action' => $action, 'details' => json_encode([
            'entity_type' => 'tourism_listing', 'entity_id' => $entityId, 'before' => $before, 'after' => $after,
        ])]);
    }
}
