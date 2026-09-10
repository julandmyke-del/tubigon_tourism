<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class FerryPort extends Model
{
    use HasUuids;

    protected $fillable = [
        'name', 'code', 'municipality', 'province', 'latitude', 'longitude',
        'is_active',
    ];

    protected $casts = ['is_active' => 'boolean', 'latitude' => 'float', 'longitude' => 'float'];
}
