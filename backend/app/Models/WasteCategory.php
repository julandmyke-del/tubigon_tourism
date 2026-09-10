<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class WasteCategory extends Model
{
    use HasUuids;

    protected $fillable = ['slug', 'name', 'helper_text', 'is_active', 'sort_order'];

    protected $casts = ['is_active' => 'boolean', 'sort_order' => 'integer'];

    public function reports()
    {
        return $this->hasMany(WasteReport::class, 'category_id');
    }
}
