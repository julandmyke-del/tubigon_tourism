<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class TouristSpotBookingAvailabilityHistory extends Model
{
    use HasUuids;

    protected $table = 'tourist_spot_booking_availability_history';

    protected $fillable = [
        'tourist_spot_id',
        'booking_enabled',
        'reason_code',
        'reason',
        'changed_by',
        'changed_at',
    ];

    protected $casts = [
        'booking_enabled' => 'boolean',
        'changed_at' => 'datetime',
    ];

    public function touristSpot()
    {
        return $this->belongsTo(TouristSpot::class);
    }

    public function changedBy()
    {
        return $this->belongsTo(User::class, 'changed_by');
    }
}
