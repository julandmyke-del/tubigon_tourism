<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\ValidatesTubigonCoordinates;
use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\MapLocation;
use App\Models\MapLocationCategory;
use App\Models\Msme;
use App\Models\TouristSpot;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class MapLocationController extends Controller
{
    use ValidatesTubigonCoordinates;

    public function show(string $id): JsonResponse
    {
        $location = MapLocation::with(['category', 'subcategory'])
            ->where('published', true)
            ->where('verified', true)
            ->where('active', true)
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->findOrFail($id);
        MapLocation::whereKey($id)->increment('view_count');

        return response()->json(['status' => 'success', 'data' => $location->toPlaceArray()]);
    }

    public function managementIndex(Request $request): JsonResponse
    {
        $query = MapLocation::with(['category', 'subcategory', 'verifier:id,name']);
        if ($request->boolean('archived')) {
            $query->onlyTrashed();
        }
        if ($request->filled('category_id')) {
            $query->where('category_id', $request->string('category_id'));
        }
        if ($request->filled('status')) {
            match ($request->string('status')->toString()) {
                'published' => $query->where('published', true),
                'draft' => $query->where('published', false),
                'verified' => $query->where('verified', true),
                'needs_verification' => $query->where('verified', false),
                'inactive' => $query->where('active', false),
                default => null,
            };
        }
        if ($request->filled('search')) {
            $term = '%'.str_replace(['%', '_'], ['\\%', '\\_'], trim((string) $request->string('search'))).'%';
            $query->where(function ($inner) use ($term) {
                $inner->where('name', 'like', $term)
                    ->orWhere('description', 'like', $term)
                    ->orWhere('address', 'like', $term);
            });
        }

        return response()->json([
            'status' => 'success',
            'data' => $query->latest()->get(),
        ]);
    }

    public function duplicates(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'latitude' => 'nullable|numeric|between:-90,90|required_with:longitude',
            'longitude' => 'nullable|numeric|between:-180,180|required_with:latitude',
            'entity_type' => ['nullable', Rule::in(['tourist_spot', 'msme'])],
            'entity_id' => 'nullable|required_with:entity_type|uuid',
            'exclude_id' => 'nullable|uuid',
        ]);

        return response()->json([
            'status' => 'success',
            'data' => $this->findDuplicates($data, $data['exclude_id'] ?? null),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validated($request);
        $duplicates = $this->findDuplicates($data);
        if ($duplicates && ! $request->boolean('duplicate_override')) {
            return response()->json([
                'status' => 'possible_duplicate',
                'message' => 'Possible existing location found.',
                'data' => $duplicates,
            ], 409);
        }

        $location = DB::transaction(function () use ($request, $data) {
            $data['slug'] = Str::slug($data['name']).'-'.Str::lower(Str::random(6));
            $data['created_by'] = $request->user()->id;
            $data['updated_by'] = $request->user()->id;
            $data['verified'] = false;
            $data['published'] = false;
            $location = MapLocation::create($data);
            $this->audit($request, 'Location created', ['location_id' => $location->id, 'new' => $location->toArray()]);

            return $location;
        });

        return response()->json(['status' => 'success', 'data' => $location->load(['category', 'subcategory'])], 201);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $location = MapLocation::findOrFail($id);
        $data = $this->validated($request, $location);
        $duplicates = $this->findDuplicates(array_merge($location->toArray(), $data), $location->id);
        if ($duplicates && ! $request->boolean('duplicate_override')) {
            return response()->json([
                'status' => 'possible_duplicate',
                'message' => 'Possible existing location found.',
                'data' => $duplicates,
            ], 409);
        }

        $before = $location->toArray();
        $trustFields = ['name', 'category_id', 'subcategory_id', 'entity_type', 'entity_id', 'latitude', 'longitude'];
        $trustChanged = collect($trustFields)->contains(
            fn (string $field) => array_key_exists($field, $data)
                && (string) ($data[$field] ?? '') !== (string) ($location->{$field} ?? '')
        );
        if ($trustChanged) {
            $data = array_merge($data, [
                'verified' => false,
                'published' => false,
                'verified_by' => null,
                'verified_at' => null,
            ]);
        }
        $data['updated_by'] = $request->user()->id;

        DB::transaction(function () use ($request, $location, $data, $before, $trustChanged) {
            $location->update($data);
            $action = $trustChanged && (isset($data['latitude']) || isset($data['longitude']))
                ? 'Location moved'
                : 'Location updated';
            $this->audit($request, $action, [
                'location_id' => $location->id,
                'before' => $before,
                'after' => $location->fresh()->toArray(),
            ]);
        });

        return response()->json(['status' => 'success', 'data' => $location->fresh()->load(['category', 'subcategory', 'verifier:id,name'])]);
    }

    public function verify(Request $request, string $id): JsonResponse
    {
        $location = MapLocation::with('category')->findOrFail($id);
        $verified = $request->has('verified') ? $request->boolean('verified') : true;
        if ($verified) {
            $this->assertPublishable($location, false);
        }
        DB::transaction(function () use ($request, $location, $verified, $id): void {
            $location->update([
                'verified' => $verified,
                'verified_by' => $verified ? $request->user()->id : null,
                'verified_at' => $verified ? now() : null,
                'published' => $verified ? $location->published : false,
                'updated_by' => $request->user()->id,
            ]);
            $this->audit($request, $verified ? 'Location verified' : 'Location verification removed', ['location_id' => $id]);
        });

        return response()->json(['status' => 'success', 'data' => $location->fresh()->load('verifier:id,name')]);
    }

    public function publish(Request $request, string $id): JsonResponse
    {
        $request->validate(['published' => 'required|boolean']);
        $location = MapLocation::with('category')->findOrFail($id);
        if ($request->boolean('published')) {
            $this->assertPublishable($location, true);
        }
        DB::transaction(function () use ($request, $location, $id): void {
            $location->update(['published' => $request->boolean('published'), 'updated_by' => $request->user()->id]);
            $this->audit($request, $location->published ? 'Location published' : 'Location unpublished', ['location_id' => $id]);
        });

        return response()->json(['status' => 'success', 'data' => $location->fresh()]);
    }

    public function setStatus(Request $request, string $id): JsonResponse
    {
        $request->validate(['active' => 'required|boolean']);
        $location = MapLocation::findOrFail($id);
        $active = $request->boolean('active');
        DB::transaction(function () use ($request, $location, $active, $id): void {
            $location->update([
                'active' => $active,
                'published' => $active ? $location->published : false,
                'updated_by' => $request->user()->id,
            ]);
            $this->audit($request, $active ? 'Location activated' : 'Location deactivated', ['location_id' => $id]);
        });

        return response()->json(['status' => 'success', 'data' => $location->fresh()]);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        $location = MapLocation::findOrFail($id);
        DB::transaction(function () use ($request, $location, $id): void {
            $location->update(['published' => false, 'active' => false, 'updated_by' => $request->user()->id]);
            $location->delete();
            $this->audit($request, 'Location archived', ['location_id' => $id, 'name' => $location->name]);
        });

        return response()->json(['status' => 'success', 'message' => 'Location archived. No record was permanently deleted.']);
    }

    private function validated(Request $request, ?MapLocation $location = null): array
    {
        $required = $location ? 'sometimes' : 'required';
        $data = $request->validate([
            'name' => [$required, 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:2000'],
            'category_id' => [$required, 'uuid', Rule::exists('map_location_categories', 'id')->where(fn ($q) => $q->where('active', true)->whereNull('deleted_at'))],
            'subcategory_id' => ['nullable', 'uuid', Rule::exists('map_location_categories', 'id')->where(fn ($q) => $q->where('active', true)->whereNull('deleted_at'))],
            'entity_type' => ['nullable', Rule::in(['tourist_spot', 'msme'])],
            'entity_id' => ['nullable', 'required_with:entity_type', 'uuid'],
            'address' => ['nullable', 'string', 'max:1000'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90', 'required_with:longitude'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180', 'required_with:latitude'],
            'marker_icon' => ['nullable', 'regex:/^[a-z0-9_\-]+$/', 'max:64'],
            'image_url' => ['nullable', 'url:http,https', 'max:2048'],
            'is_featured' => ['sometimes', 'boolean'],
            'active' => ['sometimes', 'boolean'],
            'duplicate_override' => ['sometimes', 'boolean'],
        ]);
        unset($data['duplicate_override']);

        foreach (['name', 'description', 'address', 'marker_icon'] as $field) {
            if (array_key_exists($field, $data) && is_string($data[$field])) {
                $data[$field] = trim(strip_tags($data[$field]));
            }
        }
        if (array_key_exists('entity_type', $data) xor array_key_exists('entity_id', $data)) {
            if (($data['entity_type'] ?? $location?->entity_type) || ($data['entity_id'] ?? $location?->entity_id)) {
                throw ValidationException::withMessages(['entity_id' => ['Entity type and entity ID must be supplied together.']]);
            }
        }
        $entityType = $data['entity_type'] ?? $location?->entity_type;
        $entityId = $data['entity_id'] ?? $location?->entity_id;
        $this->assertEntityExists($entityType, $entityId);
        $this->validateTubigonCoordinates(
            $data,
            $location?->latitude,
            $location?->longitude,
        );
        $subcategoryId = $data['subcategory_id'] ?? null;
        if ($subcategoryId) {
            $categoryId = $data['category_id'] ?? $location?->category_id;
            $validChild = MapLocationCategory::whereKey($subcategoryId)
                ->where('parent_id', $categoryId)
                ->where('active', true)
                ->exists();
            if (! $validChild) {
                throw ValidationException::withMessages(['subcategory_id' => ['The subcategory must belong to the selected category.']]);
            }
        }

        return $data;
    }

    private function assertEntityExists(?string $type, ?string $id): void
    {
        if (! $type && ! $id) {
            return;
        }
        $exists = match ($type) {
            'tourist_spot' => TouristSpot::whereKey($id)->exists(),
            'msme' => Msme::whereKey($id)->exists(),
            default => false,
        };
        if (! $exists) {
            throw ValidationException::withMessages(['entity_id' => ['The selected linked entity does not exist or is archived.']]);
        }
    }

    private function assertPublishable(MapLocation $location, bool $requireVerified): void
    {
        $errors = [];
        if ($location->latitude === null || $location->longitude === null) {
            $errors['latitude'][] = 'Place the exact map pin before verification or publication.';
        }
        if (! $location->active) {
            $errors['active'][] = 'Activate the location before publication.';
        }
        if (! $location->category?->active) {
            $errors['category_id'][] = 'Choose an active category before publication.';
        }
        if ($location->subcategory_id && ! $location->subcategory?->active) {
            $errors['subcategory_id'][] = 'Choose an active subcategory before publication.';
        }
        if ($requireVerified && ! $location->verified) {
            $errors['verified'][] = 'Verify the location before publication.';
        }
        if ($location->entity_type && ! $location->linkedEntity()) {
            $errors['entity_id'][] = 'The linked entity is no longer available.';
        }
        if ($location->entity_type === 'msme' &&
            ! Msme::whereKey($location->entity_id)->where('is_verified', true)->exists()) {
            $errors['entity_id'][] = 'Verify the linked MSME before publishing this map location.';
        }
        if ($location->entity_type === 'tourist_spot' &&
            ! TouristSpot::whereKey($location->entity_id)->where('is_active', true)->exists()) {
            $errors['entity_id'][] = 'Activate the linked Tourist Spot before publishing this map location.';
        }
        if ($errors) {
            throw ValidationException::withMessages($errors);
        }
    }

    private function findDuplicates(array $data, ?string $excludeId = null): array
    {
        $name = $this->normalizeName((string) ($data['name'] ?? ''));
        $latitude = isset($data['latitude']) ? (float) $data['latitude'] : null;
        $longitude = isset($data['longitude']) ? (float) $data['longitude'] : null;
        $entityType = $data['entity_type'] ?? null;
        $entityId = $data['entity_id'] ?? null;
        $matches = [];

        $sources = [
            ['map_locations', 'map_location'],
            ['tourist_spots', 'tourist_spot'],
            ['msmes', 'msme'],
            ['establishments', 'establishment'],
        ];
        foreach ($sources as [$table, $type]) {
            if (! Schema::hasTable($table)) {
                continue;
            }
            $query = DB::table($table)->whereNull('deleted_at')->select(['id', 'name', 'latitude', 'longitude']);
            if ($type === 'map_location' && $excludeId) {
                $query->where('id', '<>', $excludeId);
            }
            foreach ($query->limit(1000)->get() as $candidate) {
                if ($type === $entityType && (string) $candidate->id === (string) $entityId) {
                    continue;
                }
                $candidateName = $this->normalizeName((string) $candidate->name);
                similar_text($name, $candidateName, $similarity);
                $distance = null;
                if ($latitude !== null && $longitude !== null && $candidate->latitude !== null && $candidate->longitude !== null) {
                    $distance = $this->distanceMeters($latitude, $longitude, (float) $candidate->latitude, (float) $candidate->longitude);
                }
                if ($candidateName === $name || $similarity >= 82 || ($distance !== null && $distance <= 100)) {
                    $matches[] = [
                        'source_type' => $type,
                        'source_id' => (string) $candidate->id,
                        'name' => $candidate->name,
                        'name_similarity' => round($similarity, 1),
                        'distance_meters' => $distance === null ? null : round($distance),
                    ];
                }
            }
        }

        return collect($matches)->sortByDesc('name_similarity')->values()->take(10)->all();
    }

    private function normalizeName(string $name): string
    {
        return (string) Str::of($name)->lower()->ascii()->replaceMatches('/[^a-z0-9]+/', '')->trim();
    }

    private function distanceMeters(float $latA, float $lngA, float $latB, float $lngB): float
    {
        $earth = 6371000;
        $latDelta = deg2rad($latB - $latA);
        $lngDelta = deg2rad($lngB - $lngA);
        $a = sin($latDelta / 2) ** 2
            + cos(deg2rad($latA)) * cos(deg2rad($latB)) * sin($lngDelta / 2) ** 2;

        return $earth * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }

    private function audit(Request $request, string $action, array $details): void
    {
        if (Schema::hasTable('activity_logs')) {
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => $action,
                'details' => json_encode($details, JSON_UNESCAPED_SLASHES),
            ]);
        }
    }
}
