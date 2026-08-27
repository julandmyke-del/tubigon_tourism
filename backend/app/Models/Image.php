<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Image extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'url',
        'bucket',
        'owner_id',
    ];

    public function owner()
    {
        return $this->belongsTo(Profile::class, 'owner_id');
    }
}
