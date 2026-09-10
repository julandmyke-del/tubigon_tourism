<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class TouristSpot extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'name',
        'slug',
        'short_description',
        'description',
        'aliases',
        'category_id',
        'latitude',
        'longitude',
        'address',
        'entrance_fee',
        'opening_hours',
        'eco_tips',
        'images',
        'average_rating',
        'review_count',
        'is_featured',
        'is_active',
        'operational_status',
        'is_published',
        'is_bookable',
        'booking_enabled',
        'booking_unavailable_reason_code',
        'booking_unavailable_reason',
        'booking_availability_updated_at',
        'booking_availability_updated_by',
        'booking_mode',
        'booking_available_days',
        'booking_time_slots',
        'max_guests_per_reservation',
        'capacity_per_slot',
        'advance_booking_days',
        'minimum_notice_hours',
        'reservation_fee',
        'booking_instructions',
        'cancellation_policy',
        'cancellation_notice_hours',
        'contact_information',
        'visitor_instructions',
        'amenities',
    ];

    protected $casts = [
        'eco_tips' => 'array',
        'aliases' => 'array',
        'images' => 'array',
        'latitude' => 'float',
        'longitude' => 'float',
        'entrance_fee' => 'float',
        'average_rating' => 'float',
        'review_count' => 'integer',
        'is_featured' => 'boolean',
        'is_preapproved' => 'boolean',
        'preapproved_at' => 'datetime',
        'demo_booking_seeded_at' => 'datetime',
        'is_active' => 'boolean',
        'is_published' => 'boolean',
        'is_bookable' => 'boolean',
        'booking_enabled' => 'boolean',
        'booking_availability_updated_at' => 'datetime',
        'amenities' => 'array',
        'booking_available_days' => 'array',
        'booking_time_slots' => 'array',
        'max_guests_per_reservation' => 'integer',
        'capacity_per_slot' => 'integer',
        'advance_booking_days' => 'integer',
        'minimum_notice_hours' => 'integer',
        'reservation_fee' => 'float',
        'cancellation_notice_hours' => 'integer',
    ];

    public function category()
    {
        return $this->belongsTo(SpotCategory::class, 'category_id');
    }

    public function partnerAssignments()
    {
        return $this->hasMany(TouristSpotPartnerAssignment::class);
    }

    public function partnerProfiles()
    {
        return $this->belongsToMany(
            Profile::class,
            'tourist_spot_partner_assignments',
            'tourist_spot_id',
            'partner_profile_id',
        )->withPivot(['is_primary', 'assigned_by', 'assigned_at'])->withTimestamps();
    }

    public function bookingAvailabilityUpdatedBy()
    {
        return $this->belongsTo(User::class, 'booking_availability_updated_by');
    }

    public function bookingAvailabilityHistory()
    {
        return $this->hasMany(TouristSpotBookingAvailabilityHistory::class)->latest('changed_at');
    }

    public function bookingOfferings()
    {
        return $this->hasMany(BookingOffering::class);
    }

    public function media()
    {
        return $this->hasMany(TouristSpotMedia::class)->orderBy('sort_order');
    }
}
