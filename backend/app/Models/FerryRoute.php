<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class FerryRoute extends Model
{
    use HasUuids;

    protected $fillable = [
        'name', 'origin_port_id', 'destination_port_id',
        'estimated_duration_minutes', 'is_active',
    ];

    protected $casts = ['is_active' => 'boolean'];

    public function originPort()
    {
        return $this->belongsTo(FerryPort::class, 'origin_port_id');
    }

    public function destinationPort()
    {
        return $this->belongsTo(FerryPort::class, 'destination_port_id');
    }
}
