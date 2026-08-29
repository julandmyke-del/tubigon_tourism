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
use App\Models\User;
use App\Models\ActivityLog;
use App\Support\ReservationStatusTransitions;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

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

        $myListings = TourismListing::where('owner_id', $userId)
            ->whereNull('deleted_at')
            ->pluck('id');

        $managedDestinations = TouristSpot::with(['category', 'bookingAvailabilityUpdatedBy:id,name'])
            ->whereHas('partnerAssignments', fn ($query) => $query
                ->where('partner_profile_id', $userId))
            ->orderBy('name')
            ->get();
        $managedSpotIds = $managedDestinations->pluck('id');

        if ($myListings->isEmpty() && $managedSpotIds->isEmpty()) {
            return response()->json([
                'status' => 'success',
                'data' => [
                    'todayReservations' => 0,
                    'pendingReservations' => 0,
                    'approvedReservations' => 0,
                    'rejectedReservations' => 0,
                    'completedReservations' => 0,
                    'monthlyReservations' => 0,
                    'totalListings' => 0,
                    'draftListings' => 0,
                    'pendingListings' => 0,
                    'publishedListings' => 0,
                    'totalManagedDestinations' => 0,
                    'managedDestinations' => [],
                    'recentNotifications' => [],
                ],
            ]);
        }

        $allReservations = Reservation::with('status')
            ->where(function ($query) use ($myListings, $managedSpotIds): void {
                $query->where(fn ($spots) => $spots
                    ->where('reservable_type', 'spot')
                    ->whereIn('reservable_id', $managedSpotIds))
                    ->orWhere(fn ($listings) => $listings
                        ->where('reservable_type', 'tourism_listing')
                        ->whereIn('reservable_id', $myListings));
            })
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

        return response()->json([
            'status' => 'success',
            'data' => [
                'todayReservations' => $todayCount,
                'pendingReservations' => $pendingCount,
                'approvedReservations' => $approvedCount,
                'rejectedReservations' => $rejectedCount,
                'completedReservations' => $completedCount,
                'monthlyReservations' => $monthlyCount,
                'totalListings' => $myListings->count(),
                'draftListings' => TourismListing::where('owner_id', $userId)->where('approval_status', 'draft')->count(),
                'pendingListings' => TourismListing::where('owner_id', $userId)->where('approval_status', 'submitted')->count(),
                'publishedListings' => TourismListing::where('owner_id', $userId)->where('approval_status', 'approved')->where('is_active', true)->count(),
                'totalManagedDestinations' => $managedDestinations->count(),
                'managedDestinations' => $managedDestinations,
                'recentNotifications' => $notifications,
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
        $listing->update($validated);
        $this->log($request->user()->id, 'Partner listing updated', $listing->id, $before, $listing->fresh()->toArray());

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
        if (in_array($validated['approval_status'], ['needs_changes', 'rejected', 'suspended'], true)) {
            abort_if(blank($validated['notes'] ?? null), 422, 'Review notes are required for this decision.');
        }
        $listing = TourismListing::findOrFail($id);
        abort_if($validated['approval_status'] === 'approved' && $listing->approval_status !== 'submitted', 422, 'Only a submitted listing can be approved.');
        $before = $listing->toArray();
        $isApproved = $validated['approval_status'] === 'approved';
        DB::transaction(function () use ($request, $validated, $listing, $before, $isApproved): void {
            $listing->update([
                'approval_status' => $validated['approval_status'],
                'status' => $isApproved ? 'approved' : $validated['approval_status'],
                'is_active' => $isApproved,
                'review_notes' => $validated['notes'] ?? null,
                'reviewed_at' => now(),
                'reviewed_by' => $request->user()->id,
                'published_at' => $isApproved ? now() : null,
            ]);
            $this->log($request->user()->id, 'Partner listing '.$validated['approval_status'], $listing->id, $before, $listing->fresh()->toArray());
            PartnerNotification::create([
                'user_id' => $listing->owner_id,
                'type' => 'listing_'.$validated['approval_status'],
                'title' => $isApproved ? 'Listing Approved' : 'Listing Review Updated',
                'body' => $isApproved ? "{$listing->listing_name} is now public." : ($validated['notes'] ?? 'Your listing review status changed.'),
                'data' => ['listing_id' => $listing->id, 'route' => '/tourism-partner/listings'],
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
        $listingIds = TourismListing::where('owner_id', $request->user()->id)
            ->whereNull('deleted_at')
            ->pluck('id');

        if ($listingIds->isEmpty()) {
            return response()->json(['status' => 'success', 'data' => []]);
        }

        $reviews = Review::with('user:id,name')
            ->where('reviewable_type', 'tourism_listing')
            ->whereIn('reviewable_id', $listingIds)
            ->whereNull('deleted_at')
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json(['status' => 'success', 'data' => $reviews]);
    }

    public function reviewStats(Request $request): JsonResponse
    {
        $listingIds = TourismListing::where('owner_id', $request->user()->id)
            ->whereNull('deleted_at')
            ->pluck('id');

        $reviews = Review::where('reviewable_type', 'tourism_listing')
            ->whereIn('reviewable_id', $listingIds)
            ->whereNull('deleted_at')
            ->get();

        if ($reviews->isEmpty()) {
            return response()->json(['status' => 'success', 'data' => ['averageRating' => 0.0, 'totalReviews' => 0]]);
        }

        $avg = $reviews->avg('rating');

        return response()->json([
            'status' => 'success',
            'data' => ['averageRating' => round($avg, 2), 'totalReviews' => $reviews->count()],
        ]);
    }

    // ─── Partner Analytics ──────────────────────────────────────────────
    public function analytics(Request $request): JsonResponse
    {
        $userId = $request->user()->id;

        $allReservations = Reservation::with(['status', 'listing'])
            ->where('partner_id', $userId)
            ->get();

        // Monthly data (last 6 months)
        $monthlyData = [];
        for ($i = 5; $i >= 0; $i--) {
            $month = now()->subMonths($i);
            $key = $month->format('Y-m');
            $monthlyData[$key] = 0;
        }

        $statusDistribution = ['pending' => 0, 'approved' => 0, 'confirmed' => 0, 'rejected' => 0, 'completed' => 0, 'cancelled' => 0];
        $listingCounts = [];
        $listingNames = [];
        $totalVisitors = 0;

        foreach ($allReservations as $r) {
            $date = $r->reservation_date?->format('Y-m') ?? '';
            if (isset($monthlyData[$date])) {
                $monthlyData[$date]++;
            }

            $statusName = $r->status?->name ?? 'pending';
            if (isset($statusDistribution[$statusName])) {
                $statusDistribution[$statusName]++;
            }

            $listingId = $r->reservable_id ?? '';
            $listingName = $r->listing?->listing_name ?? 'Unknown';
            $listingCounts[$listingId] = ($listingCounts[$listingId] ?? 0) + 1;
            $listingNames[$listingId] = $listingName;

            $totalVisitors += $r->guests ?? 1;
        }

        // Most reserved
        $mostReservedId = null;
        $maxCount = 0;
        foreach ($listingCounts as $id => $count) {
            if ($count > $maxCount) {
                $maxCount = $count;
                $mostReservedId = $id;
            }
        }

        // Review stats
        $listingIds = TourismListing::where('owner_id', $userId)->whereNull('deleted_at')->pluck('id');
        $reviews = Review::where('reviewable_type', 'tourism_listing')->whereIn('reviewable_id', $listingIds)->whereNull('deleted_at')->get();
        $avgRating = $reviews->isEmpty() ? 0 : round($reviews->avg('rating'), 2);

        return response()->json([
            'status' => 'success',
            'data' => [
                'monthlyData' => $monthlyData,
                'statusDistribution' => $statusDistribution,
                'mostReservedListing' => $mostReservedId ? ($listingNames[$mostReservedId] ?? 'N/A') : 'N/A',
                'mostReservedCount' => $maxCount,
                'averageRating' => $avgRating,
                'totalReviews' => $reviews->count(),
                'totalVisitors' => $totalVisitors,
                'totalReservations' => $allReservations->count(),
            ],
        ]);
    }

    // ─── Profile ────────────────────────────────────────────────────────
    public function profile(Request $request): JsonResponse
    {
        $profile = Profile::with('role')
            ->where('id', $request->user()->id)
            ->firstOrFail();

        $payload = $profile->toArray();
        $payload['managed_destinations'] = $profile->managedTouristSpots()
            ->select('tourist_spots.id', 'tourist_spots.name', 'tourist_spots.slug')
            ->orderBy('tourist_spots.name')
            ->get();

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
