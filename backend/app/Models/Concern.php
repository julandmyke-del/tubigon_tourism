<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Str;

class Concern extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = ['reference_no', 'user_id', 'category_id', 'subject', 'description', 'priority', 'status', 'assigned_role', 'assigned_user_id', 'related_type', 'related_id', 'resolved_at', 'closed_at'];

    protected $casts = ['resolved_at' => 'datetime', 'closed_at' => 'datetime'];

    public function category()
    {
        return $this->belongsTo(ConcernCategory::class);
    }

    public function messages()
    {
        return $this->hasMany(ConcernMessage::class)->oldest();
    }

    public function histories()
    {
        return $this->hasMany(ConcernHistory::class)->oldest();
    }

    public function attachments()
    {
        return $this->hasMany(ConcernAttachment::class);
    }

    protected static function booted(): void
    {
        static::creating(function (self $m): void {
            if (! $m->reference_no) {
                do {
                    $r = 'TB-CON-'.now()->format('Y').'-'.strtoupper(Str::random(8));
                } while (self::where('reference_no', $r)->exists());
                $m->reference_no = $r;
            }
        });
    }
}
