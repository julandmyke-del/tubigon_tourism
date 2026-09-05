<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class PartnerNotification extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'user_id',
        'announcement_id',
        'type',
        'title',
        'body',
        'data',
        'is_read',
    ];

    protected $casts = [
        'data' => 'array',
        'is_read' => 'boolean',
    ];

    public function user()
    {
        return $this->belongsTo(Profile::class, 'user_id');
    }

    public function announcement()
    {
        return $this->belongsTo(Announcement::class);
    }
}
