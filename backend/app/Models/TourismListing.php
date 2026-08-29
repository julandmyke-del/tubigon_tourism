<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class TourismListing extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'owner_id',
        'listing_name',
        'listing_type',
        'description',
        'address',
        'latitude',
        'longitude',
        'contact_number',
        'email',
        'operating_hours',
        'images',
        'status',
        'is_active',
        'average_rating',
        'review_count',
        'approval_status',
        'submitted_at',
        'reviewed_at',
        'reviewed_by',
        'review_notes',
        'published_at',
        'price',
        'capacity',
        'duration_minutes',
        'available_days',
        'booking_cutoff_hours',
    ];

    protected $casts = [
        'images' => 'array',
        'latitude' => 'float',
        'longitude' => 'float',
        'is_active' => 'boolean',
        'average_rating' => 'float',
        'review_count' => 'integer',
        'price' => 'float',
        'capacity' => 'integer',
        'duration_minutes' => 'integer',
        'available_days' => 'array',
        'booking_cutoff_hours' => 'integer',
        'submitted_at' => 'datetime',
        'reviewed_at' => 'datetime',
        'published_at' => 'datetime',
    ];

    public function owner()
    {
        return $this->belongsTo(Profile::class, 'owner_id');
    }

    public function reservations()
    {
        return $this->hasMany(Reservation::class, 'reservable_id');
    }
}
