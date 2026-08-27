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
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TourismListingController extends Controller
{
    use ValidatesTubigonCoordinates;

    // ─── Dashboard Stats ────────────────────────────────────────────────
    public function dashboardStats(Request $request): JsonResponse
    {
        $userId = $request->user()->id;
        $today = now()->toDateString();
        $monthStart = now()->startOfMonth()->toDateString();

        $myListings = TourismListing::where('owner_id', $userId)
            ->whereNull('deleted_at')
            ->pluck('id');

        if ($myListings->isEmpty()) {
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
                    'recentNotifications' => [],
                ],
            ]);
        }

        $allReservations = Reservation::with('status')
            ->where('partner_id', $userId)
            ->get();

        $todayCount = $pendingCount = $approvedCount = $rejectedCount = $completedCount = $monthlyCount = 0;

        foreach ($allReservations as $r) {
            $date = substr($r->reservation_date, 0, 10);
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
        ]);
        $this->validateTubigonCoordinates($validated);

        $validated['owner_id'] = $request->user()->id;
        $listing = TourismListing::create($validated);

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
            'is_active' => 'nullable|boolean',
        ]);
        $this->validateTubigonCoordinates(
            $validated,
            $listing->latitude !== null ? (float) $listing->latitude : null,
            $listing->longitude !== null ? (float) $listing->longitude : null,
        );

        $listing->update($validated);

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

    // ─── Partner Reservations ───────────────────────────────────────────
    public function reservations(Request $request): JsonResponse
    {
        $query = Reservation::with(['user', 'status', 'listing'])
            ->where('partner_id', $request->user()->id);

        if ($request->has('status_filter') && $request->status_filter) {
            $query->whereHas('status', fn ($q) => $q->where('name', $request->status_filter));
        }

        $reservations = $query->orderBy('reservation_date', 'desc')->get();

        return response()->json(['status' => 'success', 'data' => $reservations]);
    }

    public function updateReservationStatus(Request $request, string $id): JsonResponse
    {
        $request->validate(['status_name' => 'required|string']);
        $statusName = $request->status_name;

        $statusRecord = ReservationStatus::where('name', $statusName)->firstOrFail();
        $reservation = Reservation::findOrFail($id);
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

        $reviews = Review::with('user')
            ->where('reviewable_type', 'listing')
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

        $reviews = Review::where('reviewable_type', 'listing')
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
            $date = substr($r->reservation_date, 0, 7);
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
        $reviews = Review::where('reviewable_type', 'listing')->whereIn('reviewable_id', $listingIds)->whereNull('deleted_at')->get();
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

        return response()->json(['status' => 'success', 'data' => $profile]);
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
}
