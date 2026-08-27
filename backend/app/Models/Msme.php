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
    ];

    protected $casts = [
        'products' => 'array',
        'rating' => 'float',
        'review_count' => 'integer',
        'is_verified' => 'boolean',
        'latitude' => 'float',
        'longitude' => 'float',
    ];

    public function profile()
    {
        return $this->belongsTo(Profile::class, 'profile_id');
    }
}
