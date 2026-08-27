<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\ValidatesTubigonCoordinates;
use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\WasteReport;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class WasteReportController extends Controller
{
    use ValidatesTubigonCoordinates;

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $user->loadMissing('role');
        $role = $user->role?->name;

        $query = WasteReport::with('user');
        if ($role !== 'admin' && $role !== 'lgu_staff') {
            $query->where('user_id', $user->id);
        }

        $reports = $query->orderBy('created_at', 'desc')->get();

        return response()->json(['status' => 'success', 'data' => $reports]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'category' => 'required|in:Plastic Waste,Coastal Pollution,Illegal Dumping,Overflowing Bin,Hazardous Material,Other',
            'description' => 'required|string|min:10|max:2000',
            'location_description' => 'nullable|string|max:500',
            'latitude' => 'required|numeric|between:-90,90',
            'longitude' => 'required|numeric|between:-180,180',
            'images' => 'nullable|array|max:5',
            'images.*' => 'string|max:2048',
        ]);
        $this->validateTubigonCoordinates($validated);
        $validated['user_id'] = $request->user()->id;
        $report = WasteReport::create($validated);

        return response()->json(['status' => 'success', 'data' => $report], 201);
    }

    public function updateStatus(Request $request, string $id): JsonResponse
    {
        $request->validate(['status' => 'required|in:pending,submitted,in_progress,resolved,rejected']);
        $report = WasteReport::findOrFail($id);
        $report->update(['status' => $request->status]);

        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => 'Waste report updated',
            'details' => "Updated waste report ID $id status to {$request->status}",
        ]);

        return response()->json(['status' => 'success', 'message' => 'Waste report status updated']);
    }

    public function uploadImages(Request $request, string $id): JsonResponse
    {
        $request->validate(['images' => 'required|array', 'images.*' => 'image|max:5120']);

        $report = WasteReport::findOrFail($id);
        $user = $request->user();
        $user->loadMissing('role');
        $canManageAll = in_array($user->role?->name, ['admin', 'lgu_staff'], true);
        if (! $canManageAll && (string) $report->user_id !== (string) $user->id) {
            abort(403, 'You may only upload images to your own waste reports.');
        }
        $urls = $report->images ?? [];

        foreach ($request->file('images') as $image) {
            $path = $image->store("waste-reports/$id", 'public');
            $urls[] = asset("storage/$path");
        }

        $report->update(['images' => $urls]);

        return response()->json(['status' => 'success', 'data' => ['images' => $urls]]);
    }
}
