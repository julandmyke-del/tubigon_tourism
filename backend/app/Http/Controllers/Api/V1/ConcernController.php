<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\ManageConcernRequest;
use App\Http\Requests\StoreConcernRequest;
use App\Http\Requests\StoreMessageRequest;
use App\Models\ActivityLog;
use App\Models\Concern;
use App\Models\ConcernAttachment;
use App\Models\ConcernCategory;
use App\Models\ConcernHistory;
use App\Models\ConcernMessage;
use App\Models\Notification;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Storage;
use Throwable;

class ConcernController extends Controller
{
    private const FLOW = [
        'submitted' => ['under_review', 'assigned', 'closed'],
        'under_review' => ['assigned', 'in_progress', 'needs_more_information', 'resolved', 'closed'],
        'assigned' => ['in_progress', 'needs_more_information', 'resolved', 'closed'],
        'in_progress' => ['needs_more_information', 'resolved', 'closed'],
        'needs_more_information' => ['in_progress', 'resolved', 'closed'],
        'resolved' => ['closed', 'reopened'],
        'reopened' => ['assigned', 'in_progress', 'resolved', 'closed'],
        'closed' => ['reopened'],
    ];

    public function categories(): JsonResponse
    {
        return response()->json([
            'status' => 'success',
            'data' => ConcernCategory::where('is_active', true)
                ->orderBy('sort_order')
                ->get(),
        ]);
    }

    public function index(Request $request): JsonResponse
    {
        $role = $request->user()->role?->name;
        $query = Concern::with('category')->latest();
        if ($role === 'lgu_staff') {
            $query->where('assigned_role', 'lgu_staff');
        } elseif ($role !== 'admin') {
            $query->where('user_id', $request->user()->id);
        }
        foreach (['status', 'priority'] as $filter) {
            if ($request->filled($filter)) {
                $query->where($filter, $request->string($filter));
            }
        }

        return response()->json([
            'status' => 'success',
            'data' => $query->paginate(min(100, max(1, $request->integer('per_page', 20)))),
        ]);
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $concern = Concern::with([
            'category',
            'messages.sender:id,name',
            'histories',
            'attachments',
        ])->findOrFail($id);
        Gate::forUser($request->user())->authorize('view', $concern);

        return response()->json([
            'status' => 'success',
            'data' => $this->payload($request, $concern),
        ]);
    }

    public function store(StoreConcernRequest $request): JsonResponse
    {
        $validated = $request->safe()->except('attachment');
        $category = ConcernCategory::whereKey($validated['category_id'])
            ->where('is_active', true)
            ->firstOrFail();
        $this->validateRelated(
            $request,
            $validated['related_type'] ?? null,
            $validated['related_id'] ?? null,
        );
        $storedPath = null;
        try {
            $concern = DB::transaction(function () use (
                $request,
                $validated,
                $category,
                &$storedPath,
            ): Concern {
                $concern = Concern::create([
                    ...$validated,
                    'user_id' => $request->user()->id,
                    'assigned_role' => $category->assigned_role,
                    'priority' => $validated['priority'] ?? 'normal',
                ]);
                ConcernHistory::create([
                    'concern_id' => $concern->id,
                    'actor_user_id' => $request->user()->id,
                    'action' => 'submitted',
                    'to_status' => 'submitted',
                    'note' => 'Concern submitted',
                    'is_public' => true,
                ]);
                if ($request->hasFile('attachment')) {
                    $file = $request->file('attachment');
                    $storedPath = $file->store("concerns/{$concern->id}", 'local');
                    ConcernAttachment::create([
                        'concern_id' => $concern->id,
                        'uploaded_by_user_id' => $request->user()->id,
                        'storage_path' => $storedPath,
                        'original_name' => $file->getClientOriginalName(),
                        'mime_type' => $file->getMimeType(),
                        'size_bytes' => $file->getSize(),
                    ]);
                }
                ActivityLog::create([
                    'user_id' => $request->user()->id,
                    'action' => 'Concern submitted',
                    'details' => json_encode([
                        'concern_id' => $concern->id,
                        'reference_no' => $concern->reference_no,
                        'category' => $category->slug,
                    ]),
                ]);

                return $concern;
            }, 3);
        } catch (Throwable $exception) {
            if ($storedPath) {
                Storage::disk('local')->delete($storedPath);
            }
            throw $exception;
        }

        $this->notifyRole(
            $category->assigned_role,
            'New support concern',
            "Concern {$concern->reference_no} requires review.",
            $concern,
        );

        return response()->json([
            'status' => 'success',
            'data' => $concern->load('category'),
        ], 201);
    }

