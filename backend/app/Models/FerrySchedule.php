<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class FerrySchedule extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'operator',
        'route',
        'departure_time',
        'arrival_time',
        'fare',
        'status',
        'days_of_week',
    ];

    protected $casts = [
        'fare' => 'float',
        'days_of_week' => 'array',
    ];
}
