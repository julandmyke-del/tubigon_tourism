<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Announcement;
use App\Models\EmergencyContact;
use App\Models\EmergencyContactAudit;
use App\Models\MapLocation;
use App\Models\Msme;
use App\Models\Notification;
use App\Models\PartnerNotification;
use App\Models\Reservation;
use App\Models\TouristSpot;
use App\Models\User;
use App\Models\WasteReport;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\Rule;

class LguController extends Controller
{
    public function dashboardStats(Request $request): JsonResponse
    {
        $activeReservations = Reservation::where('reservable_type', 'spot')
            ->whereHas('status', fn ($query) => $query->whereIn('name', ['pending', 'approved', 'confirmed']))
            ->count();
        $pendingWaste = WasteReport::whereIn('status', ['pending', 'submitted', 'under_review', 'assigned', 'in_progress'])->count();
        $resolvedWaste = WasteReport::whereIn('status', ['resolved', 'closed'])->count();
        $pendingMsmes = Msme::where('verification_status', 'pending')->count();
        $unverifiedEmergency = EmergencyContact::where(function ($query) {
            $query->where('is_verified', false)->orWhereNull('last_verified_at');
        })->count();
        $mapReview = MapLocation::where(function ($query) {
            $query->where('verified', false)->orWhere('published', false);
        })->where('active', true)->count();
        $activeAnnouncements = $this->activeAnnouncementCount();

        $alerts = collect([
            $pendingMsmes > 0 ? ['type' => 'msme', 'count' => $pendingMsmes, 'message' => "$pendingMsmes MSME application(s) await review.", 'route' => '/lgu/msme'] : null,
            $pendingWaste > 0 ? ['type' => 'waste', 'count' => $pendingWaste, 'message' => "$pendingWaste waste report(s) require operational attention.", 'route' => '/lgu/waste-reports'] : null,
            $unverifiedEmergency > 0 ? ['type' => 'emergency', 'count' => $unverifiedEmergency, 'message' => "$unverifiedEmergency emergency contact(s) need verification.", 'route' => '/lgu/emergency'] : null,
            $mapReview > 0 ? ['type' => 'map', 'count' => $mapReview, 'message' => "$mapReview map location(s) need review.", 'route' => '/lgu/map-locations'] : null,
        ])->filter()->values();

        return response()->json(['status' => 'success', 'data' => [
            'totalSpots' => TouristSpot::count(),
            'activeSpots' => TouristSpot::where('is_active', true)->count(),
            'verifiedMsmes' => Msme::where('verification_status', 'verified')->count(),
            'totalMsmes' => Msme::count(),
            'activeReservations' => $activeReservations,
            'pendingWasteReports' => $pendingWaste,
            'resolvedWasteReports' => $resolvedWaste,
            'activeAnnouncements' => $activeAnnouncements,
            'emergencyContacts' => EmergencyContact::where('is_active', true)->count(),
            'actionCenter' => [
                'msmesAwaitingReview' => $pendingMsmes,
                'emergencyContactsNeedingVerification' => $unverifiedEmergency,
                'wasteReportsAwaitingReview' => WasteReport::whereIn('status', ['pending', 'submitted'])->count(),
                'mapLocationsNeedingReview' => $mapReview,
            ],
            'operationalAlerts' => $alerts,
            'recentActivity' => $this->recentMunicipalActivity(10),
            'lastSyncedAt' => now()->toIso8601String(),
        ]]);
    }