    public function manage(ManageConcernRequest $request, string $id): JsonResponse
    {
        $concern = DB::transaction(function () use ($request, $id): Concern {
            $concern = Concern::lockForUpdate()->findOrFail($id);
            Gate::forUser($request->user())->authorize('manage', $concern);
            $before = $concern->status;
            $validated = $request->validated();
            if (! empty($validated['status'])) {
                abort_unless(
                    in_array($validated['status'], self::FLOW[$before] ?? [], true),
                    422,
                    "Invalid concern transition from {$before}.",
                );
            }

            $update = [];
            if (isset($validated['status'])) {
                $update['status'] = $validated['status'];
            }
            if ($validated['assign_to_self'] ?? false) {
                $update['assigned_user_id'] = $request->user()->id;
            } elseif (array_key_exists('assigned_user_id', $validated)) {
                $this->validateAssignee($concern, $validated['assigned_user_id']);
                $update['assigned_user_id'] = $validated['assigned_user_id'];
            }
            if ($validated['escalate_to_admin'] ?? false) {
                abort_unless($request->user()->role?->name === 'lgu_staff', 403);
                $update['assigned_role'] = 'admin';
                $update['assigned_user_id'] = null;
            }
            if (($validated['status'] ?? null) === 'resolved') {
                $update['resolved_at'] = now();
            }
            if (($validated['status'] ?? null) === 'closed') {
                $update['closed_at'] = now();
            }
            $concern->update($update);

            $action = ($validated['escalate_to_admin'] ?? false)
                ? 'escalated'
                : ($validated['status'] ?? 'assigned');
            ConcernHistory::create([
                'concern_id' => $concern->id,
                'actor_user_id' => $request->user()->id,
                'action' => $action,
                'from_status' => $before,
                'to_status' => $concern->status,
                'note' => $validated['note'] ?? null,
                'is_public' => ! ($validated['is_internal'] ?? false),
            ]);
            if (! empty($validated['note'])) {
                ConcernMessage::create([
                    'concern_id' => $concern->id,
                    'sender_user_id' => $request->user()->id,
                    'message' => trim($validated['note']),
                    'is_internal' => $validated['is_internal'] ?? false,
                ]);
            }
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'Concern '.$action,
                'details' => json_encode([
                    'concern_id' => $concern->id,
                    'reference_no' => $concern->reference_no,
                ]),
            ]);

            return $concern->fresh();
        }, 3);

        if ($request->boolean('escalate_to_admin')) {
            $this->notifyRole(
                'admin',
                'Support concern escalated',
                "Concern {$concern->reference_no} was escalated for Admin review.",
                $concern,
                'concern_escalated',
            );
        }

        Notification::create([
            'user_id' => $concern->user_id,
            'type' => 'concern_update',
            'title' => 'Concern updated',
            'body' => "Concern {$concern->reference_no} is now ".str_replace('_', ' ', $concern->status).'.',
            'data' => [
                'concern_id' => $concern->id,
                'route' => "/concerns/{$concern->id}",
            ],
        ]);

        return response()->json(['status' => 'success', 'data' => $concern]);
    }

    public function reply(
        StoreMessageRequest $request,
        string $id,
    ): JsonResponse {
        $concern = Concern::findOrFail($id);
        Gate::forUser($request->user())->authorize('reply', $concern);
        $staff = in_array(
            $request->user()->role?->name,
            ['lgu_staff', 'admin'],
            true,
        );
        $internal = $staff && $request->boolean('is_internal');
        $message = ConcernMessage::create([
            'concern_id' => $concern->id,
            'sender_user_id' => $request->user()->id,
            'message' => $request->validated('message'),
            'is_internal' => $internal,
        ]);
        if ($staff && ! $internal) {
            Notification::create([
                'user_id' => $concern->user_id,
                'type' => 'concern_reply',
                'title' => 'New concern reply',
                'body' => "There is a reply on {$concern->reference_no}.",
                'data' => [
                    'concern_id' => $concern->id,
                    'route' => "/concerns/{$concern->id}",
                ],
            ]);
        } elseif (! $staff) {
            $title = 'New concern reply';
            $body = "The user replied on {$concern->reference_no}.";
            if ($concern->assigned_user_id) {
                Notification::create([
                    'user_id' => $concern->assigned_user_id,
                    'type' => 'concern_reply',
                    'title' => $title,
                    'body' => $body,
                    'data' => [
                        'concern_id' => $concern->id,
                        'route' => $concern->assigned_role === 'admin'
                            ? '/admin/concerns'
                            : '/lgu/concerns',
                    ],
                ]);
            } else {
                $this->notifyRole(
                    $concern->assigned_role,
                    $title,
                    $body,
                    $concern,
                    'concern_reply',
                );
            }
        }

        return response()->json([
            'status' => 'success',
            'data' => $message,
        ], 201);
    }

    public function attachment(Request $request, string $attachment)
    {
        $file = ConcernAttachment::findOrFail($attachment);
        $concern = Concern::findOrFail($file->concern_id);
        Gate::forUser($request->user())->authorize('view', $concern);
        abort_unless(Storage::disk('local')->exists($file->storage_path), 404);

        return Storage::disk('local')->download(
            $file->storage_path,
            $file->original_name,
            [
                'Content-Type' => $file->mime_type,
                'X-Content-Type-Options' => 'nosniff',
            ],
        );
    }

    private function payload(Request $request, Concern $concern): array
    {
        $tourist = (string) $concern->user_id === (string) $request->user()->id;
        $data = $concern->toArray();
        if ($tourist) {
            $data['messages'] = $concern->messages
                ->where('is_internal', false)
                ->values();
            $data['histories'] = $concern->histories
                ->where('is_public', true)
                ->values();
        }
        $data['attachments'] = $concern->attachments->map(fn (ConcernAttachment $file) => [
            'id' => $file->id,
            'name' => $file->original_name,
            'mime_type' => $file->mime_type,
            'size_bytes' => $file->size_bytes,
            'download_url' => url("/api/v1/concern-attachments/{$file->id}"),
        ])->values();

        return $data;
    }

    private function validateAssignee(Concern $concern, ?string $userId): void
    {
        if ($userId === null) {
            return;
        }
        $assignee = User::with('role')->findOrFail($userId);
        abort_unless(
            $assignee->is_verified
                && $assignee->role?->name === $concern->assigned_role,
            422,
            'The assignee must be a verified member of the routed role.',
        );
    }

    private function validateRelated(
        Request $request,
        ?string $type,
        ?string $id,
    ): void {
        if (! $type) {
            return;
        }
        $owned = [
            'reservation' => ['reservations', 'user_id'],
            'waste_report' => ['waste_reports', 'user_id'],
            'role_application' => ['role_applications', 'applicant_user_id'],
        ];
        if (isset($owned[$type])) {
            abort_unless(
                DB::table($owned[$type][0])
                    ->where('id', $id)
                    ->where($owned[$type][1], $request->user()->id)
                    ->exists(),
                422,
                'The related record is not accessible.',
            );

            return;
        }
        $public = [
            'ferry_schedule' => 'ferry_schedules',
            'tourist_spot' => 'tourist_spots',
            'msme' => 'msmes',
            'emergency_contact' => 'emergency_contacts',
        ];
        abort_unless(
            DB::table($public[$type])->where('id', $id)->exists(),
            422,
            'The related record does not exist.',
        );
    }

    private function notifyRole(
        string $role,
        string $title,
        string $body,
        Concern $concern,
        string $type = 'concern_assigned',
    ): void {
        User::whereHas('role', fn ($query) => $query->where('name', $role))
            ->where('is_verified', true)
            ->each(fn (User $user) => Notification::create([
                'user_id' => $user->id,
                'type' => $type,
                'title' => $title,
                'body' => $body,
                'data' => [
                    'concern_id' => $concern->id,
                    'route' => $role === 'admin'
                        ? '/admin/concerns'
                        : '/lgu/concerns',
                ],
            ]));
    }
}
