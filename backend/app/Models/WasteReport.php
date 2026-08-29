<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class WasteReport extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'user_id',
        'category',
        'description',
        'location_description',
        'latitude',
        'longitude',
        'images',
        'status',
        'priority',
        'assigned_to',
        'assigned_personnel',
        'assigned_at',
        'lgu_notes',
        'resolution_evidence',
        'reviewed_at',
        'resolved_at',
    ];

    protected $casts = [
        'images' => 'array',
        'latitude' => 'float',
        'longitude' => 'float',
        'resolution_evidence' => 'array',
        'assigned_at' => 'datetime',
        'reviewed_at' => 'datetime',
        'resolved_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(Profile::class, 'user_id');
    }
}
