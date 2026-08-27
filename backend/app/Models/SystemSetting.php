<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class SystemSetting extends Model
{
    use HasUuids;

    protected $fillable = [
        'app_name',
        'contact_email',
        'contact_phone',
        'privacy_policy',
        'terms_of_service',
    ];
}
