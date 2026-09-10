<?php

namespace App\Models;

use App\Notifications\ResetPasswordNotification;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, HasUuids, Notifiable, SoftDeletes;

    protected $fillable = [
        'name',
        'email',
        'password',
        'role_id',
        'avatar_url',
        'phone',
        'bio',
        'language',
        'is_verified',
        'google_id',
        'auth_provider',
        'email_verified_at',
        'email_verification_code_hash',
        'email_verification_code_expires_at',
        'email_verification_attempts',
        'email_verification_last_sent_at',
    ];

    protected $hidden = [
        'password',
        'remember_token',
        'google_id',
        'email_verification_code_hash',
    ];

    protected function casts(): array
    {
        return [
            'is_verified' => 'boolean',
            'email_verified_at' => 'datetime',
            'email_verification_code_expires_at' => 'datetime',
            'email_verification_attempts' => 'integer',
            'email_verification_last_sent_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function role()
    {
        return $this->belongsTo(Role::class, 'role_id');
    }

    public function profile()
    {
        return $this->hasOne(Profile::class, 'id');
    }

    public function itineraries()
    {
        return $this->hasMany(Itinerary::class);
    }

    public function managedTouristSpots()
    {
        return $this->belongsToMany(
            TouristSpot::class,
            'tourist_spot_partner_assignments',
            'partner_profile_id',
            'tourist_spot_id',
        )->withPivot(['is_primary', 'assigned_by', 'assigned_at'])->withTimestamps();
    }

    public function msmes()
    {
        return $this->hasMany(Msme::class, 'profile_id');
    }

    public function msmeBusiness()
    {
        return $this->hasOne(Msme::class, 'profile_id');
    }

    public function roleApplications()
    {
        return $this->hasMany(RoleApplication::class, 'applicant_user_id');
    }

    public function preferences()
    {
        return $this->hasOne(UserPreference::class);
    }

    public function sendPasswordResetNotification($token): void
    {
        $this->notify(new ResetPasswordNotification($token));
    }
}
