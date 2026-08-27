<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Setting extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'user_id',
        'notifications_enabled',
        'location_enabled',
        'offline_mode',
        'language',
    ];

    protected $casts = [
        'notifications_enabled' => 'boolean',
        'location_enabled' => 'boolean',
        'offline_mode' => 'boolean',
    ];

    public function user()
    {
        return $this->belongsTo(Profile::class, 'user_id');
    }
}
