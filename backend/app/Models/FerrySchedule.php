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
        'origin',
        'destination',
        'vessel_name',
        'departure_date',
        'departure_time',
        'arrival_time',
        'fare',
        'status',
        'days_of_week',
        'advisory',
        'contact_information',
        'reference_url',
        'is_active',
        'updated_by',
        'ferry_route_id', 'origin_port_id', 'destination_port_id',
        'ferry_operator_id', 'ferry_vessel_id', 'arrival_next_day',
        'source_reference', 'created_by',
        'valid_from', 'valid_until', 'fare_notes', 'is_published',
        'published_at', 'archived_at',
    ];

    protected $casts = [
        'fare' => 'float',
        'days_of_week' => 'array',
        'departure_date' => 'date:Y-m-d',
        'is_active' => 'boolean',
        'is_published' => 'boolean',
        'arrival_next_day' => 'boolean',
        'valid_from' => 'date:Y-m-d', 'valid_until' => 'date:Y-m-d',
        'published_at' => 'datetime', 'archived_at' => 'datetime',
    ];

    public function ferryRoute()
    {
        return $this->belongsTo(FerryRoute::class);
    }

    public function ferryOperator()
    {
        return $this->belongsTo(FerryOperator::class);
    }

    public function ferryVessel()
    {
        return $this->belongsTo(FerryVessel::class);
    }

    public function originPort()
    {
        return $this->belongsTo(FerryPort::class, 'origin_port_id');
    }

    public function destinationPort()
    {
        return $this->belongsTo(FerryPort::class, 'destination_port_id');
    }
}
