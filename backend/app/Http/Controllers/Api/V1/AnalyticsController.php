<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Msme;
use App\Models\Reservation;
use App\Models\Review;
use App\Models\TouristSpot;
use App\Models\User;
use App\Models\WasteReport;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class AnalyticsController extends Controller
{
    public function dashboard(Request $request): JsonResponse
    {
        $totalUsers = User::count();
        $totalTourists = User::whereHas('role', fn ($q) => $q->where('name', 'tourist'))->count();
        $totalMsmes = Msme::count();
        $totalSpots = TouristSpot::count();
        $totalReservations = Reservation::count();
        $totalReviews = Review::count();
        $totalWasteReports = WasteReport::count();
        $totalPartners = User::whereHas('role', fn ($q) => $q->where('name', 'tourism_partner'))->count();
        $totalMsmeOwners = User::whereHas('role', fn ($q) => $q->where('name', 'msme_owner'))->count();
        $verifiedMsmes = Schema::hasColumn('msmes', 'is_verified')
            ? Msme::where('is_verified', true)->count()
            : 0;
        $publishedSpots = Schema::hasColumn('tourist_spots', 'is_published')
            ? TouristSpot::where('is_published', true)->where('is_active', true)->count()
            : $totalSpots;
        $activeFerrySchedules = Schema::hasTable('ferry_schedules')
            ? DB::table('ferry_schedules')
                ->when(Schema::hasColumn('ferry_schedules', 'deleted_at'), fn ($q) => $q->whereNull('deleted_at'))
                ->when(Schema::hasColumn('ferry_schedules', 'is_active'), fn ($q) => $q->where('is_active', true))
                ->count()
            : 0;

        $thirtyDaysAgo = now()->subDays(29)->startOfDay();
        $reservationsLast30Days = Reservation::where('created_at', '>=', $thirtyDaysAgo)->count();
        $wasteReportsLast30Days = WasteReport::where('created_at', '>=', $thirtyDaysAgo)->count();
        $reservationValueLast30Days = (float) Reservation::where('created_at', '>=', $thirtyDaysAgo)->sum('total_amount');

        $reservationStatuses = Schema::hasTable('reservation_status')
            ? Reservation::query()
                ->leftJoin('reservation_status', 'reservations.status_id', '=', 'reservation_status.id')
                ->selectRaw("COALESCE(reservation_status.name, 'unassigned') AS label, COUNT(*) AS total")
                ->groupBy('reservation_status.name')
                ->orderByDesc('total')
                ->get()
            : collect();
        $wasteStatuses = WasteReport::query()
            ->selectRaw('status AS label, COUNT(*) AS total')
            ->groupBy('status')
            ->orderByDesc('total')
            ->get();

        $reservationsOverTime = Reservation::where('created_at', '>=', $thirtyDaysAgo)
            ->selectRaw('DATE(created_at) AS date, COUNT(*) AS total')
            ->groupByRaw('DATE(created_at)')
            ->orderBy('date')
            ->get();
        $wasteReportsOverTime = WasteReport::where('created_at', '>=', $thirtyDaysAgo)
            ->selectRaw('DATE(created_at) AS date, COUNT(*) AS total')
            ->groupByRaw('DATE(created_at)')
            ->orderBy('date')
            ->get();

        $roleApplicationStatuses = Schema::hasTable('role_applications')
            ? DB::table('role_applications')
                ->selectRaw('status AS label, COUNT(*) AS total')
                ->groupBy('status')
                ->orderByDesc('total')
                ->get()
            : collect();
        $mostReservedDestinations = $this->mostReservedDestinations();

        $recentActivities = ActivityLog::with('user.role')
            ->orderBy('created_at', 'desc')
            ->limit(10)
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => [
                'totalUsers' => $totalUsers,
                'totalTourists' => $totalTourists,
                'totalMsmes' => $totalMsmes,
                'totalSpots' => $totalSpots,
                'totalReservations' => $totalReservations,
                'totalReviews' => $totalReviews,
                'totalWasteReports' => $totalWasteReports,
                'totalPartners' => $totalPartners,
                'totalMsmeOwners' => $totalMsmeOwners,
                'verifiedMsmes' => $verifiedMsmes,
                'publishedSpots' => $publishedSpots,
                'activeFerrySchedules' => $activeFerrySchedules,
                'reservationsLast30Days' => $reservationsLast30Days,
                'wasteReportsLast30Days' => $wasteReportsLast30Days,
                'reservationValueLast30Days' => $reservationValueLast30Days,
                'reservationStatuses' => $reservationStatuses,
                'wasteStatuses' => $wasteStatuses,
                'roleApplicationStatuses' => $roleApplicationStatuses,
                'reservationsOverTime' => $reservationsOverTime,
                'wasteReportsOverTime' => $wasteReportsOverTime,
                'mostReservedDestinations' => $mostReservedDestinations,
                'recentActivities' => $recentActivities,
            ],
        ]);
    }

    private function mostReservedDestinations(): array
    {
        $groups = Reservation::query()
            ->selectRaw('reservable_id, reservable_type, COUNT(*) AS total')
            ->groupBy('reservable_id', 'reservable_type')
            ->orderByDesc('total')
            ->limit(5)
            ->get();
        if ($groups->isEmpty()) {
            return [];
        }

        $ids = $groups->pluck('reservable_id')->unique()->values();
        $listingNames = Schema::hasTable('tourism_listings')
            ? DB::table('tourism_listings')->whereIn('id', $ids)->pluck('listing_name', 'id')
            : collect();
        $spotNames = TouristSpot::whereIn('id', $ids)->pluck('name', 'id');

        return $groups->map(fn ($group) => [
            'id' => $group->reservable_id,
            'name' => $listingNames[$group->reservable_id]
                ?? $spotNames[$group->reservable_id]
                ?? 'Archived or unavailable listing',
            'type' => $group->reservable_type,
            'total' => (int) $group->total,
        ])->all();
    }

    public function activityLogs(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'role' => 'nullable|string|max:50',
            'action' => 'nullable|string|max:100',
            'date_from' => 'nullable|date',
            'date_to' => 'nullable|date|after_or_equal:date_from',
            'search' => 'nullable|string|max:200',
            'page' => 'nullable|integer|min:1',
            'per_page' => 'nullable|integer|min:10|max:100',
        ]);

        $query = ActivityLog::with('user.role');
        if (! empty($validated['role'])) {
            if (Schema::hasColumn('activity_logs', 'actor_role')) {
                $query->where('actor_role', $validated['role']);
            } else {
                $query->whereHas('user.role', fn ($role) => $role->where('name', $validated['role']));
            }
        }
        if (! empty($validated['action'])) {
            $column = Schema::hasColumn('activity_logs', 'action_type') ? 'action_type' : 'action';
            $query->where($column, $validated['action']);
        }
        if (! empty($validated['date_from'])) {
            $query->whereDate('created_at', '>=', $validated['date_from']);
        }
        if (! empty($validated['date_to'])) {
            $query->whereDate('created_at', '<=', $validated['date_to']);
        }
        if (! empty($validated['search'])) {
            $term = '%'.trim($validated['search']).'%';
            $query->where(function ($search) use ($term): void {
                $search->where('action', 'like', $term)->orWhere('details', 'like', $term)
                    ->orWhereHas('user', fn ($actor) => $actor->where('name', 'like', $term)->orWhere('email', 'like', $term));
                if (Schema::hasColumn('activity_logs', 'target_type')) {
                    $search->orWhere('target_type', 'like', $term);
                }
                if (Schema::hasColumn('activity_logs', 'target_id')) {
                    $search->orWhere('target_id', 'like', $term);
                }
            });
        }

        $logs = $query->latest('created_at')->paginate($validated['per_page'] ?? 25);

        return response()->json(['status' => 'success', 'data' => $logs]);
    }
}
