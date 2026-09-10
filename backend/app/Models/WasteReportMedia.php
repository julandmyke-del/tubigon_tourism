<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class WasteReportMedia extends Model
{
    use HasUuids;

    protected $table = 'waste_report_media';

    protected $fillable = [
        'waste_report_id', 'uploaded_by', 'media_type', 'disk', 'storage_path',
        'mime_type', 'size_bytes', 'original_name', 'visibility',
    ];

    protected $casts = ['size_bytes' => 'integer'];

    protected $hidden = ['disk', 'storage_path'];

    protected $appends = ['url'];

    public function report()
    {
        return $this->belongsTo(WasteReport::class, 'waste_report_id');
    }

    public function uploader()
    {
        return $this->belongsTo(User::class, 'uploaded_by');
    }

    public function getUrlAttribute(): string
    {
        return url('/api/v1/waste-report-media/'.$this->id);
    }
}
