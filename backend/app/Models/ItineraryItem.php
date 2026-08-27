<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class ItineraryItem extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'itinerary_id',
        'entity_type',
        'entity_id',
        'day_number',
        'sort_order',
        'planned_start_time',
        'planned_end_time',
        'notes',
        'reservation_id',
        'visit_status',
    ];

    protected $casts = [
        'day_number' => 'integer',
        'sort_order' => 'integer',
    ];

    public function itinerary()
    {
        return $this->belongsTo(Itinerary::class);
    }

    public function reservation()
    {
        return $this->belongsTo(Reservation::class);
    }
}
