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
    ];

    protected $casts = [
        'images' => 'array',
        'latitude' => 'float',
        'longitude' => 'float',
        'is_active' => 'boolean',
        'average_rating' => 'float',
        'review_count' => 'integer',
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
