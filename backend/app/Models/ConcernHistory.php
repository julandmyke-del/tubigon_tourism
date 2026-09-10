<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class ConcernHistory extends Model
{
    use HasUuids;

    protected $fillable = [
        'concern_id', 'actor_user_id', 'action', 'from_status', 'to_status',
        'note', 'is_public',
    ];

    protected $casts = ['is_public' => 'boolean'];
}
