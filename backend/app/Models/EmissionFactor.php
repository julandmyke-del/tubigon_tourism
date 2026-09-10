<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class EmissionFactor extends Model
{
    use HasUuids;

    protected $fillable = [
        'transport_mode', 'display_name', 'emission_factor', 'unit',
        'occupancy_assumption', 'source_name', 'source_year', 'source_url',
        'version', 'notes', 'is_active', 'effective_from', 'effective_to',
    ];

    protected $casts = [
        'emission_factor' => 'float', 'source_year' => 'integer',
        'is_active' => 'boolean', 'effective_from' => 'date', 'effective_to' => 'date',
    ];
}
