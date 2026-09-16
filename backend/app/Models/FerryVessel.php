<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class FerryVessel extends Model
{
    use HasUuids;

    protected $fillable = ['ferry_operator_id', 'vessel_name', 'is_active'];

    protected $casts = ['is_active' => 'boolean'];

    public function ferryOperator()
    {
        return $this->belongsTo(FerryOperator::class);
    }

    public function schedules()
    {
        return $this->hasMany(FerrySchedule::class);
    }
}
