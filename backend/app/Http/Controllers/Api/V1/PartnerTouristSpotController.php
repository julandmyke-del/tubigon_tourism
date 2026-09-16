<?php

namespace App\Http\Controllers\Api\V1;

use App\Actions\UpdateTouristSpotBookingAvailabilityAction;
use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\TouristSpot;
use App\Models\TouristSpotPartnerAssignment;
use App\Support\StaleRecordGuard;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

class PartnerTouristSpotController extends Controller
{
    public function assignment(Request $request): JsonResponse
    {
        $assignment = TouristSpotPartnerAssignment::with([
            'touristSpot.category',
            'touristSpot.bookingAvailabilityUpdatedBy:id,name',
            'assignedBy:id,name',
        ])->where('partner_profile_id', $request->user()->id)->first();

        if (! $assignment) {
            return response()->json(['status' => 'success', 'data' => null]);
        }

        return response()->json([
            'status' => 'success',
            'data' => [
                'id' => $assignment->id,
                'status' => 'active',
                'is_primary' => $assignment->is_primary,
                'assigned_at' => $assignment->assigned_at?->toIso8601String(),
                'assigned_by' => $assignment->assignedBy?->only(['id', 'name']),
                'destination' => $assignment->touristSpot,
            ],
        ]);
    }

    public function activity(Request $request): JsonResponse
    {
        $items = ActivityLog::where('user_id', $request->user()->id)
            ->where(function ($query): void {
                $query->where('action', 'like', 'Partner %')
                    ->orWhere('action', 'like', 'Tourist Spot booking %');
            })
            ->latest()
            ->limit(20)
            ->get(['id', 'action', 'details', 'created_at']);

        return response()->json(['status' => 'success', 'data' => $items]);
    }

    public function index(Request $request): JsonResponse
    {
        $spots = TouristSpot::with(['category', 'bookingAvailabilityUpdatedBy:id,name'])
            ->whereHas('partnerAssignments', fn ($query) => $query
                ->where('partner_profile_id', $request->user()->id))
            ->orderBy('name')
            ->get();

        return response()->json(['status' => 'success', 'data' => $spots]);
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $spot = TouristSpot::with([
            'category',
            'bookingAvailabilityUpdatedBy:id,name',
            'bookingAvailabilityHistory.changedBy:id,name',
        ])->findOrFail($id);
        Gate::forUser($request->user())->authorize('viewManaged', $spot);

        return response()->json(['status' => 'success', 'data' => $spot]);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $spot = TouristSpot::findOrFail($id);
        Gate::forUser($request->user())->authorize('updateManagedContent', $spot);

        $validated = $request->validate([
            'short_description' => 'sometimes|nullable|string|max:500',
            'description' => 'sometimes|nullable|string|max:10000',
            'images' => 'sometimes|nullable|array|max:20',
            'images.*' => ['url', 'max:2048', 'regex:/^https:\/\//i'],
            'contact_information' => 'sometimes|nullable|string|max:2000',
            'opening_hours' => 'sometimes|nullable|string|max:2000',
            'visitor_instructions' => 'sometimes|nullable|string|max:5000',
            'amenities' => 'sometimes|nullable|array|max:100',
            'amenities.*' => 'string|max:255|distinct:ignore_case',
            'booking_instructions' => 'sometimes|nullable|string|max:5000',
        ]);
        $expectedUpdatedAt = StaleRecordGuard::expectedUpdatedAt($request);

        DB::transaction(function () use ($request, $spot, $validated, $expectedUpdatedAt): void {
            $locked = TouristSpot::whereKey($spot->id)->lockForUpdate()->firstOrFail();
            Gate::forUser($request->user())->authorize('updateManagedContent', $locked);
            StaleRecordGuard::assertCurrent($locked, $expectedUpdatedAt);
            $locked->update($validated);
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'Partner tourist spot content updated',
                'details' => json_encode([
                    'tourist_spot_id' => $locked->id,
                    'tourist_spot_name' => $locked->name,
                    'updated_fields' => array_keys($validated),
                ], JSON_THROW_ON_ERROR),
            ]);
        });

        return response()->json([
            'status' => 'success',
            'data' => $spot->fresh(['category', 'bookingAvailabilityUpdatedBy:id,name']),
        ]);
    }

    public function updateBookingAvailability(
        Request $request,
        string $id,
        UpdateTouristSpotBookingAvailabilityAction $action,
    ): JsonResponse {
        $spot = TouristSpot::findOrFail($id);
        Gate::forUser($request->user())->authorize('manageBookingAvailability', $spot);
        $validated = $this->validateAvailability($request);
        $expectedUpdatedAt = StaleRecordGuard::expectedUpdatedAt($request);

        return response()->json([
            'status' => 'success',
            'data' => $action->execute(
                $spot,
                $request->user(),
                (bool) $validated['booking_enabled'],
                $validated['reason_code'] ?? null,
                $validated['reason'] ?? null,
                $expectedUpdatedAt,
            ),
        ]);
    }

    /** @return array<string, mixed> */
    private function validateAvailability(Request $request): array
    {
        return $request->validate([
            'booking_enabled' => 'required|boolean',
            'reason_code' => [
                Rule::requiredIf(! $request->boolean('booking_enabled')),
                'nullable',
                Rule::in(config('tourist_spot_partners.unavailable_reason_codes', [])),
            ],
            'reason' => 'nullable|string|max:2000',
        ]);
    }
}
