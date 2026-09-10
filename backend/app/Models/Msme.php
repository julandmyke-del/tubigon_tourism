<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Msme extends Model
{
    use HasUuids, SoftDeletes;

    protected $table = 'msmes';

    protected $fillable = [
        'profile_id',
        'name',
        'category',
        'category_id',
        'tagline',
        'description',
        'phone',
        'address',
        'latitude',
        'longitude',
        'business_hours',
        'rating',
        'review_count',
        'color',
        'icon',
        'is_verified',
        'products',
        'verification_status',
        'verification_notes',
        'submitted_at',
        'reviewed_at',
        'reviewed_by',
        'operational_status',
        'booking_enabled',
        'opening_hours',
        'unavailable_dates',
        'images',
    ];

    protected $casts = [
        'products' => 'array',
        'rating' => 'float',
        'review_count' => 'integer',
        'is_verified' => 'boolean',
        'booking_enabled' => 'boolean',
        'latitude' => 'float',
        'longitude' => 'float',
        'opening_hours' => 'array',
        'unavailable_dates' => 'array',
        'images' => 'array',
        'submitted_at' => 'datetime',
        'reviewed_at' => 'datetime',
    ];

    public function profile()
    {
        return $this->belongsTo(Profile::class, 'profile_id');
    }

    public function categoryRecord()
    {
        return $this->belongsTo(MsmeCategory::class, 'category_id');
    }
}
