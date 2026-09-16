<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class FerryOperator extends Model
{
    use HasUuids;

    protected $fillable = [
        'name', 'logo', 'description', 'contact_number', 'website', 'is_active',
    ];

    protected $casts = ['is_active' => 'boolean'];

    public function vessels()
    {
        return $this->hasMany(FerryVessel::class);
    }

    public function schedules()
    {
        return $this->hasMany(FerrySchedule::class);
    }
}
