<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Facades\Schema;

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
        'display_type', 'cta_label', 'related_type', 'related_id', 'image_path',
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
            ->where(function ($audience) use ($role): void {
                if (Schema::hasTable('announcement_audiences')) {
                    $audience->whereHas('audiences', fn ($q) => $q->whereIn('role', ['public', $role]))
                        ->orWhere(fn ($legacy) => $legacy->whereDoesntHave('audiences')->whereIn('audience', ['everyone', $role]));
                } else {
                    $audience->whereIn('audience', ['everyone', $role]);
                }
            });
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function audiences()
    {
        return $this->hasMany(AnnouncementAudience::class);
    }

    public function audienceRoles(): array
    {
        if (! Schema::hasTable('announcement_audiences')) {
            return [$this->audience === 'everyone' ? 'public' : $this->audience];
        }
        $roles = $this->relationLoaded('audiences') ? $this->audiences->pluck('role')->all() : $this->audiences()->pluck('role')->all();

        return $roles !== [] ? $roles : [$this->audience === 'everyone' ? 'public' : $this->audience];
    }
}
