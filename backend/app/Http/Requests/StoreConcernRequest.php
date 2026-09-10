<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreConcernRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return ['category_id' => ['required', 'uuid', 'exists:concern_categories,id'], 'subject' => ['required', 'string', 'min:5', 'max:255'], 'description' => ['required', 'string', 'min:10', 'max:10000'], 'related_type' => ['nullable', Rule::in(['reservation', 'ferry_schedule', 'tourist_spot', 'msme', 'waste_report', 'emergency_contact', 'role_application'])], 'related_id' => ['nullable', 'uuid', 'required_with:related_type'], 'priority' => ['nullable', Rule::in(['low', 'normal', 'high'])], 'attachment' => ['nullable', 'file', 'mimetypes:image/jpeg,image/png,image/webp,application/pdf', 'max:5120']];
    }
}
