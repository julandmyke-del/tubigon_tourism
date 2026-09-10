<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class ReservationItem extends Model
{
    use HasUuids;

    protected $fillable = [
        'reservation_id', 'offering_id', 'offering_name_snapshot',
        'offering_type_snapshot', 'quantity', 'unit_price_snapshot',
        'pricing_mode_snapshot', 'subtotal', 'booking_details',
    ];

    protected $casts = ['booking_details' => 'array', 'unit_price_snapshot' => 'float', 'subtotal' => 'float', 'quantity' => 'integer'];

    public function offering()
    {
        return $this->belongsTo(BookingOffering::class);
    }

    public function reservation()
    {
        return $this->belongsTo(Reservation::class);
    }
}
