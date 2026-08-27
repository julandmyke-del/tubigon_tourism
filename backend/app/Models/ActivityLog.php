<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class ActivityLog extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'user_id',
        'action',
        'details',
    ];

    public function user()
    {
        return $this->belongsTo(Profile::class, 'user_id');
    }
}
