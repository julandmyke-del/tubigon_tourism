<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\ValidatesTubigonCoordinates;
use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Msme;
use App\Models\MsmeCategory;
use App\Models\Notification;
use App\Models\Reservation;
use App\Models\ReservationStatus;
use App\Models\ReservationStatusHistory;
use App\Models\Review;
use App\Models\SystemSetting;
use App\Models\User;
use App\Services\EmailNotificationService;
use App\Support\ReservationStatusTransitions;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class MsmeController extends Controller
{
    use ValidatesTubigonCoordinates;

    public function categories(): JsonResponse
    {
        return response()->json([
            'status' => 'success',
            'data' => MsmeCategory::query()
                ->where('is_active', true)
                ->orderBy('display_order')
                ->orderBy('name')
                ->get(['id', 'name', 'slug', 'description']),
        ]);
    }

    public function index(Request $request): JsonResponse
    {
        $query = Msme::query()
            ->when(Schema::hasTable('msme_categories'), fn ($query) => $query->with('categoryRecord'))
            ->where('is_verified', true)
            ->where('verification_status', 'verified')
            ->when(
                Schema::hasColumn('msmes', 'operational_status'),
                fn ($query) => $query->whereIn('operational_status', ['open', 'temporarily_closed', 'fully_booked']),
            );
        if ($request->filled('category')) {
            $category = trim((string) $request->category);
            $query->where(function ($filter) use ($category): void {
                $filter->where('category', $category);
                if (Schema::hasTable('msme_categories')) {
                    $filter->orWhere('category_id', $category)
                        ->orWhereHas('categoryRecord', fn ($record) => $record
                            ->where('slug', $category)
                            ->orWhere('name', $category));
                }
            });
        }
        if ($request->filled('search')) {
            $term = '%'.trim((string) $request->search).'%';
            $query->where(fn ($search) => $search
                ->where('name', 'like', $term)
                ->orWhere('category', 'like', $term)
                ->orWhere('tagline', 'like', $term)
                ->orWhere('description', 'like', $term)
                ->orWhere('address', 'like', $term));
        }

        return response()->json(['status' => 'success', 'data' => $query->latest()->get()]);
    }

    public function show(string $id): JsonResponse
    {
        $msme = Msme::query()
            ->where('is_verified', true)
            ->where('verification_status', 'verified')
            ->findOrFail($id);

        return response()->json(['status' => 'success', 'data' => $msme]);
    }

    public function managementIndex(Request $request): JsonResponse
    {
        $query = Msme::with('profile')
            ->when(Schema::hasTable('msme_categories'), fn ($query) => $query->with('categoryRecord'));
        if ($request->filled('status')) {
            $validated = $request->validate([
                'status' => ['nullable', Rule::in(['pending', 'verified', 'needs_changes', 'suspended'])],
            ]);
            $query->where('verification_status', $validated['status']);
        }
        if ($request->filled('category')) {
            $category = trim((string) $request->category);
            $query->where(function ($filter) use ($category): void {
                $filter->where('category', $category);
                if (Schema::hasTable('msme_categories')) {
                    $filter->orWhere('category_id', $category)
                        ->orWhereHas('categoryRecord', fn ($record) => $record
                            ->where('slug', $category)
                            ->orWhere('name', $category));
                }
            });
        }
        if ($request->filled('search')) {
            $term = '%'.trim((string) $request->search).'%';
            $query->where(fn ($search) => $search
                ->where('name', 'like', $term)
                ->orWhere('category', 'like', $term)
                ->orWhere('tagline', 'like', $term)
                ->orWhere('description', 'like', $term)
                ->orWhere('address', 'like', $term));
        }

        return response()->json(['status' => 'success', 'data' => $query->latest()->get()]);
    }

    public function managementShow(string $id): JsonResponse
    {
        $msme = Msme::with('profile')->findOrFail($id);
        $history = ActivityLog::with('user:id,name')
            ->where('action', 'like', 'MSME review%')
            ->where('details', 'like', '%'.$msme->id.'%')
            ->latest()
            ->limit(25)
            ->get()
            ->map(function (ActivityLog $entry): array {
                $details = json_decode((string) $entry->details, true);

                return [
                    'id' => $entry->id,
                    'action' => $entry->action,
                    'actor' => $entry->user?->name ?? 'Authorized staff',
                    'notes' => is_array($details)
                        ? data_get($details, 'after.verification_notes')
                        : null,
                    'created_at' => $entry->created_at?->toIso8601String(),
                ];
            });

        return response()->json(['status' => 'success', 'data' => [
            ...$msme->toArray(),
            'review_history' => $history,
        ]]);
    }

    public function store(Request $request): JsonResponse
    {
        abort_unless(SystemSetting::enabled('msme_registration_enabled'), 403, 'MSME registration is currently disabled.');
        $validated = $this->validateBusiness($request);
        $validated['profile_id'] = $request->user()->id;
        $saveAsDraft = $request->boolean('save_as_draft');
        unset($validated['save_as_draft']);
        $requiresVerification = SystemSetting::enabled('require_msme_verification');
        $validated['is_verified'] = ! $saveAsDraft && ! $requiresVerification;
        $validated['verification_status'] = $saveAsDraft
            ? 'draft'
            : ($requiresVerification ? 'pending' : 'verified');
        $validated['submitted_at'] = $saveAsDraft ? null : now();
        $validated['reviewed_at'] = $saveAsDraft || $requiresVerification ? null : now();
        $this->validateTubigonCoordinates($validated);

        $msme = DB::transaction(function () use ($request, $validated, $requiresVerification, $saveAsDraft): Msme {
            User::whereKey($request->user()->id)->lockForUpdate()->firstOrFail();
            abort_if(
                Msme::withTrashed()->where('profile_id', $request->user()->id)->exists(),
                422,
                'This account already has a business profile, including an archived record. Contact LGU staff if it needs to be restored.',
            );
            $msme = Msme::create($validated);
            $this->log(
                $request->user()->id,
                $saveAsDraft ? 'MSME business draft created' : 'MSME business submitted',
                $msme->id,
                null,
                $msme->toArray(),
            );
            if (! $saveAsDraft && $requiresVerification) {
                $this->notifyReviewers($msme);
            }

            return $msme;
        });

        return response()->json([
            'status' => 'success',
            'message' => $saveAsDraft ? 'Business draft saved.' : 'Business submitted for review.',
            'data' => $msme,
            'profile_required' => false,
        ], 201);
    }

    public function ownerProfile(Request $request): JsonResponse
    {
        $msme = $this->currentBusiness($request);

        return response()->json([
            'status' => 'success',
            'data' => $msme,
            'profile_required' => $msme === null,
            'relationship' => 'zero_or_one_business_per_owner',
        ]);
    }

    public function updateOwnerProfile(Request $request): JsonResponse
    {
        $msme = $this->currentBusiness($request);
        if (! $msme) {
            return $this->profileRequiredMutation();
        }
        $validated = $this->validateBusiness($request, true);
        $this->validateTubigonCoordinates($validated, $msme->latitude, $msme->longitude);
        $before = $msme->toArray();
        $sensitive = ['name', 'category', 'phone', 'address', 'latitude', 'longitude'];
        $sensitiveChanged = collect($sensitive)->contains(
            fn (string $field) => array_key_exists($field, $validated) && (string) $validated[$field] !== (string) $msme->{$field}
        );
        if ($msme->is_verified && $sensitiveChanged
            && SystemSetting::enabled('require_msme_verification')) {
            $validated['is_verified'] = false;
            $validated['verification_status'] = 'pending';
            $validated['verification_notes'] = null;
            $validated['submitted_at'] = now();
            $validated['reviewed_at'] = null;
            $validated['reviewed_by'] = null;
        }

        DB::transaction(function () use ($request, $msme, $validated, $before, $sensitiveChanged): void {
            $msme->update($validated);
            $this->log($request->user()->id, 'MSME business updated', $msme->id, $before, $msme->fresh()->toArray());
            if ($sensitiveChanged) {
                $this->notifyReviewers($msme->fresh());
            }
        });

        return response()->json(['status' => 'success', 'data' => $msme->fresh()]);
    }

    public function submitOwnerProfile(Request $request): JsonResponse
    {
        $msme = $this->currentBusiness($request);
        if (! $msme) {
            return $this->profileRequiredMutation();
        }
        abort_if(blank($msme->name) || blank($msme->category) || blank($msme->address) || blank($msme->phone) || $msme->latitude === null || $msme->longitude === null, 422, 'Complete the business identity, contact, address, and map location before submitting.');
        abort_if($msme->verification_status === 'verified', 422, 'This business is already verified.');
        $before = $msme->toArray();
        $requiresVerification = SystemSetting::enabled('require_msme_verification');
        DB::transaction(function () use ($request, $msme, $before, $requiresVerification): void {
            $msme->update([
                'is_verified' => ! $requiresVerification,
                'verification_status' => $requiresVerification ? 'pending' : 'verified',
                'verification_notes' => null,
                'submitted_at' => now(),
                'reviewed_at' => $requiresVerification ? null : now(),
                'reviewed_by' => null,
            ]);
            $this->log($request->user()->id, 'MSME business submitted', $msme->id, $before, $msme->fresh()->toArray());
            if ($requiresVerification) {
                $this->notifyReviewers($msme->fresh());
            }
        });

        return response()->json([
            'status' => 'success',
            'message' => $requiresVerification ? 'Business submitted for review.' : 'Business published without manual verification.',
            'data' => $msme->fresh(),
        ]);
    }

    public function dashboardStats(Request $request): JsonResponse
    {
        $msme = $this->currentBusiness($request);
        if (! $msme) {
            return response()->json([
                'status' => 'success',
                'data' => $this->emptyDashboard(),
                'profile_required' => true,
            ]);
        }
        $reservationBase = Reservation::query()
            ->where('reservable_type', 'msme')->where('reservable_id', $msme->id);
        $statuses = (clone $reservationBase)
            ->leftJoin('reservation_status', 'reservation_status.id', '=', 'reservations.status_id')
            ->selectRaw("COALESCE(reservation_status.name, 'pending') as status_name, COUNT(*) as total")
            ->groupBy('status_name')->pluck('total', 'status_name');
        $reviewBase = Review::query()->where('reviewable_type', 'msme')->where('reviewable_id', $msme->id);
        $activity = ActivityLog::query()
            ->where('details', 'like', '%"entity_id":"'.$msme->id.'"%')
            ->latest()->limit(8)->get(['id', 'action', 'created_at'])
            ->map(fn (ActivityLog $item) => [
                'id' => $item->id,
                'action' => $item->action,
                'created_at' => $item->created_at?->toIso8601String(),
            ]);

        return response()->json(['status' => 'success', 'data' => [
            'business' => $msme,
            'profileCompletion' => $this->profileCompletion($msme),
            'totalReservations' => (clone $reservationBase)->count(),
            'pendingReservations' => (int) ($statuses['pending'] ?? 0),
            'confirmedReservations' => (int) (($statuses['confirmed'] ?? 0) + ($statuses['approved'] ?? 0)),
            'completedReservations' => (int) ($statuses['completed'] ?? 0),
            'cancelledReservations' => (int) (($statuses['cancelled'] ?? 0) + ($statuses['rejected'] ?? 0)),
            'averageRating' => round((float) ((clone $reviewBase)->avg('rating') ?? 0), 2),
            'reviewCount' => (clone $reviewBase)->count(),
            'recentActivity' => $activity,
        ], 'profile_required' => false]);
    }

    public function reservations(Request $request): JsonResponse
    {
        $msme = $this->currentBusiness($request);
        if (! $msme) {
            return response()->json([
                'status' => 'success', 'data' => [], 'profile_required' => true,
            ]);
        }
        $query = Reservation::with(['user:id,name,phone', 'status', 'statusHistory.status'])
            ->where('reservable_type', 'msme')
            ->where('reservable_id', $msme->id);
        if ($request->filled('status')) {
            $query->whereHas('status', fn ($q) => $q->where('name', $request->status));
        }

        return response()->json([
            'status' => 'success',
            'data' => $query->orderByDesc('reservation_date')->limit(100)->get(),
            'profile_required' => false,
        ]);
    }

    public function showReservation(Request $request, string $id): JsonResponse
    {
        $msme = $this->currentBusiness($request);
        if (! $msme) {
            return response()->json([
                'status' => 'success', 'data' => null, 'profile_required' => true,
            ]);
        }
        $reservation = $this->ownedReservation($msme, $id, true);

        return response()->json(['status' => 'success', 'data' => $reservation]);
    }

    public function updateReservationStatus(Request $request, string $id, EmailNotificationService $emailDelivery): JsonResponse
    {
        $validated = $request->validate([
            'status_name' => 'required|in:confirmed,rejected,completed,cancelled',
            'reason' => 'nullable|required_if:status_name,rejected,cancelled|string|max:1000',
        ]);
        $msme = $this->currentBusiness($request);
        if (! $msme) {
            return $this->profileRequiredMutation();
        }
        $reservation = DB::transaction(function () use ($request, $id, $validated, $msme): Reservation {
            $reservation = $this->ownedReservation($msme, $id, false, true);
            if (! ReservationStatusTransitions::allows($reservation->status?->name, $validated['status_name'])) {
                abort(response()->json([
                    'status' => 'error',
                    'message' => 'Invalid reservation status transition.',
                    'allowed_statuses' => ReservationStatusTransitions::allowedFrom($reservation->status?->name),
                ], 422));
            }
            $status = ReservationStatus::where('name', $validated['status_name'])->firstOrFail();
            $before = $reservation->status?->name;
            $reservation->update(['status_id' => $status->id]);
            if (Schema::hasTable('reservation_status_history')) {
                ReservationStatusHistory::create([
                    'reservation_id' => $reservation->id,
                    'status_id' => $status->id,
                    'changed_by' => $request->user()->id,
                    'notes' => $validated['reason'] ?? 'Status updated by MSME owner',
                ]);
            }
            Notification::create([
                'user_id' => $reservation->user_id,
                'type' => 'reservation_'.$status->name,
                'title' => 'Reservation '.ucfirst($status->name),
                'body' => "Your reservation at {$msme->name} has been {$status->name}.".
                    (isset($validated['reason']) ? ' Reason: '.$validated['reason'] : ''),
                'data' => ['reservation_id' => $reservation->id, 'route' => '/reservations/'.$reservation->id],
            ]);
            $this->log($request->user()->id, 'MSME reservation '.$status->name, $msme->id, ['status' => $before], ['status' => $status->name, 'reservation_id' => $reservation->id]);

            return $reservation;
        });

        if (in_array($validated['status_name'], ['confirmed', 'rejected', 'cancelled'], true)) {
            $emailDelivery->reservation(
                $reservation,
                $validated['status_name'],
                in_array($validated['status_name'], ['rejected', 'cancelled'], true)
                    ? trim((string) ($validated['reason'] ?? ''))
                    : null,
            );
        }

        return response()->json(['status' => 'success', 'message' => 'Reservation '.ucfirst($validated['status_name']).'.']);
    }

    public function reviews(Request $request): JsonResponse
    {
        $msme = $this->currentBusiness($request);
        if (! $msme) {
            return response()->json(['status' => 'success', 'data' => [
                'averageRating' => 0.0,
                'reviewCount' => 0,
                'ratingDistribution' => ['1' => 0, '2' => 0, '3' => 0, '4' => 0, '5' => 0],
                'reviews' => [],
            ], 'profile_required' => true]);
        }
        $reviews = Review::with('user:id,name')->where('reviewable_type', 'msme')->where('reviewable_id', $msme->id)->latest()->get();
        $distribution = $reviews->countBy('rating');

        return response()->json(['status' => 'success', 'data' => [
            'averageRating' => round((float) ($reviews->avg('rating') ?? 0), 2),
            'reviewCount' => $reviews->count(),
            'ratingDistribution' => collect(range(1, 5))->mapWithKeys(
                fn (int $rating) => [(string) $rating => (int) ($distribution[$rating] ?? 0)],
            ),
            'latestReview' => $reviews->first(),
            'reviews' => $reviews,
        ], 'profile_required' => false]);
    }

    public function analytics(Request $request): JsonResponse
    {
        $msme = $this->currentBusiness($request);
        if (! $msme) {
            return response()->json([
                'status' => 'success',
                'data' => [...$this->emptyDashboard(), 'period' => null],
                'profile_required' => true,
            ]);
        }

        [$start, $end, $periodKey] = $this->analyticsPeriod($request);
        $periodSeconds = $start->diffInSeconds($end) + 1;
        $previousStart = $start->copy()->subSeconds($periodSeconds);
        $previousEnd = $start->copy()->subSecond();
        $reservationBase = Reservation::query()->where('reservations.reservable_type', 'msme')
            ->where('reservations.reservable_id', $msme->id)
            ->whereBetween('reservations.created_at', [$start, $end]);
        $reviewBase = Review::query()->where('reviewable_type', 'msme')
            ->where('reviewable_id', $msme->id)->whereBetween('created_at', [$start, $end]);
        $statusCounts = (clone $reservationBase)
            ->leftJoin('reservation_status', 'reservation_status.id', '=', 'reservations.status_id')
            ->selectRaw("COALESCE(reservation_status.name, 'pending') as status_name, COUNT(*) as total")
            ->groupBy('status_name')->pluck('total', 'status_name');
        $currentTotal = (clone $reservationBase)->count();
        $previousTotal = Reservation::query()->where('reservable_type', 'msme')
            ->where('reservable_id', $msme->id)->whereBetween('created_at', [$previousStart, $previousEnd])->count();
        $comparison = $previousTotal > 0
            ? round((($currentTotal - $previousTotal) / $previousTotal) * 100, 1)
            : null;
        $ratingDistribution = (clone $reviewBase)->select('rating', DB::raw('COUNT(*) as total'))
            ->groupBy('rating')->pluck('total', 'rating');

        return response()->json(['status' => 'success', 'data' => [
            'business' => $msme,
            'period' => ['key' => $periodKey, 'from' => $start->toDateString(), 'to' => $end->toDateString()],
            'totalReservations' => $currentTotal,
            'pendingReservations' => (int) ($statusCounts['pending'] ?? 0),
            'confirmedReservations' => (int) (($statusCounts['confirmed'] ?? 0) + ($statusCounts['approved'] ?? 0)),
            'completedReservations' => (int) ($statusCounts['completed'] ?? 0),
            'cancelledReservations' => (int) (($statusCounts['cancelled'] ?? 0) + ($statusCounts['rejected'] ?? 0)),
            'reservationComparisonPercent' => $comparison,
            'averageRating' => round((float) ((clone $reviewBase)->avg('rating') ?? 0), 2),
            'reviewCount' => (clone $reviewBase)->count(),
            'reservationTrend' => (clone $reservationBase)->selectRaw('DATE(reservations.created_at) as date, COUNT(*) as total')
                ->groupBy('date')->orderBy('date')->get(),
            'reviewTrend' => (clone $reviewBase)->selectRaw('DATE(created_at) as date, COUNT(*) as total')
                ->groupBy('date')->orderBy('date')->get(),
            'reservationStatuses' => $statusCounts,
            'ratingDistribution' => collect(range(1, 5))->mapWithKeys(
                fn (int $rating) => [(string) $rating => (int) ($ratingDistribution[$rating] ?? 0)],
            ),
        ], 'profile_required' => false]);
    }

    public function updateVerification(Request $request, string $id): JsonResponse
    {
        $validated = $request->validate([
            'is_verified' => 'nullable|boolean',
            'verification_status' => ['nullable', Rule::in(['pending', 'verified', 'needs_changes', 'rejected', 'suspended', 'archived'])],
            'notes' => 'nullable|string|max:2000',
        ]);
        $targetStatus = $validated['verification_status'] ?? ($request->boolean('is_verified') ? 'verified' : 'needs_changes');
        abort_if(! array_key_exists('verification_status', $validated) && ! $request->has('is_verified'), 422, 'A verification decision is required.');
        abort_if(in_array($targetStatus, ['needs_changes', 'rejected', 'suspended'], true) && blank($validated['notes'] ?? null), 422, 'Review notes are required for this decision.');
        $msme = Msme::findOrFail($id);
        $before = $msme->toArray();

        DB::transaction(function () use ($request, $msme, $before, $targetStatus, $validated): void {
            $msme->update([
                'is_verified' => $targetStatus === 'verified',
                'verification_status' => $targetStatus,
                'verification_notes' => $validated['notes'] ?? null,
                'reviewed_at' => now(),
                'reviewed_by' => $request->user()->id,
            ]);
            $this->log($request->user()->id, 'MSME review '.$targetStatus, $msme->id, $before, $msme->fresh()->toArray());
            Notification::create([
                'user_id' => $msme->profile_id,
                'type' => 'msme_'.$targetStatus,
                'title' => $targetStatus === 'verified' ? 'Business Verified' : 'Business Review Updated',
                'body' => $targetStatus === 'verified' ? 'Your business has been verified and is now public.' : ($validated['notes'] ?? 'Your business review status has changed.'),
                'data' => ['msme_id' => $msme->id, 'status' => $targetStatus, 'route' => '/msme-portal/profile'],
            ]);
        });

        return response()->json(['status' => 'success', 'message' => 'MSME review saved.', 'data' => $msme->fresh()]);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        DB::transaction(function () use ($request, $id): void {
            $msme = Msme::findOrFail($id);
            $before = $msme->toArray();
            $msme->update(['verification_status' => 'archived', 'is_verified' => false]);
            $msme->delete();
            $this->log($request->user()->id, 'MSME archived', $id, $before, ['verification_status' => 'archived']);
        });

        return response()->json(['status' => 'success', 'message' => 'MSME archived']);
    }

    private function currentBusiness(Request $request): ?Msme
    {
        return $request->user()->msmeBusiness()
            ->when(Schema::hasTable('msme_categories'), fn ($query) => $query->with('categoryRecord'))
            ->first();
    }

    private function profileRequiredMutation(): JsonResponse
    {
        return response()->json([
            'status' => 'error',
            'code' => 'profile_required',
            'message' => 'Complete your business setup before using this feature.',
            'data' => null,
            'profile_required' => true,
        ], 409);
    }

    private function ownedReservation(
        Msme $msme,
        string $id,
        bool $withCustomer = false,
        bool $lock = false,
    ): Reservation {
        $query = Reservation::query()
            ->when($withCustomer, fn ($query) => $query->with(['user:id,name,phone', 'status']))
            ->when(! $withCustomer, fn ($query) => $query->with('status'))
            ->when($lock, fn ($query) => $query->lockForUpdate())
            ->where('reservable_type', 'msme')
            ->where('reservable_id', $msme->id);
        $reservation = $query->find($id);
        if ($reservation) {
            return $reservation;
        }

        abort_if(Reservation::whereKey($id)->exists(), 403, 'You may only access reservations for your own business.');
        abort(404, 'Reservation not found.');
    }

    private function profileCompletion(Msme $msme): array
    {
        $checks = [
            'business_name' => filled($msme->name),
            'category' => filled($msme->category),
            'description' => filled($msme->description),
            'contact_number' => filled($msme->phone),
            'address' => filled($msme->address),
            'coordinates' => $msme->latitude !== null && $msme->longitude !== null,
            'opening_hours' => ! empty($msme->opening_hours),
            'cover_image' => ! empty($msme->images),
            'verification_submission' => $msme->submitted_at !== null,
        ];
        $completed = collect($checks)->filter()->count();

        return [
            'percent' => (int) round(($completed / count($checks)) * 100),
            'completed' => $completed,
            'total' => count($checks),
            'items' => $checks,
        ];
    }

    /** @return array{0: Carbon, 1: Carbon, 2: string} */
    private function analyticsPeriod(Request $request): array
    {
        $validated = $request->validate([
            'period' => ['nullable', Rule::in(['7_days', '30_days', '3_months', 'year', 'custom'])],
            'from' => 'nullable|required_if:period,custom|date',
            'to' => 'nullable|required_if:period,custom|date|after_or_equal:from',
        ]);
        $period = (string) ($validated['period'] ?? '30_days');
        $now = now();
        [$start, $end] = match ($period) {
            '7_days' => [$now->copy()->subDays(6)->startOfDay(), $now->copy()->endOfDay()],
            '3_months' => [$now->copy()->subMonthsNoOverflow(3)->startOfDay(), $now->copy()->endOfDay()],
            'year' => [$now->copy()->startOfYear(), $now->copy()->endOfDay()],
            'custom' => [
                Carbon::parse((string) $validated['from'])->startOfDay(),
                Carbon::parse((string) $validated['to'])->endOfDay(),
            ],
            default => [$now->copy()->subDays(29)->startOfDay(), $now->copy()->endOfDay()],
        };
        abort_if($start->diffInDays($end) > 365, 422, 'Analytics ranges may cover at most 366 days.');

        return [$start, $end, $period];
    }

    private function validateBusiness(Request $request, bool $partial = false): array
    {
        $presence = $partial ? 'sometimes' : 'required';
        $hasCategoryTaxonomy = Schema::hasTable('msme_categories');
        $categoryIdRules = $hasCategoryTaxonomy
            ? [
                $partial ? 'sometimes' : 'required_without:category',
                'uuid',
                Rule::exists('msme_categories', 'id')
                    ->where(fn ($query) => $query->where('is_active', true)),
            ]
            : ['nullable'];
        $categoryRules = $hasCategoryTaxonomy
            ? [$partial ? 'sometimes' : 'required_without:category_id', 'string', 'max:255']
            : [$presence, 'string', 'max:255'];

        $validated = $request->validate([
            'name' => "$presence|string|max:255",
            'category_id' => $categoryIdRules,
            'category' => $categoryRules,
            'tagline' => 'nullable|string|max:255',
            'description' => 'nullable|string|max:5000',
            'phone' => 'nullable|string|max:255',
            'address' => 'nullable|string|max:1000',
            'latitude' => 'nullable|numeric|between:-90,90',
            'longitude' => 'nullable|numeric|between:-180,180',
            'business_hours' => 'nullable|string|max:255',
            'opening_hours' => 'nullable|array',
            'opening_hours.*' => 'nullable|array',
            'operational_status' => ['nullable', Rule::in(['open', 'temporarily_closed', 'fully_booked'])],
            'unavailable_dates' => 'nullable|array',
            'unavailable_dates.*' => 'date_format:Y-m-d',
            'images' => 'nullable|array|max:10',
            'images.*' => 'string|max:2048',
            'booking_enabled' => 'nullable|boolean',
            'save_as_draft' => 'nullable|boolean',
            'products' => 'nullable|array',
            'color' => 'nullable|string|max:50',
            'icon' => 'nullable|string|max:100',
        ]);

        if ($hasCategoryTaxonomy && array_key_exists('category_id', $validated)) {
            $category = MsmeCategory::query()
                ->where('is_active', true)
                ->findOrFail($validated['category_id']);
            $validated['category'] = $category->name;
        } elseif ($hasCategoryTaxonomy && array_key_exists('category', $validated)) {
            $categoryInput = trim((string) $validated['category']);
            $category = MsmeCategory::query()
                ->where('is_active', true)
                ->where(fn ($query) => $query
                    ->whereRaw('LOWER(name) = ?', [mb_strtolower($categoryInput)])
                    ->orWhere('slug', $categoryInput))
                ->first();
            if (! $category) {
                throw ValidationException::withMessages([
                    'category' => ['Select an active MSME category.'],
                ]);
            }
            $validated['category_id'] = $category->id;
            $validated['category'] = $category->name;
        }

        if (array_key_exists('opening_hours', $validated) && $validated['opening_hours'] !== null) {
            $weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
            foreach ($validated['opening_hours'] as $day => $hours) {
                if (! in_array($day, $weekdays, true)) {
                    throw ValidationException::withMessages([
                        "opening_hours.{$day}" => ['Opening hours may only contain weekday keys.'],
                    ]);
                }

                if (! is_array($hours)) {
                    throw ValidationException::withMessages([
                        "opening_hours.{$day}" => ['Opening hours must describe an open interval or a closed day.'],
                    ]);
                }

                if (($hours['closed'] ?? false) === true) {
                    continue;
                }

                $open = $hours['open'] ?? null;
                $close = $hours['close'] ?? null;
                if (! is_string($open) || ! is_string($close)
                    || preg_match('/^(?:[01]\d|2[0-3]):[0-5]\d$/', $open) !== 1
                    || preg_match('/^(?:[01]\d|2[0-3]):[0-5]\d$/', $close) !== 1
                    || $close <= $open) {
                    throw ValidationException::withMessages([
                        "opening_hours.{$day}" => ['Provide valid HH:mm opening and closing times, with closing after opening.'],
                    ]);
                }
            }
        }

        return $validated;
    }

    private function notifyReviewers(Msme $msme): void
    {
        User::with('role')->whereHas('role', fn ($query) => $query->whereIn('name', ['admin', 'lgu_staff']))
            ->get()->each(fn (User $reviewer) => Notification::create([
                'user_id' => $reviewer->id,
                'type' => 'msme_submitted',
                'title' => 'MSME Awaiting Review',
                'body' => "{$msme->name} submitted a business profile for review.",
                'data' => [
                    'msme_id' => $msme->id,
                    'route' => $reviewer->role?->name === 'admin' ? '/admin/msmes' : '/lgu/msme',
                ],
            ]));
    }

    private function log(string $actor, string $action, string $entityId, ?array $before, ?array $after): void
    {
        ActivityLog::create(['user_id' => $actor, 'action' => $action, 'details' => json_encode([
            'entity_type' => 'msme', 'entity_id' => $entityId, 'before' => $before, 'after' => $after,
        ])]);
    }

    private function emptyDashboard(): array
    {
        return [
            'business' => null,
            'profileCompletion' => ['percent' => 0, 'completed' => 0, 'total' => 9, 'items' => []],
            'totalReservations' => 0,
            'pendingReservations' => 0,
            'confirmedReservations' => 0,
            'completedReservations' => 0,
            'cancelledReservations' => 0,
            'averageRating' => 0.0,
            'reviewCount' => 0,
            'recentActivity' => [],
        ];
    }
}
