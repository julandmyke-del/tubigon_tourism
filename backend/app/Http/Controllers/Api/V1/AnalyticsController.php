<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Profile;
use App\Models\TouristSpot;
use App\Models\Reservation;
use App\Models\Review;
use App\Models\WasteReport;
use App\Models\Msme;
use App\Models\ActivityLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AnalyticsController extends Controller
{
    public function dashboard(Request $request): JsonResponse
    {
        $totalUsers = Profile::count();
        $totalTourists = Profile::whereHas('role', fn($q) => $q->where('name', 'tourist'))->count();
        $totalMsmes = Msme::count();
        $totalSpots = TouristSpot::count();
        $totalReservations = Reservation::count();
        $totalReviews = Review::count();
        $totalWasteReports = WasteReport::count();

        $recentActivities = ActivityLog::with('user')
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
                'recentActivities' => $recentActivities,
            ],
        ]);
    }

    public function activityLogs(): JsonResponse
    {
        $logs = ActivityLog::with('user')
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json(['status' => 'success', 'data' => $logs]);
    }
}
