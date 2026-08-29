<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class TouristSpotPartnerAssignment extends Model
{
    use HasUuids;

    protected $fillable = [
        'tourist_spot_id',
        'partner_profile_id',
        'is_primary',
        'assigned_by',
        'assigned_at',
    ];

    protected $casts = [
        'is_primary' => 'boolean',
        'assigned_at' => 'datetime',
    ];

    public function touristSpot()
    {
        return $this->belongsTo(TouristSpot::class);
    }

    public function partnerProfile()
    {
        return $this->belongsTo(Profile::class, 'partner_profile_id');
    }

    public function assignedBy()
    {
        return $this->belongsTo(User::class, 'assigned_by');
    }
}
