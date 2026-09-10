<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\EcoTip;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\Rule;
use App\Models\ActivityLog;

class EcoTipController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = EcoTip::with('spot');
        if (Schema::hasColumn('eco_tips', 'is_active')) $query->where('is_active', true);
        if (Schema::hasColumn('eco_tips', 'is_published')) $query->where('is_published', true);
        if (Schema::hasColumn('eco_tips', 'starts_at')) {
            $query->where(fn ($q) => $q->whereNull('starts_at')->orWhere('starts_at', '<=', now()));
        }
        if (Schema::hasColumn('eco_tips', 'ends_at')) {
            $query->where(fn ($q) => $q->whereNull('ends_at')->orWhere('ends_at', '>=', now()));
        }
        if ($request->has('spot_id')) {
            $query->where('spot_id', $request->spot_id);
        }
        if (Schema::hasColumn('eco_tips', 'priority')) $query->orderByDesc('priority');
        $tips = $query->orderBy('title')->get();
        return response()->json(['status' => 'success', 'data' => $tips]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate($this->rules());
        if (Schema::hasColumn('eco_tips', 'created_by')) $validated['created_by'] = $request->user()->id;
        if (Schema::hasColumn('eco_tips', 'updated_by')) $validated['updated_by'] = $request->user()->id;
        $tip = DB::transaction(function () use ($validated, $request) {
            $tip = EcoTip::create($validated);
            ActivityLog::create(['user_id' => $request->user()->id, 'action' => 'Eco tip created', 'details' => json_encode(['entity_type' => 'eco_tip', 'entity_id' => $tip->id])]);
            return $tip;
        });
        return response()->json(['status' => 'success', 'data' => $tip->load('spot')], 201);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $tip = EcoTip::findOrFail($id);
        $validated = $request->validate($this->rules(true));
        if (Schema::hasColumn('eco_tips', 'updated_by')) $validated['updated_by'] = $request->user()->id;
        DB::transaction(function () use ($tip, $validated, $request): void {
            $tip->update($validated);
            ActivityLog::create(['user_id' => $request->user()->id, 'action' => 'Eco tip updated', 'details' => json_encode(['entity_type' => 'eco_tip', 'entity_id' => $tip->id])]);
        });
        return response()->json(['status' => 'success', 'data' => $tip->load('spot')]);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        $tip = EcoTip::findOrFail($id);
        DB::transaction(function () use ($tip, $request): void {
            $changes = [];
            if (Schema::hasColumn('eco_tips', 'is_active')) $changes['is_active'] = false;
            if (Schema::hasColumn('eco_tips', 'updated_by')) $changes['updated_by'] = $request->user()->id;
            if ($changes !== []) $tip->update($changes);
            $tip->delete();
            ActivityLog::create(['user_id' => $request->user()->id, 'action' => 'Eco tip archived', 'details' => json_encode(['entity_type' => 'eco_tip', 'entity_id' => $tip->id])]);
        });
        return response()->json(['status' => 'success', 'message' => 'Eco tip archived']);
    }

    public function managementIndex(): JsonResponse
    {
        $query = EcoTip::with('spot');
        if (Schema::hasColumn('eco_tips', 'priority')) $query->orderByDesc('priority');
        return response()->json(['status' => 'success', 'data' => $query->latest()->get()]);
    }

    private function rules(bool $updating = false): array
    {
        $required = $updating ? 'sometimes' : 'required';
        return [
            'title' => "$required|string|min:3|max:255",
            'short_message' => 'nullable|string|max:500',
            'content' => "$required|string|min:10|max:5000",
            'category' => ['nullable', Rule::in(['general', 'marine', 'waste', 'nature', 'wildlife', 'community', 'resources', 'transport'])],
            'spot_id' => 'nullable|exists:tourist_spots,id',
            'language' => ['nullable', Rule::in(['en', 'ceb'])],
            'is_active' => 'sometimes|boolean',
            'is_published' => 'sometimes|boolean',
            'starts_at' => 'nullable|date',
            'ends_at' => 'nullable|date|after_or_equal:starts_at',
            'priority' => 'nullable|integer|min:0|max:100',
        ];
    }
}
