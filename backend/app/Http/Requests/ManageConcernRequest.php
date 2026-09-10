<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ManageConcernRequest extends FormRequest
{
    public function authorize(): bool
    {
        return in_array($this->user()?->role?->name, ['lgu_staff', 'admin'], true);
    }

    public function rules(): array
    {
        return ['status' => ['nullable', Rule::in(['under_review', 'assigned', 'in_progress', 'needs_more_information', 'resolved', 'closed', 'reopened'])], 'assigned_user_id' => ['nullable', 'uuid', 'exists:users,id'], 'assign_to_self' => ['sometimes', 'boolean'], 'escalate_to_admin' => ['sometimes', 'boolean'], 'note' => ['nullable', 'string', 'max:3000'], 'is_internal' => ['sometimes', 'boolean']];
    }
}
