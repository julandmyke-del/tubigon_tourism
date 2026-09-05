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
        $settings = SystemSetting::firstOrCreate([], ['app_name' => 'Tubigon Smart Tourism']);
        return response()->json(['status' => 'success', 'data' => $settings->only([
            'id', 'app_name', 'municipality_name', 'contact_email', 'contact_phone',
            'tourism_office_address', 'support_contact',
            'tourist_registration_enabled', 'msme_registration_enabled',
            'msme_applications_enabled', 'partner_applications_enabled',
            'require_msme_verification', 'reviews_enabled',
            'waste_reporting_enabled', 'global_booking_enabled',
            'maintenance_notice', 'privacy_policy', 'terms_of_service', 'updated_at',
        ])]);
    }

    /**
     * PUT /api/v1/system-settings/{id}
     */
    public function updateSystemSettings(Request $request, string $id): JsonResponse
    {
        $settings = SystemSetting::findOrFail($id);
        $validated = $request->validate([
            'app_name' => 'sometimes|string|max:255',
            'municipality_name' => 'sometimes|string|max:255',
            'contact_email' => 'sometimes|email|max:255',
            'contact_phone' => 'sometimes|string|max:255',
            'tourism_office_address' => 'nullable|string|max:500',
            'support_contact' => 'nullable|string|max:255',
            'tourist_registration_enabled' => 'sometimes|boolean',
            'msme_registration_enabled' => 'sometimes|boolean',
            'msme_applications_enabled' => 'sometimes|boolean',
            'partner_applications_enabled' => 'sometimes|boolean',
            'require_msme_verification' => 'sometimes|boolean',
            'reviews_enabled' => 'sometimes|boolean',
            'waste_reporting_enabled' => 'sometimes|boolean',
            'global_booking_enabled' => 'sometimes|boolean',
            'maintenance_notice' => 'nullable|string|max:1000',
            'privacy_policy' => 'nullable|string',
            'terms_of_service' => 'nullable|string',
        ]);
        DB::transaction(function () use ($request, $settings, $validated): void {
            $settings->update([...$validated, 'updated_by' => $request->user()->id]);
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'System Settings updated',
                'details' => json_encode([
                    'target_type' => 'system_settings',
                    'target_id' => $settings->id,
                    'changed_keys' => array_keys($validated),
                ]),
            ]);
        });

        return response()->json(['status' => 'success', 'data' => $settings]);
    }
}
