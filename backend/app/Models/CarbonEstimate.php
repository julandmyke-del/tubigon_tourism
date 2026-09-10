<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class CarbonEstimate extends Model
{
    use HasUuids;

    protected $fillable = [
        'user_id', 'emission_factor_id', 'origin_name', 'destination_name',
        'origin_entity_type', 'origin_entity_id', 'destination_entity_type',
        'destination_entity_id', 'distance_km', 'distance_source',
        'route_calculated_at', 'travelers', 'trip_type', 'estimated_kg_co2e',
        'per_traveler_kg_co2e', 'factor_version', 'factor_unit', 'itinerary_id',
        'leg_breakdown',
    ];

    protected $casts = [
        'distance_km' => 'float', 'route_calculated_at' => 'datetime',
        'travelers' => 'integer', 'estimated_kg_co2e' => 'float',
        'per_traveler_kg_co2e' => 'float', 'leg_breakdown' => 'array',
    ];

    public function factor()
    {
        return $this->belongsTo(EmissionFactor::class, 'emission_factor_id');
    }
}
