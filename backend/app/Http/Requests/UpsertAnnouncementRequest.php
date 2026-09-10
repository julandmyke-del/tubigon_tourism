<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpsertAnnouncementRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->role?->name === 'admin';
    }

    protected function prepareForValidation(): void
    {
        if (! $this->has('audiences') && $this->has('audience')) {
            $a = $this->input('audience');
            $this->merge(['audiences' => [$a === 'everyone' ? 'public' : $a]]);
        }if ($this->isMethod('post') && ! $this->has('display_type')) {
            $this->merge(['display_type' => 'notification']);
        }
    }

    public function rules(): array
    {
        $p = $this->isMethod('post') ? 'required' : 'sometimes';

        return ['title' => [$p, 'string', 'min:3', 'max:255'], 'body' => [$p, 'string', 'min:3', 'max:10000'], 'category' => ['nullable', 'string', 'max:100'], 'type' => [$p, Rule::in(['general', 'advisory', 'event', 'safety', 'service', 'system'])], 'audiences' => [$p, 'array', 'min:1', 'max:6'], 'audiences.*' => [Rule::in(['public', 'tourist', 'msme_owner', 'tourism_partner', 'lgu_staff', 'admin']), 'distinct'], 'audience' => ['nullable', Rule::in(['everyone', 'tourist', 'msme_owner', 'tourism_partner', 'lgu_staff', 'admin'])], 'priority' => [$p, Rule::in(['normal', 'important', 'urgent'])], 'display_type' => [$p, Rule::in(['notification', 'banner', 'carousel', 'pinned', 'urgent_alert'])], 'status' => [$p, Rule::in(['draft', 'scheduled', 'published', 'archived'])], 'cta_label' => ['nullable', 'string', 'max:80'], 'related_type' => ['nullable', 'required_with:related_id', Rule::in(['tourist_spot', 'ferry_schedule', 'msme', 'eco_tip', 'emergency_advisory'])], 'related_id' => ['nullable', 'uuid', 'required_with:related_type'], 'starts_at' => ['nullable', 'date'], 'expires_at' => ['nullable', 'date', 'after:starts_at'], 'image' => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120']];
    }
}
