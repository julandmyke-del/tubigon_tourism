<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Role extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = ['name'];

    public function users()
    {
        return $this->hasMany(User::class, 'role_id');
    }
}
