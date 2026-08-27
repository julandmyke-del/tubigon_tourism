<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Itinerary;
use App\Models\ItineraryItem;
use App\Models\Reservation;
use App\Support\ItineraryPlaceResolver;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class ItineraryController extends Controller
{
    public function __construct(private readonly ItineraryPlaceResolver $places) {}

    public function index(Request $request): JsonResponse
    {
        $this->assertTourist($request);
        $itineraries = Itinerary::where('user_id', $request->user()->id)
            ->withCount('items')
            ->orderBy('start_date')
            ->orderByDesc('created_at')
            ->get()
            ->map(fn (Itinerary $itinerary) => $this->present($itinerary, false));

        return response()->json(['status' => 'success', 'data' => $itineraries]);
    }

    public function store(Request $request): JsonResponse
    {
        $this->assertTourist($request);
        $data = $this->validatedItinerary($request);
        $this->assertDateRange($data['start_date'], $data['end_date']);
        $data['user_id'] = $request->user()->id;
        $data['status'] = $data['status'] ?? 'draft';

        $itinerary = Itinerary::create($data);

        return response()->json([
            'status' => 'success',
            'data' => $this->present($itinerary->load('items.reservation.status')),
        ], 201);
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $this->assertTourist($request);
        $itinerary = $this->owned($request, $id)->load('items.reservation.status');

        return response()->json(['status' => 'success', 'data' => $this->present($itinerary)]);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $this->assertTourist($request);
        $itinerary = $this->owned($request, $id);
        $data = $this->validatedItinerary($request, true);
        $start = $data['start_date'] ?? $itinerary->start_date->toDateString();
        $end = $data['end_date'] ?? $itinerary->end_date->toDateString();
        $this->assertDateRange($start, $end);

        if (isset($data['status']) && $data['status'] === 'active') {
            $today = now()->startOfDay();
            if ($today->lt(Carbon::parse($start)) || $today->gt(Carbon::parse($end))) {
                throw ValidationException::withMessages([
                    'status' => ['A trip can only be started during its scheduled dates.'],
                ]);
            }
        }

        $itinerary->update($data);

        return response()->json([
            'status' => 'success',
            'data' => $this->present($itinerary->fresh()->load('items.reservation.status')),
        ]);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        $this->assertTourist($request);
        $itinerary = $this->owned($request, $id);
        DB::transaction(function () use ($itinerary) {
            $itinerary->items()->delete();
            $itinerary->update(['status' => 'archived']);
            $itinerary->delete();
        });

        return response()->json(['status' => 'success', 'message' => 'Itinerary archived.']);
    }

    public function storeItem(Request $request, string $id): JsonResponse
    {
        $this->assertTourist($request);
        $itinerary = $this->owned($request, $id);
        $data = $this->validatedItem($request);
        $this->assertDay($itinerary, (int) $data['day_number']);

        $place = $this->places->resolve($data['entity_type'], $data['entity_id']);
        if (! $place) {
            throw ValidationException::withMessages([
                'entity_id' => ['This place is unavailable or is not published for tourists.'],
            ]);
        }

        $existing = $itinerary->items()
            ->where('day_number', $data['day_number'])
            ->where('entity_type', $data['entity_type'])
            ->where('entity_id', $data['entity_id'])
            ->first();
        if ($existing && ! $request->boolean('allow_duplicate')) {
            return response()->json([
                'status' => 'duplicate',
                'message' => "{$place['name']} is already included in Day {$data['day_number']}.",
                'data' => ['existing_item_id' => $existing->id],
            ], 409);
        }

        $data['sort_order'] = $itinerary->items()
            ->where('day_number', $data['day_number'])
            ->max('sort_order') + 1;
        $data['reservation_id'] = $this->reservationFor(
            $request,
            $itinerary,
            $data['entity_type'],
            $data['entity_id'],
            (int) $data['day_number'],
            $data['reservation_id'] ?? null,
        );

        $item = $itinerary->items()->create($data);

        return response()->json([
            'status' => 'success',
            'data' => $this->presentItem($item->load('reservation.status')),
        ], 201);
    }

    public function updateItem(Request $request, string $id, string $itemId): JsonResponse
    {
        $this->assertTourist($request);
        $itinerary = $this->owned($request, $id);
        $item = $itinerary->items()->findOrFail($itemId);
        $data = $this->validatedItem($request, true);
        $day = (int) ($data['day_number'] ?? $item->day_number);
        $this->assertDay($itinerary, $day);

        if (array_key_exists('reservation_id', $data)) {
            $data['reservation_id'] = $this->reservationFor(
                $request,
                $itinerary,
                $item->entity_type,
                $item->entity_id,
                $day,
                $data['reservation_id'],
                false,
            );
        }

        $item->update($data);

        return response()->json([
            'status' => 'success',
            'data' => $this->presentItem($item->fresh()->load('reservation.status')),
        ]);
    }

    public function destroyItem(Request $request, string $id, string $itemId): JsonResponse
    {
        $this->assertTourist($request);
        $itinerary = $this->owned($request, $id);
        $item = $itinerary->items()->findOrFail($itemId);
        $day = $item->day_number;
        $item->delete();
        $this->normalizeOrder($itinerary, $day);

        return response()->json(['status' => 'success', 'message' => 'Itinerary stop removed.']);
    }

    public function reorderItems(Request $request, string $id): JsonResponse
    {
        $this->assertTourist($request);
        $itinerary = $this->owned($request, $id);
        $data = $request->validate([
            'items' => ['required', 'array', 'min:1', 'max:100'],
            'items.*.id' => ['required', 'uuid'],
            'items.*.day_number' => ['required', 'integer', 'min:1'],
            'items.*.sort_order' => ['required', 'integer', 'min:1'],
        ]);

        $ownedIds = $itinerary->items()->whereIn('id', collect($data['items'])->pluck('id'))->pluck('id');
        if ($ownedIds->count() !== count($data['items'])) {
            throw ValidationException::withMessages(['items' => ['One or more stops do not belong to this itinerary.']]);
        }

        foreach ($data['items'] as $position) {
            $this->assertDay($itinerary, (int) $position['day_number']);
        }

        DB::transaction(function () use ($itinerary, $data) {
            foreach ($data['items'] as $position) {
                $itinerary->items()->whereKey($position['id'])->update([
                    'day_number' => $position['day_number'],
                    'sort_order' => $position['sort_order'],
                ]);
            }
        });

        return response()->json([
            'status' => 'success',
            'data' => $this->present($itinerary->fresh()->load('items.reservation.status')),
        ]);
    }

    private function validatedItinerary(Request $request, bool $partial = false): array
    {
        $required = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'name' => [$required, 'string', 'max:120'],
            'description' => ['nullable', 'string', 'max:2000'],
            'start_date' => [$required, 'date'],
            'end_date' => [$required, 'date'],
            'travelers' => ['nullable', 'integer', 'min:1', 'max:100'],
            'status' => ['sometimes', Rule::in(['draft', 'upcoming', 'active', 'completed', 'archived'])],
            'start_location_type' => ['sometimes', Rule::in(['current_location', 'first_stop', 'map_location', 'custom'])],
            'start_location_name' => ['nullable', 'string', 'max:255'],
            'start_location_id' => ['nullable', 'uuid'],
            'start_latitude' => ['nullable', 'numeric', 'between:-90,90', 'required_with:start_longitude'],
            'start_longitude' => ['nullable', 'numeric', 'between:-180,180', 'required_with:start_latitude'],
        ]);
    }

    private function validatedItem(Request $request, bool $partial = false): array
    {
        $required = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'entity_type' => [$required, Rule::in(ItineraryPlaceResolver::TYPES)],
            'entity_id' => [$required, 'uuid'],
            'day_number' => [$required, 'integer', 'min:1', 'max:31'],
            'sort_order' => ['sometimes', 'integer', 'min:1', 'max:100'],
            'planned_start_time' => ['nullable', 'date_format:H:i'],
            'planned_end_time' => ['nullable', 'date_format:H:i', 'after:planned_start_time'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'reservation_id' => ['nullable', 'uuid'],
            'visit_status' => ['sometimes', Rule::in(['planned', 'visited', 'skipped'])],
            'allow_duplicate' => ['sometimes', 'boolean'],
        ]);
    }

    private function owned(Request $request, string $id): Itinerary
    {
        return Itinerary::where('user_id', $request->user()->id)->findOrFail($id);
    }

    private function assertTourist(Request $request): void
    {
        $request->user()->loadMissing('role');
        abort_unless($request->user()->role?->name === 'tourist', 403, 'Only Tourist/User accounts can manage itineraries.');
    }

    private function assertDateRange(string $start, string $end): void
    {
        $startDate = Carbon::parse($start)->startOfDay();
        $endDate = Carbon::parse($end)->startOfDay();
        if ($endDate->lt($startDate)) {
            throw ValidationException::withMessages(['end_date' => ['The end date must be on or after the start date.']]);
        }
        if ($startDate->diffInDays($endDate) > 30) {
            throw ValidationException::withMessages(['end_date' => ['An itinerary may cover at most 31 days.']]);
        }
    }

    private function assertDay(Itinerary $itinerary, int $day): void
    {
        $days = $itinerary->start_date->diffInDays($itinerary->end_date) + 1;
        if ($day > $days) {
            throw ValidationException::withMessages(['day_number' => ["This itinerary only has $days day(s)."]]);
        }
    }

    private function reservationFor(
        Request $request,
        Itinerary $itinerary,
        string $entityType,
        string $entityId,
        int $day,
        ?string $reservationId,
        bool $autoDetect = true,
    ): ?string {
        if (! Schema::hasTable('reservations')) {
            return null;
        }

        $reservableType = match ($entityType) {
            'tourist_spot' => 'spot',
            'msme' => 'msme',
            'tourism_listing' => 'tourism_listing',
            default => null,
        };
        if (! $reservableType) {
            return null;
        }

        $query = Reservation::where('user_id', $request->user()->id)
            ->where('reservable_type', $reservableType)
            ->where('reservable_id', $entityId);

        if ($reservationId) {
            $reservation = $query->find($reservationId);
            if (! $reservation) {
                throw ValidationException::withMessages([
                    'reservation_id' => ['The reservation does not belong to you or does not match this place.'],
                ]);
            }

            return (string) $reservation->id;
        }

        if (! $autoDetect) {
            return null;
        }

        $plannedDate = $itinerary->start_date->copy()->addDays($day - 1)->toDateString();

        return $query->whereDate('reservation_date', $plannedDate)
            ->latest('reservation_date')
            ->value('id');
    }

    private function normalizeOrder(Itinerary $itinerary, int $day): void
    {
        $itinerary->items()->where('day_number', $day)->get()
            ->each(fn (ItineraryItem $item, int $index) => $item->update(['sort_order' => $index + 1]));
    }

    private function effectiveStatus(Itinerary $itinerary): string
    {
        if (in_array($itinerary->status, ['archived', 'completed', 'active'], true)) {
            return $itinerary->status;
        }
        $today = now()->startOfDay();
        if ($today->gt($itinerary->end_date)) {
            return 'completed';
        }
        if ($today->betweenIncluded($itinerary->start_date, $itinerary->end_date)) {
            return 'active';
        }
        if ($today->lt($itinerary->start_date) && $itinerary->status !== 'draft') {
            return 'upcoming';
        }

        return $itinerary->status;
    }

    private function present(Itinerary $itinerary, bool $withItems = true): array
    {
        $items = $withItems
            ? $itinerary->items->map(fn (ItineraryItem $item) => $this->presentItem($item))->values()->all()
            : [];

        return [
            'id' => (string) $itinerary->id,
            'name' => $itinerary->name,
            'description' => $itinerary->description,
            'start_date' => $itinerary->start_date->toDateString(),
            'end_date' => $itinerary->end_date->toDateString(),
            'day_count' => $itinerary->start_date->diffInDays($itinerary->end_date) + 1,
            'travelers' => $itinerary->travelers,
            'status' => $this->effectiveStatus($itinerary),
            'stored_status' => $itinerary->status,
            'start_location_type' => $itinerary->start_location_type,
            'start_location_name' => $itinerary->start_location_name,
            'start_location_id' => $itinerary->start_location_id,
            'start_latitude' => $itinerary->start_latitude,
            'start_longitude' => $itinerary->start_longitude,
            'place_count' => $itinerary->items_count ?? count($items),
            'items' => $items,
            'created_at' => $itinerary->created_at?->toISOString(),
            'updated_at' => $itinerary->updated_at?->toISOString(),
        ];
    }

    private function presentItem(ItineraryItem $item): array
    {
        $reservation = $item->reservation;

        return [
            'id' => (string) $item->id,
            'itinerary_id' => (string) $item->itinerary_id,
            'entity_type' => $item->entity_type,
            'entity_id' => (string) $item->entity_id,
            'day_number' => $item->day_number,
            'sort_order' => $item->sort_order,
            'planned_start_time' => $item->planned_start_time,
            'planned_end_time' => $item->planned_end_time,
            'notes' => $item->notes,
            'visit_status' => $item->visit_status,
            'place' => $this->places->resolve($item->entity_type, $item->entity_id),
            'reservation' => $reservation ? [
                'id' => (string) $reservation->id,
                'date' => $reservation->reservation_date?->toDateString(),
                'start_time' => $reservation->start_time,
                'end_time' => $reservation->end_time,
                'status' => $reservation->status?->name,
            ] : null,
        ];
    }
}
