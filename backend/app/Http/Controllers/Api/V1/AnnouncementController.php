<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\UpsertAnnouncementRequest;
use App\Models\ActivityLog;
use App\Models\Announcement;
use App\Services\AnnouncementDeliveryService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Throwable;

class AnnouncementController extends Controller
{
    private const AUDIENCES = ['everyone', 'tourist', 'msme_owner', 'tourism_partner', 'lgu_staff', 'admin'];

    private const PRIORITIES = ['normal', 'important', 'urgent'];

    private const STATUSES = ['draft', 'scheduled', 'published', 'archived'];

    private const TYPES = ['general', 'advisory', 'event', 'safety', 'service', 'system'];

    public function index(Request $request): JsonResponse
    {
        $request->user()->loadMissing('role');
        $role = $request->user()->role?->name ?? 'tourist';
        $announcements = Announcement::when(Schema::hasTable('announcement_audiences'), fn ($q) => $q->with('audiences'))->visibleTo($role)
            ->orderByRaw("CASE priority WHEN 'urgent' THEN 3 WHEN 'important' THEN 2 ELSE 1 END DESC")
            ->orderByDesc('starts_at')
            ->get();
        $reads = Schema::hasTable('announcement_reads')
            ? DB::table('announcement_reads')->where('user_id', $request->user()->id)->whereIn('announcement_id', $announcements->pluck('id'))->get()->keyBy('announcement_id')
            : collect();
        $announcements = $announcements->map(fn (Announcement $item) => $this->payload($item, $reads->get($item->id)));

        return response()->json(['status' => 'success', 'data' => $announcements]);
    }

    public function publicIndex(): JsonResponse
    {
        $items = Announcement::when(Schema::hasTable('announcement_audiences'), fn ($q) => $q->with('audiences'))->visibleTo('public')->orderByRaw("CASE priority WHEN 'urgent' THEN 3 WHEN 'important' THEN 2 ELSE 1 END DESC")->orderByDesc('starts_at')->get()->map(fn (Announcement $item) => $this->payload($item));

        return response()->json(['status' => 'success', 'data' => $items]);
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $request->user()->loadMissing('role');
        $role = $request->user()->role?->name ?? 'tourist';
        $announcement = Announcement::when(Schema::hasTable('announcement_audiences'), fn ($q) => $q->with('audiences'))->visibleTo($role)->findOrFail($id);

        $read = Schema::hasTable('announcement_reads') ? DB::table('announcement_reads')->where('announcement_id', $announcement->id)->where('user_id', $request->user()->id)->first() : null;

        return response()->json(['status' => 'success', 'data' => $this->payload($announcement, $read)]);
    }

    public function managementIndex(Request $request): JsonResponse
    {
        $query = Announcement::query()->orderByDesc('created_at');
        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }
        if ($request->filled('audience')) {
            $audience = $request->string('audience')->toString();
            $query->where(function ($q) use ($audience): void {
                $q->where('audience', $audience);
                if (Schema::hasTable('announcement_audiences')) {
                    $q->orWhereHas('audiences', fn ($a) => $a->where('role', $audience));
                }
            });
        }

