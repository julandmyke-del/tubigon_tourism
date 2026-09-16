<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\ValidatesTubigonCoordinates;
use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Msme;
use App\Models\MsmeCategory;
use App\Models\Notification;
use App\Models\Profile;
use App\Models\Role;
use App\Models\RoleApplication;
use App\Models\RoleApplicationHistory;
use App\Models\SystemSetting;
use App\Models\TouristSpot;
use App\Models\TouristSpotPartnerAssignment;
use App\Models\User;
use App\Services\EmailNotificationService;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use App\Support\StaleRecordGuard;

class RoleApplicationController extends Controller
{
    use ValidatesTubigonCoordinates;

    private const MSME_CATEGORIES = [
        'Food & Dining', 'Accommodation', 'Tour Services', 'Handicrafts',
        'Agriculture', 'Retail', 'Transport', 'Other',
    ];

    private const CHECKLIST_KEYS = [
        'applicant_identity_complete', 'business_information_complete',
        'address_valid', 'coordinates_valid', 'category_appropriate',
        'contact_information_valid', 'required_proof_complete',
        'organization_relationship_verified', 'requested_destination_valid',
        'destination_assignment_available',
    ];

    public function options(Request $request): JsonResponse
    {
        $userRole = $request->user()->role?->name;

        return response()->json(['status' => 'success', 'data' => [
            'application_types' => RoleApplication::TYPES,
            'statuses' => RoleApplication::STATUSES,
            'msme_categories' => $this->msmeCategories(),
            'msme_applications_enabled' => SystemSetting::enabled('msme_applications_enabled'),
            'partner_applications_enabled' => SystemSetting::enabled('partner_applications_enabled'),
            'eligible' => [
                RoleApplication::TYPE_MSME => $userRole === 'tourist',
                RoleApplication::TYPE_PARTNER => $userRole === 'tourist',
            ],
        ]]);
    }

