<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CarbonEstimate;
use App\Models\EmissionFactor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class CarbonController extends Controller
{
    public function factors(): JsonResponse
    {
        $today = today();
        $factors = EmissionFactor::where('is_active', true)
            ->where(fn ($query) => $query->whereNull('effective_from')->orWhereDate('effective_from', '<=', $today))
            ->where(fn ($query) => $query->whereNull('effective_to')->orWhereDate('effective_to', '>=', $today))
            ->orderBy('display_name')->get();

        return response()->json([
            'status' => 'success', 'data' => $factors,
            'meta' => [
                'cached_at' => now()->toIso8601String(),
                'method' => 'distance × passenger-km factor × travelers × trip multiplier',
                'disclaimer' => 'Approximate planning estimates, not measured or audited emissions.',
            ],
        ]);
    }

    public function index(Request $request): JsonResponse
    {
        $estimates = CarbonEstimate::with('factor')
            ->where('user_id', $request->user()->id)
            ->latest()->limit(100)->get();
        return response()->json(['status' => 'success', 'data' => $estimates]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'emission_factor_id' => 'nullable|required_without:legs|uuid|exists:emission_factors,id',
            'origin_name' => 'nullable|string|max:255',
            'destination_name' => 'nullable|string|max:255',
            'origin_entity_type' => ['nullable', Rule::in(['tourist_spot', 'msme', 'tourism_listing', 'map_location', 'current_location', 'manual'])],
            'origin_entity_id' => 'nullable|uuid',
            'destination_entity_type' => ['nullable', Rule::in(['tourist_spot', 'msme', 'tourism_listing', 'map_location', 'manual'])],
            'destination_entity_id' => 'nullable|uuid',
            'distance_km' => 'nullable|required_without:legs|numeric|gt:0|max:5000',
            'distance_source' => ['nullable', 'required_without:legs', Rule::in(['manual', 'osrm', 'cached_route', 'itinerary', 'configured_ferry'])],
            'route_calculated_at' => 'nullable|date',
            'travelers' => 'required|integer|min:1|max:100',
            'trip_type' => ['required', Rule::in(['one_way', 'round_trip'])],
            'itinerary_id' => 'nullable|uuid|exists:itineraries,id',
            'legs' => 'nullable|array|min:1|max:50',
            'legs.*.emission_factor_id' => 'required_with:legs|uuid|exists:emission_factors,id',
            'legs.*.distance_km' => 'required_with:legs|numeric|gt:0|max:5000',
            'legs.*.distance_source' => ['required_with:legs', Rule::in(['manual', 'osrm', 'cached_route', 'itinerary', 'configured_ferry'])],
            'legs.*.origin_name' => 'nullable|string|max:255',
            'legs.*.destination_name' => 'nullable|string|max:255',
        ]);

        if (! empty($validated['itinerary_id'])) {
            abort_unless(DB::table('itineraries')->where('id', $validated['itinerary_id'])
                ->where('user_id', $request->user()->id)->exists(), 403, 'You may only save an estimate for your own itinerary.');
        }

        $tripMultiplier = $validated['trip_type'] === 'round_trip' ? 2 : 1;
        $travelers = (int) $validated['travelers'];
        $legsInput = $validated['legs'] ?? [[
            'emission_factor_id' => $validated['emission_factor_id'],
            'distance_km' => $validated['distance_km'],
            'distance_source' => $validated['distance_source'],
            'origin_name' => $validated['origin_name'] ?? null,
            'destination_name' => $validated['destination_name'] ?? null,
        ]];
        $factorIds = collect($legsInput)->pluck('emission_factor_id')->unique()->values();
        $factors = EmissionFactor::whereIn('id', $factorIds)->where('is_active', true)->get()->keyBy('id');
        abort_unless($factors->count() === $factorIds->count(), 422, 'One or more transport factors are inactive.');

        $totalDistance = 0.0;
        $total = 0.0;
        $breakdown = [];
        foreach ($legsInput as $index => $leg) {
            $factor = $factors->get($leg['emission_factor_id']);
            abort_unless($factor->unit === 'kg_co2e_per_passenger_km', 422, 'Unsupported emission-factor unit.');
            abort_if(str_starts_with($factor->transport_mode, 'ferry') && $leg['distance_source'] === 'osrm', 422, 'Ferry distance cannot use a road-routing source.');
            $distance = (float) $leg['distance_km'];
            $legTotal = $distance * (float) $factor->emission_factor * $travelers * $tripMultiplier;
            $totalDistance += $distance;
            $total += $legTotal;
            $breakdown[] = [
                'leg' => $index + 1,
                'origin_name' => $leg['origin_name'] ?? null,
                'destination_name' => $leg['destination_name'] ?? null,
                'distance_km' => round($distance, 3),
                'distance_source' => $leg['distance_source'],
                'transport_mode' => $factor->transport_mode,
                'display_name' => $factor->display_name,
                'factor' => (float) $factor->emission_factor,
                'factor_version' => $factor->version,
                'estimated_kg_co2e' => round($legTotal, 4),
            ];
        }
        abort_if($totalDistance > 5000, 422, 'Total itinerary distance must not exceed 5,000 km.');
        $primaryFactor = $factors->get($legsInput[0]['emission_factor_id']);
        $distanceSources = collect($legsInput)->pluck('distance_source')->unique();

        $estimate = CarbonEstimate::create([
            'user_id' => $request->user()->id,
            'emission_factor_id' => $primaryFactor->id,
            'origin_name' => $validated['origin_name'] ?? ($legsInput[0]['origin_name'] ?? null),
            'destination_name' => $validated['destination_name'] ?? (collect($legsInput)->last()['destination_name'] ?? null),
            'origin_entity_type' => $validated['origin_entity_type'] ?? null,
            'origin_entity_id' => $validated['origin_entity_id'] ?? null,
            'destination_entity_type' => $validated['destination_entity_type'] ?? null,
            'destination_entity_id' => $validated['destination_entity_id'] ?? null,
            'distance_km' => round($totalDistance, 3),
            'distance_source' => $distanceSources->count() === 1 ? $distanceSources->first() : 'itinerary',
            'route_calculated_at' => $validated['route_calculated_at'] ?? null,
            'travelers' => $travelers,
            'trip_type' => $validated['trip_type'],
            'estimated_kg_co2e' => round($total, 4),
            'per_traveler_kg_co2e' => round($total / $travelers, 4),
            'factor_version' => $factorIds->count() === 1 ? $primaryFactor->version : 'multimodal',
            'factor_unit' => 'kg_co2e_per_passenger_km',
            'itinerary_id' => $validated['itinerary_id'] ?? null,
            'leg_breakdown' => $breakdown,
        ]);

        return response()->json(['status' => 'success', 'data' => $estimate->load('factor')], 201);
    }
}