        return response()->json([
            'status' => 'success',
            'data' => $query->when(Schema::hasTable('announcement_audiences'), fn ($q) => $q->with('audiences'))->get()->map(fn (Announcement $item) => $this->payload($item)),
        ]);
    }

    public function lguIndex(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['nullable', Rule::in(['active', 'scheduled', 'expired', 'archived'])],
            'priority' => ['nullable', Rule::in(self::PRIORITIES)],
            'type' => ['nullable', Rule::in(self::TYPES)],
            'search' => 'nullable|string|max:200',
        ]);
        $query = Announcement::with('creator:id,name')
            ->where(function ($audience): void {
                $audience->whereIn('audience', ['everyone', 'lgu_staff']);
                if (Schema::hasTable('announcement_audiences')) {
                    $audience->orWhereHas('audiences', fn ($q) => $q->whereIn('role', ['public', 'lgu_staff']));
                }
            })
            ->where('status', '!=', 'draft');
        if (! empty($validated['priority'])) {
            $query->where('priority', $validated['priority']);
        }
        if (! empty($validated['type'])) {
            $query->where('type', $validated['type']);
        }
        if (! empty($validated['search'])) {
            $query->where(function ($inner) use ($validated) {
                $inner->where('title', 'like', '%'.$validated['search'].'%')
                    ->orWhere('body', 'like', '%'.$validated['search'].'%');
            });
        }

        $items = $query->latest('created_at')->get()
            ->map(fn (Announcement $item) => [
                ...$this->payload($item),
                'publisher' => $item->creator?->name ?? 'Tubigon Administration',
            ])
            ->when(! empty($validated['status']), fn ($items) => $items->filter(function (array $item) use ($validated) {
                $status = $validated['status'] === 'active' ? 'published' : $validated['status'];

                return $item['effective_status'] === $status;
            })->values());

        return response()->json(['status' => 'success', 'data' => $items]);
    }

    public function store(UpsertAnnouncementRequest $request, AnnouncementDeliveryService $delivery): JsonResponse
    {
        $validated = $request->safe()->except(['audiences', 'image']);
        $validated = $this->normalizePublication($validated);
        $this->validateRelated($validated['related_type'] ?? null, $validated['related_id'] ?? null);
        $audiences = $request->validated('audiences');
        $validated['audience'] = count($audiences) === 1 ? ($audiences[0] === 'public' ? 'everyone' : $audiences[0]) : 'everyone';
        $imagePath = null;
        if ($request->hasFile('image')) {
            $imagePath = $request->file('image')->store('announcements', 'public');
            $validated['image_path'] = $imagePath;
        }
        $validated['created_by'] = $request->user()->id;
        $validated = $this->supportedColumns($validated);

        try {
            $announcement = DB::transaction(function () use ($request, $validated, $audiences): Announcement {
                $announcement = Announcement::create($validated);
                if (Schema::hasTable('announcement_audiences')) {
                    $announcement->audiences()->createMany(array_map(fn ($role) => ['role' => $role], $audiences));
                }
                $this->log($request, 'Announcement created', $announcement);

                return Schema::hasTable('announcement_audiences') ? $announcement->load('audiences') : $announcement;
            });
        } catch (Throwable $exception) {
            if ($imagePath) {
                Storage::disk('public')->delete($imagePath);
            }
            throw $exception;
        }
        // Per-user records are created lazily when each role checks its bell.

        return response()->json(['status' => 'success', 'data' => $this->payload($announcement)], 201);
    }

    public function update(UpsertAnnouncementRequest $request, string $id, AnnouncementDeliveryService $delivery): JsonResponse
    {
        $announcement = Announcement::findOrFail($id);
        $validated = $request->safe()->except(['audiences', 'image']);
        $audiences = $request->validated('audiences', null);
        if ($audiences !== null) {
            $validated['audience'] = count($audiences) === 1 ? ($audiences[0] === 'public' ? 'everyone' : $audiences[0]) : 'everyone';
        }
        $newImagePath = null;
        $oldImagePath = $announcement->image_path;
        if ($request->hasFile('image')) {
            $newImagePath = $request->file('image')->store('announcements', 'public');
            $validated['image_path'] = $newImagePath;
        }
        $validated = $this->normalizePublication($validated, $announcement);
        $relatedType = array_key_exists('related_type', $validated) ? $validated['related_type'] : $announcement->related_type;
        $relatedId = array_key_exists('related_id', $validated) ? $validated['related_id'] : $announcement->related_id;
        $this->validateRelated($relatedType, $relatedId);
        $validated = $this->supportedColumns($validated);

        try {
            DB::transaction(function () use ($request, $announcement, $validated, $audiences): void {
                $announcement->update($validated);
                if ($audiences !== null && Schema::hasTable('announcement_audiences')) {
                    $announcement->audiences()->delete();
                    $announcement->audiences()->createMany(array_map(fn ($role) => ['role' => $role], $audiences));
                }
                $this->log($request, 'Announcement updated', $announcement);
            });
        } catch (Throwable $exception) {
            if ($newImagePath) {
                Storage::disk('public')->delete($newImagePath);
            }
            throw $exception;
        }
        if ($newImagePath && $oldImagePath) {
            Storage::disk('public')->delete($oldImagePath);
        }
        $announcement->refresh();
        if (Schema::hasTable('announcement_audiences')) {
            $announcement->load('audiences');
        }
        // Remove stale audience/title copies. Eligible users receive the updated
        // authoritative record on their next feed request.
        $delivery->remove($announcement);

        return response()->json(['status' => 'success', 'data' => $this->payload($announcement)]);
    }

    public function markRead(Request $request, string $id): JsonResponse
    {
        $request->user()->loadMissing('role');
        $announcement = Announcement::visibleTo($request->user()->role?->name ?? 'tourist')->findOrFail($id);
        if (Schema::hasTable('announcement_reads')) {
            DB::table('announcement_reads')->updateOrInsert(['announcement_id' => $announcement->id, 'user_id' => $request->user()->id], ['read_at' => now()]);
        }

        return response()->json(['status' => 'success']);
    }

    public function dismiss(Request $request, string $id): JsonResponse
    {
        $request->user()->loadMissing('role');
        $announcement = Announcement::visibleTo($request->user()->role?->name ?? 'tourist')->findOrFail($id);
        if (Schema::hasTable('announcement_reads')) {
            $opened = DB::table('announcement_reads')
                ->where('announcement_id', $announcement->id)
                ->where('user_id', $request->user()->id)
                ->whereNotNull('read_at')
                ->exists();
            abort_if($announcement->priority === 'urgent' && ! $opened, 422, 'Open the urgent alert before dismissing it.');
            DB::table('announcement_reads')->updateOrInsert(['announcement_id' => $announcement->id, 'user_id' => $request->user()->id], ['read_at' => now(), 'dismissed_at' => now()]);
        }

        return response()->json(['status' => 'success']);
    }

    public function destroy(Request $request, string $id, AnnouncementDeliveryService $delivery): JsonResponse
    {
        $announcement = Announcement::findOrFail($id);
        DB::transaction(function () use ($request, $announcement): void {
            $announcement->update(['status' => 'archived', 'is_active' => false]);
            $this->log($request, 'Announcement archived', $announcement);
        });
        $delivery->remove($announcement);

        return response()->json(['status' => 'success', 'message' => 'Announcement archived']);
    }

    private function validated(Request $request, bool $partial = false): array
    {
        $presence = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'title' => [$presence, 'string', 'max:255'],
            'body' => [$presence, 'string', 'max:10000'],
            'category' => ['nullable', 'string', 'max:100'],
            'type' => [$presence, Rule::in(self::TYPES)],
            'audience' => [$presence, Rule::in(self::AUDIENCES)],
            'priority' => [$presence, Rule::in(self::PRIORITIES)],
            'status' => [$presence, Rule::in(self::STATUSES)],
            'starts_at' => ['nullable', 'date'],
            'expires_at' => ['nullable', 'date', 'after:starts_at'],
        ]);
    }

    private function normalizePublication(array $data, ?Announcement $current = null): array
    {
        $status = $data['status'] ?? $current?->status ?? 'draft';
        $startsAt = $data['starts_at'] ?? $current?->starts_at;
        $expiresAt = $data['expires_at'] ?? $current?->expires_at;
        if ($expiresAt && $startsAt && strtotime((string) $expiresAt) <= strtotime((string) $startsAt)) {
            throw ValidationException::withMessages(['expires_at' => ['Expiry must be after the start time.']]);
        }
        if ($status === 'scheduled' && ! $startsAt) {
            throw ValidationException::withMessages(['starts_at' => ['A scheduled announcement requires a start time.']]);
        }
        $data['is_active'] = in_array($status, ['published', 'scheduled'], true);
        if ($status === 'published') {
            $data['published_at'] = $current?->published_at ?? now();
            $data['starts_at'] = $startsAt ?? now();
        }

        return $data;
    }

    private function payload(Announcement $announcement, mixed $read = null): array
    {
        $effectiveStatus = $announcement->status;
        if ($announcement->status !== 'archived' && $announcement->expires_at?->isPast()) {
            $effectiveStatus = 'expired';
        } elseif ($announcement->status === 'scheduled' && $announcement->starts_at?->isPast()) {
            $effectiveStatus = 'published';
        }
        $data = [...$announcement->toArray(), 'effective_status' => $effectiveStatus, 'audiences' => $announcement->audienceRoles(), 'is_read' => $read?->read_at !== null, 'is_dismissed' => $read?->dismissed_at !== null];
        unset($data['image_path']);
        $data['image_url'] = $announcement->image_path ? url('/storage/'.$announcement->image_path) : null;

        return $data;
    }

    private function log(Request $request, string $action, Announcement $announcement): void
    {
        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => $action,
            'details' => json_encode([
                'target_type' => 'announcement',
                'target_id' => $announcement->id,
                'audiences' => $announcement->audienceRoles(),
                'status' => $announcement->status,
            ]),
        ]);
    }

    private function supportedColumns(array $data): array
    {
        return array_filter($data, fn ($value, $key) => Schema::hasColumn('announcements', $key), ARRAY_FILTER_USE_BOTH);
    }

    private function validateRelated(?string $type, ?string $id): void
    {
        if ($type === null && $id === null) {
            return;
        }
        abort_unless($type && $id, 422, 'Related type and record must be selected together.');
        $tables = [
            'tourist_spot' => 'tourist_spots',
            'ferry_schedule' => 'ferry_schedules',
            'msme' => 'msmes',
            'eco_tip' => 'eco_tips',
            'emergency_advisory' => 'emergency_contacts',
        ];
        abort_unless(isset($tables[$type]) && DB::table($tables[$type])->where('id', $id)->exists(), 422, 'The related announcement record does not exist.');
    }
}
