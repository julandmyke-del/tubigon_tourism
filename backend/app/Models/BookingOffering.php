<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class BookingOffering extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'tourist_spot_id',
        'type',
        'display_name',
        'description',
        'price',
        'pricing_mode',
        'capacity_per_unit',
        'quantity_available',
        'min_quantity',
        'max_quantity',
        'lead_time_minutes',
        'max_advance_days',
        'available_days',
        'time_slots',
        'blackout_dates',
        'cancellation_note',
        'operating_note',
        'is_add_on',
        'is_active',
        'sort_order',
        'created_by_user_id',
    ];

    protected $hidden = ['created_by_user_id', 'deleted_at'];

    protected $casts = [
        'price' => 'float',
        'available_days' => 'array',
        'time_slots' => 'array',
        'blackout_dates' => 'array',
        'is_active' => 'boolean',
        'is_add_on' => 'boolean',
    ];

    public function touristSpot()
    {
        return $this->belongsTo(TouristSpot::class);
    }

    public function fields()
    {
        return $this->hasMany(BookingOfferingField::class, 'offering_id')
            ->orderBy('sort_order');
    }
}
