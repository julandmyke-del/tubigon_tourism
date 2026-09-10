<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class ConcernCategory extends Model
{
    use HasUuids;

    protected $fillable = [
        'slug', 'name', 'assigned_role', 'redirect_feature', 'is_active',
        'sort_order',
    ];

    protected $casts = ['is_active' => 'boolean'];
}
