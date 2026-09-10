<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class BookingOfferingField extends Model
{
    use HasUuids;

    protected $fillable = [
        'offering_id',
        'field_key',
        'label',
        'field_type',
        'is_required',
        'options_json',
        'min_value',
        'max_value',
        'sort_order',
        'is_active',
    ];

    protected $casts = [
        'options_json' => 'array',
        'is_required' => 'boolean',
        'is_active' => 'boolean',
        'min_value' => 'float',
        'max_value' => 'float',
    ];
}
