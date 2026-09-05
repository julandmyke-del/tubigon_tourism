<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class ReservationStatusHistory extends Model
{
    use HasUuids;

    protected $table = 'reservation_status_history';

    protected $fillable = ['reservation_id', 'status_id', 'changed_by', 'notes'];

    public function status()
    {
        return $this->belongsTo(ReservationStatus::class, 'status_id');
    }

    public function changedBy()
    {
        return $this->belongsTo(User::class, 'changed_by');
    }
}
