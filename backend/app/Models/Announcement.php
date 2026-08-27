<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Announcement extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'title',
        'body',
        'category',
        'is_active',
    ];

    protected $casts = [
        'is_active' => 'boolean',
    ];
}
