<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\FerrySchedule;
use App\Models\ActivityLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

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
            'status' => ['nullable', Rule::in(['scheduled', 'delayed', 'cancelled', 'suspended'])],
            'days_of_week' => 'nullable|array',
        ]);
        $validated['status'] ??= 'scheduled';
        $schedule = DB::transaction(function () use ($request, $validated): FerrySchedule {
            $schedule = FerrySchedule::create($validated);
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'Ferry schedule created',
                'details' => "Created ferry schedule {$schedule->route}",
            ]);
            return $schedule;
        });
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
            'status' => ['nullable', Rule::in(['scheduled', 'delayed', 'cancelled', 'suspended'])],
            'days_of_week' => 'nullable|array',
        ]);
        DB::transaction(function () use ($request, $schedule, $validated): void {
            $schedule->update($validated);
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'Ferry schedule updated',
                'details' => "Updated ferry schedule {$schedule->route}",
            ]);
        });
        return response()->json(['status' => 'success', 'data' => $schedule]);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        DB::transaction(function () use ($request, $id): void {
            $schedule = FerrySchedule::findOrFail($id);
            $schedule->delete();
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'Ferry schedule archived',
                'details' => "Archived ferry schedule {$schedule->route}",
            ]);
        });
        return response()->json(['status' => 'success', 'message' => 'Ferry schedule archived']);
    }
}
