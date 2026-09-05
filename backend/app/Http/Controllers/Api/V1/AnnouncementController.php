<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Announcement;
use App\Services\AnnouncementDeliveryService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

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
        $announcements = Announcement::visibleTo($role)
            ->orderByDesc('priority')
            ->orderByDesc('starts_at')
            ->get()
            ->map(fn (Announcement $item) => $this->payload($item));

        return response()->json(['status' => 'success', 'data' => $announcements]);
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $request->user()->loadMissing('role');
        $role = $request->user()->role?->name ?? 'tourist';
        $announcement = Announcement::visibleTo($role)->findOrFail($id);

        return response()->json(['status' => 'success', 'data' => $this->payload($announcement)]);
    }

    public function managementIndex(Request $request): JsonResponse
    {
        $query = Announcement::query()->orderByDesc('created_at');
        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }
        if ($request->filled('audience')) {
            $query->where('audience', $request->string('audience'));
        }

        return response()->json([
            'status' => 'success',
            'data' => $query->get()->map(fn (Announcement $item) => $this->payload($item)),
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
            ->whereIn('audience', ['everyone', 'lgu_staff'])
            ->where('status', '!=', 'draft');
        if (! empty($validated['priority'])) $query->where('priority', $validated['priority']);
        if (! empty($validated['type'])) $query->where('type', $validated['type']);
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

    public function store(Request $request, AnnouncementDeliveryService $delivery): JsonResponse
    {
        $validated = $this->validated($request);
        $validated = $this->normalizePublication($validated);
        $validated['created_by'] = $request->user()->id;

        $announcement = DB::transaction(function () use ($request, $validated): Announcement {
            $announcement = Announcement::create($validated);
            $this->log($request, 'Announcement created', $announcement);
            return $announcement;
        });
        // Per-user records are created lazily when each role checks its bell.

        return response()->json(['status' => 'success', 'data' => $this->payload($announcement)], 201);
    }

    public function update(Request $request, string $id, AnnouncementDeliveryService $delivery): JsonResponse
    {
        $announcement = Announcement::findOrFail($id);
        $validated = $this->normalizePublication($this->validated($request, true), $announcement);

        DB::transaction(function () use ($request, $announcement, $validated): void {
            $announcement->update($validated);
            $this->log($request, 'Announcement updated', $announcement);
        });
        $announcement->refresh();
        // Remove stale audience/title copies. Eligible users receive the updated
        // authoritative record on their next feed request.
        $delivery->remove($announcement);

        return response()->json(['status' => 'success', 'data' => $this->payload($announcement)]);
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

    private function payload(Announcement $announcement): array
    {
        $effectiveStatus = $announcement->status;
        if ($announcement->status !== 'archived' && $announcement->expires_at?->isPast()) {
            $effectiveStatus = 'expired';
        } elseif ($announcement->status === 'scheduled' && $announcement->starts_at?->isPast()) {
            $effectiveStatus = 'published';
        }
        return [...$announcement->toArray(), 'effective_status' => $effectiveStatus];
    }

    private function log(Request $request, string $action, Announcement $announcement): void
    {
        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => $action,
            'details' => json_encode([
                'target_type' => 'announcement',
                'target_id' => $announcement->id,
                'audience' => $announcement->audience,
                'status' => $announcement->status,
            ]),
        ]);
    }
}
