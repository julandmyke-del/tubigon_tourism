<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class ReservationStatus extends Model
{
    use HasUuids, SoftDeletes;

    protected $table = 'reservation_status';

    protected $fillable = ['name'];
}
