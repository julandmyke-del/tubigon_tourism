<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class MapLocationCategory extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'parent_id',
        'name',
        'slug',
        'icon',
        'marker_color',
        'active',
        'sort_order',
    ];

    protected $casts = [
        'active' => 'boolean',
        'sort_order' => 'integer',
    ];

    public function parent()
    {
        return $this->belongsTo(self::class, 'parent_id');
    }

    public function children()
    {
        return $this->hasMany(self::class, 'parent_id')->orderBy('sort_order');
    }

    public function locations()
    {
        return $this->hasMany(MapLocation::class, 'category_id');
    }
}
