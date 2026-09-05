<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\ValidatesTubigonCoordinates;
use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\WasteReport;
use App\Models\Notification;
use App\Models\User;
use App\Models\SystemSetting;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class WasteReportController extends Controller
{
    use ValidatesTubigonCoordinates;

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $user->loadMissing('role');
        $role = $user->role?->name;

        $query = WasteReport::with('user:id,name');
        if ($role !== 'admin' && $role !== 'lgu_staff') {
            $query->where('user_id', $user->id);
        }

        $reports = $query->orderBy('created_at', 'desc')->get();

        return response()->json(['status' => 'success', 'data' => $reports]);
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $user = $request->user();
        $user->loadMissing('role');
        $canManage = in_array($user->role?->name, ['admin', 'lgu_staff'], true);
        $query = WasteReport::with('user:id,name');
        if (! $canManage) $query->where('user_id', $user->id);
        return response()->json(['status' => 'success', 'data' => $query->findOrFail($id)]);
    }

    public function store(Request $request): JsonResponse
    {
        abort_unless(SystemSetting::enabled('waste_reporting_enabled'), 403, 'Waste reporting is currently disabled.');
        $validated = $request->validate([
            'category' => 'required|in:garbage,water_pollution,beach_coastal,environmental_damage,road_infrastructure,public_facility,safety,tourism_site,marine_wildlife,other,Plastic Waste,Coastal Pollution,Illegal Dumping,Overflowing Bin,Hazardous Material,Other',
            'description' => 'required|string|min:10|max:2000',
            'location_description' => 'nullable|string|max:500',
            'latitude' => 'required|numeric|between:-90,90',
            'longitude' => 'required|numeric|between:-180,180',
            'images' => 'nullable|array|max:5',
            'images.*' => 'string|max:2048',
        ]);
        $this->validateTubigonCoordinates($validated);
        $validated['user_id'] = $request->user()->id;
        $validated['status'] = 'submitted';
        $validated['priority'] = 'normal';
        $report = DB::transaction(function () use ($request, $validated): WasteReport {
            $report = WasteReport::create($validated);
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'Waste report submitted',
                'details' => json_encode(['entity_type' => 'waste_report', 'entity_id' => $report->id]),
            ]);
            User::whereHas('role', fn ($query) => $query->whereIn('name', ['admin', 'lgu_staff']))
                ->pluck('id')->each(fn (string $id) => Notification::create([
                    'user_id' => $id,
                    'type' => 'waste_report_submitted',
                    'title' => 'New Waste Report',
                    'body' => 'A new waste report is awaiting review.',
                    'data' => ['waste_report_id' => $report->id, 'route' => '/lgu/waste-reports/'.$report->id],
                ]));
            return $report;
        });

        return response()->json(['status' => 'success', 'data' => $report], 201);
    }

    public function updateStatus(Request $request, string $id): JsonResponse
    {
        return (new LguController())->updateWasteStatus($request, $id);
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
