<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Schema;

class UserPreference extends Model
{
    public $incrementing = false;

    protected $primaryKey = 'user_id';

    protected $keyType = 'string';

    protected $fillable = [
        'user_id', 'personalization_enabled', 'preferred_destination_category_ids',
        'travel_interests', 'travel_pace', 'group_type', 'preferred_transport_mode',
        'eco_tourism_interest', 'nearby_suggestions', 'wheelchair_friendly',
        'limited_walking', 'senior_friendly', 'child_friendly', 'accessibility_notes',
        'reservation_updates', 'tourism_announcements', 'eco_tips', 'ferry_alerts',
        'waste_report_updates', 'application_updates', 'location_recommendations',
        'remember_last_map_location',
    ];

    protected $casts = [
        'personalization_enabled' => 'boolean',
        'preferred_destination_category_ids' => 'array',
        'travel_interests' => 'array',
        'eco_tourism_interest' => 'boolean', 'nearby_suggestions' => 'boolean',
        'wheelchair_friendly' => 'boolean', 'limited_walking' => 'boolean',
        'senior_friendly' => 'boolean', 'child_friendly' => 'boolean',
        'reservation_updates' => 'boolean', 'tourism_announcements' => 'boolean',
        'eco_tips' => 'boolean', 'ferry_alerts' => 'boolean',
        'waste_report_updates' => 'boolean', 'application_updates' => 'boolean',
        'location_recommendations' => 'boolean', 'remember_last_map_location' => 'boolean',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public static function notificationKey(string $type): ?string
    {
        return match (true) {
            $type === 'announcement' => 'tourism_announcements',
            str_starts_with($type, 'reservation_'), $type === 'new_reservation' => 'reservation_updates',
            str_starts_with($type, 'waste_report_') => 'waste_report_updates',
            $type === 'role_application', str_starts_with($type, 'msme_') => 'application_updates',
            str_starts_with($type, 'eco_') => 'eco_tips',
            str_starts_with($type, 'ferry_') => 'ferry_alerts',
            default => null,
        };
    }

    public static function allowsNotification(?string $userId, string $type): bool
    {
        $key = self::notificationKey($type);
        if (! $userId || ! $key || ! Schema::hasTable('user_preferences')) {
            return true;
        }

        $preference = self::where('user_id', $userId)->value($key);

        return $preference === null || (bool) $preference;
    }
}
