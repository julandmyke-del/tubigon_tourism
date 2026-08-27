<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Itinerary extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'user_id',
        'name',
        'description',
        'start_date',
        'end_date',
        'travelers',
        'status',
        'start_location_type',
        'start_location_name',
        'start_location_id',
        'start_latitude',
        'start_longitude',
    ];

    protected $casts = [
        'start_date' => 'date',
        'end_date' => 'date',
        'travelers' => 'integer',
        'start_latitude' => 'float',
        'start_longitude' => 'float',
    ];

    public function items()
    {
        return $this->hasMany(ItineraryItem::class)
            ->orderBy('day_number')
            ->orderBy('sort_order')
            ->orderBy('created_at');
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
