<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Establishment extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'name',
        'category',
        'description',
        'latitude',
        'longitude',
        'address',
        'phone',
        'email',
        'website',
        'business_hours',
        'images',
        'average_rating',
        'review_count',
        'is_verified',
        'is_active',
    ];

    protected $casts = [
        'images' => 'array',
        'latitude' => 'float',
        'longitude' => 'float',
        'average_rating' => 'float',
        'review_count' => 'integer',
        'is_verified' => 'boolean',
        'is_active' => 'boolean',
    ];
}
