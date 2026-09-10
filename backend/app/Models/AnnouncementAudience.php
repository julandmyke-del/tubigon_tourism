<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AnnouncementAudience extends Model
{
    public $incrementing = false;

    public $timestamps = false;

    protected $table = 'announcement_audiences';

    protected $fillable = ['announcement_id', 'role'];
}
