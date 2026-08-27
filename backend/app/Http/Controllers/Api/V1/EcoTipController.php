<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\EcoTip;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class EcoTipController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = EcoTip::with('spot');
        if ($request->has('spot_id')) {
            $query->where('spot_id', $request->spot_id);
        }
        $tips = $query->orderBy('title')->get();
        return response()->json(['status' => 'success', 'data' => $tips]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'content' => 'required|string',
            'category' => 'nullable|string',
            'spot_id' => 'nullable|exists:tourist_spots,id',
            'language' => 'nullable|string|max:50',
        ]);
        $tip = EcoTip::create($validated);
        return response()->json(['status' => 'success', 'data' => $tip->load('spot')], 201);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $tip = EcoTip::findOrFail($id);
        $validated = $request->validate([
            'title' => 'sometimes|string|max:255',
            'content' => 'sometimes|string',
            'category' => 'nullable|string',
            'spot_id' => 'nullable|exists:tourist_spots,id',
            'language' => 'nullable|string|max:50',
        ]);
        $tip->update($validated);
        return response()->json(['status' => 'success', 'data' => $tip->load('spot')]);
    }

    public function destroy(string $id): JsonResponse
    {
        EcoTip::findOrFail($id)->delete();
        return response()->json(['status' => 'success', 'message' => 'Eco tip deleted']);
    }
}
