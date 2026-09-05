<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class RoleApplicationHistory extends Model
{
    use HasUuids;

    public const UPDATED_AT = null;

    protected $table = 'role_application_history';

    protected $fillable = [
        'application_id', 'actor_user_id', 'action', 'from_status', 'to_status',
        'notes', 'metadata',
    ];

    protected $casts = ['metadata' => 'array'];

    public function actor()
    {
        return $this->belongsTo(User::class, 'actor_user_id');
    }
}
