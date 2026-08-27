<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Reservation extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'user_id',
        'partner_id',
        'reservable_type',
        'reservable_id',
        'reservation_date',
        'start_time',
        'end_time',
        'guests',
        'status_id',
        'notes',
        'total_amount',
    ];

    protected $casts = [
        'reservation_date' => 'datetime',
        'guests' => 'integer',
        'total_amount' => 'float',
    ];

    public function user()
    {
        return $this->belongsTo(Profile::class, 'user_id');
    }

    public function status()
    {
        return $this->belongsTo(ReservationStatus::class, 'status_id');
    }

    public function listing()
    {
        return $this->belongsTo(TourismListing::class, 'reservable_id');
    }
}
