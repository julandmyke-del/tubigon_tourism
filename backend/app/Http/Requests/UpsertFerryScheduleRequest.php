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
            'ferry_operator_id' => ['nullable', 'uuid', 'exists:ferry_operators,id'],
            'operator' => ['nullable', 'string', 'min:2', 'max:255'],
            'ferry_vessel_id' => ['nullable', 'uuid', 'exists:ferry_vessels,id'],
            'vessel_name' => ['nullable', 'string', 'max:255'],
            'ferry_route_id' => ['nullable', 'uuid', 'exists:ferry_routes,id'], 'origin_port_id' => ['nullable', 'uuid', 'exists:ferry_ports,id', 'different:destination_port_id'], 'destination_port_id' => ['nullable', 'uuid', 'exists:ferry_ports,id', 'different:origin_port_id'],
            'route' => ['nullable', 'string', 'max:255'], 'origin' => ['nullable', 'string', 'max:255'], 'destination' => ['nullable', 'string', 'max:255'],
            'departure_date' => ['nullable', 'date'], 'valid_from' => ['nullable', 'date'], 'valid_until' => ['nullable', 'date', 'after_or_equal:valid_from'],
            'departure_time' => [$p, 'regex:/^(?:(?:[01]?\d|2[0-3]):[0-5]\d|(?:0?[1-9]|1[0-2]):[0-5]\d\s*[AP]M)$/i'], 'arrival_time' => ['nullable', 'regex:/^(?:(?:[01]?\d|2[0-3]):[0-5]\d|(?:0?[1-9]|1[0-2]):[0-5]\d\s*[AP]M)$/i'], 'arrival_next_day' => ['sometimes', 'boolean'], 'fare' => ['nullable', 'numeric', 'min:0', 'max:999999.99'], 'fare_notes' => ['nullable', 'string', 'max:1000'],
            'status' => ['nullable', Rule::in(['scheduled', 'boarding', 'delayed', 'departed', 'arrived', 'cancelled', 'suspended'])],
            'days_of_week' => ['nullable', 'array', 'max:7'], 'days_of_week.*' => ['string', 'regex:/^(?:mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)$/i'],
            'advisory' => ['nullable', 'string', 'max:2000'], 'contact_information' => ['nullable', 'string', 'max:255'], 'reference_url' => ['nullable', 'url:http,https', 'max:2000'], 'source_reference' => ['nullable', 'string', 'max:2000'], 'is_active' => ['sometimes', 'boolean'], 'is_published' => ['sometimes', 'boolean'],
            'expected_updated_at' => ['sometimes', 'required', 'date'],
        ];
    }

    protected function prepareForValidation(): void
    {
        $aliases = [];
        if ($this->has('schedule_date') && ! $this->has('departure_date')) {
            $aliases['departure_date'] = $this->input('schedule_date');
        }
        if ($this->has('effective_from') && ! $this->has('valid_from')) {
            $aliases['valid_from'] = $this->input('effective_from');
        }
        if ($this->has('effective_until') && ! $this->has('valid_until')) {
            $aliases['valid_until'] = $this->input('effective_until');
        }
        if ($this->has('operating_days') && ! $this->has('days_of_week')) {
            $aliases['days_of_week'] = $this->input('operating_days');
        }
        if ($this->has('notes') && ! $this->has('advisory')) {
            $aliases['advisory'] = $this->input('notes');
        }
        $this->merge($aliases);
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($v): void {
            if ($this->isMethod('post') && ! $this->filled('ferry_operator_id') && ! $this->filled('operator')) {
                $v->errors()->add('ferry_operator_id', 'Select a ferry operator.');
            }
            if ($this->isMethod('post') && ! $this->filled('ferry_route_id') && ! ($this->filled('origin_port_id') && $this->filled('destination_port_id')) && ! ($this->filled('origin') && $this->filled('destination')) && ! $this->filled('route')) {
                $v->errors()->add('ferry_route_id', 'Select a ferry route or provide both route endpoints.');
            }
            if ($this->filled('departure_date') && ($this->filled('valid_from') || $this->filled('valid_until'))) {
                $v->errors()->add('departure_date', 'Use either a schedule date or an effective period, not both.');
            }
            if ($this->boolean('arrival_next_day') && ! $this->filled('arrival_time')) {
                $v->errors()->add('arrival_next_day', 'A next-day arrival requires an arrival time.');
            }
        });
    }
}
