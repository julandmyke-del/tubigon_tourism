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
        'description',
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
    ];

    protected $casts = [
        'eco_tips' => 'array',
        'images' => 'array',
        'latitude' => 'float',
        'longitude' => 'float',
        'entrance_fee' => 'float',
        'average_rating' => 'float',
        'review_count' => 'integer',
        'is_featured' => 'boolean',
        'is_active' => 'boolean',
    ];

    public function category()
    {
        return $this->belongsTo(SpotCategory::class, 'category_id');
    }
}
