<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreFerryOperatorRequest;
use App\Http\Requests\StoreFerryPortRequest;
use App\Http\Requests\StoreFerryRouteRequest;
use App\Http\Requests\StoreFerryVesselRequest;
use App\Http\Requests\UpsertFerryScheduleRequest;
use App\Models\ActivityLog;
use App\Models\FerryOperator;
use App\Models\FerryPort;
use App\Models\FerryRoute;
use App\Models\FerrySchedule;
use App\Models\FerryVessel;
use App\Support\StaleRecordGuard;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class FerryScheduleController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = FerrySchedule::query();
        if (Schema::hasColumn('ferry_schedules', 'is_active')) {
            $query->where('is_active', true);
        }
        if (Schema::hasColumn('ferry_schedules', 'is_published')) {
            $query->where('is_published', true)->whereNull('archived_at');
        }
        if (Schema::hasColumn('ferry_schedules', 'ferry_operator_id') && Schema::hasTable('ferry_operators')) {
            $query->where(fn ($operators) => $operators
                ->whereNull('ferry_operator_id')
                ->orWhereHas('ferryOperator', fn ($operator) => $operator->where('is_active', true)));
        }
        if (Schema::hasColumn('ferry_schedules', 'departure_date')) {
            $query->where(fn ($date) => $date
                ->whereNull('departure_date')
                ->orWhereDate('departure_date', '>=', today()));
        }
        if (Schema::hasColumn('ferry_schedules', 'valid_from')) {
            $query->where(fn ($date) => $date->whereNull('valid_from')->orWhereDate('valid_from', '<=', today()))
                ->where(fn ($date) => $date->whereNull('valid_until')->orWhereDate('valid_until', '>=', today()));
        }
        if ($request->filled('operator_id') && Schema::hasColumn('ferry_schedules', 'ferry_operator_id')) {
            $query->where('ferry_operator_id', $request->string('operator_id'));
        } elseif ($request->filled('operator')) {
            $query->whereRaw('LOWER(operator) = ?', [Str::lower(trim((string) $request->query('operator')))]);
        }
        if ($request->filled('origin')) {
            $query->whereRaw('LOWER(origin) = ?', [Str::lower(trim((string) $request->query('origin')))]);
        }
        if ($request->filled('destination')) {
            $query->whereRaw('LOWER(destination) = ?', [Str::lower(trim((string) $request->query('destination')))]);
        }

        $schedules = $query->with($this->scheduleRelations())
            ->orderBy('operator')
            ->orderBy('origin')
            ->orderBy('destination')
            ->orderBy('departure_time')
            ->get()
            ->map(fn (FerrySchedule $schedule): array => $this->scheduleData($schedule));

        return response()->json(['status' => 'success', 'data' => $schedules]);
    }

    public function operators(): JsonResponse
    {
        if (! Schema::hasTable('ferry_operators')) {
            return response()->json(['status' => 'success', 'data' => []]);
        }

        $operators = FerryOperator::query()
            ->where('is_active', true)
            ->with(['vessels' => fn ($query) => $query->where('is_active', true)->orderBy('vessel_name')])
            ->orderBy('name')
            ->get();

        return response()->json(['status' => 'success', 'data' => $operators]);
    }

    public function managementIndex(): JsonResponse
    {
        $schedules = FerrySchedule::query()
            ->with($this->scheduleRelations())
            ->orderBy('operator')
            ->orderByDesc('departure_date')
            ->orderBy('departure_time')
            ->get()
            ->map(fn (FerrySchedule $schedule): array => $this->scheduleData($schedule, true));

        return response()->json(['status' => 'success', 'data' => $schedules]);
    }

    public function catalogs(): JsonResponse
    {
        $operators = Schema::hasTable('ferry_operators')
            ? FerryOperator::where('is_active', true)
                ->with(['vessels' => fn ($query) => $query->where('is_active', true)->orderBy('vessel_name')])
                ->orderBy('name')->get()
            : [];

        return response()->json(['status' => 'success', 'data' => [
            'ports' => Schema::hasTable('ferry_ports') ? FerryPort::where('is_active', true)->orderBy('name')->get() : [],
            'routes' => Schema::hasTable('ferry_routes') ? FerryRoute::with(['originPort', 'destinationPort'])->where('is_active', true)->orderBy('name')->get() : [],
            'operators' => $operators,
            'statuses' => ['scheduled', 'boarding', 'delayed', 'departed', 'arrived', 'cancelled', 'suspended'],
        ]]);
    }

    public function managementOperators(): JsonResponse
    {
        return response()->json(['status' => 'success', 'data' => FerryOperator::with(['vessels' => fn ($query) => $query->orderBy('vessel_name')])
            ->orderBy('name')->get(),
        ]);
    }

    public function storeOperator(StoreFerryOperatorRequest $request): JsonResponse
    {
        $operator = DB::transaction(function () use ($request): FerryOperator {
            $data = $request->validated();
            unset($data['expected_updated_at']);
            $data['name'] = $this->canonicalOperatorName($data['name']);
            abort_if(FerryOperator::whereRaw('LOWER(name) = ?', [Str::lower($data['name'])])->exists(), 422, 'A ferry operator with this name already exists.');
            $operator = FerryOperator::create($data);
            $this->log($request, 'Ferry operator created', ['ferry_operator_id' => $operator->id]);

            return $operator;
        });

        return response()->json(['status' => 'success', 'data' => $operator->load('vessels')], 201);
    }

    public function updateOperator(StoreFerryOperatorRequest $request, FerryOperator $operator): JsonResponse
    {
        $operator = DB::transaction(function () use ($request, $operator): FerryOperator {
            $operator = FerryOperator::whereKey($operator->id)->lockForUpdate()->firstOrFail();
            StaleRecordGuard::assertCurrent($operator, $request->validated('expected_updated_at'));
            $data = $request->validated();
            unset($data['expected_updated_at']);
            $data['name'] = $this->canonicalOperatorName($data['name']);
            abort_if(FerryOperator::where('id', '!=', $operator->id)->whereRaw('LOWER(name) = ?', [Str::lower($data['name'])])->exists(), 422, 'A ferry operator with this name already exists.');
            $operator->update($data);
            FerrySchedule::where('ferry_operator_id', $operator->id)->update(['operator' => $operator->name]);
            $this->log($request, 'Ferry operator updated', ['ferry_operator_id' => $operator->id]);

            return $operator->refresh()->load('vessels');
        });

        return response()->json(['status' => 'success', 'data' => $operator]);
    }

    public function storeVessel(StoreFerryVesselRequest $request): JsonResponse
    {
        $vessel = DB::transaction(function () use ($request): FerryVessel {
            $data = $request->validated();
            unset($data['expected_updated_at']);
            $vessel = FerryVessel::create($data);
            $this->log($request, 'Ferry vessel created', ['ferry_vessel_id' => $vessel->id]);

            return $vessel;
        });

        return response()->json(['status' => 'success', 'data' => $vessel->load('ferryOperator')], 201);
    }

    public function updateVessel(StoreFerryVesselRequest $request, FerryVessel $vessel): JsonResponse
    {
        $vessel = DB::transaction(function () use ($request, $vessel): FerryVessel {
            $vessel = FerryVessel::whereKey($vessel->id)->lockForUpdate()->firstOrFail();
            StaleRecordGuard::assertCurrent($vessel, $request->validated('expected_updated_at'));
            $data = $request->validated();
            unset($data['expected_updated_at']);
            $vessel->update($data);
            FerrySchedule::where('ferry_vessel_id', $vessel->id)->update(['vessel_name' => $vessel->vessel_name]);
            $this->log($request, 'Ferry vessel updated', ['ferry_vessel_id' => $vessel->id]);

            return $vessel->refresh()->load('ferryOperator');
        });

        return response()->json(['status' => 'success', 'data' => $vessel]);
    }

    public function storePort(StoreFerryPortRequest $request): JsonResponse
    {
        $port = DB::transaction(function () use ($request): FerryPort {
            $port = FerryPort::create($request->validated());
            $this->log($request, 'Ferry port created', ['ferry_port_id' => $port->id, 'code' => $port->code]);

            return $port;
        });

        return response()->json(['status' => 'success', 'data' => $port], 201);
    }

    public function updatePort(StoreFerryPortRequest $request, FerryPort $port): JsonResponse
    {
        DB::transaction(function () use ($request, $port): void {
            $port->update($request->validated());
            $this->log($request, 'Ferry port updated', ['ferry_port_id' => $port->id]);
        });

        return response()->json(['status' => 'success', 'data' => $port->refresh()]);
    }

    public function storeRoute(StoreFerryRouteRequest $request): JsonResponse
    {
        $route = DB::transaction(function () use ($request): FerryRoute {
            $route = FerryRoute::create($request->validated());
            $this->log($request, 'Ferry route created', ['ferry_route_id' => $route->id]);

            return $route;
        });

        return response()->json(['status' => 'success', 'data' => $route->load(['originPort', 'destinationPort'])], 201);
    }

    public function updateRoute(StoreFerryRouteRequest $request, FerryRoute $route): JsonResponse
    {
        DB::transaction(function () use ($request, $route): void {
            $route->update($request->validated());
            $this->log($request, 'Ferry route updated', ['ferry_route_id' => $route->id]);
        });

        return response()->json(['status' => 'success', 'data' => $route->refresh()->load(['originPort', 'destinationPort'])]);
    }

    public function store(UpsertFerryScheduleRequest $request): JsonResponse
    {
        $validated = $request->validated();
        unset($validated['expected_updated_at']);
        $validated = $this->resolveOperatorAndVessel($this->resolveStructuredRoute($this->normalizeSchedule($validated)));
        if (isset($validated['origin'], $validated['destination'])) {
            abort_if(Str::lower(trim($validated['origin'])) === Str::lower(trim($validated['destination'])), 422, 'Origin and destination must be different.');
        }
        $this->assertScheduleWindow($validated);
        $validated['status'] ??= 'scheduled';
        $validated['route'] = $validated['route'] ?? "{$validated['origin']} to {$validated['destination']}";
        if (Schema::hasColumn('ferry_schedules', 'created_by')) {
            $validated['created_by'] = $request->user()->id;
        }
        if (Schema::hasColumn('ferry_schedules', 'updated_by')) {
            $validated['updated_by'] = $request->user()->id;
        }
        if (Schema::hasColumn('ferry_schedules', 'is_published')) {
            $validated['is_published'] ??= (bool) ($validated['is_active'] ?? false);
            $validated['published_at'] = $validated['is_published'] ? now() : null;
        }

        $schedule = DB::transaction(function () use ($request, $validated): FerrySchedule {
            $schedule = FerrySchedule::create($validated);
            $this->log($request, 'Ferry schedule created', ['ferry_schedule_id' => $schedule->id]);

            return $schedule;
        });

        return response()->json(['status' => 'success', 'data' => $this->scheduleData($schedule->load($this->scheduleRelations()), true)], 201);
    }

    public function update(UpsertFerryScheduleRequest $request, string $id): JsonResponse
    {
        $expectedUpdatedAt = $request->validated('expected_updated_at');
        $validated = $request->validated();
        unset($validated['expected_updated_at']);

        $schedule = DB::transaction(function () use ($request, $id, $validated, $expectedUpdatedAt): FerrySchedule {
            $schedule = FerrySchedule::whereKey($id)->lockForUpdate()->firstOrFail();
            StaleRecordGuard::assertCurrent($schedule, $expectedUpdatedAt, $this->scheduleData($schedule, true));
            $data = $this->resolveOperatorAndVessel(
                $this->resolveStructuredRoute($this->normalizeSchedule($validated)),
                $schedule,
            );
            $effectiveOrigin = $data['origin'] ?? $schedule->origin;
            $effectiveDestination = $data['destination'] ?? $schedule->destination;
            if ($effectiveOrigin && $effectiveDestination) {
                abort_if(Str::lower(trim($effectiveOrigin)) === Str::lower(trim($effectiveDestination)), 422, 'Origin and destination must be different.');
            }
            $this->assertScheduleWindow($data, $schedule);
            if (isset($data['status']) && $data['status'] !== $schedule->status) {
                $transitions = ['scheduled' => ['boarding', 'delayed', 'cancelled', 'suspended'], 'boarding' => ['departed', 'delayed', 'cancelled', 'suspended'], 'delayed' => ['boarding', 'departed', 'cancelled', 'suspended'], 'departed' => ['arrived'], 'arrived' => [], 'cancelled' => ['scheduled'], 'suspended' => ['scheduled', 'cancelled']];
                abort_unless(in_array($data['status'], $transitions[$schedule->status] ?? [], true), 422, "Invalid ferry status transition from {$schedule->status}.");
            }
            if (isset($data['origin'], $data['destination'])) {
                $data['route'] = "{$data['origin']} to {$data['destination']}";
            }
            if (Schema::hasColumn('ferry_schedules', 'updated_by')) {
                $data['updated_by'] = $request->user()->id;
            }
            if (array_key_exists('is_published', $data)) {
                $data['published_at'] = $data['is_published'] ? ($schedule->published_at ?? now()) : null;
            }
            $before = $schedule->only(['status', 'advisory', 'is_published']);
            $schedule->update($data);
            $action = $before['status'] !== $schedule->status
                ? 'Ferry status changed'
                : (($before['is_published'] ?? null) !== $schedule->is_published
                    ? ($schedule->is_published ? 'Ferry schedule published' : 'Ferry schedule unpublished')
                    : 'Ferry schedule updated');
            $this->log($request, $action, ['ferry_schedule_id' => $schedule->id]);

            return $schedule->refresh()->load($this->scheduleRelations());
        });

        return response()->json(['status' => 'success', 'data' => $this->scheduleData($schedule, true)]);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        DB::transaction(function () use ($request, $id): void {
            $schedule = FerrySchedule::whereKey($id)->lockForUpdate()->firstOrFail();
            StaleRecordGuard::assertCurrent($schedule, StaleRecordGuard::expectedUpdatedAt($request));
            if (Schema::hasColumn('ferry_schedules', 'archived_at')) {
                $archive = ['is_active' => false, 'is_published' => false, 'archived_at' => now()];
                if (Schema::hasColumn('ferry_schedules', 'updated_by')) {
                    $archive['updated_by'] = $request->user()->id;
                }
                $schedule->update($archive);
            }
            $schedule->delete();
            $this->log($request, 'Ferry schedule archived', ['ferry_schedule_id' => $schedule->id]);
        });

        return response()->json(['status' => 'success', 'message' => 'Ferry schedule archived']);
    }

    private function normalizeSchedule(array $data): array
    {
        foreach (['departure_time', 'arrival_time'] as $field) {
            if (empty($data[$field])) {
                continue;
            }
            $value = trim((string) $data[$field]);
            if (preg_match('/^([01]?\d|2[0-3]):([0-5]\d)\s*([AP]M)$/i', $value, $matches)) {
                $hour = (int) $matches[1];
                if ($hour === 12) {
                    $hour = 0;
                }
                if (strtoupper($matches[3]) === 'PM') {
                    $hour += 12;
                }
                $data[$field] = sprintf('%02d:%s', $hour, $matches[2]);
            }
        }
        if (isset($data['days_of_week'])) {
            $aliases = ['mon' => 'monday', 'tue' => 'tuesday', 'wed' => 'wednesday', 'thu' => 'thursday', 'fri' => 'friday', 'sat' => 'saturday', 'sun' => 'sunday'];
            $data['days_of_week'] = array_values(array_unique(array_map(
                fn (string $day): string => $aliases[strtolower($day)] ?? strtolower($day),
                $data['days_of_week'],
            )));
        }

        return $data;
    }

    private function resolveOperatorAndVessel(array $data, ?FerrySchedule $existing = null): array
    {
        if (! Schema::hasTable('ferry_operators')) {
            return $data;
        }

        $operator = null;
        $operatorId = $data['ferry_operator_id'] ?? $existing?->ferry_operator_id;
        if ($operatorId) {
            $operator = FerryOperator::findOrFail($operatorId);
            abort_unless($operator->is_active || $existing?->ferry_operator_id === $operator->id, 422, 'The selected ferry operator is inactive.');
        } elseif (! empty($data['operator'])) {
            $canonical = $this->canonicalOperatorName($data['operator']);
            $operator = FerryOperator::whereRaw('LOWER(name) = ?', [Str::lower($canonical)])->first();
            if ($operator) {
                $data['ferry_operator_id'] = $operator->id;
            }
            $data['operator'] = $operator?->name ?? $canonical;
        }
        if ($operator) {
            $data['ferry_operator_id'] = $operator->id;
            $data['operator'] = $operator->name;
        }

        if (array_key_exists('ferry_vessel_id', $data) && $data['ferry_vessel_id'] === null) {
            $data['vessel_name'] = null;

            return $data;
        }
        $vesselId = array_key_exists('ferry_vessel_id', $data)
            ? $data['ferry_vessel_id']
            : $existing?->ferry_vessel_id;
        if ($vesselId) {
            $vessel = FerryVessel::findOrFail($vesselId);
            $effectiveOperatorId = $data['ferry_operator_id'] ?? $existing?->ferry_operator_id;
            abort_unless($effectiveOperatorId && $vessel->ferry_operator_id === $effectiveOperatorId, 422, 'The selected vessel does not belong to this ferry operator.');
            abort_unless($vessel->is_active || $existing?->ferry_vessel_id === $vessel->id, 422, 'The selected ferry vessel is inactive.');
            $data['vessel_name'] = $vessel->vessel_name;
        } elseif (! empty($data['vessel_name']) && ($data['ferry_operator_id'] ?? $existing?->ferry_operator_id)) {
            $vessel = FerryVessel::where('ferry_operator_id', $data['ferry_operator_id'] ?? $existing?->ferry_operator_id)
                ->whereRaw('LOWER(vessel_name) = ?', [Str::lower(trim($data['vessel_name']))])->first();
            if ($vessel) {
                $data['ferry_vessel_id'] = $vessel->id;
            }
        }

        return $data;
    }

    private function resolveStructuredRoute(array $data): array
    {
        if (! empty($data['ferry_route_id']) && Schema::hasTable('ferry_routes')) {
            $route = FerryRoute::with(['originPort', 'destinationPort'])->findOrFail($data['ferry_route_id']);
            abort_unless($route->is_active, 422, 'The selected ferry route is inactive.');
            $data['origin_port_id'] = $route->origin_port_id;
            $data['destination_port_id'] = $route->destination_port_id;
            $data['origin'] = $route->originPort->name;
            $data['destination'] = $route->destinationPort->name;
            $data['route'] = $route->name;
        } elseif (! empty($data['origin_port_id']) && ! empty($data['destination_port_id'])) {
            $origin = FerryPort::whereKey($data['origin_port_id'])->where('is_active', true)->firstOrFail();
            $destination = FerryPort::whereKey($data['destination_port_id'])->where('is_active', true)->firstOrFail();
            abort_if($origin->is($destination), 422, 'Origin and destination must be different.');
            $data['origin'] = $origin->name;
            $data['destination'] = $destination->name;
            $data['route'] = "{$origin->name} to {$destination->name}";
        }

        return $data;
    }

    private function scheduleRelations(): array
    {
        $relations = ['ferryRoute.originPort', 'ferryRoute.destinationPort'];
        if (Schema::hasTable('ferry_operators')) {
            $relations[] = 'ferryOperator';
        }
        if (Schema::hasTable('ferry_vessels')) {
            $relations[] = 'ferryVessel';
        }

        return $relations;
    }

    private function assertScheduleWindow(array $data, ?FerrySchedule $existing = null): void
    {
        $scheduleDate = array_key_exists('departure_date', $data)
            ? $data['departure_date']
            : $existing?->departure_date;
        $effectiveFrom = array_key_exists('valid_from', $data)
            ? $data['valid_from']
            : $existing?->valid_from;
        $effectiveUntil = array_key_exists('valid_until', $data)
            ? $data['valid_until']
            : $existing?->valid_until;

        abort_if($scheduleDate && ($effectiveFrom || $effectiveUntil), 422, 'Use either a schedule date or an effective period, not both.');
        abort_if($effectiveUntil && ! $effectiveFrom, 422, 'An effective end date requires an effective start date.');
        abort_if($effectiveFrom && $effectiveUntil && Carbon::parse($effectiveUntil)->lt(Carbon::parse($effectiveFrom)), 422, 'The effective end date must be on or after the start date.');
    }

    private function scheduleData(FerrySchedule $schedule, bool $management = false): array
    {
        $data = $schedule->toArray();
        $data['operator_id'] = $schedule->ferry_operator_id;
        $data['operator_name'] = $schedule->relationLoaded('ferryOperator') ? ($schedule->ferryOperator?->name ?? $schedule->operator) : $schedule->operator;
        $data['vessel_id'] = $schedule->ferry_vessel_id;
        $data['vessel_name'] = $schedule->relationLoaded('ferryVessel') ? ($schedule->ferryVessel?->vessel_name ?? $schedule->vessel_name) : $schedule->vessel_name;
        $data['schedule_date'] = $schedule->departure_date?->format('Y-m-d');
        $data['effective_from'] = $schedule->valid_from?->format('Y-m-d');
        $data['effective_until'] = $schedule->valid_until?->format('Y-m-d');
        $data['operating_days'] = $schedule->days_of_week;
        $data['notes'] = $schedule->advisory;
        $data['last_updated'] = $schedule->updated_at?->toIso8601String();
        unset($data['ferry_operator'], $data['ferry_vessel']);
        if (! $management) {
            unset($data['created_by'], $data['updated_by'], $data['source_reference'], $data['reference_url'], $data['archived_at'], $data['deleted_at']);
        }

        return $data;
    }

    private function canonicalOperatorName(string $name): string
    {
        $trimmed = preg_replace('/\s+/', ' ', trim($name)) ?? '';

        return match (Str::lower($trimmed)) {
            'fastcat', 'fast cat' => 'FastCat',
            'lite ferry', 'lite ferries' => 'Lite Ferries',
            'mv star craft', 'mv starcraft', 'starcraft' => 'MV Starcraft',
            default => $trimmed,
        };
    }

    private function log(Request $request, string $action, array $details): void
    {
        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => $action,
            'details' => json_encode($details),
        ]);
    }
}
