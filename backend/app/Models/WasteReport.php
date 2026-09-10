<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class WasteReport extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'user_id',
        'category_id',
        'category',
        'severity',
        'description',
        'location_description',
        'resolved_address',
        'geocoding_source',
        'barangay',
        'latitude',
        'longitude',
        'images',
        'status',
        'priority',
        'assigned_to',
        'assigned_personnel',
        'assigned_at',
        'lgu_notes',
        'resolution_evidence',
        'reviewed_at',
        'resolved_at',
        'resolved_by',
        'resolution_summary',
        'reopened_at',
        'submitted_at',
        'client_submission_id',
    ];

    protected $casts = [
        'images' => 'array',
        'latitude' => 'float',
        'longitude' => 'float',
        'resolution_evidence' => 'array',
        'assigned_at' => 'datetime',
        'reviewed_at' => 'datetime',
        'resolved_at' => 'datetime',
        'reopened_at' => 'datetime',
        'submitted_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(Profile::class, 'user_id');
    }

    public function history()
    {
        return $this->hasMany(WasteReportHistory::class)->oldest();
    }

    public function categoryDefinition()
    {
        return $this->belongsTo(WasteCategory::class, 'category_id');
    }

    public function media()
    {
        return $this->hasMany(WasteReportMedia::class, 'waste_report_id')->oldest();
    }
}
