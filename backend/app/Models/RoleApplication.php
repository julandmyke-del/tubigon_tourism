<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class RoleApplication extends Model
{
    use HasUuids;

    public const TYPE_MSME = 'msme_owner';

    public const TYPE_PARTNER = 'tourism_partner';

    public const STATUS_DRAFT = 'draft';

    public const STATUS_SUBMITTED = 'submitted';

    public const STATUS_UNDER_REVIEW = 'under_review';

    public const STATUS_NEEDS_CHANGES = 'needs_changes';

    public const STATUS_RECOMMENDED = 'recommended_for_approval';

    public const STATUS_APPROVED = 'approved';

    public const STATUS_REJECTED = 'rejected';

    public const STATUS_WITHDRAWN = 'withdrawn';

    public const TYPES = [self::TYPE_MSME, self::TYPE_PARTNER];

    public const STATUSES = [
        self::STATUS_DRAFT,
        self::STATUS_SUBMITTED,
        self::STATUS_UNDER_REVIEW,
        self::STATUS_NEEDS_CHANGES,
        self::STATUS_RECOMMENDED,
        self::STATUS_APPROVED,
        self::STATUS_REJECTED,
        self::STATUS_WITHDRAWN,
    ];

    protected $fillable = [
        'applicant_user_id', 'application_type', 'status', 'active_slot', 'payload',
        'requested_tourist_spot_id', 'requested_msme_category_id',
        'recommended_msme_category_id', 'final_msme_category_id',
        'linked_msme_id', 'lgu_checklist',
        'reviewed_by_lgu_id', 'lgu_reviewed_at', 'lgu_notes',
        'admin_reviewed_by_id', 'admin_reviewed_at', 'admin_notes',
        'submitted_at', 'approved_at', 'rejected_at', 'withdrawn_at',
    ];

    protected $casts = [
        'active_slot' => 'boolean',
        'payload' => 'array',
        'lgu_checklist' => 'array',
        'lgu_reviewed_at' => 'datetime',
        'admin_reviewed_at' => 'datetime',
        'submitted_at' => 'datetime',
        'approved_at' => 'datetime',
        'rejected_at' => 'datetime',
        'withdrawn_at' => 'datetime',
    ];

    public function applicant()
    {
        return $this->belongsTo(User::class, 'applicant_user_id');
    }

    public function requestedTouristSpot()
    {
        return $this->belongsTo(TouristSpot::class, 'requested_tourist_spot_id');
    }

    public function linkedMsme()
    {
        return $this->belongsTo(Msme::class, 'linked_msme_id');
    }

    public function requestedMsmeCategory()
    {
        return $this->belongsTo(MsmeCategory::class, 'requested_msme_category_id');
    }

    public function recommendedMsmeCategory()
    {
        return $this->belongsTo(MsmeCategory::class, 'recommended_msme_category_id');
    }

    public function finalMsmeCategory()
    {
        return $this->belongsTo(MsmeCategory::class, 'final_msme_category_id');
    }

    public function lguReviewer()
    {
        return $this->belongsTo(User::class, 'reviewed_by_lgu_id');
    }

    public function adminReviewer()
    {
        return $this->belongsTo(User::class, 'admin_reviewed_by_id');
    }

    public function history()
    {
        return $this->hasMany(RoleApplicationHistory::class, 'application_id')->oldest('created_at');
    }

    public function canTransitionTo(string $status): bool
    {
        return in_array($status, match ($this->status) {
            self::STATUS_DRAFT => [self::STATUS_SUBMITTED, self::STATUS_WITHDRAWN],
            self::STATUS_SUBMITTED => [self::STATUS_UNDER_REVIEW, self::STATUS_WITHDRAWN],
            self::STATUS_UNDER_REVIEW => [self::STATUS_NEEDS_CHANGES, self::STATUS_RECOMMENDED, self::STATUS_REJECTED],
            self::STATUS_NEEDS_CHANGES => [self::STATUS_SUBMITTED, self::STATUS_WITHDRAWN],
            self::STATUS_RECOMMENDED => [self::STATUS_APPROVED, self::STATUS_REJECTED],
            default => [],
        }, true);
    }

    public function isTerminal(): bool
    {
        return in_array($this->status, [self::STATUS_APPROVED, self::STATUS_REJECTED, self::STATUS_WITHDRAWN], true);
    }
}
