<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\ValidatesTubigonCoordinates;
use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Msme;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MsmeController extends Controller
{
    use ValidatesTubigonCoordinates;

    public function index(Request $request): JsonResponse
    {
        $query = Msme::with('profile');
        if ($request->has('category')) {
            $query->where('category', $request->category);
        }
        if ($request->has('search')) {
            $query->where('name', 'like', '%'.$request->search.'%');
        }
        $msmes = $query->orderBy('created_at', 'desc')->get();

        return response()->json(['status' => 'success', 'data' => $msmes]);
    }

    public function show(string $id): JsonResponse
    {
        $msme = Msme::with('profile')->findOrFail($id);

        return response()->json(['status' => 'success', 'data' => $msme]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'category' => 'required|string|max:255',
            'tagline' => 'nullable|string|max:255',
            'description' => 'nullable|string',
            'phone' => 'nullable|string|max:255',
            'address' => 'nullable|string',
            'latitude' => 'nullable|numeric|between:-90,90',
            'longitude' => 'nullable|numeric|between:-180,180',
            'business_hours' => 'nullable|string|max:255',
            'color' => 'nullable|string|max:50',
            'icon' => 'nullable|string|max:100',
            'products' => 'nullable|array',
        ]);
        $this->validateTubigonCoordinates($validated);
        $validated['profile_id'] = $request->user()->id;
        $msme = Msme::create($validated);

        return response()->json(['status' => 'success', 'data' => $msme], 201);
    }

    public function updateVerification(Request $request, string $id): JsonResponse
    {
        $request->validate(['is_verified' => 'required|boolean']);
        $msme = Msme::findOrFail($id);
        $msme->update(['is_verified' => $request->is_verified]);

        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => $request->is_verified ? 'MSME verified' : 'MSME unverified',
            'details' => "Updated verification status of MSME ID $id",
        ]);

        return response()->json(['status' => 'success', 'message' => 'MSME verification updated']);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        $msme = Msme::findOrFail($id);
        $msme->delete();

        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => 'MSME deleted',
            'details' => "Soft deleted MSME ID $id",
        ]);

        return response()->json(['status' => 'success', 'message' => 'MSME deleted']);
    }
}
