<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class EmailDelivery extends Model
{
    use HasUuids;

    protected $fillable = [
        'user_id',
        'message_type',
        'entity_type',
        'entity_id',
        'dedupe_key',
        'recipient_masked',
        'status',
        'attempts',
        'last_attempt_at',
        'sent_at',
        'error_class',
    ];

    protected $casts = [
        'attempts' => 'integer',
        'last_attempt_at' => 'datetime',
        'sent_at' => 'datetime',
    ];
}
