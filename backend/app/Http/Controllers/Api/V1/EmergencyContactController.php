<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\ValidatesTubigonCoordinates;
use App\Http\Controllers\Controller;
use App\Models\EmergencyContact;
use App\Models\EmergencyContactAudit;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;

class EmergencyContactController extends Controller
{
    use ValidatesTubigonCoordinates;

    private const VERIFICATION_SENSITIVE_FIELDS = [
        'name',
        'category',
        'phone',
        'alternative_phone',
        'address',
        'latitude',
        'longitude',
        'description',
        'operating_hours',
    ];

    public function index(): JsonResponse
    {
        $contacts = EmergencyContact::with(['updater:id,name', 'verifier:id,name'])
            ->where('is_active', true)
            ->where('is_verified', true)
            ->orderBy('category')
            ->orderBy('name')
            ->get();

        return response()
            ->json(['status' => 'success', 'data' => $contacts])
            ->header('Cache-Control', 'no-store, max-age=0');
    }

    public function managementIndex(): JsonResponse
    {
        $contacts = EmergencyContact::with(['updater:id,name', 'verifier:id,name'])
            ->orderByDesc('is_active')
            ->orderBy('category')
            ->orderBy('name')
            ->get();

        return response()->json(['status' => 'success', 'data' => $contacts]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate($this->rules());
        $this->validateTubigonCoordinates($validated);
        $validated['updated_by'] = $request->user()->id;
        $validated['is_verified'] = false;

        $contact = DB::transaction(function () use ($validated, $request) {
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
        $contact = EmergencyContact::findOrFail($id);
        $validated = $request->validate($this->rules(true));
        $this->validateTubigonCoordinates(
            $validated,
            $contact->latitude !== null ? (float) $contact->latitude : null,
            $contact->longitude !== null ? (float) $contact->longitude : null,
        );

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
        }

        DB::transaction(function () use ($contact, $validated, $old, $request) {
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
        });

        return response()->json([
            'status' => 'success',
            'data' => $contact->fresh(['updater:id,name', 'verifier:id,name']),
        ]);
    }

    public function setStatus(Request $request, string $id): JsonResponse
    {
        $validated = $request->validate(['is_active' => 'required|boolean']);
        $contact = EmergencyContact::findOrFail($id);
        $old = ['is_active' => $contact->is_active];

        DB::transaction(function () use ($contact, $validated, $request, $old) {
            $contact->update([
                'is_active' => $validated['is_active'],
                'updated_by' => $request->user()->id,
            ]);
            $this->audit(
                $contact,
                $validated['is_active'] ? 'activated' : 'deactivated',
                $old,
                ['is_active' => $contact->is_active],
                $request->user()->id,
            );
        });

        return response()->json([
            'status' => 'success',
            'data' => $contact->fresh(['updater:id,name', 'verifier:id,name']),
        ]);
    }

    public function verify(Request $request, string $id): JsonResponse
    {
        $contact = EmergencyContact::findOrFail($id);
        $old = [
            'is_verified' => $contact->is_verified,
            'verified_by' => $contact->verified_by,
            'verified_at' => $contact->verified_at,
            'last_verified_at' => $contact->last_verified_at,
        ];
        $now = now();

        DB::transaction(function () use ($contact, $request, $old, $now) {
            $contact->update([
                'is_verified' => true,
                'verified_by' => $request->user()->id,
                'verified_at' => $contact->verified_at ?? $now,
                'last_verified_at' => $now,
                'updated_by' => $request->user()->id,
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
        });

        return response()->json([
            'status' => 'success',
            'data' => $contact->fresh(['updater:id,name', 'verifier:id,name']),
        ]);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        $contact = EmergencyContact::findOrFail($id);
        $wasActive = $contact->is_active;

        DB::transaction(function () use ($contact, $request, $wasActive) {
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
            'name' => "$required|string|max:255",
            'category' => "$required|string|max:100",
            'phone' => "$required|string|max:50|regex:/^[0-9+()\-\s]+$/",
            'alternative_phone' => 'nullable|string|max:50|regex:/^[0-9+()\-\s]+$/',
            'address' => 'nullable|string|max:1000',
            'description' => 'nullable|string|max:2000',
            'operating_hours' => 'nullable|string|max:255',
            'classification' => 'sometimes|in:emergency,non_emergency',
            'is_active' => 'sometimes|boolean',
            'source' => 'nullable|string|max:255',
            'source_url' => 'nullable|url|max:2000',
            'latitude' => 'nullable|numeric|between:-90,90',
            'longitude' => 'nullable|numeric|between:-180,180',
        ];
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
