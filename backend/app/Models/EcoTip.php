<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class EcoTip extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'title',
        'content',
        'category',
        'spot_id',
        'language',
    ];

    public function spot()
    {
        return $this->belongsTo(TouristSpot::class, 'spot_id');
    }
}