    public function activity(Request $request): JsonResponse
    {
        $request->validate([
            'period' => ['nullable', Rule::in(['today', 'weekly', 'monthly', 'quarterly', 'yearly', 'custom'])],
            'from' => 'nullable|required_if:period,custom|date',
            'to' => 'nullable|required_if:period,custom|date|after_or_equal:from',
            'type' => ['nullable', Rule::in(['reservation', 'tourist_spot', 'msme', 'waste', 'map', 'emergency', 'announcement'])],
            'search' => 'nullable|string|max:200',
            'limit' => 'nullable|integer|min:1|max:100',
        ]);
        [$start, $end, $period] = $this->resolvePeriod($request);
        $limit = (int) $request->query('limit', 50);
        $type = $request->query('type');
        $search = trim((string) $request->query('search', ''));

        $activities = $type === 'emergency' ? collect() : ActivityLog::with('user:id,name')
            ->whereBetween('created_at', [$start, $end])
            ->where(fn (Builder $query) => $this->municipalActivityFilter($query))
            ->when($type, fn (Builder $query) => $this->activityTypeFilter($query, (string) $type))
            ->when($search !== '', fn (Builder $query) => $query->where(function (Builder $inner) use ($search) {
                $inner->where('action', 'like', '%'.$search.'%')->orWhere('details', 'like', '%'.$search.'%');
            }))
            ->latest()
            ->limit($limit)
            ->get()
            ->map(fn (ActivityLog $entry) => $this->activityPayload($entry));

        if (! $type || $type === 'emergency') {
            $emergency = EmergencyContactAudit::with(['actor:id,name', 'contact:id,name'])
                ->whereBetween('created_at', [$start, $end])
                ->latest()
                ->limit($limit)
                ->get()
                ->map(fn (EmergencyContactAudit $entry) => [
                    'id' => $entry->id,
                    'type' => 'emergency',
                    'action' => 'Emergency contact '.$entry->action,
                    'target' => $entry->contact?->name ?? 'Emergency contact',
                    'target_id' => $entry->contact_id,
                    'actor' => $entry->actor?->name ?? 'Authorized staff',
                    'created_at' => $entry->created_at?->toIso8601String(),
                ]);
            $activities = $activities->concat($emergency);
        }

        $items = $activities->sortByDesc('created_at')->take($limit)->values();

        return response()->json(['status' => 'success', 'data' => [
            'items' => $items,
            'period' => $this->periodPayload($period, $start, $end),
            'limit' => $limit,
        ]]);
    }

