<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class ConcernMessage extends Model
{
    use HasUuids;

    protected $fillable = [
        'concern_id', 'sender_user_id', 'message', 'is_internal',
    ];

    protected $casts = ['is_internal' => 'boolean'];

    public function sender()
    {
        return $this->belongsTo(User::class, 'sender_user_id');
    }
}
