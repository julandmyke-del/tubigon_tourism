<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\ValidatesTubigonCoordinates;
use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\TouristSpot;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

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
        if ($request->has('search')) {
            $query->where('name', 'like', '%'.$request->search.'%');
        }

        $spots = $query->where('is_active', true)
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json(['status' => 'success', 'data' => $spots]);
    }

    public function show(string $id): JsonResponse
    {
        $spot = TouristSpot::with('category')->findOrFail($id);

        return response()->json(['status' => 'success', 'data' => $spot]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'description' => 'nullable|string',
            'category_id' => 'nullable|exists:spot_categories,id',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'address' => 'nullable|string',
            'entrance_fee' => 'nullable|numeric',
            'opening_hours' => 'nullable|string',
            'eco_tips' => 'nullable|array',
            'images' => 'nullable|array',
            'is_featured' => 'nullable|boolean',
        ]);
        $this->validateTubigonCoordinates($validated);

        $validated['slug'] = Str::slug($validated['name']).'-'.Str::random(6);
        $spot = TouristSpot::create($validated);

        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => 'Tourist Spot created',
            'details' => "Created tourist spot: {$spot->name}",
        ]);

        return response()->json(['status' => 'success', 'data' => $spot], 201);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $spot = TouristSpot::findOrFail($id);

        $validated = $request->validate([
            'name' => 'sometimes|string|max:255',
            'description' => 'nullable|string',
            'category_id' => 'nullable|exists:spot_categories,id',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'address' => 'nullable|string',
            'entrance_fee' => 'nullable|numeric',
            'opening_hours' => 'nullable|string',
            'eco_tips' => 'nullable|array',
            'images' => 'nullable|array',
            'is_featured' => 'nullable|boolean',
            'is_active' => 'nullable|boolean',
        ]);
        $this->validateTubigonCoordinates(
            $validated,
            $spot->latitude !== null ? (float) $spot->latitude : null,
            $spot->longitude !== null ? (float) $spot->longitude : null,
        );

        $spot->update($validated);

        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => 'Tourist Spot updated',
            'details' => "Updated tourist spot: {$spot->name}",
        ]);

        return response()->json(['status' => 'success', 'data' => $spot->fresh()->load('category')]);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        $spot = TouristSpot::findOrFail($id);
        $spot->delete();

        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => 'Tourist Spot deleted',
            'details' => "Deleted tourist spot ID $id",
        ]);

        return response()->json(['status' => 'success', 'message' => 'Tourist spot deleted']);
    }
}
