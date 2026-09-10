<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreFerryPortRequest;
use App\Http\Requests\StoreFerryRouteRequest;
use App\Http\Requests\UpsertFerryScheduleRequest;
use App\Models\ActivityLog;
use App\Models\FerryPort;
use App\Models\FerryRoute;
use App\Models\FerrySchedule;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\Rule;

class FerryScheduleController extends Controller
{
    public function index(): JsonResponse
    {
        $query = FerrySchedule::query();
        if (Schema::hasColumn('ferry_schedules', 'is_active')) {
            $query->where('is_active', true);
        }
        if (Schema::hasColumn('ferry_schedules', 'is_published')) {
            $query->where('is_published', true)->whereNull('archived_at');
        }
        if (Schema::hasColumn('ferry_schedules', 'departure_date')) {
            $query->where(fn ($date) => $date->whereNull('departure_date')->orWhereDate('departure_date', '>=', today()));
        }
        if (Schema::hasColumn('ferry_schedules', 'departure_date')) {
            $query->orderByRaw('departure_date IS NULL DESC')->orderBy('departure_date');
        }
        $schedules = $query->with(['ferryRoute.originPort', 'ferryRoute.destinationPort'])->orderBy('departure_time')->get();

        return response()->json(['status' => 'success', 'data' => $schedules]);
    }

    public function managementIndex(): JsonResponse
    {
        $query = FerrySchedule::query();
        if (Schema::hasColumn('ferry_schedules', 'departure_date')) {
            $query->orderByDesc('departure_date');
        }

        return response()->json([
            'status' => 'success',
            'data' => $query->orderBy('departure_time')->get(),
        ]);
    }

    public function catalogs(): JsonResponse
    {
        return response()->json(['status' => 'success', 'data' => [
            'ports' => Schema::hasTable('ferry_ports') ? FerryPort::where('is_active', true)->orderBy('name')->get() : [],
            'routes' => Schema::hasTable('ferry_routes') ? FerryRoute::with(['originPort', 'destinationPort'])->where('is_active', true)->orderBy('name')->get() : [],
            'statuses' => ['scheduled', 'boarding', 'delayed', 'departed', 'arrived', 'cancelled', 'suspended'],
        ]]);
    }

    public function storePort(StoreFerryPortRequest $request): JsonResponse
    {
        $port = DB::transaction(function () use ($request): FerryPort {
            $port = FerryPort::create($request->validated());
            ActivityLog::create(['user_id' => $request->user()->id, 'action' => 'Ferry port created', 'details' => json_encode(['ferry_port_id' => $port->id, 'code' => $port->code])]);

            return $port;
        });

        return response()->json(['status' => 'success', 'data' => $port], 201);
    }

