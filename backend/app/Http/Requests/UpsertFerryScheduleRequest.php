<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpsertFerryScheduleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return in_array($this->user()?->role?->name, ['lgu_staff', 'admin'], true);
    }

    public function rules(): array
    {
        $p = $this->isMethod('post') ? 'required' : 'sometimes';

        return [
            'operator' => [$p, 'string', 'min:2', 'max:255'], 'vessel_name' => ['nullable', 'string', 'max:255'],
            'ferry_route_id' => ['nullable', 'uuid', 'exists:ferry_routes,id'], 'origin_port_id' => ['nullable', 'uuid', 'exists:ferry_ports,id', 'different:destination_port_id'], 'destination_port_id' => ['nullable', 'uuid', 'exists:ferry_ports,id', 'different:origin_port_id'],
            'route' => ['nullable', 'string', 'max:255'], 'origin' => ['nullable', 'string', 'max:255'], 'destination' => ['nullable', 'string', 'max:255'],
            'departure_date' => ['nullable', 'date', 'after_or_equal:today'], 'valid_from' => ['nullable', 'date'], 'valid_until' => ['nullable', 'date', 'after_or_equal:valid_from'],
            'departure_time' => [$p, 'regex:/^(?:(?:[01]?\d|2[0-3]):[0-5]\d|(?:0?[1-9]|1[0-2]):[0-5]\d\s*[AP]M)$/i'], 'arrival_time' => ['nullable', 'regex:/^(?:(?:[01]?\d|2[0-3]):[0-5]\d|(?:0?[1-9]|1[0-2]):[0-5]\d\s*[AP]M)$/i'], 'fare' => ['nullable', 'numeric', 'min:0', 'max:999999.99'], 'fare_notes' => ['nullable', 'string', 'max:1000'],
            'status' => ['nullable', Rule::in(['scheduled', 'boarding', 'delayed', 'departed', 'arrived', 'cancelled', 'suspended'])],
            'days_of_week' => ['nullable', 'array', 'max:7'], 'days_of_week.*' => ['string', 'regex:/^(?:mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)$/i'],
            'advisory' => ['nullable', 'string', 'max:2000'], 'contact_information' => ['nullable', 'string', 'max:255'], 'reference_url' => ['nullable', 'url:http,https', 'max:2000'], 'is_active' => ['sometimes', 'boolean'], 'is_published' => ['sometimes', 'boolean'],
        ];
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($v): void {
            if ($this->isMethod('post') && ! $this->filled('ferry_route_id') && ! ($this->filled('origin_port_id') && $this->filled('destination_port_id')) && ! ($this->filled('origin') && $this->filled('destination')) && ! $this->filled('route')) {
                $v->errors()->add('ferry_route_id', 'Select a ferry route or provide both route endpoints.');
            }
        });
    }
}
