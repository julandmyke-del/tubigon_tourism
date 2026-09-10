<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreFerryRouteRequest extends FormRequest
{
    public function authorize(): bool
    {
        return in_array($this->user()?->role?->name, ['lgu_staff', 'admin'], true);
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'min:2', 'max:255'],
            'origin_port_id' => ['required', 'uuid', 'exists:ferry_ports,id', 'different:destination_port_id'],
            'destination_port_id' => ['required', 'uuid', 'exists:ferry_ports,id'],
            'estimated_duration_minutes' => ['nullable', 'integer', 'min:1', 'max:10080'],
            'is_active' => ['sometimes', 'boolean'],
        ];
    }
}