    public function index(Request $request): JsonResponse
    {
        $applications = RoleApplication::query()
            ->where('applicant_user_id', $request->user()->id)
            ->with($this->relations())
            ->latest()
            ->get();

        return response()->json(['status' => 'success', 'data' => $applications]);
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $application = $this->ownedApplication($request, $id);

        return response()->json([
            'status' => 'success',
            'data' => $application->load($this->relations()),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $this->assertTouristApplicant($request);
        $validated = $request->validate([
            'application_type' => ['required', Rule::in(RoleApplication::TYPES)],
        ]);
        $type = $validated['application_type'];
        $this->assertApplicationTypeEnabled($type);

        $application = DB::transaction(function () use ($request, $type): RoleApplication {
            User::whereKey($request->user()->id)->lockForUpdate()->firstOrFail();
            $existing = RoleApplication::query()
                ->where('applicant_user_id', $request->user()->id)
                ->where('application_type', $type)
                ->where('active_slot', true)
                ->first();
            if ($existing) {
                return $existing;
            }

            $application = RoleApplication::create([
                'applicant_user_id' => $request->user()->id,
                'application_type' => $type,
                'status' => RoleApplication::STATUS_DRAFT,
                'active_slot' => true,
                'payload' => [],
            ]);
            $this->recordTransition($application, $request->user()->id, 'created', null, RoleApplication::STATUS_DRAFT);
            $this->audit($request->user()->id, 'Role application created', $application);

            return $application;
        });

        return response()->json([
            'status' => 'success',
            'message' => $application->wasRecentlyCreated ? 'Application draft created.' : 'Your active application was reopened.',
            'data' => $application->load($this->relations()),
        ], $application->wasRecentlyCreated ? 201 : 200);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $this->assertTouristApplicant($request);
        $application = $this->ownedApplication($request, $id);
        abort_unless(
            in_array($application->status, [RoleApplication::STATUS_DRAFT, RoleApplication::STATUS_NEEDS_CHANGES], true),
            422,
            'Only draft applications or applications needing changes can be edited.',
        );

        $data = $this->validatePayload($request, $application->application_type, false);
        $changes = [
            'payload' => array_merge($application->payload ?? [], $data['payload']),
            'requested_tourist_spot_id' => $data['requested_tourist_spot_id']
                ?? $application->requested_tourist_spot_id,
        ];
        if (Schema::hasColumn('role_applications', 'requested_msme_category_id') && array_key_exists('requested_msme_category_id', $data)) {
            $changes['requested_msme_category_id'] = $data['requested_msme_category_id'];
        }
        $application->update($changes);
        $this->recordTransition($application, $request->user()->id, 'draft_updated', $application->status, $application->status);
        $this->audit($request->user()->id, 'Role application draft updated', $application);

        return response()->json(['status' => 'success', 'message' => 'Application draft saved.', 'data' => $application->fresh()->load($this->relations())]);
    }

    public function submit(Request $request, string $id): JsonResponse
    {
        $this->assertTouristApplicant($request);
        $application = $this->ownedApplication($request, $id);
        $this->assertApplicationTypeEnabled($application->application_type);
        abort_unless($application->canTransitionTo(RoleApplication::STATUS_SUBMITTED), 422, 'This application cannot be submitted in its current state.');
        $data = $this->validatePayload($request, $application->application_type, true, $application);

        $application = DB::transaction(function () use ($request, $application, $data): RoleApplication {
            $locked = RoleApplication::whereKey($application->id)->lockForUpdate()->firstOrFail();
            abort_unless($locked->canTransitionTo(RoleApplication::STATUS_SUBMITTED), 422, 'This application was already processed.');
            $from = $locked->status;
            $payload = array_merge($locked->payload ?? [], $data['payload']);
            $changes = [
                'payload' => $payload,
                'requested_tourist_spot_id' => $data['requested_tourist_spot_id'] ?? $locked->requested_tourist_spot_id,
                'status' => RoleApplication::STATUS_SUBMITTED,
                'submitted_at' => now(),
                'lgu_checklist' => null,
                'reviewed_by_lgu_id' => null, 'lgu_reviewed_at' => null,
            ];
            if (Schema::hasColumn('role_applications', 'requested_msme_category_id') && array_key_exists('requested_msme_category_id', $data)) {
                $changes['requested_msme_category_id'] = $data['requested_msme_category_id'];
            }
            $locked->fill($changes);
            if ($locked->application_type === RoleApplication::TYPE_MSME) {
                $locked->linked_msme_id = $this->syncPendingMsme($locked, $payload)->id;
            }
            $locked->save();
            $this->recordTransition($locked, $request->user()->id, 'submitted', $from, RoleApplication::STATUS_SUBMITTED);
            $this->notifyRole('lgu_staff', 'New role application', $this->applicationLabel($locked).' is ready for LGU review.', $locked, '/lgu/role-applications/'.$locked->id);
            $this->audit($request->user()->id, 'Role application submitted', $locked);

            return $locked;
        });

        return response()->json(['status' => 'success', 'message' => 'Application submitted for LGU review.', 'data' => $application->load($this->relations())]);
    }

    public function withdraw(Request $request, string $id): JsonResponse
    {
        $application = $this->ownedApplication($request, $id);
        abort_unless($application->canTransitionTo(RoleApplication::STATUS_WITHDRAWN), 422, 'This application can no longer be withdrawn.');

        DB::transaction(function () use ($request, $application): void {
            $locked = RoleApplication::whereKey($application->id)->lockForUpdate()->firstOrFail();
            abort_unless($locked->canTransitionTo(RoleApplication::STATUS_WITHDRAWN), 422, 'This application was already processed.');
            $from = $locked->status;
            $locked->update(['status' => RoleApplication::STATUS_WITHDRAWN, 'active_slot' => null, 'withdrawn_at' => now()]);
            $this->recordTransition($locked, $request->user()->id, 'withdrawn', $from, RoleApplication::STATUS_WITHDRAWN);
            $this->audit($request->user()->id, 'Role application withdrawn', $locked);
        });

        return response()->json(['status' => 'success', 'message' => 'Application withdrawn.', 'data' => $application->fresh()->load($this->relations())]);
    }

    public function lguIndex(Request $request): JsonResponse
    {
        $query = RoleApplication::query()->with($this->relations());
        $this->applyFilters($query, $request);

        return response()->json(['status' => 'success', 'data' => $query->latest('submitted_at')->get()]);
    }

    public function lguShow(string $id): JsonResponse
    {
        return response()->json(['status' => 'success', 'data' => RoleApplication::with($this->relations())->findOrFail($id)]);
    }

    public function startReview(Request $request, string $id): JsonResponse
    {
        return $this->lguTransition($request, $id, RoleApplication::STATUS_UNDER_REVIEW, 'review_started');
    }

    public function needsChanges(Request $request, string $id, EmailNotificationService $emailDelivery): JsonResponse
    {
        $validated = $request->validate([
            'notes' => 'required|string|max:3000',
            'checklist' => 'nullable|array',
            'checklist.*' => 'boolean',
        ]);

        return $this->lguTransition($request, $id, RoleApplication::STATUS_NEEDS_CHANGES, 'changes_requested', $validated, $emailDelivery, 'needs_changes');
    }

    public function recommend(Request $request, string $id): JsonResponse
    {
        $validated = $request->validate([
            'notes' => 'nullable|string|max:3000',
            'checklist' => 'required|array',
            'checklist.*' => 'boolean',
            'recommended_msme_category_id' => [
                'nullable', 'uuid',
                Rule::exists('msme_categories', 'id')->where(fn ($query) => $query->where('is_active', true)->whereNull('deleted_at')),
            ],
        ]);
        $this->validateChecklist($validated['checklist']);
        if (in_array(false, array_values($validated['checklist']), true)) {
            throw ValidationException::withMessages(['checklist' => ['Every applicable LGU verification item must be complete before recommendation.']]);
        }

        return $this->lguTransition($request, $id, RoleApplication::STATUS_RECOMMENDED, 'recommended_for_approval', $validated);
    }

    public function lguReject(Request $request, string $id, EmailNotificationService $emailDelivery): JsonResponse
    {
        $validated = $request->validate([
            'notes' => 'required|string|max:3000',
            'checklist' => 'nullable|array',
            'checklist.*' => 'boolean',
        ]);

        return $this->lguTransition($request, $id, RoleApplication::STATUS_REJECTED, 'rejected_by_lgu', $validated, $emailDelivery, 'rejected');
    }

    public function adminIndex(Request $request): JsonResponse
    {
        $query = RoleApplication::query()->with($this->relations());
        if (! $request->filled('status')) {
            $query->where('status', RoleApplication::STATUS_RECOMMENDED);
        }
        $this->applyFilters($query, $request);

        return response()->json(['status' => 'success', 'data' => $query->latest('lgu_reviewed_at')->get()]);
    }

    public function adminShow(string $id): JsonResponse
    {
        return response()->json(['status' => 'success', 'data' => RoleApplication::with($this->relations())->findOrFail($id)]);
    }

    public function approve(Request $request, string $id, EmailNotificationService $emailDelivery): JsonResponse
    {
        $rules = ['notes' => 'nullable|string|max:3000'];
        if (Schema::hasTable('msme_categories')) {
            $rules['final_msme_category_id'] = [
                'nullable', 'uuid',
                Rule::exists('msme_categories', 'id')->where(fn ($query) => $query->where('is_active', true)->whereNull('deleted_at')),
            ];
        }
        $validated = $request->validate($rules);
        $expectedUpdatedAt = StaleRecordGuard::expectedUpdatedAt($request);

        $application = DB::transaction(function () use ($request, $id, $validated, $expectedUpdatedAt): RoleApplication {
            $application = RoleApplication::whereKey($id)->lockForUpdate()->firstOrFail();
            StaleRecordGuard::assertCurrent($application, $expectedUpdatedAt, [
                'status' => $application->status,
            ], 'This request was updated in another session. Refresh and try again.');
            abort_unless($application->canTransitionTo(RoleApplication::STATUS_APPROVED), 422, 'Only LGU-recommended applications can be approved.');
            $applicant = User::with('role')->whereKey($application->applicant_user_id)->lockForUpdate()->firstOrFail();
            abort_unless($applicant->role?->name === 'tourist', 422, 'The applicant is no longer eligible for this role.');

            $targetRole = Role::where('name', $application->application_type)->firstOrFail();
            if ($application->application_type === RoleApplication::TYPE_MSME) {
                if (Schema::hasColumn('role_applications', 'final_msme_category_id')) {
                    $application->final_msme_category_id = $validated['final_msme_category_id']
                        ?? $application->recommended_msme_category_id
                        ?? $application->requested_msme_category_id;
                    $application->save();
                }
                $this->provisionMsmeOwner($application, $applicant);
            } else {
                $this->provisionTourismPartner($application, $applicant, $request->user()->id);
            }

            $applicant->update(['role_id' => $targetRole->id]);
            Profile::whereKey($applicant->id)->update(['role_id' => $targetRole->id]);
            $from = $application->status;
            $reviewChanges = [
                'status' => RoleApplication::STATUS_APPROVED,
                'active_slot' => null,
                'admin_reviewed_by_id' => $request->user()->id,
                'admin_reviewed_at' => now(),
                'admin_notes' => $validated['notes'] ?? null,
                'approved_at' => now(),
            ];
            $application->update($reviewChanges);
            RoleApplication::query()
                ->where('applicant_user_id', $applicant->id)
                ->where('id', '!=', $application->id)
                ->where('active_slot', true)
                ->lockForUpdate()
                ->get()
                ->each(function (RoleApplication $other) use ($request): void {
                    $from = $other->status;
                    $other->update([
                        'status' => RoleApplication::STATUS_WITHDRAWN,
                        'active_slot' => null,
                        'withdrawn_at' => now(),
                    ]);
                    $this->recordTransition(
                        $other,
                        $request->user()->id,
                        'closed_after_other_role_approval',
                        $from,
                        RoleApplication::STATUS_WITHDRAWN,
                        'Closed automatically because another privileged role was approved.',
                    );
                });
            $this->recordTransition($application, $request->user()->id, 'approved_and_provisioned', $from, RoleApplication::STATUS_APPROVED, $validated['notes'] ?? null);
            $portalRoute = $application->application_type === RoleApplication::TYPE_MSME ? '/msme-portal' : '/tourism-partner';
            $this->notifyUser($applicant->id, 'Application approved', 'Your '.$this->applicationLabel($application).' was approved. Your new portal is ready.', $application, $portalRoute, ['role_changed' => true]);
            $this->audit($request->user()->id, 'Role application approved and provisioned', $application, ['provisioned_role' => $targetRole->name]);

            return $application;
        });

        $emailDelivery->application($application, 'approved');

        return response()->json([
            'status' => 'success',
            'message' => 'Application approved and role provisioned.',
            'data' => $application->load($this->relations()),
        ]);
    }

    public function adminReject(Request $request, string $id, EmailNotificationService $emailDelivery): JsonResponse
    {
        $validated = $request->validate(['notes' => 'required|string|max:3000']);
        $expectedUpdatedAt = StaleRecordGuard::expectedUpdatedAt($request);

        $application = DB::transaction(function () use ($request, $id, $validated, $expectedUpdatedAt): RoleApplication {
            $application = RoleApplication::whereKey($id)->lockForUpdate()->firstOrFail();
            StaleRecordGuard::assertCurrent($application, $expectedUpdatedAt, [
                'status' => $application->status,
            ], 'This request was updated in another session. Refresh and try again.');
            abort_unless($application->canTransitionTo(RoleApplication::STATUS_REJECTED), 422, 'Only LGU-recommended applications can be rejected by Admin.');
            $from = $application->status;
            $application->update([
                'status' => RoleApplication::STATUS_REJECTED,
                'active_slot' => null,
                'admin_reviewed_by_id' => $request->user()->id,
                'admin_reviewed_at' => now(),
                'admin_notes' => $validated['notes'],
                'rejected_at' => now(),
            ]);
            $this->recordTransition($application, $request->user()->id, 'rejected_by_admin', $from, RoleApplication::STATUS_REJECTED, $validated['notes']);
            $this->notifyUser($application->applicant_user_id, 'Application not approved', 'Admin reviewed your application. Open it to read the decision.', $application, '/applications/'.$application->id);
            $this->audit($request->user()->id, 'Role application rejected by Admin', $application);

            return $application;
        });

        $emailDelivery->application($application, 'rejected');

        return response()->json(['status' => 'success', 'message' => 'Application rejected.', 'data' => $application->load($this->relations())]);
    }

    private function lguTransition(
        Request $request,
        string $id,
        string $target,
        string $action,
        array $input = [],
        ?EmailNotificationService $emailDelivery = null,
        ?string $emailEvent = null,
    ): JsonResponse {
        if (isset($input['checklist'])) {
            $this->validateChecklist($input['checklist']);
        }
        $expectedUpdatedAt = StaleRecordGuard::expectedUpdatedAt($request);

        $application = DB::transaction(function () use ($request, $id, $target, $action, $input, $expectedUpdatedAt): RoleApplication {
            $application = RoleApplication::whereKey($id)->lockForUpdate()->firstOrFail();
            StaleRecordGuard::assertCurrent($application, $expectedUpdatedAt, [
                'status' => $application->status,
            ], 'This request was updated in another session. Refresh and try again.');
            abort_unless($application->canTransitionTo($target), 422, 'That review action is not valid for the current application state.');
            if ($target === RoleApplication::STATUS_RECOMMENDED) {
                $this->assertCompleteChecklist($application, $input['checklist'] ?? []);
            }
            $from = $application->status;
            $terminal = in_array($target, [RoleApplication::STATUS_REJECTED, RoleApplication::STATUS_WITHDRAWN], true);
            $changes = [
                'status' => $target,
                'active_slot' => $terminal ? null : true,
                'reviewed_by_lgu_id' => $request->user()->id,
                'lgu_reviewed_at' => now(),
                'lgu_notes' => $input['notes'] ?? $application->lgu_notes,
                'lgu_checklist' => $input['checklist'] ?? $application->lgu_checklist,
                'rejected_at' => $target === RoleApplication::STATUS_REJECTED ? now() : null,
            ];
            if ($target === RoleApplication::STATUS_RECOMMENDED
                && Schema::hasColumn('role_applications', 'recommended_msme_category_id')
                && $application->application_type === RoleApplication::TYPE_MSME) {
                $changes['recommended_msme_category_id'] = $input['recommended_msme_category_id'] ?? null;
            }
            $application->update($changes);
            $this->recordTransition($application, $request->user()->id, $action, $from, $target, $input['notes'] ?? null, [
                'checklist' => $input['checklist'] ?? null,
                'requested_msme_category_id' => $application->requested_msme_category_id ?? null,
                'recommended_msme_category_id' => $application->recommended_msme_category_id ?? null,
            ]);

            if ($target === RoleApplication::STATUS_RECOMMENDED) {
                $this->notifyRole('admin', 'Application recommended by LGU', $this->applicationLabel($application).' is ready for final review.', $application, '/admin/access-requests/'.$application->id);
            } elseif ($target !== RoleApplication::STATUS_UNDER_REVIEW) {
                $titles = [
                    RoleApplication::STATUS_NEEDS_CHANGES => 'Application needs changes',
                    RoleApplication::STATUS_REJECTED => 'Application rejected by LGU',
                ];
                $this->notifyUser(
                    $application->applicant_user_id,
                    $titles[$target] ?? 'Application status updated',
                    $input['notes'] ?? 'Your application status was updated.',
                    $application,
                    '/applications/'.$application->id,
                );
            }
            $this->audit($request->user()->id, 'Role application '.$action, $application);

            return $application;
        });

        if ($emailDelivery !== null && $emailEvent !== null) {
            $emailDelivery->application($application, $emailEvent);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'Application status updated.',
            'data' => $application->load($this->relations()),
        ]);
    }

    /** @return array<string, mixed> */
    private function validatePayload(Request $request, string $type, bool $complete, ?RoleApplication $application = null): array
    {
        $request->validate([
            'status' => 'prohibited', 'role' => 'prohibited', 'role_id' => 'prohibited',
            'approved' => 'prohibited', 'reviewed_by_lgu_id' => 'prohibited',
            'admin_reviewed_by_id' => 'prohibited', 'linked_msme_id' => 'prohibited',
        ]);

        $safeKeys = $type === RoleApplication::TYPE_MSME
            ? ['applicant_contact', 'business_name', 'business_category', 'business_category_id', 'business_address', 'business_phone', 'business_description', 'latitude', 'longitude', 'reason', 'supporting_evidence', 'declaration']
            : ['applicant_contact', 'organization', 'contact_phone', 'relationship', 'reason', 'supporting_evidence', 'declaration'];
        $incoming = $request->only($safeKeys);
        $payload = $complete ? array_merge($application?->payload ?? [], $incoming) : $incoming;

        if ($type === RoleApplication::TYPE_MSME) {
            $required = $complete ? 'required' : 'sometimes';
            $category = null;
            if (Schema::hasTable('msme_categories')) {
                if (! empty($payload['business_category_id'])) {
                    $category = MsmeCategory::whereKey($payload['business_category_id'])->where('is_active', true)->first();
                } elseif (! empty($payload['business_category'])) {
                    $category = MsmeCategory::whereRaw('LOWER(name) = ?', [strtolower(trim((string) $payload['business_category']))])
                        ->where('is_active', true)->first();
                } elseif ($application?->requested_msme_category_id) {
                    $category = MsmeCategory::whereKey($application->requested_msme_category_id)->where('is_active', true)->first();
                }
                if ($complete && ! $category) {
                    throw ValidationException::withMessages(['business_category_id' => ['Select an active business category.']]);
                }
                if ($category) {
                    $payload['business_category_id'] = $category->id;
                    $payload['business_category'] = $category->name;
                }
            }
            $rules = [
                'applicant_contact' => [$required, 'string', 'max:255'],
                'business_name' => [$required, 'string', 'max:255'],
                'business_category' => [$required, 'string', 'max:255'],
                'business_category_id' => ['sometimes', 'uuid'],
                'business_address' => [$required, 'string', 'max:1000'],
                'business_phone' => [$required, 'string', 'max:80'],
                'business_description' => [$required, 'string', 'max:3000'],
                'latitude' => [$required, 'numeric', 'between:-90,90'],
                'longitude' => [$required, 'numeric', 'between:-180,180'],
                'reason' => [$required, 'string', 'max:3000'],
                'supporting_evidence' => ['nullable', 'string', 'max:3000'],
                'declaration' => [$complete ? 'accepted' : 'sometimes', 'boolean'],
            ];
            $validated = Validator::make($payload, $rules)->validate();
            $this->validateTubigonCoordinates($validated);

            return [
                'payload' => $validated,
                'requested_msme_category_id' => $category?->id,
            ];
        }

        $requestedSpot = $request->input('requested_tourist_spot_id', $application?->requested_tourist_spot_id);
        $candidate = [...$payload, 'requested_tourist_spot_id' => $requestedSpot];
        $required = $complete ? 'required' : 'sometimes';
        $rules = [
            'applicant_contact' => [$required, 'string', 'max:255'],
            'organization' => [$required, 'string', 'max:255'],
            'contact_phone' => [$required, 'string', 'max:80'],
            'relationship' => [$required, 'string', 'max:3000'],
            'reason' => [$required, 'string', 'max:3000'],
            'supporting_evidence' => ['nullable', 'string', 'max:3000'],
            'declaration' => [$complete ? 'accepted' : 'sometimes', 'boolean'],
            'requested_tourist_spot_id' => [$required, 'uuid', Rule::exists('tourist_spots', 'id')->where(fn ($query) => $query->whereNull('deleted_at')->where('is_active', true))],
        ];
        $validated = Validator::make($candidate, $rules)->validate();
        $spotId = $validated['requested_tourist_spot_id'] ?? null;
        unset($validated['requested_tourist_spot_id']);

        return ['payload' => $validated, 'requested_tourist_spot_id' => $spotId];
    }

    private function syncPendingMsme(RoleApplication $application, array $payload): Msme
    {
        $msme = $application->linked_msme_id
            ? Msme::whereKey($application->linked_msme_id)->lockForUpdate()->firstOrFail()
            : Msme::where('profile_id', $application->applicant_user_id)->lockForUpdate()->first();
        abort_if($msme && ($msme->is_verified || $msme->verification_status === 'verified'), 422, 'A verified MSME already exists for this account.');

        $values = [
            'profile_id' => $application->applicant_user_id,
            'name' => $payload['business_name'],
            'category' => $payload['business_category'],
            'description' => $payload['business_description'],
            'phone' => $payload['business_phone'],
            'address' => $payload['business_address'],
            'latitude' => $payload['latitude'],
            'longitude' => $payload['longitude'],
            'is_verified' => false,
            'verification_status' => 'pending',
            'submitted_at' => now(),
            'booking_enabled' => false,
        ];
        if (Schema::hasColumn('msmes', 'category_id')) {
            $values['category_id'] = $application->requested_msme_category_id
                ?? ($payload['business_category_id'] ?? null);
        }
        if ($msme) {
            $msme->update($values);

            return $msme->fresh();
        }

        return Msme::create($values);
    }

    private function provisionMsmeOwner(RoleApplication $application, User $applicant): void
    {
        $msme = Msme::whereKey($application->linked_msme_id)->lockForUpdate()->first();
        abort_unless($msme, 422, 'The application is not linked to an authoritative MSME record.');
        abort_unless((string) $msme->profile_id === (string) $applicant->id, 422, 'The MSME ownership link does not match the applicant.');
        abort_if(Msme::where('profile_id', $applicant->id)->where('id', '!=', $msme->id)->exists(), 422, 'This applicant already owns another MSME.');
        // Role approval does not publish the business. Existing LGU MSME
        // verification remains the independent public visibility gate.
        $values = ['is_verified' => false, 'booking_enabled' => false];
        if (Schema::hasColumn('msmes', 'category_id')) {
            $categoryId = $application->final_msme_category_id
                ?? $application->recommended_msme_category_id
                ?? $application->requested_msme_category_id;
            if ($categoryId) {
                $category = MsmeCategory::whereKey($categoryId)->where('is_active', true)->firstOrFail();
                $values['category_id'] = $category->id;
                $values['category'] = $category->name;
            }
        }
        $msme->update($values);
    }

    private function provisionTourismPartner(RoleApplication $application, User $applicant, string $adminId): void
    {
        $spot = TouristSpot::whereKey($application->requested_tourist_spot_id)->where('is_active', true)->lockForUpdate()->first();
        abort_unless($spot, 422, 'The requested Tourist Spot is no longer available.');
        abort_if(TouristSpotPartnerAssignment::where('tourist_spot_id', $spot->id)->exists(), 422, 'This Tourist Spot is already assigned to a partner.');
        abort_if(TouristSpotPartnerAssignment::where('partner_profile_id', $applicant->id)->exists(), 422, 'This applicant already has a Tourist Spot assignment.');

        TouristSpotPartnerAssignment::create([
            'tourist_spot_id' => $spot->id,
            'partner_profile_id' => $applicant->id,
            'is_primary' => true,
            'assigned_by' => $adminId,
            'assigned_at' => now(),
        ]);
    }

    private function ownedApplication(Request $request, string $id): RoleApplication
    {
        $application = RoleApplication::findOrFail($id);
        abort_unless((string) $application->applicant_user_id === (string) $request->user()->id, 403, 'You may only access your own applications.');

        return $application;
    }

    private function assertTouristApplicant(Request $request): void
    {
        abort_unless($request->user()->role?->name === 'tourist', 403, 'Only eligible Tourist accounts may apply for privileged access.');
    }

    private function assertApplicationTypeEnabled(string $type): void
    {
        $key = $type === RoleApplication::TYPE_MSME
            ? 'msme_applications_enabled'
            : 'partner_applications_enabled';
        abort_unless(SystemSetting::enabled($key), 403, 'Applications of this type are currently disabled.');
    }

    private function validateChecklist(array $checklist): void
    {
        $unknown = array_diff(array_keys($checklist), self::CHECKLIST_KEYS);
        if ($unknown !== []) {
            throw ValidationException::withMessages(['checklist' => ['The checklist contains unsupported verification items.']]);
        }
    }

    private function assertCompleteChecklist(RoleApplication $application, array $checklist): void
    {
        $required = $application->application_type === RoleApplication::TYPE_MSME
            ? [
                'applicant_identity_complete', 'business_information_complete',
                'address_valid', 'coordinates_valid', 'category_appropriate',
                'contact_information_valid', 'required_proof_complete',
            ]
            : [
                'applicant_identity_complete', 'organization_relationship_verified',
                'requested_destination_valid', 'required_proof_complete',
                'destination_assignment_available',
            ];
        foreach ($required as $key) {
            if (($checklist[$key] ?? false) !== true) {
                throw ValidationException::withMessages([
                    "checklist.$key" => ['This verification item must be completed before recommendation.'],
                ]);
            }
        }
    }

    private function applyFilters(Builder $query, Request $request): void
    {
        if ($request->filled('application_type')) {
            $request->validate(['application_type' => [Rule::in(RoleApplication::TYPES)]]);
            $query->where('application_type', $request->string('application_type'));
        }
        if ($request->filled('status')) {
            $request->validate(['status' => [Rule::in(RoleApplication::STATUSES)]]);
            $query->where('status', $request->string('status'));
        }
        if ($request->filled('date_from')) {
            $request->validate(['date_from' => 'date']);
            $query->whereDate('submitted_at', '>=', $request->date('date_from'));
        }
        if ($request->filled('date_to')) {
            $request->validate(['date_to' => 'date']);
            $query->whereDate('submitted_at', '<=', $request->date('date_to'));
        }
        if ($request->filled('search')) {
            $term = '%'.trim((string) $request->input('search')).'%';
            $query->where(function (Builder $search) use ($term): void {
                $search->where('payload', 'like', $term)
                    ->orWhereHas('applicant', fn (Builder $user) => $user->where('name', 'like', $term)->orWhere('email', 'like', $term))
                    ->orWhereHas('requestedTouristSpot', fn (Builder $spot) => $spot->where('name', 'like', $term));
            });
        }
    }

    /** @return array<int, string> */
    private function relations(): array
    {
        $relations = [
            'applicant:id,name,email,phone,role_id',
            'applicant.role:id,name',
            'requestedTouristSpot:id,name,address,is_active,category_id',
            'requestedTouristSpot.category:id,name,slug',
            'linkedMsme:id,profile_id,name,category,address,latitude,longitude,is_verified,verification_status',
            'lguReviewer:id,name,email',
            'adminReviewer:id,name,email',
            'history.actor:id,name,email',
        ];
        if (Schema::hasTable('msme_categories') && Schema::hasColumn('role_applications', 'requested_msme_category_id')) {
            array_push($relations, 'requestedMsmeCategory:id,name,slug', 'recommendedMsmeCategory:id,name,slug', 'finalMsmeCategory:id,name,slug');
        }

        return $relations;
    }

    /** @return array<int, array{id: string|null, name: string, slug: string}> */
    private function msmeCategories(): array
    {
        if (! Schema::hasTable('msme_categories')) {
            return collect(self::MSME_CATEGORIES)->map(fn (string $name) => [
                'id' => null, 'name' => $name, 'slug' => Str::slug($name),
            ])->all();
        }

        return MsmeCategory::where('is_active', true)->orderBy('display_order')->orderBy('name')
            ->get(['id', 'name', 'slug'])->toArray();
    }

    private function recordTransition(
        RoleApplication $application,
        ?string $actorId,
        string $action,
        ?string $from,
        ?string $to,
        ?string $notes = null,
        ?array $metadata = null,
    ): void {
        RoleApplicationHistory::create([
            'application_id' => $application->id,
            'actor_user_id' => $actorId,
            'action' => $action,
            'from_status' => $from,
            'to_status' => $to,
            'notes' => $notes,
            'metadata' => $metadata,
        ]);
    }

    private function notifyRole(string $role, string $title, string $body, RoleApplication $application, string $route): void
    {
        User::whereHas('role', fn (Builder $query) => $query->where('name', $role))
            ->pluck('id')
            ->each(fn (string $id) => $this->notifyUser($id, $title, $body, $application, $route));
    }

    private function notifyUser(
        string $userId,
        string $title,
        string $body,
        RoleApplication $application,
        string $route,
        array $extra = [],
    ): void {
        Notification::create([
            'user_id' => $userId,
            'type' => 'role_application',
            'title' => $title,
            'body' => $body,
            'data' => [
                'application_id' => $application->id,
                'application_type' => $application->application_type,
                'application_status' => $application->status,
                'route' => $route,
                ...$extra,
            ],
            'is_read' => false,
        ]);
    }

    private function audit(string $actorId, string $action, RoleApplication $application, array $metadata = []): void
    {
        ActivityLog::create([
            'user_id' => $actorId,
            'action' => $action,
            'details' => json_encode([
                'target_type' => 'role_application',
                'target_id' => $application->id,
                'applicant_user_id' => $application->applicant_user_id,
                'application_type' => $application->application_type,
                'status' => $application->status,
                ...$metadata,
            ]),
        ]);
    }

    private function applicationLabel(RoleApplication $application): string
    {
        return $application->application_type === RoleApplication::TYPE_MSME
            ? 'MSME Owner application'
            : 'Tourism Partner application';
    }
}
