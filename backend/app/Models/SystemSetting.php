<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Schema;

class SystemSetting extends Model
{
    use HasUuids;

    protected $fillable = [
        'app_name',
        'municipality_name',
        'contact_email',
        'contact_phone',
        'tourism_office_address',
        'support_contact',
        'tourist_registration_enabled',
        'msme_registration_enabled',
        'msme_applications_enabled',
        'partner_applications_enabled',
        'require_msme_verification',
        'reviews_enabled',
        'waste_reporting_enabled',
        'global_booking_enabled',
        'maintenance_notice',
        'updated_by',
        'privacy_policy',
        'terms_of_service',
    ];

    protected $casts = [
        'tourist_registration_enabled' => 'boolean',
        'msme_registration_enabled' => 'boolean',
        'msme_applications_enabled' => 'boolean',
        'partner_applications_enabled' => 'boolean',
        'require_msme_verification' => 'boolean',
        'reviews_enabled' => 'boolean',
        'waste_reporting_enabled' => 'boolean',
        'global_booking_enabled' => 'boolean',
    ];

    public static function enabled(string $key): bool
    {
        if (! Schema::hasTable('system_settings') || ! Schema::hasColumn('system_settings', $key)) {
            return true;
        }
        return (bool) (static::query()->value($key) ?? true);
    }
}
