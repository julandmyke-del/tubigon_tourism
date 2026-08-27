<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class EmergencyContactAudit extends Model
{
    use HasUuids;

    protected $fillable = [
        'contact_id',
        'action',
        'old_value',
        'new_value',
        'updated_by',
    ];

    protected function casts(): array
    {
        return [
            'old_value' => 'array',
            'new_value' => 'array',
        ];
    }

    public function actor()
    {
        return $this->belongsTo(User::class, 'updated_by');
    }

    public function contact()
    {
        return $this->belongsTo(EmergencyContact::class, 'contact_id')->withTrashed();
    }
}
