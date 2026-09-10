<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpsertBookingOfferingRequest extends FormRequest
{
    public const TYPES = ['entrance', 'cottage', 'room', 'tour_package', 'boat_tour', 'food_package', 'meal', 'equipment_rental', 'venue', 'activity', 'parking', 'other_approved_service'];

    public const PRICING = ['per_person', 'per_adult', 'per_child', 'per_room_per_night', 'per_cottage', 'per_hour', 'per_day', 'per_reservation', 'fixed_package'];

    public const FIELDS = ['date', 'time', 'date_range', 'quantity', 'guest_count', 'adult_count', 'child_count', 'select', 'multi_select', 'boolean', 'short_text', 'notes'];

    public function authorize(): bool
    {
        return $this->user()?->role?->name === 'tourism_partner';
    }

    public function rules(): array
    {
        $p = $this->isMethod('post') ? 'required' : 'sometimes';

        return [
            'type' => [$p, Rule::in(self::TYPES)], 'display_name' => [$p, 'string', 'min:2', 'max:255'], 'description' => ['nullable', 'string', 'max:3000'], 'price' => [$p, 'numeric', 'min:0', 'max:9999999.99'], 'pricing_mode' => [$p, Rule::in(self::PRICING)],
            'capacity_per_unit' => ['nullable', 'integer', 'min:1', 'max:10000'], 'quantity_available' => ['nullable', 'integer', 'min:1', 'max:10000'], 'min_quantity' => ['nullable', 'integer', 'min:1', 'max:10000'], 'max_quantity' => ['nullable', 'integer', 'gte:min_quantity', 'max:10000'], 'lead_time_minutes' => ['nullable', 'integer', 'min:0', 'max:525600'], 'max_advance_days' => ['nullable', 'integer', 'min:1', 'max:730'],
            'available_days' => ['nullable', 'array', 'max:7'], 'available_days.*' => [Rule::in(['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'])],
            'time_slots' => ['nullable', 'array', 'max:50'], 'time_slots.*.start' => ['required_with:time_slots', 'date_format:H:i'], 'time_slots.*.end' => ['nullable', 'date_format:H:i'], 'blackout_dates' => ['nullable', 'array', 'max:366'], 'blackout_dates.*' => ['date_format:Y-m-d'],
            'cancellation_note' => ['nullable', 'string', 'max:2000'], 'operating_note' => ['nullable', 'string', 'max:2000'], 'is_add_on' => ['sometimes', 'boolean'], 'is_active' => ['sometimes', 'boolean'], 'sort_order' => ['nullable', 'integer', 'min:0', 'max:10000'],
            'fields' => ['nullable', 'array', 'max:20'], 'fields.*.field_key' => ['required', 'alpha_dash', 'max:64', 'distinct'], 'fields.*.label' => ['required', 'string', 'max:120'], 'fields.*.field_type' => ['required', Rule::in(self::FIELDS)], 'fields.*.is_required' => ['sometimes', 'boolean'], 'fields.*.options_json' => ['nullable', 'array', 'max:50'], 'fields.*.options_json.*' => ['string', 'max:120'], 'fields.*.min_value' => ['nullable', 'numeric'], 'fields.*.max_value' => ['nullable', 'numeric', 'gte:fields.*.min_value'], 'fields.*.sort_order' => ['nullable', 'integer', 'min:0', 'max:100'],
        ];
    }
}
