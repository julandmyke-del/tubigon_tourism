<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\SystemSetting;
use App\Models\Setting;
use App\Models\ActivityLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SettingController extends Controller
{
    /**
     * GET /api/v1/settings — user settings
     */
    public function index(Request $request): JsonResponse
    {
        $settings = Setting::firstOrCreate(
            ['user_id' => $request->user()->id],
            ['notifications_enabled' => true, 'location_enabled' => true, 'offline_mode' => false, 'language' => 'en']
        );
        return response()->json(['status' => 'success', 'data' => $settings]);
    }

    /**
     * PUT /api/v1/settings
     */
    public function update(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'notifications_enabled' => 'nullable|boolean',
            'location_enabled' => 'nullable|boolean',
            'offline_mode' => 'nullable|boolean',
            'language' => 'nullable|string|max:50',
        ]);

        $settings = Setting::updateOrCreate(
            ['user_id' => $request->user()->id],
            $validated
        );

        return response()->json(['status' => 'success', 'data' => $settings]);
    }

    /**
     * GET /api/v1/system-settings
     */
    public function systemSettings(): JsonResponse
    {
        $settings = SystemSetting::first();
        return response()->json(['status' => 'success', 'data' => $settings ?? (object)[]]);
    }

    /**
     * PUT /api/v1/system-settings/{id}
     */
    public function updateSystemSettings(Request $request, string $id): JsonResponse
    {
        $settings = SystemSetting::findOrFail($id);
        $validated = $request->validate([
            'app_name' => 'sometimes|string|max:255',
            'contact_email' => 'sometimes|email|max:255',
            'contact_phone' => 'sometimes|string|max:255',
            'privacy_policy' => 'nullable|string',
            'terms_of_service' => 'nullable|string',
        ]);
        DB::transaction(function () use ($request, $settings, $validated): void {
            $settings->update($validated);
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'System Settings updated',
                'details' => 'Updated global application settings',
            ]);
        });

        return response()->json(['status' => 'success', 'data' => $settings]);
    }
}
