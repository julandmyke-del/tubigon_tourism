<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\ValidatesTubigonCoordinates;
use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Notification;
use App\Models\SystemSetting;
use App\Models\User;
use App\Models\WasteCategory;
use App\Models\WasteReport;
use App\Models\WasteReportHistory;
use App\Models\WasteReportMedia;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Symfony\Component\HttpFoundation\StreamedResponse;

class WasteReportController extends Controller
{
    use ValidatesTubigonCoordinates;

    private const LEGACY_CATEGORIES = [
        'garbage', 'water_pollution', 'beach_coastal', 'environmental_damage',
        'road_infrastructure', 'public_facility', 'safety', 'tourism_site',
        'marine_wildlife', 'other', 'Plastic Waste', 'Coastal Pollution',
        'Illegal Dumping', 'Overflowing Bin', 'Hazardous Material', 'Other',
    ];

    public function categories(): JsonResponse
    {
        if (! Schema::hasTable('waste_categories')) {
            return response()->json(['status' => 'success', 'data' => collect(self::LEGACY_CATEGORIES)
                ->map(fn (string $name) => ['id' => $name, 'slug' => $name, 'name' => str_replace('_', ' ', $name)])
                ->values()]);
        }

        return response()->json([
            'status' => 'success',
            'data' => WasteCategory::where('is_active', true)->orderBy('sort_order')->orderBy('name')->get(),
            'meta' => ['cached_at' => now()->toIso8601String()],
        ]);
    }

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $user->loadMissing('role');
        $canManage = in_array($user->role?->name, ['admin', 'lgu_staff'], true);

        $with = ['user:id,name'];
        if (Schema::hasTable('waste_report_history')) $with[] = 'history.actor:id,name';
        if (Schema::hasTable('waste_report_media')) $with[] = 'media';
        if (Schema::hasTable('waste_categories')) $with[] = 'categoryDefinition';
        $query = WasteReport::with($with);
        if (! $canManage) {
            $query->where('user_id', $user->id);
        } else {
            $validated = $request->validate([
                'status' => ['nullable', Rule::in(['submitted', 'under_review', 'assigned', 'in_progress', 'resolved', 'rejected', 'reopened', 'closed'])],
                'severity' => ['nullable', Rule::in(['low', 'moderate', 'high', 'urgent'])],
                'category' => 'nullable|string|max:100',
                'barangay' => 'nullable|string|max:255',
                'assigned_to' => 'nullable|uuid',
                'from' => 'nullable|date',
                'to' => 'nullable|date|after_or_equal:from',
                'page' => 'nullable|integer|min:1',
                'per_page' => 'nullable|integer|min:1|max:100',
            ]);
            foreach (['status', 'severity', 'barangay', 'assigned_to'] as $field) {
                if (isset($validated[$field]) && Schema::hasColumn('waste_reports', $field)) $query->where($field, $validated[$field]);
            }
            if (isset($validated['category'])) {
                $category = $validated['category'];
                $query->where(function ($inner) use ($category): void {
                    $inner->where('category', $category);
                    if (Schema::hasTable('waste_categories') && Schema::hasColumn('waste_reports', 'category_id')) {
                        $inner->orWhereHas('categoryDefinition', fn ($definition) => $definition->where('slug', $category));
                    }
                });
            }
            if (isset($validated['from'])) $query->whereDate('created_at', '>=', $validated['from']);
            if (isset($validated['to'])) $query->whereDate('created_at', '<=', $validated['to']);
        }

        if ($canManage && ($request->has('page') || $request->has('per_page'))) {
            $paginator = $query->latest()->paginate((int) $request->input('per_page', 25));
            return response()->json([
                'status' => 'success',
                'data' => collect($paginator->items())->map(fn (WasteReport $report) => $this->payload($report, true))->values(),
                'meta' => [
                    'current_page' => $paginator->currentPage(), 'last_page' => $paginator->lastPage(),
                    'per_page' => $paginator->perPage(), 'total' => $paginator->total(),
                ],
            ]);
        }

