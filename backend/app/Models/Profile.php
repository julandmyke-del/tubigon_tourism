<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Profile extends Model
{
    use HasUuids, SoftDeletes;

    public $incrementing = false;
    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'name',
        'email',
        'role_id',
        'avatar_url',
        'phone',
        'bio',
        'language',
        'is_verified',
    ];

    protected $casts = [
        'is_verified' => 'boolean',
    ];

    public function role()
    {
        return $this->belongsTo(Role::class, 'role_id');
    }

    public function user()
    {
        return $this->belongsTo(User::class, 'id');
    }

    public function touristSpotAssignments()
    {
        return $this->hasMany(TouristSpotPartnerAssignment::class, 'partner_profile_id');
    }

    public function managedTouristSpots()
    {
        return $this->belongsToMany(
            TouristSpot::class,
            'tourist_spot_partner_assignments',
            'partner_profile_id',
            'tourist_spot_id',
        )->withPivot(['is_primary', 'assigned_by', 'assigned_at'])->withTimestamps();
    }
}
