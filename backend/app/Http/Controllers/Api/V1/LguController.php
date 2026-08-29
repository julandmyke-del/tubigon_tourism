<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Announcement;
use App\Models\EmergencyContact;
use App\Models\FerrySchedule;
use App\Models\MapLocation;
use App\Models\Msme;
use App\Models\Notification;
use App\Models\Reservation;
use App\Models\TouristSpot;
use App\Models\User;
use App\Models\WasteReport;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class LguController extends Controller
{
    public function dashboardStats(Request $request): JsonResponse
    {
        $activeReservations = Reservation::whereHas('status', fn ($query) => $query->whereIn('name', ['pending', 'approved', 'confirmed']))->count();
        $pendingWaste = WasteReport::whereIn('status', ['pending', 'submitted', 'under_review', 'assigned', 'in_progress'])->count();
        $actionCenter = [
            'msmesAwaitingReview' => Msme::where('verification_status', 'pending')->count(),
            'emergencyContactsNeedingVerification' => EmergencyContact::where(function ($query) {
                $query->where('is_verified', false)->orWhereNull('last_verified_at');
            })->count(),
            'wasteReportsAwaitingReview' => WasteReport::whereIn('status', ['pending', 'submitted'])->count(),
            'mapLocationsNeedingReview' => MapLocation::where(function ($query) {
                $query->where('verified', false)->orWhere('published', false);
            })->where('active', true)->count(),
        ];

        return response()->json(['status' => 'success', 'data' => [
            'totalSpots' => TouristSpot::count(),
            'totalMsmes' => Msme::count(),
            'activeReservations' => $activeReservations,
            'pendingWasteReports' => $pendingWaste,
            'resolvedWasteReports' => WasteReport::whereIn('status', ['resolved', 'closed'])->count(),
            'publishedAnnouncements' => Announcement::count(),
            'emergencyContacts' => EmergencyContact::count(),
            'ferrySchedules' => FerrySchedule::count(),
            'actionCenter' => $actionCenter,
        ]]);
    }

    public function updateSpotStatus(Request $request, string $id): JsonResponse
    {
        $validated = $request->validate(['status' => 'required|in:active,maintenance,archived']);
        $spot = TouristSpot::findOrFail($id);
        $before = $spot->toArray();
        $spot->update(['is_active' => $validated['status'] === 'active']);
        $this->log($request->user()->id, 'Tourist spot '.$validated['status'], 'tourist_spot', $spot->id, $before, $spot->fresh()->toArray());
        return response()->json(['status' => 'success', 'message' => 'Tourist spot status updated.', 'data' => $spot->fresh()]);
    }

    public function verifyMsme(Request $request, string $id): JsonResponse
    {
        return (new MsmeController())->updateVerification($request, $id);
    }

    public function updateWasteStatus(Request $request, string $id): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', Rule::in(['submitted', 'under_review', 'assigned', 'in_progress', 'resolved', 'closed', 'rejected'])],
            'priority' => ['nullable', Rule::in(['low', 'normal', 'high', 'urgent'])],
            'assigned_to' => 'nullable|uuid|exists:users,id',
            'assigned_personnel' => 'nullable|string|max:255',
            'notes' => 'nullable|string|max:2000',
            'resolution_evidence' => 'nullable|array|max:10',
            'resolution_evidence.*' => 'string|max:2048',
        ]);
        $report = WasteReport::findOrFail($id);
        $current = $report->status === 'pending' ? 'submitted' : $report->status;
        $allowed = [
            'submitted' => ['under_review', 'rejected'],
            'under_review' => ['assigned', 'in_progress', 'rejected'],
            'assigned' => ['in_progress', 'rejected'],
            'in_progress' => ['resolved'],
            'resolved' => ['closed'],
            'closed' => [],
            'rejected' => [],
        ];
        abort_unless($validated['status'] === $current || in_array($validated['status'], $allowed[$current] ?? [], true), 422, "A {$current} report cannot transition to {$validated['status']}.");
        abort_if($validated['status'] === 'assigned' && empty($validated['assigned_to']) && empty($validated['assigned_personnel']), 422, 'Choose a staff member or responsible team before assigning this report.');
        $before = $report->toArray();
        $changes = [
            'status' => $validated['status'],
            'priority' => $validated['priority'] ?? $report->priority,
            'lgu_notes' => $validated['notes'] ?? $report->lgu_notes,
            'resolution_evidence' => $validated['resolution_evidence'] ?? $report->resolution_evidence,
        ];
        if (array_key_exists('assigned_to', $validated) || array_key_exists('assigned_personnel', $validated)) {
            $changes['assigned_to'] = $validated['assigned_to'] ?? null;
            $changes['assigned_personnel'] = isset($validated['assigned_to'])
                ? User::whereKey($validated['assigned_to'])->value('name')
                : ($validated['assigned_personnel'] ?? null);
            $changes['assigned_at'] = now();
        }
        if ($validated['status'] === 'under_review') $changes['reviewed_at'] = now();
        if ($validated['status'] === 'resolved') $changes['resolved_at'] = now();

        DB::transaction(function () use ($request, $report, $before, $changes, $validated): void {
            $report->update($changes);
            $this->log($request->user()->id, 'Waste report '.$validated['status'], 'waste_report', $report->id, $before, $report->fresh()->toArray());
            Notification::create([
                'user_id' => $report->user_id,
                'type' => 'waste_report_'.$validated['status'],
                'title' => 'Waste Report '.str_replace('_', ' ', ucfirst($validated['status'])),
                'body' => "Your waste report is now ".str_replace('_', ' ', $validated['status']).'.',
                'data' => ['waste_report_id' => $report->id, 'status' => $validated['status'], 'route' => '/waste-report'],
            ]);
        });

        return response()->json(['status' => 'success', 'message' => 'Waste report updated.', 'data' => $report->fresh()]);
    }

    public function analytics(Request $request): JsonResponse
    {
        $reservationStatuses = Reservation::with('status')->get()->groupBy(fn (Reservation $item) => $item->status?->name ?? 'pending')->map->count();
        $wasteStatuses = WasteReport::select('status', DB::raw('COUNT(*) as total'))->groupBy('status')->pluck('total', 'status');
        return response()->json(['status' => 'success', 'data' => [
            'totalReservations' => Reservation::count(),
            'reservationStatuses' => $reservationStatuses,
            'verifiedMsmes' => Msme::where('verification_status', 'verified')->count(),
            'pendingMsmes' => Msme::where('verification_status', 'pending')->count(),
            'wasteStatuses' => $wasteStatuses,
        ]]);
    }

    public function reports(Request $request): JsonResponse
    {
        return response()->json(['status' => 'success', 'data' => [
            'period' => $request->query('period', 'monthly'),
            'generatedAt' => now()->toIso8601String(),
            'spotsActive' => TouristSpot::where('is_active', true)->count(),
            'msmesVerified' => Msme::where('verification_status', 'verified')->count(),
            'wasteReportsResolved' => WasteReport::whereIn('status', ['resolved', 'closed'])->count(),
            'reservations' => Reservation::count(),
        ]]);
    }

    private function log(string $actor, string $action, string $entityType, string $entityId, ?array $before, ?array $after): void
    {
        ActivityLog::create(['user_id' => $actor, 'action' => $action, 'details' => json_encode(compact('entityType', 'entityId', 'before', 'after'))]);
    }
}
