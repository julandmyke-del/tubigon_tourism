<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\FerrySchedule;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FerryScheduleController extends Controller
{
    public function index(): JsonResponse
    {
        $schedules = FerrySchedule::orderBy('departure_time')->get();
        return response()->json(['status' => 'success', 'data' => $schedules]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'operator' => 'required|string|max:255',
            'route' => 'required|string|max:255',
            'departure_time' => 'required|string',
            'arrival_time' => 'nullable|string',
            'fare' => 'nullable|numeric',
            'status' => 'nullable|string',
            'days_of_week' => 'nullable|array',
        ]);
        $schedule = FerrySchedule::create($validated);
        return response()->json(['status' => 'success', 'data' => $schedule], 201);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $schedule = FerrySchedule::findOrFail($id);
        $validated = $request->validate([
            'operator' => 'sometimes|string|max:255',
            'route' => 'sometimes|string|max:255',
            'departure_time' => 'sometimes|string',
            'arrival_time' => 'nullable|string',
            'fare' => 'nullable|numeric',
            'status' => 'nullable|string',
            'days_of_week' => 'nullable|array',
        ]);
        $schedule->update($validated);
        return response()->json(['status' => 'success', 'data' => $schedule]);
    }

    public function destroy(string $id): JsonResponse
    {
        FerrySchedule::findOrFail($id)->delete();
        return response()->json(['status' => 'success', 'message' => 'Ferry schedule deleted']);
    }
}
