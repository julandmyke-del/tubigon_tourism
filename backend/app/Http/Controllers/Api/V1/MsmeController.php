<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\ValidatesTubigonCoordinates;
use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Msme;
use App\Models\Notification;
use App\Models\Reservation;
use App\Models\ReservationStatus;
use App\Models\Review;
use App\Models\User;
use App\Support\ReservationStatusTransitions;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class MsmeController extends Controller
{
    use ValidatesTubigonCoordinates;

    public function index(Request $request): JsonResponse
    {
        $query = Msme::query()
            ->where('is_verified', true)
            ->where('verification_status', 'verified')
            ->when(
                \Illuminate\Support\Facades\Schema::hasColumn('msmes', 'operational_status'),
                fn ($query) => $query->whereIn('operational_status', ['open', 'temporarily_closed', 'fully_booked']),
            );
        if ($request->filled('category')) $query->where('category', $request->category);
        if ($request->filled('search')) $query->where('name', 'like', '%'.$request->search.'%');

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
        $query = Msme::with('profile');
        if ($request->filled('status')) $query->where('verification_status', $request->status);
        if ($request->filled('category')) $query->where('category', $request->category);
        if ($request->filled('search')) $query->where('name', 'like', '%'.$request->search.'%');
        return response()->json(['status' => 'success', 'data' => $query->latest()->get()]);
    }

    public function store(Request $request): JsonResponse
    {
        abort_if(Msme::where('profile_id', $request->user()->id)->exists(), 422, 'This account already has a business profile.');
        $validated = $this->validateBusiness($request);
        $validated['profile_id'] = $request->user()->id;
        $validated['is_verified'] = false;
        $validated['verification_status'] = 'pending';
        $validated['submitted_at'] = now();
        $this->validateTubigonCoordinates($validated);

        $msme = DB::transaction(function () use ($request, $validated): Msme {
            $msme = Msme::create($validated);
            $this->log($request->user()->id, 'MSME business submitted', $msme->id, null, $msme->toArray());
            $this->notifyReviewers($msme);
            return $msme;
        });

        return response()->json(['status' => 'success', 'data' => $msme], 201);
    }

    public function ownerProfile(Request $request): JsonResponse
    {
        $msme = Msme::where('profile_id', $request->user()->id)->first();
        return response()->json(['status' => 'success', 'data' => $msme]);
    }

    public function updateOwnerProfile(Request $request): JsonResponse
    {
        $msme = $this->ownedBusiness($request);
        $validated = $this->validateBusiness($request, true);
        $this->validateTubigonCoordinates($validated, $msme->latitude, $msme->longitude);
        $before = $msme->toArray();
        $sensitive = ['name', 'category', 'phone', 'address', 'latitude', 'longitude'];
        $sensitiveChanged = collect($sensitive)->contains(
            fn (string $field) => array_key_exists($field, $validated) && (string) $validated[$field] !== (string) $msme->{$field}
        );
        if ($msme->is_verified && $sensitiveChanged) {
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
            if ($sensitiveChanged) $this->notifyReviewers($msme->fresh());
        });

        return response()->json(['status' => 'success', 'data' => $msme->fresh()]);
    }

    public function submitOwnerProfile(Request $request): JsonResponse
    {
        $msme = $this->ownedBusiness($request);
        abort_if(blank($msme->name) || blank($msme->category) || blank($msme->address) || blank($msme->phone) || $msme->latitude === null || $msme->longitude === null, 422, 'Complete the business identity, contact, address, and map location before submitting.');
        abort_if($msme->verification_status === 'verified', 422, 'This business is already verified.');
        $before = $msme->toArray();
        DB::transaction(function () use ($request, $msme, $before): void {
            $msme->update([
                'is_verified' => false,
                'verification_status' => 'pending',
                'verification_notes' => null,
                'submitted_at' => now(),
                'reviewed_at' => null,
                'reviewed_by' => null,
            ]);
            $this->log($request->user()->id, 'MSME business submitted', $msme->id, $before, $msme->fresh()->toArray());
            $this->notifyReviewers($msme->fresh());
        });
        return response()->json(['status' => 'success', 'message' => 'Business submitted for review.', 'data' => $msme->fresh()]);
    }

    public function dashboardStats(Request $request): JsonResponse
    {
        $msme = Msme::where('profile_id', $request->user()->id)->first();
        if (! $msme) return response()->json(['status' => 'success', 'data' => $this->emptyDashboard()]);
        $reservations = Reservation::with('status')->where('reservable_type', 'msme')->where('reservable_id', $msme->id)->get();
        $reviews = Review::where('reviewable_type', 'msme')->where('reviewable_id', $msme->id)->get();
        $statuses = $reservations->groupBy(fn (Reservation $item) => $item->status?->name ?? 'pending')->map->count();
        return response()->json(['status' => 'success', 'data' => [
            'business' => $msme,
            'totalReservations' => $reservations->count(),
            'pendingReservations' => (int) ($statuses['pending'] ?? 0),
            'confirmedReservations' => (int) (($statuses['confirmed'] ?? 0) + ($statuses['approved'] ?? 0)),
            'completedReservations' => (int) ($statuses['completed'] ?? 0),
            'averageRating' => round((float) ($reviews->avg('rating') ?? 0), 2),
            'reviewCount' => $reviews->count(),
            'recentActivity' => ActivityLog::where('details', 'like', '%"entity_id":"'.$msme->id.'"%')->latest()->limit(8)->get(),
        ]]);
    }

    public function reservations(Request $request): JsonResponse
    {
        $msme = $this->ownedBusiness($request);
        $query = Reservation::with(['user:id,name,phone', 'status'])->where('reservable_type', 'msme')->where('reservable_id', $msme->id);
        if ($request->filled('status')) $query->whereHas('status', fn ($q) => $q->where('name', $request->status));
        return response()->json(['status' => 'success', 'data' => $query->orderByDesc('reservation_date')->get()]);
    }

    public function showReservation(Request $request, string $id): JsonResponse
    {
        $msme = $this->ownedBusiness($request);
        $reservation = Reservation::with(['user:id,name,phone', 'status'])->where('reservable_type', 'msme')->where('reservable_id', $msme->id)->findOrFail($id);
        return response()->json(['status' => 'success', 'data' => $reservation]);
    }

    public function updateReservationStatus(Request $request, string $id): JsonResponse
    {
        $validated = $request->validate(['status_name' => 'required|in:confirmed,rejected,completed,cancelled']);
        $msme = $this->ownedBusiness($request);
        $reservation = Reservation::with('status')->where('reservable_type', 'msme')->where('reservable_id', $msme->id)->findOrFail($id);
        if (! ReservationStatusTransitions::allows($reservation->status?->name, $validated['status_name'])) {
            return response()->json(['status' => 'error', 'message' => 'Invalid reservation status transition.', 'allowed_statuses' => ReservationStatusTransitions::allowedFrom($reservation->status?->name)], 422);
        }
        $status = ReservationStatus::where('name', $validated['status_name'])->firstOrFail();
        DB::transaction(function () use ($request, $reservation, $status, $msme): void {
            $before = $reservation->status?->name;
            $reservation->update(['status_id' => $status->id]);
            Notification::create([
                'user_id' => $reservation->user_id,
                'type' => 'reservation_'.$status->name,
                'title' => 'Reservation '.ucfirst($status->name),
                'body' => "Your reservation at {$msme->name} has been {$status->name}.",
                'data' => ['reservation_id' => $reservation->id, 'route' => '/reservations/'.$reservation->id],
            ]);
            $this->log($request->user()->id, 'MSME reservation '.$status->name, $msme->id, ['status' => $before], ['status' => $status->name, 'reservation_id' => $reservation->id]);
        });
        return response()->json(['status' => 'success', 'message' => 'Reservation '.ucfirst($status->name).'.']);
    }

    public function reviews(Request $request): JsonResponse
    {
        $msme = $this->ownedBusiness($request);
        $reviews = Review::with('user:id,name')->where('reviewable_type', 'msme')->where('reviewable_id', $msme->id)->latest()->get();
        return response()->json(['status' => 'success', 'data' => [
            'averageRating' => round((float) ($reviews->avg('rating') ?? 0), 2),
            'reviewCount' => $reviews->count(),
            'reviews' => $reviews,
        ]]);
    }

    public function analytics(Request $request): JsonResponse
    {
        return $this->dashboardStats($request);
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

    private function ownedBusiness(Request $request): Msme
    {
        return Msme::where('profile_id', $request->user()->id)->firstOrFail();
    }

    private function validateBusiness(Request $request, bool $partial = false): array
    {
        $presence = $partial ? 'sometimes' : 'required';
        return $request->validate([
            'name' => "$presence|string|max:255",
            'category' => "$presence|string|max:255",
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
            'products' => 'nullable|array',
            'color' => 'nullable|string|max:50',
            'icon' => 'nullable|string|max:100',
        ]);
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
        return ['business' => null, 'totalReservations' => 0, 'pendingReservations' => 0, 'confirmedReservations' => 0, 'completedReservations' => 0, 'averageRating' => 0.0, 'reviewCount' => 0, 'recentActivity' => []];
    }
}