        return response()->json([
            'status' => 'success',
            'data' => $query->latest()->get()->map(fn (WasteReport $report) => $this->payload($report, $canManage))->values(),
            'meta' => ['cached_at' => now()->toIso8601String()],
        ]);
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $user = $request->user();
        $user->loadMissing('role');
        $canManage = in_array($user->role?->name, ['admin', 'lgu_staff'], true);
        $with = ['user:id,name'];
        if (Schema::hasTable('waste_report_history')) $with[] = 'history.actor:id,name';
        if (Schema::hasTable('waste_report_media')) $with[] = 'media';
        if (Schema::hasTable('waste_categories')) $with[] = 'categoryDefinition';
        $query = WasteReport::with($with);
        if (! $canManage) $query->where('user_id', $user->id);
        return response()->json(['status' => 'success', 'data' => $this->payload($query->findOrFail($id), $canManage)]);
    }

    public function store(Request $request): JsonResponse
    {
        abort_unless(SystemSetting::enabled('waste_reporting_enabled'), 403, 'Waste reporting is currently disabled.');
        $validated = $request->validate([
            'category_id' => ['nullable', 'uuid', Rule::exists('waste_categories', 'id')->where('is_active', true)],
            'category_slug' => 'nullable|string|max:80',
            'category' => ['nullable', 'string', Rule::in(self::LEGACY_CATEGORIES)],
            'severity' => ['nullable', Rule::in(['low', 'moderate', 'high', 'urgent'])],
            'description' => 'required|string|min:10|max:2000',
            'location_description' => 'nullable|string|max:500',
            'resolved_address' => 'nullable|string|max:1000',
            'geocoding_source' => 'nullable|string|max:255',
            'barangay' => 'nullable|string|max:255',
            'latitude' => 'required|numeric|between:-90,90',
            'longitude' => 'required|numeric|between:-180,180',
            'client_submission_id' => 'nullable|uuid',
            'photos' => 'nullable|array|max:3',
            'photos.*' => 'file|mimetypes:image/jpeg,image/png,image/webp|mimes:jpeg,jpg,png,webp|max:5120',
            'images' => 'nullable|array|max:3',
            'images.*' => 'file|mimetypes:image/jpeg,image/png,image/webp|mimes:jpeg,jpg,png,webp|max:5120',
            'video' => 'nullable|file|mimetypes:video/mp4,video/quicktime,video/webm|mimes:mp4,mov,webm|max:25600',
        ]);
        $this->validateTubigonCoordinates($validated);
        $category = $this->resolveCategory($validated);
        abort_if($category === null && blank($validated['category'] ?? null), 422, 'Choose an active waste category.');

        if (Schema::hasColumn('waste_reports', 'client_submission_id') && ! empty($validated['client_submission_id'])) {
            $existing = WasteReport::where('user_id', $request->user()->id)
                ->where('client_submission_id', $validated['client_submission_id'])->first();
            if ($existing) {
                return response()->json([
                    'status' => 'success', 'data' => $this->payload($existing->load($this->availableRelations()), false),
                    'meta' => ['idempotent_replay' => true],
                ]);
            }
        }

        $photos = array_merge($request->file('photos', []), $request->file('images', []));
        abort_if(count($photos) > 3, 422, 'A waste report may contain at most three photos.');
        $video = $request->file('video');

        $attributes = [
            'user_id' => $request->user()->id,
            'category' => $category?->slug ?? $validated['category'],
            'description' => $validated['description'],
            'location_description' => $validated['location_description'] ?? null,
            'barangay' => $validated['barangay'] ?? null,
            'latitude' => $validated['latitude'],
            'longitude' => $validated['longitude'],
            'status' => 'submitted',
            'priority' => ($validated['severity'] ?? 'moderate') === 'moderate' ? 'normal' : ($validated['severity'] ?? 'moderate'),
        ];
        foreach ([
            'category_id' => $category?->id,
            'severity' => $validated['severity'] ?? 'moderate',
            'resolved_address' => $validated['resolved_address'] ?? null,
            'geocoding_source' => $validated['geocoding_source'] ?? null,
            'client_submission_id' => $validated['client_submission_id'] ?? null,
            'submitted_at' => now(),
        ] as $column => $value) {
            if (Schema::hasColumn('waste_reports', $column)) $attributes[$column] = $value;
        }

        $report = DB::transaction(function () use ($request, $attributes, $photos, $video): WasteReport {
            $report = WasteReport::create($attributes);
            if (Schema::hasTable('waste_report_media')) {
                foreach ($photos as $photo) $this->storeMedia($report, $photo, 'photo', $request->user()->id);
                if ($video) $this->storeMedia($report, $video, 'video', $request->user()->id);
            } elseif ($photos !== []) {
                $urls = [];
                foreach ($photos as $photo) {
                    $path = $photo->store("waste-reports/{$report->id}", 'public');
                    $urls[] = asset("storage/$path");
                }
                $report->update(['images' => $urls]);
            }
            if (Schema::hasTable('waste_report_history')) {
                $history = [
                    'waste_report_id' => $report->id, 'changed_by' => $request->user()->id,
                    'to_status' => 'submitted', 'notes' => 'Report submitted by Tourist.',
                ];
                if (Schema::hasColumn('waste_report_history', 'is_public')) $history['is_public'] = true;
                WasteReportHistory::create($history);
            }
            ActivityLog::create([
                'user_id' => $request->user()->id, 'action' => 'Waste report submitted',
                'details' => json_encode(['entity_type' => 'waste_report', 'entity_id' => $report->id]),
            ]);
            User::whereHas('role', fn ($query) => $query->whereIn('name', ['admin', 'lgu_staff']))
                ->pluck('id')->each(fn (string $id) => Notification::create([
                    'user_id' => $id, 'type' => 'waste_report_submitted', 'title' => 'New Waste Report',
                    'body' => 'A new waste report is awaiting review.',
                    'data' => ['waste_report_id' => $report->id, 'route' => '/lgu/waste-reports/'.$report->id],
                ]));
            return $report;
        });

        return response()->json([
            'status' => 'success',
            'data' => $this->payload($report->fresh($this->availableRelations()), false),
        ], 201);
    }

    public function updateStatus(Request $request, string $id): JsonResponse
    {
        return (new LguController())->updateWasteStatus($request, $id);
    }

    public function uploadImages(Request $request, string $id): JsonResponse
    {
        $request->merge(['legacy_images_upload' => true]);
        return $this->uploadMedia($request, $id);
    }

    public function uploadMedia(Request $request, string $id): JsonResponse
    {
        $request->validate([
            'photos' => 'nullable|array|max:3',
            'photos.*' => 'file|mimetypes:image/jpeg,image/png,image/webp|mimes:jpeg,jpg,png,webp|max:5120',
            'images' => 'nullable|array|max:3',
            'images.*' => 'file|mimetypes:image/jpeg,image/png,image/webp|mimes:jpeg,jpg,png,webp|max:5120',
            'video' => 'nullable|file|mimetypes:video/mp4,video/quicktime,video/webm|mimes:mp4,mov,webm|max:25600',
        ]);
        $report = WasteReport::findOrFail($id);
        $this->authorizeParticipant($request, $report);
        $photos = array_merge($request->file('photos', []), $request->file('images', []));
        abort_if($photos === [] && ! $request->hasFile('video'), 422, 'Attach at least one valid photo or video.');

        if (! Schema::hasTable('waste_report_media')) {
            $urls = $report->images ?? [];
            abort_if(count($urls) + count($photos) > 5, 422, 'A waste report may contain at most five legacy images.');
            foreach ($photos as $photo) {
                $path = $photo->store("waste-reports/$id", 'public');
                $urls[] = asset("storage/$path");
            }
            $report->update(['images' => array_values(array_unique($urls))]);
            return response()->json(['status' => 'success', 'data' => $report->fresh()]);
        }

        $existingPhotos = $report->media()->where('media_type', 'photo')->count();
        $existingVideos = $report->media()->where('media_type', 'video')->count();
        abort_if($existingPhotos + count($photos) > 3, 422, 'A waste report may contain at most three photos.');
        abort_if($existingVideos + ($request->hasFile('video') ? 1 : 0) > 1, 422, 'A waste report may contain at most one video.');
        foreach ($photos as $photo) $this->storeMedia($report, $photo, 'photo', $request->user()->id);
        if ($request->hasFile('video')) $this->storeMedia($report, $request->file('video'), 'video', $request->user()->id);
        return response()->json([
            'status' => 'success', 'data' => $this->payload($report->fresh($this->availableRelations()), $this->canManage($request)),
        ]);
    }

    public function uploadResolutionMedia(Request $request, string $id): JsonResponse
    {
        abort_unless($this->canManage($request), 403, 'Only LGU staff or Admin may upload resolution evidence.');
        $validated = $request->validate([
            'photo' => 'required|file|mimetypes:image/jpeg,image/png,image/webp|mimes:jpeg,jpg,png,webp|max:5120',
        ]);
        $report = WasteReport::findOrFail($id);
        abort_unless(Schema::hasTable('waste_report_media'), 409, 'Authorized report media storage is not installed yet.');
        abort_if($report->media()->where('media_type', 'resolution_photo')->count() >= 3, 422, 'At most three resolution photos are allowed.');
        $this->storeMedia($report, $validated['photo'], 'resolution_photo', $request->user()->id);
        return response()->json(['status' => 'success', 'data' => $this->payload($report->fresh($this->availableRelations()), true)]);
    }

    public function showMedia(Request $request, WasteReportMedia $media): StreamedResponse
    {
        $this->authorizeParticipant($request, $media->report);
        abort_unless(Storage::disk($media->disk)->exists($media->storage_path), 404, 'Waste report media is unavailable.');
        return Storage::disk($media->disk)->response(
            $media->storage_path,
            $media->original_name,
            ['Content-Type' => $media->mime_type, 'Cache-Control' => 'private, no-store'],
        );
    }

    private function resolveCategory(array $validated): ?WasteCategory
    {
        if (! Schema::hasTable('waste_categories')) return null;
        if (! empty($validated['category_id'])) return WasteCategory::where('is_active', true)->find($validated['category_id']);
        $slug = $validated['category_slug'] ?? $validated['category'] ?? null;
        if ($slug === null) return null;
        $aliases = [
            'Illegal Dumping' => 'illegal-dumping', 'Overflowing Bin' => 'overflowing-bin',
            'Plastic Waste' => 'plastic-waste', 'Coastal Pollution' => 'coastal-marine-waste',
            'Hazardous Material' => 'hazardous-looking-waste', 'Other' => 'other', 'garbage' => 'uncollected-garbage',
        ];
        return WasteCategory::where('is_active', true)->where('slug', $aliases[$slug] ?? $slug)->first();
    }

    private function storeMedia(WasteReport $report, $file, string $type, string $uploader): WasteReportMedia
    {
        $path = $file->store("waste-reports/{$report->id}", 'local');
        return WasteReportMedia::create([
            'waste_report_id' => $report->id, 'uploaded_by' => $uploader,
            'media_type' => $type, 'disk' => 'local', 'storage_path' => $path,
            'mime_type' => $file->getMimeType() ?: $file->getClientMimeType(),
            'size_bytes' => $file->getSize(), 'original_name' => $file->getClientOriginalName(),
            'visibility' => 'participants',
        ]);
    }

    private function canManage(Request $request): bool
    {
        $request->user()->loadMissing('role');
        return in_array($request->user()->role?->name, ['admin', 'lgu_staff'], true);
    }

    private function authorizeParticipant(Request $request, WasteReport $report): void
    {
        abort_unless($this->canManage($request) || (string) $report->user_id === (string) $request->user()->id, 403, 'You may only access media for your own waste reports.');
    }

    private function availableRelations(): array
    {
        $with = [];
        if (Schema::hasTable('waste_report_history')) $with[] = 'history.actor:id,name';
        if (Schema::hasTable('waste_report_media')) $with[] = 'media';
        if (Schema::hasTable('waste_categories')) $with[] = 'categoryDefinition';
        return $with;
    }

    private function payload(WasteReport $report, bool $manager): array
    {
        $data = $report->toArray();
        if (! $manager) {
            unset($data['lgu_notes'], $data['resolution_evidence']);
            if (isset($data['history']) && is_array($data['history'])) {
                $data['history'] = array_values(array_map(function (array $row): array {
                    if (isset($row['metadata']) && is_array($row['metadata'])) unset($row['metadata']['internal_note']);
                    return $row;
                }, array_filter($data['history'], fn ($row) => ! Schema::hasColumn('waste_report_history', 'is_public') || ($row['is_public'] ?? false))));
            }
            if (isset($data['user'])) $data['user'] = ['id' => $report->user_id, 'name' => 'You'];
        }
        $data['report_reference'] = 'WR-'.strtoupper(substr((string) $report->id, 0, 8));
        return $data;
    }
}
