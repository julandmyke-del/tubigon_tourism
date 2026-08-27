<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\MapLocation;
use App\Models\MapLocationCategory;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class MapLocationCategoryController extends Controller
{
    public function index(): JsonResponse
    {
        if (! Schema::hasTable('map_location_categories')) {
            return response()->json(['status' => 'success', 'data' => []]);
        }

        $categories = MapLocationCategory::where('active', true)
            ->with('children')
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();

        return response()->json(['status' => 'success', 'data' => $categories]);
    }

    public function managementIndex(): JsonResponse
    {
        return response()->json([
            'status' => 'success',
            'data' => MapLocationCategory::withTrashed()
                ->withCount('children')
                ->orderBy('sort_order')
                ->orderBy('name')
                ->get(),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validated($request);
        $data['slug'] = $data['slug'] ?? Str::slug($data['name']);
        $category = MapLocationCategory::create($data);
        $this->audit($request, 'Map category created', $category->toArray());

        return response()->json(['status' => 'success', 'data' => $category], 201);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $category = MapLocationCategory::findOrFail($id);
        $before = $category->toArray();
        $category->update($this->validated($request, $category));
        $this->audit($request, 'Map category updated', ['before' => $before, 'after' => $category->fresh()->toArray()]);

        return response()->json(['status' => 'success', 'data' => $category->fresh()]);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        $category = MapLocationCategory::findOrFail($id);
        if (MapLocation::where('category_id', $id)->orWhere('subcategory_id', $id)->exists()) {
            return response()->json(['message' => 'This category is in use. Deactivate it instead.'], 422);
        }
        $category->delete();
        $this->audit($request, 'Map category archived', ['id' => $id, 'name' => $category->name]);

        return response()->json(['status' => 'success', 'message' => 'Map category archived.']);
    }

    private function validated(Request $request, ?MapLocationCategory $category = null): array
    {
        $id = $category?->id;
        $required = $category ? 'sometimes' : 'required';
        $data = $request->validate([
            'parent_id' => ['nullable', 'uuid', 'different:id', Rule::exists('map_location_categories', 'id')->whereNull('deleted_at')],
            'name' => [$required, 'string', 'max:80', Rule::unique('map_location_categories', 'name')->ignore($id)],
            'slug' => ['sometimes', 'required', 'alpha_dash', 'max:80', Rule::unique('map_location_categories', 'slug')->ignore($id)],
            'icon' => [$required, 'regex:/^[a-z0-9_\-]+$/', 'max:64'],
            'marker_color' => [$required, 'regex:/^#[0-9A-Fa-f]{6}$/'],
            'active' => ['sometimes', 'boolean'],
            'sort_order' => ['sometimes', 'integer', 'between:0,10000'],
        ]);
        foreach (['name', 'slug', 'icon'] as $field) {
            if (isset($data[$field])) {
                $data[$field] = trim(strip_tags($data[$field]));
            }
        }
        if (! empty($data['parent_id'])) {
            $parent = MapLocationCategory::find($data['parent_id']);
            if ($parent?->parent_id !== null) {
                throw ValidationException::withMessages([
                    'parent_id' => ['Subcategories can only belong to a top-level category.'],
                ]);
            }
            if ($category && $category->children()->exists()) {
                throw ValidationException::withMessages([
                    'parent_id' => ['A category with subcategories must remain top-level.'],
                ]);
            }
        }

        return $data;
    }

    private function audit(Request $request, string $action, array $details): void
    {
        if (Schema::hasTable('activity_logs')) {
            ActivityLog::create(['user_id' => $request->user()->id, 'action' => $action, 'details' => json_encode($details)]);
        }
    }
}
