<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\TouristSpot;
use App\Models\Msme;
use App\Models\Reservation;
use App\Models\WasteReport;
use App\Models\Announcement;
use App\Models\EmergencyContact;
use App\Models\FerrySchedule;
use App\Models\EcoTip;
use Illuminate\Support\Facades\DB;

class LguController extends Controller
{
    /**
     * Executive Municipal Dashboard Statistics
     */
    public function dashboardStats(Request $request)
    {
        $totalSpots = TouristSpot::count();
        $totalMsmes = Msme::count();
        $activeReservations = Reservation::whereIn('status', ['pending', 'confirmed'])->count();
        $pendingWaste = WasteReport::whereIn('status', ['submitted', 'in_progress'])->count();
        $resolvedWaste = WasteReport::where('status', 'resolved')->count();
        $publishedAnnouncements = Announcement::count();
        $emergencyContacts = EmergencyContact::count();
        $ferrySchedules = FerrySchedule::count();

        return response()->json([
            'status' => 'success',
            'data' => [
                'total_spots' => $totalSpots,
                'total_msmes' => $totalMsmes,
                'active_reservations' => $activeReservations,
                'pending_waste_reports' => $pendingWaste,
                'resolved_waste_reports' => $resolvedWaste,
                'published_announcements' => $publishedAnnouncements,
                'emergency_contacts' => $emergencyContacts,
                'ferry_schedules' => $ferrySchedules,
            ],
        ]);
    }

    /**
     * Update Tourist Spot Status / Archiving
     */
    public function updateSpotStatus(Request $request, $id)
    {
        $request->validate([
            'status' => 'required|string|in:active,maintenance,archived',
        ]);

        $spot = TouristSpot::findOrFail($id);
        $spot->status = $request->status;
        $spot->save();

        return response()->json([
            'status' => 'success',
            'message' => 'Tourist spot status updated successfully.',
            'data' => $spot,
        ]);
    }

    /**
     * MSME Verification / Approval / Rejection / Suspension
     */
    public function verifyMsme(Request $request, $id)
    {
        $request->validate([
            'is_verified' => 'required|boolean',
            'status' => 'nullable|string|in:pending,approved,rejected,suspended',
            'notes' => 'nullable|string',
        ]);

        $msme = Msme::findOrFail($id);
        $msme->is_verified = $request->is_verified;
        if ($request->has('status')) {
            $msme->status = $request->status;
        }
        $msme->save();

        return response()->json([
            'status' => 'success',
            'message' => 'MSME verification state updated successfully.',
            'data' => $msme,
        ]);
    }

    /**
     * Waste Report Status, Remarks & Personnel Assignment
     */
    public function updateWasteStatus(Request $request, $id)
    {
        $request->validate([
            'status' => 'required|string|in:submitted,in_progress,resolved',
            'remarks' => 'nullable|string',
            'assigned_personnel' => 'nullable|string',
        ]);

        $report = WasteReport::findOrFail($id);
        $report->status = $request->status;
        if ($request->has('remarks')) {
            $report->remarks = $request->remarks;
        }
        if ($request->has('assigned_personnel')) {
            $report->assigned_personnel = $request->assigned_personnel;
        }
        $report->save();

        return response()->json([
            'status' => 'success',
            'message' => 'Waste report status updated successfully.',
            'data' => $report,
        ]);
    }

    /**
     * Municipal Tourism Analytics
     */
    public function analytics(Request $request)
    {
        $monthlyVisitors = [
            ['month' => 'Jan', 'visitors' => 1200],
            ['month' => 'Feb', 'visitors' => 1450],
            ['month' => 'Mar', 'visitors' => 1800],
            ['month' => 'Apr', 'visitors' => 2400],
            ['month' => 'May', 'visitors' => 2100],
            ['month' => 'Jun', 'visitors' => 1950],
            ['month' => 'Jul', 'visitors' => 2300],
        ];

        $reservationTrends = [
            ['month' => 'Jan', 'count' => 180],
            ['month' => 'Feb', 'count' => 220],
            ['month' => 'Mar', 'count' => 310],
            ['month' => 'Apr', 'count' => 450],
            ['month' => 'May', 'count' => 390],
            ['month' => 'Jun', 'count' => 340],
            ['month' => 'Jul', 'count' => 410],
        ];

        $wasteStats = [
            'submitted' => WasteReport::where('status', 'submitted')->count(),
            'in_progress' => WasteReport::where('status', 'in_progress')->count(),
            'resolved' => WasteReport::where('status', 'resolved')->count(),
        ];

        return response()->json([
            'status' => 'success',
            'data' => [
                'monthly_visitors' => $monthlyVisitors,
                'reservation_trends' => $reservationTrends,
                'waste_stats' => $wasteStats,
                'estimated_revenue' => 348500.00,
            ],
        ]);
    }

    /**
     * Municipal Reports Generation Data
     */
    public function reports(Request $request)
    {
        $period = $request->query('period', 'monthly');

        return response()->json([
            'status' => 'success',
            'data' => [
                'period' => $period,
                'generated_at' => now()->toIso8601String(),
                'total_tourists' => 15640,
                'total_revenue' => 348500.00,
                'spots_active' => TouristSpot::where('status', 'active')->count(),
                'msmes_active' => Msme::where('is_verified', true)->count(),
                'waste_reports_resolved' => WasteReport::where('status', 'resolved')->count(),
            ],
        ]);
    }
}
