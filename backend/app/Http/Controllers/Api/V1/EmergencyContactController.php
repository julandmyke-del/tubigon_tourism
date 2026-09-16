<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\ValidatesTubigonCoordinates;
use App\Http\Controllers\Controller;
use App\Models\EmergencyContact;
use App\Models\EmergencyContactAudit;
use App\Support\StaleRecordGuard;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class EmergencyContactController extends Controller
{
    use ValidatesTubigonCoordinates;

    private const VERIFICATION_SENSITIVE_FIELDS = [
        'name',
        'contact_label',
        'category',
        'phone',
        'alternative_phone',
        'address',
        'barangay',
        'latitude',
        'longitude',
        'description',
        'operating_hours',
        'availability_notes',
        'emergency_instructions',
        'source',
        'source_name',
        'source_url',
    ];

    public function index(): JsonResponse
    {
        $safeColumns = array_values(array_filter([
            'id', 'integer_id', 'name', 'category', 'phone',
            'contact_label', 'display_order',
            'alternative_phone', 'address', 'barangay', 'description',
            'operating_hours', 'availability_notes', 'emergency_instructions',
            'classification', 'is_active', 'is_verified', 'is_public',
            'verification_status', 'source_name', 'source_url', 'verified_at',
            'last_verified_at', 'latitude', 'longitude', 'updated_at',
        ], fn (string $column) => Schema::hasColumn('emergency_contacts', $column)));
        $contacts = EmergencyContact::query()->select($safeColumns)
            ->where('is_active', true)
            ->where('is_verified', true)
            ->when(Schema::hasColumn('emergency_contacts', 'is_public'), fn ($query) => $query->where('is_public', true))
            ->when(Schema::hasColumn('emergency_contacts', 'verification_status'), fn ($query) => $query->where('verification_status', 'verified'))
            ->when(Schema::hasColumn('emergency_contacts', 'display_order'), fn ($query) => $query->orderBy('display_order'))
            ->orderBy('name')
            ->get();

        $data = $contacts->map(function (EmergencyContact $contact): array {
            $row = $contact->toArray();
            $row['uuid'] = $contact->id;
            $row['agency_name'] = $contact->name;
            $row['phone_number'] = $contact->phone;

            return $row;
        });

        return response()
            ->json(['status' => 'success', 'data' => $data])
            ->header('Cache-Control', 'no-store, max-age=0');
    }

    public function managementIndex(): JsonResponse
    {
        $contacts = EmergencyContact::with(['updater:id,name', 'verifier:id,name'])
            ->orderByDesc('is_active')
            ->when(Schema::hasColumn('emergency_contacts', 'display_order'), fn ($query) => $query->orderBy('display_order'))
            ->orderBy('name')
            ->get();

        return response()->json(['status' => 'success', 'data' => $contacts]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate($this->rules());
        unset($validated['expected_updated_at']);
        $this->validateTubigonCoordinates($validated);
        $validated['updated_by'] = $request->user()->id;
        if (Schema::hasColumn('emergency_contacts', 'created_by')) {
            $validated['created_by'] = $request->user()->id;
        }
        $validated['is_verified'] = false;
        if (Schema::hasColumn('emergency_contacts', 'verification_status')) {
            $validated['verification_status'] = 'draft';
        }
        if (Schema::hasColumn('emergency_contacts', 'is_public') && ! array_key_exists('is_public', $validated)) {
            $validated['is_public'] = true;
        }

        $contact = DB::transaction(function () use ($validated, $request) {
            $this->assertNoDuplicate($validated);
            $contact = EmergencyContact::create($validated);
            $this->audit($contact, 'created', null, $contact->getAttributes(), $request->user()->id);

            return $contact;
        });

        return response()->json([
            'status' => 'success',
            'data' => $contact->load(['updater:id,name', 'verifier:id,name']),
        ], 201);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $validated = $request->validate($this->rules(true));
        $expectedUpdatedAt = $validated['expected_updated_at'] ?? null;
        unset($validated['expected_updated_at']);
        $existing = EmergencyContact::findOrFail($id);
        $this->validateTubigonCoordinates(
            $validated,
            $existing->latitude !== null ? (float) $existing->latitude : null,
            $existing->longitude !== null ? (float) $existing->longitude : null,
        );

        $contact = DB::transaction(function () use ($id, $validated, $expectedUpdatedAt, $request) {
            $contact = EmergencyContact::whereKey($id)->lockForUpdate()->firstOrFail();
            StaleRecordGuard::assertCurrent($contact, $expectedUpdatedAt, $contact->toArray());
            $this->assertNoDuplicate($validated, $contact);
            $old = $contact->getAttributes();
            $validated['updated_by'] = $request->user()->id;
            $sensitiveDataChanged = collect(self::VERIFICATION_SENSITIVE_FIELDS)
                ->contains(fn (string $field) => array_key_exists($field, $validated)
                    && $validated[$field] != $contact->{$field});
            if ($contact->is_verified && $sensitiveDataChanged) {
                $validated['is_verified'] = false;
                $validated['verified_by'] = null;
                $validated['verified_at'] = null;
                $validated['last_verified_at'] = null;
                if (Schema::hasColumn('emergency_contacts', 'verification_status')) {
                    $validated['verification_status'] = 'needs_reverification';
                }
            }
            $contact->update($validated);
            $changes = $contact->getChanges();
            unset($changes['updated_at']);
            $this->audit(
                $contact,
                'updated',
                Arr::only($old, array_keys($changes)),
                $changes,
                $request->user()->id,
            );

            return $contact;
        });

        return response()->json([
            'status' => 'success',
            'data' => $contact->fresh(['updater:id,name', 'verifier:id,name']),
        ]);
    }

    public function setStatus(Request $request, string $id): JsonResponse
    {
        $validated = $request->validate([
            'is_active' => 'required|boolean',
            'expected_updated_at' => 'sometimes|required|date',
        ]);

        $contact = DB::transaction(function () use ($id, $validated, $request) {
            $contact = EmergencyContact::whereKey($id)->lockForUpdate()->firstOrFail();
            StaleRecordGuard::assertCurrent($contact, $validated['expected_updated_at'] ?? null, $contact->toArray());
            $old = ['is_active' => $contact->is_active];
            $contact->update([
                'is_active' => $validated['is_active'],
                'updated_by' => $request->user()->id,
                ...(Schema::hasColumn('emergency_contacts', 'verification_status') && ! $validated['is_active'] ? ['verification_status' => 'inactive', 'is_verified' => false] : []),
                ...(Schema::hasColumn('emergency_contacts', 'verification_status') && $validated['is_active'] && $contact->verification_status === 'inactive'
                    ? ['verification_status' => 'needs_reverification', 'is_verified' => false] : []),
            ]);
            $this->audit(
                $contact,
                $validated['is_active'] ? 'activated' : 'deactivated',
                $old,
                ['is_active' => $contact->is_active],
                $request->user()->id,
            );

            return $contact;
        });

        return response()->json([
            'status' => 'success',
            'data' => $contact->fresh(['updater:id,name', 'verifier:id,name']),
        ]);
    }

    public function verify(Request $request, string $id): JsonResponse
    {
        $expectedUpdatedAt = StaleRecordGuard::expectedUpdatedAt($request);

        $contact = DB::transaction(function () use ($id, $request, $expectedUpdatedAt) {
            $contact = EmergencyContact::whereKey($id)->lockForUpdate()->firstOrFail();
            StaleRecordGuard::assertCurrent($contact, $expectedUpdatedAt, $contact->toArray());
            if (Schema::hasColumn('emergency_contacts', 'source_name')) {
                abort_if(
                    blank($contact->source_name ?? $contact->source)
                        || (blank($contact->source_url) && blank($contact->source)),
                    422,
                    'Add an exact official source name and either a source URL or source description before verification.'
                );
            }
            $old = [
                'is_verified' => $contact->is_verified,
                'verified_by' => $contact->verified_by,
                'verified_at' => $contact->verified_at,
                'last_verified_at' => $contact->last_verified_at,
            ];
            $now = now();
            $contact->update([
                'is_verified' => true,
                'verified_by' => $request->user()->id,
                'verified_at' => $contact->verified_at ?? $now,
                'last_verified_at' => $now,
                'updated_by' => $request->user()->id,
                ...(Schema::hasColumn('emergency_contacts', 'verification_status') ? ['verification_status' => 'verified'] : []),
            ]);
            $this->audit(
                $contact,
                'verified',
                $old,
                [
                    'is_verified' => true,
                    'verified_by' => $request->user()->id,
                    'verified_at' => $contact->verified_at,
                    'last_verified_at' => $contact->last_verified_at,
                ],
                $request->user()->id,
            );

            return $contact;
        });

        return response()->json([
            'status' => 'success',
            'data' => $contact->fresh(['updater:id,name', 'verifier:id,name']),
        ]);
    }

    public function setVerificationStatus(Request $request, string $id): JsonResponse
    {
        abort_unless(Schema::hasColumn('emergency_contacts', 'verification_status'), 409, 'Verification lifecycle migration is not installed.');
        $validated = $request->validate([
            'verification_status' => ['required', Rule::in(['draft', 'needs_reverification', 'inactive'])],
            'notes' => 'nullable|string|max:2000',
            'expected_updated_at' => 'sometimes|required|date',
        ]);
        $contact = DB::transaction(function () use ($id, $validated, $request): EmergencyContact {
            $contact = EmergencyContact::whereKey($id)->lockForUpdate()->firstOrFail();
            StaleRecordGuard::assertCurrent($contact, $validated['expected_updated_at'] ?? null, $contact->toArray());
            $old = $contact->only(['verification_status', 'is_verified', 'verified_by', 'verified_at', 'last_verified_at']);
            $contact->update([
                'verification_status' => $validated['verification_status'],
                'is_verified' => false,
                'verified_by' => null,
                'verified_at' => null,
                'last_verified_at' => null,
                'notes' => $validated['notes'] ?? $contact->notes,
                'updated_by' => $request->user()->id,
            ]);
            $this->audit($contact, $validated['verification_status'], $old, $contact->only(array_keys($old)), $request->user()->id);

            return $contact;
        });

        return response()->json(['status' => 'success', 'data' => $contact->fresh(['updater:id,name', 'verifier:id,name'])]);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        $expectedUpdatedAt = StaleRecordGuard::expectedUpdatedAt($request);

        DB::transaction(function () use ($id, $request, $expectedUpdatedAt) {
            $contact = EmergencyContact::whereKey($id)->lockForUpdate()->firstOrFail();
            StaleRecordGuard::assertCurrent($contact, $expectedUpdatedAt, $contact->toArray());
            $wasActive = $contact->is_active;
            $contact->update([
                'is_active' => false,
                'archived_by' => $request->user()->id,
                'updated_by' => $request->user()->id,
            ]);
            $contact->delete();
            $this->audit(
                $contact,
                'archived',
                ['is_active' => $wasActive, 'deleted_at' => null],
                ['is_active' => false, 'deleted_at' => $contact->deleted_at],
                $request->user()->id,
            );
        });

        return response()->json([
            'status' => 'success',
            'message' => 'Emergency contact archived. No record was permanently deleted.',
        ]);
    }

    private function rules(bool $updating = false): array
    {
        $required = $updating ? 'sometimes' : 'required';

        return [
            'name' => "$required|string|min:2|max:255",
            'contact_label' => 'nullable|string|max:80',
            'display_order' => 'sometimes|integer|min:0|max:100000',
            'category' => [$required, Rule::in([
                'Disaster / MDRRMO', 'Disaster Risk', 'Police', 'Fire', 'Fire & Rescue',
                'Hospital', 'Medical', 'Medical / Hospital', 'Municipal Health',
                'Ambulance / Rescue', 'Rescue', 'Coast Guard / Port Emergency',
                'Coast Guard / Maritime Emergency', 'LGU Emergency',
                'National Emergency Hotline', 'Government', 'Red Cross', 'Other',
            ])],
            'phone' => "$required|string|max:50|regex:/^[0-9+()\-\s]+$/",
            'alternative_phone' => 'nullable|string|max:50|regex:/^[0-9+()\-\s]+$/',
            'address' => 'nullable|string|max:1000',
            'barangay' => 'nullable|string|max:255',
            'description' => 'nullable|string|max:2000',
            'operating_hours' => 'nullable|string|max:255',
            'availability_notes' => 'nullable|string|max:1000',
            'emergency_instructions' => 'nullable|string|max:2000',
            'classification' => 'sometimes|in:emergency,non_emergency',
            'is_active' => 'sometimes|boolean',
            'is_public' => 'sometimes|boolean',
            'source' => 'nullable|string|max:255',
            'source_name' => 'nullable|string|max:255',
            'source_url' => 'nullable|url|max:2000',
            'notes' => 'nullable|string|max:2000',
            'latitude' => 'nullable|numeric|between:-90,90',
            'longitude' => 'nullable|numeric|between:-180,180',
            'expected_updated_at' => 'sometimes|required|date',
        ];
    }

    /** @param array<string, mixed> $data */
    private function assertNoDuplicate(array $data, ?EmergencyContact $current = null): void
    {
        $name = trim((string) ($data['name'] ?? $current?->name ?? ''));
        $phone = trim((string) ($data['phone'] ?? $current?->phone ?? ''));
        $label = trim((string) ($data['contact_label'] ?? $current?->contact_label ?? ''));
        if ($name === '' || $phone === '') {
            return;
        }

        $query = EmergencyContact::query()
            ->when($current, fn ($builder) => $builder->whereKeyNot($current->id))
            ->whereRaw('LOWER(name) = ?', [Str::lower($name)])
            ->where('phone', $phone);
        $label === ''
            ? $query->where(fn ($builder) => $builder->whereNull('contact_label')->orWhere('contact_label', ''))
            : $query->whereRaw('LOWER(contact_label) = ?', [Str::lower($label)]);

        abort_if($query->exists(), 422, 'An emergency contact with this agency, label, and phone number already exists.');
    }

    private function audit(
        EmergencyContact $contact,
        string $action,
        ?array $oldValue,
        ?array $newValue,
        string $actorId,
    ): void {
        EmergencyContactAudit::create([
            'contact_id' => $contact->id,
            'action' => $action,
            'old_value' => $oldValue,
            'new_value' => $newValue,
            'updated_by' => $actorId,
        ]);
    }
}
