<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Review extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'user_id',
        'reviewable_type',
        'reviewable_id',
        'rating',
        'content',
        'images',
    ];

    protected $casts = [
        'rating' => 'integer',
        'images' => 'array',
    ];

    public function user()
    {
        return $this->belongsTo(Profile::class, 'user_id');
    }
}
