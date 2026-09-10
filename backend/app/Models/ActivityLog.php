<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class ActivityLog extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'user_id',
        'action',
        'details',
        'actor_role',
        'action_type',
        'target_type',
        'target_id',
        'metadata',
    ];

    protected $casts = ['metadata' => 'array'];

    protected static function booted(): void
    {
        static::creating(function (ActivityLog $log): void {
            if (! Schema::hasTable('activity_logs')) {
                return;
            }

            if (Schema::hasColumn('activity_logs', 'action_type') && ! $log->action_type) {
                $log->action_type = Str::of((string) $log->action)->lower()->slug('_')->limit(100, '')->toString();
            }
            if (Schema::hasColumn('activity_logs', 'actor_role') && ! $log->actor_role && $log->user_id
                && Schema::hasTable('profiles') && Schema::hasTable('roles')) {
                $log->actor_role = Profile::with('role')->find($log->user_id)?->role?->name;
            }

            $decoded = is_string($log->details) ? json_decode($log->details, true) : null;
            if (! is_array($decoded)) {
                return;
            }
            if (Schema::hasColumn('activity_logs', 'target_type') && ! $log->target_type) {
                $targetType = $decoded['target_type'] ?? $decoded['entity_type'] ?? $decoded['reservable_type'] ?? null;
                $log->target_type = $targetType !== null ? Str::limit((string) $targetType, 100, '') : null;
            }
            if (Schema::hasColumn('activity_logs', 'target_id') && ! $log->target_id) {
                $targetId = $decoded['target_id'] ?? $decoded['entity_id'] ?? $decoded['reservable_id'] ?? null;
                $log->target_id = $targetId !== null ? Str::limit((string) $targetId, 255, '') : null;
            }
            if (Schema::hasColumn('activity_logs', 'metadata') && ! $log->metadata) {
                $log->metadata = self::safeMetadata($decoded);
            }
        });
    }

    private static function safeMetadata(array $values): array
    {
        $blocked = ['password', 'secret', 'token', 'code', 'authorization', 'cookie', 'id_token'];
        $safe = [];
        foreach ($values as $key => $value) {
            $normalized = Str::lower((string) $key);
            if (collect($blocked)->contains(fn (string $term) => str_contains($normalized, $term))) {
                continue;
            }
            $safe[$key] = is_array($value) ? self::safeMetadata($value) : $value;
        }

        return $safe;
    }

    public function user()
    {
        return $this->belongsTo(Profile::class, 'user_id');
    }
}
