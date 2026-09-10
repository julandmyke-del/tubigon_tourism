<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class MsmeCategory extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = ['name', 'slug', 'description', 'is_active', 'display_order'];

    protected $casts = ['is_active' => 'boolean', 'display_order' => 'integer'];

    public function msmes()
    {
        return $this->hasMany(Msme::class, 'category_id');
    }
}
