<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class SpotCategory extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = ['name', 'slug'];

    public function touristSpots()
    {
        return $this->hasMany(TouristSpot::class, 'category_id');
    }
}
