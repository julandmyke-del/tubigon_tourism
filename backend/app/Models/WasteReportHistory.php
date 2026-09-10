<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class WasteReportHistory extends Model
{
    use HasUuids;

    protected $table = 'waste_report_history';

    protected $fillable = [
        'waste_report_id', 'changed_by', 'from_status', 'to_status', 'notes', 'metadata', 'is_public',
    ];

    protected $casts = ['metadata' => 'array', 'is_public' => 'boolean'];

    public function actor()
    {
        return $this->belongsTo(User::class, 'changed_by');
    }
}