    public function updateSpotStatus(Request $request, string $id): JsonResponse
    {
        $validated = $request->validate(['status' => ['required', Rule::in(['active', 'maintenance', 'inactive', 'archived'])]]);
        $status = $validated['status'] === 'archived' ? 'inactive' : $validated['status'];
        $spot = TouristSpot::with('partnerAssignments')->findOrFail($id);
        $before = $spot->toArray();
        $changes = ['is_active' => $status === 'active'];
        if (Schema::hasColumn('tourist_spots', 'operational_status')) {
            $changes['operational_status'] = $status;
        }

        DB::transaction(function () use ($request, $spot, $before, $changes, $status): void {
            $spot->update($changes);
            $this->log($request->user()->id, 'Tourist spot '.$status, 'tourist_spot', $spot->id, $before, $spot->fresh()->toArray());
            foreach ($spot->partnerAssignments as $assignment) {
                PartnerNotification::create([
                    'user_id' => $assignment->partner_profile_id,
                    'type' => 'tourist_spot_status_changed',
                    'title' => 'Destination Status Updated',
                    'body' => "{$spot->name} is now marked {$status} by LGU staff.",
                    'data' => ['tourist_spot_id' => $spot->id, 'status' => $status, 'route' => '/tourism-partner'],
                ]);
            }
        });

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
        abort_if(in_array($validated['status'], ['resolved', 'rejected'], true) && blank($validated['notes'] ?? null), 422, 'A resolution or rejection note is required.');
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
            if ($report->user_id) {
                Notification::create([
                    'user_id' => $report->user_id,
                    'type' => 'waste_report_'.$validated['status'],
                    'title' => 'Waste Report '.str_replace('_', ' ', ucfirst($validated['status'])),
                    'body' => 'Your waste report is now '.str_replace('_', ' ', $validated['status']).'.',
                    'data' => ['waste_report_id' => $report->id, 'status' => $validated['status'], 'route' => '/waste-report'],
                ]);
            }
        });

        return response()->json(['status' => 'success', 'message' => 'Waste report updated.', 'data' => $report->fresh()]);
    }

    public function analytics(Request $request): JsonResponse
    {
        return response()->json(['status' => 'success', 'data' => $this->analyticsPayload($request)]);
    }

    public function reports(Request $request): JsonResponse
    {
        $request->validate(['category' => ['nullable', Rule::in([
            'tourism_operations', 'reservations', 'tourist_spots', 'msmes', 'waste_reports', 'emergency_contacts', 'announcements',
        ])]]);
        $analytics = $this->analyticsPayload($request);
        $category = (string) $request->query('category', 'tourism_operations');
        $insights = [];
        $top = collect($analytics['mostBookedDestinations'])->first();
        if ($top) $insights[] = $top['name'].' recorded the most reservations in this period.';
        if (($analytics['msmeStatuses']['pending'] ?? 0) > 0) $insights[] = $analytics['msmeStatuses']['pending'].' MSME application(s) remain pending.';
        if (($analytics['wasteOpen'] ?? 0) > 0) $insights[] = $analytics['wasteOpen'].' waste report(s) remain open.';

        return response()->json(['status' => 'success', 'data' => [
            'title' => 'Tubigon Tourism Office Municipal Operations Report',
            'category' => $category,
            'period' => $analytics['period'],
            'generatedAt' => now()->toIso8601String(),
            'generatedBy' => $request->user()->name,
            'summary' => [
                'reservations' => $analytics['totalReservations'],
                'activeTouristSpots' => $analytics['activeTouristSpots'],
                'verifiedMsmes' => $analytics['verifiedMsmes'],
                'resolvedWasteReports' => $analytics['resolvedWasteReports'],
                'activeEmergencyContacts' => $analytics['activeEmergencyContacts'],
                'activeAnnouncements' => $analytics['activeAnnouncements'],
            ],
            'reservationStatuses' => $analytics['reservationStatuses'],
            'msmeStatuses' => $analytics['msmeStatuses'],
            'wasteStatuses' => $analytics['wasteStatuses'],
            'touristSpotStatuses' => $analytics['touristSpotStatuses'],
            'bookingOverview' => $analytics['bookingOverview'],
            'mostBookedDestinations' => $analytics['mostBookedDestinations'],
            'keyInsights' => $insights,
        ]]);
    }

    private function analyticsPayload(Request $request): array
    {
        [$start, $end, $period] = $this->resolvePeriod($request);
        $reservationBase = Reservation::query()->where('reservable_type', 'spot')->whereBetween('reservations.created_at', [$start, $end]);
        $totalReservations = (clone $reservationBase)->count();
        $reservationStatuses = (clone $reservationBase)
            ->leftJoin('reservation_status', 'reservation_status.id', '=', 'reservations.status_id')
            ->selectRaw("COALESCE(reservation_status.name, 'pending') as status_name, COUNT(*) as total")
            ->groupBy('status_name')->pluck('total', 'status_name');
        $reservationSeries = (clone $reservationBase)
            ->selectRaw('DATE(reservations.created_at) as activity_date, COUNT(*) as total')
            ->groupBy('activity_date')->orderBy('activity_date')->get()
            ->map(fn ($row) => ['date' => $row->activity_date, 'total' => (int) $row->total]);
        $wasteStatuses = WasteReport::whereBetween('created_at', [$start, $end])
            ->select('status', DB::raw('COUNT(*) as total'))->groupBy('status')->pluck('total', 'status');
        $msmeStatuses = Msme::whereBetween('created_at', [$start, $end])
            ->select('verification_status', DB::raw('COUNT(*) as total'))->groupBy('verification_status')->pluck('total', 'verification_status');
        $spotStatusColumn = Schema::hasColumn('tourist_spots', 'operational_status') ? 'operational_status' : null;
        $spotStatuses = $spotStatusColumn
            ? TouristSpot::select($spotStatusColumn, DB::raw('COUNT(*) as total'))->groupBy($spotStatusColumn)->pluck('total', $spotStatusColumn)
            : collect(['active' => TouristSpot::where('is_active', true)->count(), 'inactive' => TouristSpot::where('is_active', false)->count()]);
        $mostBooked = (clone $reservationBase)
            ->join('tourist_spots', 'tourist_spots.id', '=', 'reservations.reservable_id')
            ->select('tourist_spots.id', 'tourist_spots.name', DB::raw('COUNT(*) as total'))
            ->groupBy('tourist_spots.id', 'tourist_spots.name')->orderByDesc('total')->limit(10)->get()
            ->map(fn ($row) => ['id' => $row->id, 'name' => $row->name, 'total' => (int) $row->total]);

        $duration = max(1, $start->diffInSeconds($end));
        $previousEnd = $start->copy()->subSecond();
        $previousStart = $previousEnd->copy()->subSeconds($duration);
        $previousReservations = Reservation::where('reservable_type', 'spot')->whereBetween('created_at', [$previousStart, $previousEnd])->count();

        return [
            'period' => $this->periodPayload($period, $start, $end),
            'totalReservations' => $totalReservations,
            'previousReservations' => $previousReservations,
            'reservationChangePercent' => $previousReservations > 0
                ? round((($totalReservations - $previousReservations) / $previousReservations) * 100, 1)
                : null,
            'reservationStatuses' => $reservationStatuses,
            'reservationsOverTime' => $reservationSeries,
            'msmeStatuses' => $msmeStatuses,
            'verifiedMsmes' => Msme::where('verification_status', 'verified')->count(),
            'wasteStatuses' => $wasteStatuses,
            'wasteOpen' => WasteReport::whereNotIn('status', ['resolved', 'closed', 'rejected'])->count(),
            'resolvedWasteReports' => WasteReport::whereBetween('resolved_at', [$start, $end])->count(),
            'touristSpotStatuses' => $spotStatuses,
            'activeTouristSpots' => TouristSpot::where('is_active', true)->count(),
            'bookingOverview' => [
                'open' => TouristSpot::where('is_bookable', true)->where('booking_enabled', true)->count(),
                'closed' => TouristSpot::where('is_bookable', true)->where('booking_enabled', false)->count(),
                'not_configured' => TouristSpot::where('is_bookable', false)->count(),
            ],
            'mostBookedDestinations' => $mostBooked,
            'activeEmergencyContacts' => EmergencyContact::where('is_active', true)->count(),
            'activeAnnouncements' => $this->activeAnnouncementCount(),
        ];
    }

    /** @return array{0: Carbon, 1: Carbon, 2: string} */
    private function resolvePeriod(Request $request): array
    {
        $request->validate([
            'period' => ['nullable', Rule::in(['today', 'daily', 'weekly', 'monthly', 'quarterly', 'yearly', 'custom'])],
            'from' => 'nullable|required_if:period,custom|date',
            'to' => 'nullable|required_if:period,custom|date|after_or_equal:from',
        ]);
        $period = (string) $request->query('period', 'monthly');
        $now = now();
        [$start, $end] = match ($period) {
            'today', 'daily' => [$now->copy()->startOfDay(), $now->copy()->endOfDay()],
            'weekly' => [$now->copy()->startOfWeek(), $now->copy()->endOfDay()],
            'quarterly' => [$now->copy()->startOfQuarter(), $now->copy()->endOfDay()],
            'yearly' => [$now->copy()->startOfYear(), $now->copy()->endOfDay()],
            'custom' => [Carbon::parse((string) $request->query('from'))->startOfDay(), Carbon::parse((string) $request->query('to'))->endOfDay()],
            default => [$now->copy()->startOfMonth(), $now->copy()->endOfDay()],
        };
        abort_if($start->diffInDays($end) > 366, 422, 'The reporting range cannot exceed 366 days.');

        return [$start, $end, $period];
    }

    private function periodPayload(string $period, Carbon $start, Carbon $end): array
    {
        return ['key' => $period, 'from' => $start->toDateString(), 'to' => $end->toDateString()];
    }

    private function activeAnnouncementCount(): int
    {
        if (Schema::hasColumn('announcements', 'status')) {
            return Announcement::visibleTo('lgu_staff')->count();
        }

        return Announcement::where('is_active', true)->count();
    }

    private function recentMunicipalActivity(int $limit): Collection
    {
        $activities = ActivityLog::with('user:id,name')
            ->where(fn (Builder $query) => $this->municipalActivityFilter($query))
            ->latest()->limit($limit * 2)->get()
            ->map(fn (ActivityLog $entry) => $this->activityPayload($entry));
        if (Schema::hasTable('emergency_contact_audits')) {
            $activities = $activities->concat(
                EmergencyContactAudit::with(['actor:id,name', 'contact:id,name'])->latest()->limit($limit)->get()
                    ->map(fn (EmergencyContactAudit $entry) => [
                        'id' => $entry->id,
                        'type' => 'emergency',
                        'action' => 'Emergency contact '.$entry->action,
                        'target' => $entry->contact?->name ?? 'Emergency contact',
                        'target_id' => $entry->contact_id,
                        'actor' => $entry->actor?->name ?? 'Authorized staff',
                        'created_at' => $entry->created_at?->toIso8601String(),
                    ]),
            );
        }

        return $activities->sortByDesc('created_at')->take($limit)->values();
    }

    private function municipalActivityFilter(Builder $query): Builder
    {
        foreach (['Reservation', 'Tourist spot', 'Tourist Spot', 'MSME', 'Waste report', 'Location', 'Announcement'] as $index => $term) {
            $index === 0 ? $query->where('action', 'like', $term.'%') : $query->orWhere('action', 'like', $term.'%');
        }

        return $query;
    }

    private function activityTypeFilter(Builder $query, string $type): Builder
    {
        $terms = match ($type) {
            'reservation' => ['Reservation'],
            'tourist_spot' => ['Tourist spot', 'Tourist Spot'],
            'msme' => ['MSME'],
            'waste' => ['Waste report'],
            'map' => ['Location'],
            'announcement' => ['Announcement'],
            default => [],
        };
        return $query->where(function (Builder $inner) use ($terms) {
            foreach ($terms as $index => $term) {
                $index === 0 ? $inner->where('action', 'like', $term.'%') : $inner->orWhere('action', 'like', $term.'%');
            }
        });
    }

    private function activityPayload(ActivityLog $entry): array
    {
        $details = json_decode((string) $entry->details, true);
        $details = is_array($details) ? $details : [];
        $target = data_get($details, 'tourist_spot_name')
            ?? data_get($details, 'after.name')
            ?? data_get($details, 'new.name')
            ?? data_get($details, 'name')
            ?? data_get($details, 'entityType')
            ?? data_get($details, 'entity_type')
            ?? 'Municipal record';
        $targetId = data_get($details, 'tourist_spot_id')
            ?? data_get($details, 'entityId')
            ?? data_get($details, 'entity_id')
            ?? data_get($details, 'location_id');

        return [
            'id' => $entry->id,
            'type' => $this->activityType($entry->action),
            'action' => $entry->action,
            'target' => (string) $target,
            'target_id' => $targetId,
            'actor' => $entry->user?->name ?? 'Authorized user',
            'created_at' => $entry->created_at?->toIso8601String(),
        ];
    }

    private function activityType(string $action): string
    {
        $action = strtolower($action);
        return match (true) {
            str_contains($action, 'reservation') => 'reservation',
            str_contains($action, 'tourist spot') => 'tourist_spot',
            str_contains($action, 'msme') => 'msme',
            str_contains($action, 'waste') => 'waste',
            str_contains($action, 'location') => 'map',
            str_contains($action, 'announcement') => 'announcement',
            default => 'municipal',
        };
    }

    private function log(string $actor, string $action, string $entityType, string $entityId, ?array $before, ?array $after): void
    {
        ActivityLog::create(['user_id' => $actor, 'action' => $action, 'details' => json_encode(compact('entityType', 'entityId', 'before', 'after'))]);
    }
}
