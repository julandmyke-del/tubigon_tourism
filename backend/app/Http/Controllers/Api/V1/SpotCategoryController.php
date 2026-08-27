<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\SpotCategory;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class SpotCategoryController extends Controller
{
    public function index(): JsonResponse
    {
        $categories = SpotCategory::orderBy('name')->get();
        return response()->json(['status' => 'success', 'data' => $categories]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255|unique:spot_categories,name',
        ]);
        $validated['slug'] = Str::slug($validated['name']);

        $category = SpotCategory::create($validated);
        return response()->json(['status' => 'success', 'data' => $category], 201);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $category = SpotCategory::findOrFail($id);
        $validated = $request->validate([
            'name' => 'sometimes|string|max:255|unique:spot_categories,name,' . $id,
        ]);
        if (isset($validated['name'])) {
            $validated['slug'] = Str::slug($validated['name']);
        }
        $category->update($validated);
        return response()->json(['status' => 'success', 'data' => $category]);
    }

    public function destroy(string $id): JsonResponse
    {
        SpotCategory::findOrFail($id)->delete();
        return response()->json(['status' => 'success', 'message' => 'Category deleted']);
    }
}
