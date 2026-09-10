<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class ConcernAttachment extends Model
{
    use HasUuids;

    protected $fillable = [
        'concern_id', 'uploaded_by_user_id', 'storage_path', 'original_name',
        'mime_type', 'size_bytes',
    ];

    protected $hidden = ['storage_path'];

    protected $casts = ['size_bytes' => 'integer'];
}
