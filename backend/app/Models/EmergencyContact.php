<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class EmergencyContact extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'name',
        'category',
        'phone',
        'alternative_phone',
        'address',
        'description',
        'operating_hours',
        'classification',
        'is_active',
        'is_verified',
        'source',
        'source_url',
        'verified_by',
        'verified_at',
        'last_verified_at',
        'updated_by',
        'archived_by',
        'latitude',
        'longitude',
    ];

    protected $casts = [
        'latitude' => 'float',
        'longitude' => 'float',
        'is_active' => 'boolean',
        'is_verified' => 'boolean',
        'verified_at' => 'datetime',
        'last_verified_at' => 'datetime',
    ];

    public function updater()
    {
        return $this->belongsTo(User::class, 'updated_by');
    }

    public function verifier()
    {
        return $this->belongsTo(User::class, 'verified_by');
    }

    public function audits()
    {
        return $this->hasMany(EmergencyContactAudit::class, 'contact_id');
    }
}
