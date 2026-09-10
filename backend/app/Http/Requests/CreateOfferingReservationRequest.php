<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class CreateOfferingReservationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->role?->name === 'tourist';
    }

    public function rules(): array
    {
        return ['tourist_spot_id' => ['required', 'uuid', 'exists:tourist_spots,id'], 'reservation_date' => ['required', 'date_format:Y-m-d', 'after_or_equal:today'], 'start_time' => ['nullable', 'date_format:H:i'], 'end_time' => ['nullable', 'date_format:H:i', 'after:start_time'], 'notes' => ['nullable', 'string', 'max:1000'], 'client_submission_id' => ['nullable', 'uuid'], 'items' => ['required', 'array', 'min:1', 'max:12'], 'items.*.offering_id' => ['required', 'uuid', 'distinct', 'exists:booking_offerings,id'], 'items.*.quantity' => ['required', 'integer', 'min:1', 'max:10000'], 'items.*.booking_details' => ['nullable', 'array', 'max:20']];
    }
}
