<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class WasteReport extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'user_id',
        'category',
        'description',
        'location_description',
        'latitude',
        'longitude',
        'images',
        'status',
    ];

    protected $casts = [
        'images' => 'array',
        'latitude' => 'float',
        'longitude' => 'float',
    ];

    public function user()
    {
        return $this->belongsTo(Profile::class, 'user_id');
    }
}
