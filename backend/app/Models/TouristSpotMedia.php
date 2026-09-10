<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class TouristSpotMedia extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'tourist_spot_id', 'booking_offering_id', 'media_type', 'storage_path',
        'thumbnail_path', 'mime_type', 'size_bytes', 'caption',
        'media_category', 'sort_order', 'is_cover', 'is_active',
        'uploaded_by_user_id', 'moderated_by_user_id', 'moderation_note',
    ];

    protected $hidden = ['storage_path', 'thumbnail_path'];

    protected $casts = ['is_cover' => 'boolean', 'is_active' => 'boolean', 'size_bytes' => 'integer'];

    public function offering()
    {
        return $this->belongsTo(BookingOffering::class, 'booking_offering_id');
    }
}
