<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\ValidatesTubigonCoordinates;
use App\Http\Controllers\Controller;
use App\Models\Establishment;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class EstablishmentController extends Controller
{
    use ValidatesTubigonCoordinates;

    public function index(Request $request): JsonResponse
    {
        $query = Establishment::query();
        if ($request->has('category')) {
            $query->where('category', $request->category);
        }
        if ($request->has('search')) {
            $query->where('name', 'like', '%'.$request->search.'%');
        }
        $establishments = $query
            ->where('is_active', true)
            ->where('is_verified', true)
            ->orderBy('name')
            ->get();

        return response()->json(['status' => 'success', 'data' => $establishments]);
    }

    public function show(string $id): JsonResponse
    {
        $establishment = Establishment::where('is_active', true)
            ->where('is_verified', true)
            ->findOrFail($id);

        return response()->json(['status' => 'success', 'data' => $establishment]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'category' => 'nullable|string|max:255',
            'description' => 'nullable|string',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'address' => 'nullable|string',
            'phone' => 'nullable|string|max:255',
            'email' => 'nullable|email|max:255',
            'website' => 'nullable|string|max:255',
            'business_hours' => 'nullable|string',
            'images' => 'nullable|array',
        ]);
        $this->validateTubigonCoordinates($validated);
        $establishment = Establishment::create($validated);

        return response()->json(['status' => 'success', 'data' => $establishment], 201);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $establishment = Establishment::findOrFail($id);
        $validated = $request->validate([
            'name' => 'sometimes|string|max:255',
            'category' => 'nullable|string|max:255',
            'description' => 'nullable|string',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'address' => 'nullable|string',
            'phone' => 'nullable|string|max:255',
            'email' => 'nullable|email|max:255',
            'website' => 'nullable|string|max:255',
            'business_hours' => 'nullable|string',
            'images' => 'nullable|array',
            'is_verified' => 'nullable|boolean',
            'is_active' => 'nullable|boolean',
        ]);
        $this->validateTubigonCoordinates(
            $validated,
            $establishment->latitude !== null ? (float) $establishment->latitude : null,
            $establishment->longitude !== null ? (float) $establishment->longitude : null,
        );
        $establishment->update($validated);

        return response()->json(['status' => 'success', 'data' => $establishment]);
    }

    public function destroy(string $id): JsonResponse
    {
        Establishment::findOrFail($id)->delete();

        return response()->json(['status' => 'success', 'message' => 'Establishment deleted']);
    }
}