    public function updatePort(StoreFerryPortRequest $request, FerryPort $port): JsonResponse
    {
        DB::transaction(function () use ($request, $port): void {
            $before = $port->only(['name', 'code', 'is_active']);
            $port->update($request->validated());
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'Ferry port updated',
                'details' => json_encode([
                    'ferry_port_id' => $port->id,
                    'before' => $before,
                    'after' => $port->only(['name', 'code', 'is_active']),
                ]),
            ]);
        });

        return response()->json(['status' => 'success', 'data' => $port->refresh()]);
    }

    public function storeRoute(StoreFerryRouteRequest $request): JsonResponse
    {
        $route = DB::transaction(function () use ($request): FerryRoute {
            $route = FerryRoute::create($request->validated());
            ActivityLog::create(['user_id' => $request->user()->id, 'action' => 'Ferry route created', 'details' => json_encode(['ferry_route_id' => $route->id, 'origin_port_id' => $route->origin_port_id, 'destination_port_id' => $route->destination_port_id])]);

            return $route;
        });

        return response()->json(['status' => 'success', 'data' => $route->load(['originPort', 'destinationPort'])], 201);
    }

    public function updateRoute(StoreFerryRouteRequest $request, FerryRoute $route): JsonResponse
    {
        DB::transaction(function () use ($request, $route): void {
            $before = $route->only(['name', 'origin_port_id', 'destination_port_id', 'is_active']);
            $route->update($request->validated());
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'Ferry route updated',
                'details' => json_encode([
                    'ferry_route_id' => $route->id,
                    'before' => $before,
                    'after' => $route->only(['name', 'origin_port_id', 'destination_port_id', 'is_active']),
                ]),
            ]);
        });

        return response()->json([
            'status' => 'success',
            'data' => $route->refresh()->load(['originPort', 'destinationPort']),
        ]);
    }

    public function store(UpsertFerryScheduleRequest $request): JsonResponse
    {
        $validated = $this->normalizeSchedule($request->validated());
        $validated = $this->resolveStructuredRoute($validated);
        $validated['status'] ??= 'scheduled';
        $validated['route'] = $validated['route'] ?? "{$validated['origin']} to {$validated['destination']}";
        if (Schema::hasColumn('ferry_schedules', 'is_published')) {
            $validated['is_published'] ??= (bool) ($validated['is_active'] ?? false);
            if ($validated['is_published']) {
                $validated['published_at'] = now();
            }
        }
        if (Schema::hasColumn('ferry_schedules', 'updated_by')) {
            $validated['updated_by'] = $request->user()->id;
        }
        $schedule = DB::transaction(function () use ($request, $validated): FerrySchedule {
            $schedule = FerrySchedule::create($validated);
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'Ferry schedule created',
                'details' => "Created ferry schedule {$schedule->route}",
            ]);

            return $schedule;
        });

        return response()->json(['status' => 'success', 'data' => $schedule], 201);
    }

    public function update(UpsertFerryScheduleRequest $request, string $id): JsonResponse
    {
        $schedule = FerrySchedule::findOrFail($id);
        $validated = $this->resolveStructuredRoute($this->normalizeSchedule($request->validated()));
        if (isset($validated['status']) && $validated['status'] !== $schedule->status) {
            $transitions = ['scheduled' => ['boarding', 'delayed', 'cancelled', 'suspended'], 'boarding' => ['departed', 'delayed', 'cancelled', 'suspended'], 'delayed' => ['boarding', 'departed', 'cancelled', 'suspended'], 'departed' => ['arrived'], 'arrived' => [], 'cancelled' => ['scheduled'], 'suspended' => ['scheduled', 'cancelled']];
            abort_unless(in_array($validated['status'], $transitions[$schedule->status] ?? [], true), 422, "Invalid ferry status transition from {$schedule->status}.");
        }
        if (isset($validated['origin'], $validated['destination'])) {
            $validated['route'] = "{$validated['origin']} to {$validated['destination']}";
        }
        if (Schema::hasColumn('ferry_schedules', 'updated_by')) {
            $validated['updated_by'] = $request->user()->id;
        }
        $before = $schedule->only(['status', 'advisory', 'is_published']);
        if (array_key_exists('is_published', $validated)) {
            $validated['published_at'] = $validated['is_published'] ? ($schedule->published_at ?? now()) : null;
        }
        DB::transaction(function () use ($request, $schedule, $validated, $before): void {
            $schedule->update($validated);
            $action = ($before['status'] ?? null) !== $schedule->status ? 'Ferry status changed' : ((($before['is_published'] ?? null) !== $schedule->is_published) ? ($schedule->is_published ? 'Ferry schedule published' : 'Ferry schedule unpublished') : ((($before['advisory'] ?? null) !== $schedule->advisory) ? 'Ferry advisory updated' : 'Ferry schedule updated'));
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => $action,
                'details' => "Updated ferry schedule {$schedule->route}",
            ]);
        });

        return response()->json(['status' => 'success', 'data' => $schedule]);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        DB::transaction(function () use ($request, $id): void {
            $schedule = FerrySchedule::findOrFail($id);
            if (Schema::hasColumn('ferry_schedules', 'archived_at')) {
                $schedule->update(['is_active' => false, 'is_published' => false, 'archived_at' => now()]);
            }
            $schedule->delete();
            ActivityLog::create([
                'user_id' => $request->user()->id,
                'action' => 'Ferry schedule archived',
                'details' => "Archived ferry schedule {$schedule->route}",
            ]);
        });

        return response()->json(['status' => 'success', 'message' => 'Ferry schedule archived']);
    }

    private function rules(bool $updating = false): array
    {
        $required = $updating ? 'sometimes' : 'required';
        $routeRule = $updating ? 'nullable' : 'nullable|required_without_all:origin,destination';
        $endpointRule = $updating ? 'nullable' : 'nullable|required_without:route';

        return [
            'operator' => "$required|string|min:2|max:255",
            'route' => "$routeRule|string|max:255",
            'origin' => "$endpointRule|string|min:2|max:255|different:destination",
            'destination' => "$endpointRule|string|min:2|max:255|different:origin",
            'vessel_name' => 'nullable|string|max:255',
            'departure_date' => 'nullable|date|after_or_equal:today',
            'departure_time' => [$required, 'regex:/^(?:(?:[01]?\d|2[0-3]):[0-5]\d|(?:0?[1-9]|1[0-2]):[0-5]\d\s*[AP]M)$/i'],
            'arrival_time' => ['nullable', 'regex:/^(?:(?:[01]?\d|2[0-3]):[0-5]\d|(?:0?[1-9]|1[0-2]):[0-5]\d\s*[AP]M)$/i'],
            'fare' => 'nullable|numeric|min:0|max:999999.99',
            'status' => ['nullable', Rule::in(['scheduled', 'delayed', 'cancelled', 'boarding', 'departed', 'completed', 'suspended'])],
            'days_of_week' => 'nullable|array|max:7',
            'days_of_week.*' => ['string', 'regex:/^(?:mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)$/i'],
            'advisory' => 'nullable|string|max:2000',
            'contact_information' => 'nullable|string|max:255',
            'reference_url' => 'nullable|url:http,https|max:2000',
            'is_active' => 'sometimes|boolean',
        ];
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
            $aliases = [
                'mon' => 'monday', 'tue' => 'tuesday', 'wed' => 'wednesday',
                'thu' => 'thursday', 'fri' => 'friday', 'sat' => 'saturday',
                'sun' => 'sunday',
            ];
            $data['days_of_week'] = array_values(array_unique(array_map(
                fn (string $day): string => $aliases[strtolower($day)] ?? strtolower($day),
                $data['days_of_week'],
            )));
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
            $data['origin'] = $origin->name;
            $data['destination'] = $destination->name;
            $data['route'] = "{$origin->name} to {$destination->name}";
        }

        return $data;
    }
}
