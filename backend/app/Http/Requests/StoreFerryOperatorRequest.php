<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreFerryOperatorRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->role?->name === 'admin';
    }

    public function rules(): array
    {
        $operator = $this->route('operator');

        return [
            'name' => ['required', 'string', 'min:2', 'max:255', Rule::unique('ferry_operators', 'name')->ignore($operator?->id)],
            'logo' => ['nullable', 'string', 'max:2000'],
            'description' => ['nullable', 'string', 'max:2000'],
            'contact_number' => ['nullable', 'string', 'max:255'],
            'website' => ['nullable', 'url:http,https', 'max:2000'],
            'is_active' => ['sometimes', 'boolean'],
            'expected_updated_at' => ['sometimes', 'required', 'date'],
        ];
    }
}
