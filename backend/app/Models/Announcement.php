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
        'type',
        'audience',
        'priority',
        'status',
        'starts_at',
        'expires_at',
        'published_at',
        'created_by',
        'is_active',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'starts_at' => 'datetime',
        'expires_at' => 'datetime',
        'published_at' => 'datetime',
    ];

    public function scopeVisibleTo($query, string $role)
    {
        return $query
            ->where('is_active', true)
            ->whereIn('status', ['published', 'scheduled'])
            ->where(fn ($q) => $q->whereNull('starts_at')->orWhere('starts_at', '<=', now()))
            ->where(fn ($q) => $q->whereNull('expires_at')->orWhere('expires_at', '>', now()))
            ->whereIn('audience', ['everyone', $role]);
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
