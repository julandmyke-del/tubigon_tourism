<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UploadTouristSpotMediaRequest extends FormRequest
{
    public function authorize(): bool
    {
        return in_array($this->user()?->role?->name, ['tourism_partner', 'lgu_staff', 'admin'], true);
    }

    public function rules(): array
    {
        return ['image' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120', 'dimensions:max_width=8000,max_height=8000'], 'caption' => ['nullable', 'string', 'max:255'], 'media_category' => ['nullable', Rule::in(['general', 'scenery', 'facilities', 'activities', 'accommodation', 'food', 'entrance_access', 'other'])], 'booking_offering_id' => ['nullable', 'uuid', 'exists:booking_offerings,id'], 'is_cover' => ['sometimes', 'boolean']];
    }
}
