<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreFerryVesselRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->role?->name === 'admin';
    }

    public function rules(): array
    {
        $vessel = $this->route('vessel');
        $operatorId = $this->input('ferry_operator_id', $vessel?->ferry_operator_id);

        return [
            'ferry_operator_id' => ['required', 'uuid', 'exists:ferry_operators,id'],
            'vessel_name' => [
                'required', 'string', 'min:2', 'max:255',
                Rule::unique('ferry_vessels', 'vessel_name')
                    ->where(fn ($query) => $query->where('ferry_operator_id', $operatorId))
                    ->ignore($vessel?->id),
            ],
            'is_active' => ['sometimes', 'boolean'],
            'expected_updated_at' => ['sometimes', 'required', 'date'],
        ];
    }
}
