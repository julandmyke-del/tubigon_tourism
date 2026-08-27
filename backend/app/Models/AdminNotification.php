<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class AdminNotification extends Model
{
    use HasUuids;

    public $timestamps = false;

    protected $fillable = [
        'title',
        'body',
        'type',
        'data',
        'is_read',
    ];

    protected $casts = [
        'data' => 'array',
        'is_read' => 'boolean',
        'created_at' => 'datetime',
    ];
}
