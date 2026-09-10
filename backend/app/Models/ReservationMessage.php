<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class ReservationMessage extends Model
{
    use HasUuids;

    protected $fillable = [
        'reservation_id', 'sender_user_id', 'sender_role_at_time', 'message',
        'message_type', 'is_internal',
    ];

    protected $casts = ['is_internal' => 'boolean'];

    public function sender()
    {
        return $this->belongsTo(User::class, 'sender_user_id');
    }

    public function readers()
    {
        return $this->belongsToMany(User::class, 'reservation_message_reads')->withPivot('read_at');
    }
}
