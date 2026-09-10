<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class Reservation extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'user_id',
        'public_reference',
        'partner_id',
        'customer_name_snapshot',
        'customer_email_snapshot',
        'customer_phone_snapshot',
        'tourist_spot_id',
        'client_submission_id',
        'reservable_type',
        'reservable_id',
        'reservation_date',
        'start_time',
        'end_time',
        'guests',
        'status_id',
        'notes',
        'total_amount',
    ];

    protected $casts = [
        'reservation_date' => 'datetime',
        'guests' => 'integer',
        'total_amount' => 'float',
    ];

    public function user()
    {
        return $this->belongsTo(Profile::class, 'user_id');
    }

    public function status()
    {
        return $this->belongsTo(ReservationStatus::class, 'status_id');
    }

    public function listing()
    {
        return $this->belongsTo(TourismListing::class, 'reservable_id');
    }

    public function statusHistory()
    {
        return $this->hasMany(ReservationStatusHistory::class)->with('status')->oldest();
    }

    public function items()
    {
        return $this->hasMany(ReservationItem::class);
    }

    public function messages()
    {
        return $this->hasMany(ReservationMessage::class)->oldest();
    }

    protected static function booted(): void
    {
        static::creating(function (Reservation $reservation): void {
            if (Schema::hasColumn('reservations', 'public_reference') && ! $reservation->public_reference) {
                do {
                    $reference = 'TB-RSV-'.now()->format('Y').'-'.strtoupper(Str::random(8));
                } while (static::where('public_reference', $reference)->exists());
                $reservation->public_reference = $reference;
            }
        });
    }
}
