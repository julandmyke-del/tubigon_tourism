<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Rating extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'user_id',
        'rateable_type',
        'rateable_id',
        'value',
    ];

    protected $casts = [
        'value' => 'integer',
    ];

    public function user()
    {
        return $this->belongsTo(Profile::class, 'user_id');
    }
}
