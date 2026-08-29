<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\ValidatesTubigonCoordinates;
use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\TouristSpot;
use App\Services\TouristSpotBookingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class TouristSpotController extends Controller
{
    use ValidatesTubigonCoordinates;

    public function index(Request $request): JsonResponse
    {
        $query = TouristSpot::with('category');

        if ($request->has('category_id')) {
            $query->where('category_id', $request->category_id);
        }
        if ($request->boolean('featured_only')) {
            $query->where('is_featured', true);
        }
        if ($request->boolean('bookable_only')) {
            $query->where('is_bookable', true)
                ->where('booking_enabled', true)
                ->whereIn('booking_mode', ['date_only', 'date_time_slot']);
        }
        if ($request->boolean('booking_capable_only')) {
            $query->where('is_bookable', true)
                ->whereIn('booking_mode', ['date_only', 'date_time_slot']);
        }
        if ($request->has('search')) {
            $search = '%'.$request->search.'%';
            $query->where(fn ($query) => $query
                ->where('name', 'like', $search)
                ->orWhere('aliases', 'like', $search));
        }

        $spots = $query->where('is_active', true)
            ->when(
                Schema::hasColumn('tourist_spots', 'is_published'),
                fn ($query) => $query->where('is_published', true),
            )
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $spots->map(fn (TouristSpot $spot) => $this->publicPayload($spot)),
        ]);
    }

    public function managementIndex(Request $request): JsonResponse
    {
        $query = TouristSpot::with([
            'category',
            'partnerAssignments.partnerProfile:id,name,email',
            'bookingAvailabilityUpdatedBy:id,name,email',
        ]);
        if ($request->filled('category_id')) {
            $query->where('category_id', $request->category_id);
        }
        if ($request->filled('search')) {
            $query->where('name', 'like', '%'.$request->search.'%');
        }

        return response()->json([
            'status' => 'success',
            'data' => $query->orderBy('created_at', 'desc')->get(),
        ]);
    }

    public function show(string $id): JsonResponse
    {
        $spot = TouristSpot::with('category')
            ->where('is_active', true)
            ->when(
                Schema::hasColumn('tourist_spots', 'is_published'),
                fn ($query) => $query->where('is_published', true),
            )
            ->findOrFail($id);

        return response()->json(['status' => 'success', 'data' => $this->publicPayload($spot)]);
    }

    public function availability(Request $request, string $id, TouristSpotBookingService $booking): JsonResponse
    {
        $validated = $request->validate(['date' => 'required|date_format:Y-m-d']);
        $spot = TouristSpot::findOrFail($id);

        return response()->json([
            'status' => 'success',
            'data' => $booking->availability($spot, $validated['date']),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'short_description' => 'nullable|string|max:500',
            'description' => 'nullable|string',
            'aliases' => 'nullable|array|max:20',
            'aliases.*' => 'string|max:255|distinct:ignore_case',
            'category_id' => 'nullable|exists:spot_categories,id',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'address' => 'nullable|string',
            'entrance_fee' => 'nullable|numeric',
            'opening_hours' => 'nullable|string',
            'contact_information' => 'nullable|string|max:2000',
            'visitor_instructions' => 'nullable|string|max:5000',
            'amenities' => 'nullable|array|max:100',
            'amenities.*' => 'string|max:255|distinct:ignore_case',
            'eco_tips' => 'nullable|array',
            'images' => 'nullable|array',
            'images.*' => ['url', 'max:2048', 'regex:/^https:\/\//i'],
            'is_featured' => 'nullable|boolean',
            'is_active' => 'nullable|boolean',
            'is_published' => 'nullable|boolean',
        ]);
        $this->validateTubigonCoordinates($validated);

        $validated['slug'] = Str::slug($validated['name']).'-'.Str::random(6);
        $spot = DB::transaction(function () use ($request, $validated): TouristSpot {
            $spot = TouristSpot::create($validated);
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'Tourist Spot created',
                'details' => "Created tourist spot: {$spot->name}",
            ]);

            return $spot;
        });

        return response()->json([
            'status' => 'success',
            'data' => $spot->fresh()->load('category'),
        ], 201);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $spot = TouristSpot::findOrFail($id);

        $validated = $request->validate([
            'name' => 'sometimes|string|max:255',
            'short_description' => 'nullable|string|max:500',
            'description' => 'nullable|string',
            'aliases' => 'nullable|array|max:20',
            'aliases.*' => 'string|max:255|distinct:ignore_case',
            'category_id' => 'nullable|exists:spot_categories,id',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'address' => 'nullable|string',
            'entrance_fee' => 'nullable|numeric',
            'opening_hours' => 'nullable|string',
            'contact_information' => 'nullable|string|max:2000',
            'visitor_instructions' => 'nullable|string|max:5000',
            'amenities' => 'nullable|array|max:100',
            'amenities.*' => 'string|max:255|distinct:ignore_case',
            'booking_instructions' => 'nullable|string|max:5000',
            'eco_tips' => 'nullable|array',
            'images' => 'nullable|array',
            'images.*' => ['url', 'max:2048', 'regex:/^https:\/\//i'],
            'is_featured' => 'nullable|boolean',
            'is_active' => 'nullable|boolean',
            'is_published' => 'nullable|boolean',
        ]);
        $this->validateTubigonCoordinates(
            $validated,
            $spot->latitude !== null ? (float) $spot->latitude : null,
            $spot->longitude !== null ? (float) $spot->longitude : null,
        );

        DB::transaction(function () use ($request, $spot, $validated): void {
            $spot->update($validated);
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'Tourist Spot updated',
                'details' => "Updated tourist spot: {$spot->name}",
            ]);
        });

        return response()->json(['status' => 'success', 'data' => $spot->fresh()->load('category')]);
    }

    public function updateBooking(Request $request, string $id): JsonResponse
    {
        $spot = TouristSpot::findOrFail($id);
        $validated = $request->validate([
            'is_bookable' => 'required|boolean',
            'booking_mode' => ['required', Rule::in(['no_reservation', 'date_only', 'date_time_slot'])],
            'booking_available_days' => 'nullable|array|max:7',
            'booking_available_days.*' => ['string', Rule::in([
                'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
            ])],
            'booking_time_slots' => 'nullable|array|max:48',
            'booking_time_slots.*.start' => 'required_with:booking_time_slots|date_format:H:i',
            'booking_time_slots.*.end' => 'required_with:booking_time_slots|date_format:H:i|after:booking_time_slots.*.start',
            'booking_time_slots.*.capacity' => 'nullable|integer|min:1|max:100000',
            'max_guests_per_reservation' => 'nullable|integer|min:1|max:1000',
            'capacity_per_slot' => 'nullable|integer|min:1|max:100000',
            'advance_booking_days' => 'nullable|integer|min:0|max:730',
            'minimum_notice_hours' => 'nullable|integer|min:0|max:8760',
            'reservation_fee' => 'nullable|numeric|min:0|max:999999.99',
            'booking_instructions' => 'nullable|string|max:5000',
            'cancellation_policy' => 'nullable|string|max:5000',
            'cancellation_notice_hours' => 'nullable|integer|min:0|max:8760',
        ]);

        if ($validated['booking_mode'] === 'date_time_slot' && empty($validated['booking_time_slots'])) {
            throw ValidationException::withMessages([
                'booking_time_slots' => ['At least one verified time slot is required for date + time-slot booking.'],
            ]);
        }
        if ($validated['is_bookable'] && $validated['booking_mode'] === 'no_reservation') {
            throw ValidationException::withMessages([
                'booking_mode' => ['Choose date-only or date + time-slot before enabling booking.'],
            ]);
        }
        if ($validated['booking_mode'] === 'no_reservation') {
            $validated['is_bookable'] = false;
        }
        if (! $validated['is_bookable'] && $spot->booking_enabled) {
            throw ValidationException::withMessages([
                'is_bookable' => ['Disable live booking availability with a reason before removing reservation support.'],
            ]);
        }

        $validated['booking_available_days'] = array_values(array_unique(array_map(
            'strtolower',
            $validated['booking_available_days'] ?? [],
        )));
        if ($validated['booking_mode'] !== 'date_time_slot') {
            $validated['booking_time_slots'] = null;
        }

        DB::transaction(function () use ($request, $spot, $validated): void {
            $spot->update($validated);
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'Tourist Spot booking configuration updated',
                'details' => "Updated booking configuration for: {$spot->name}",
            ]);
        });

        return response()->json([
            'status' => 'success',
            'data' => $spot->fresh()->load('category'),
        ]);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        DB::transaction(function () use ($request, $id): void {
            TouristSpot::findOrFail($id)->delete();
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'Tourist Spot archived',
                'details' => "Archived tourist spot ID $id",
            ]);
        });

        return response()->json(['status' => 'success', 'message' => 'Tourist spot archived']);
    }

    private function publicPayload(TouristSpot $spot): array
    {
        $payload = $spot->toArray();
        unset($payload['capacity_per_slot']);
        if (is_array($payload['booking_time_slots'] ?? null)) {
            $payload['booking_time_slots'] = array_map(function ($slot): array {
                $slot = is_array($slot) ? $slot : [];
                unset($slot['capacity']);

                return $slot;
            }, $payload['booking_time_slots']);
        }
        $payload['fee_configured'] = $spot->reservation_fee !== null;

        return $payload;
    }
}
