<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\CreateOfferingReservationRequest;
use App\Http\Requests\UpsertBookingOfferingRequest;
use App\Models\ActivityLog;
use App\Models\BookingOffering;
use App\Models\BookingOfferingField;
use App\Models\TouristSpot;
use App\Services\BookingOfferingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Schema;

class BookingOfferingController extends Controller
{
    public function publicIndex(string $spot): JsonResponse
    {
        $s = TouristSpot::whereKey($spot)->where('is_active', true)->where('is_published', true)->firstOrFail();
        $items = $s->bookingOfferings()->with(['fields' => fn ($q) => $q->where('is_active', true)])->where('is_active', true)->orderBy('sort_order')->get();
        $cover = Schema::hasTable('tourist_spot_media') ? $s->media()->where('is_active', true)->where('is_cover', true)->first() : null;

        return response()->json(['status' => 'success', 'data' => $items, 'meta' => ['destination_name' => $s->name, 'cover_url' => $cover ? url("/api/v1/tourist-spot-media/{$cover->id}") : null, 'booking_enabled' => (bool) ($s->is_bookable && $s->booking_enabled), 'unavailable_reason' => $s->booking_unavailable_reason]]);
    }

    public function partnerIndex(Request $r, string $spot): JsonResponse
    {
        $s = TouristSpot::findOrFail($spot);
        Gate::forUser($r->user())->authorize('viewManaged', $s);

        return response()->json(['status' => 'success', 'data' => $s->bookingOfferings()->with('fields')->orderBy('sort_order')->get()]);
    }

    public function store(UpsertBookingOfferingRequest $r, string $spot): JsonResponse
    {
        $s = TouristSpot::findOrFail($spot);
        Gate::forUser($r->user())->authorize('updateManagedContent', $s);
        $o = $this->persist($r, $s);

        return response()->json(['status' => 'success', 'data' => $o], 201);
    }

    public function update(UpsertBookingOfferingRequest $r, string $spot, string $offering): JsonResponse
    {
        $s = TouristSpot::findOrFail($spot);
        Gate::forUser($r->user())->authorize('updateManagedContent', $s);
        $o = $s->bookingOfferings()->findOrFail($offering);
        $o = $this->persist($r, $s, $o);

        return response()->json(['status' => 'success', 'data' => $o]);
    }

    public function destroy(Request $r, string $spot, string $offering): JsonResponse
    {
        $s = TouristSpot::findOrFail($spot);
        Gate::forUser($r->user())->authorize('updateManagedContent', $s);
        $o = $s->bookingOfferings()->findOrFail($offering);
        $o->update(['is_active' => false]);
        ActivityLog::create(['user_id' => $r->user()->id, 'action' => 'Booking offering disabled', 'details' => json_encode(['tourist_spot_id' => $s->id, 'offering_id' => $o->id])]);

        return response()->json(['status' => 'success']);
    }

    public function reserve(CreateOfferingReservationRequest $r, BookingOfferingService $service): JsonResponse
    {
        $reservation = $service->create($r->user(), $r->validated());

        return response()->json(['status' => 'success', 'data' => $reservation], 201);
    }

    private function persist(UpsertBookingOfferingRequest $r, TouristSpot $s, ?BookingOffering $o = null): BookingOffering
    {
        return DB::transaction(function () use ($r, $s, $o) {
            $d = $r->safe()->except('fields');
            $d['tourist_spot_id'] = $s->id;
            $d['created_by_user_id'] = $o?->created_by_user_id ?? $r->user()->id;
            $o ? $o->update($d) : $o = BookingOffering::create($d);
            if ($r->has('fields')) {
                $o->fields()->delete();
                foreach ($r->validated('fields', []) as $f) {
                    BookingOfferingField::create([...$f, 'offering_id' => $o->id]);
                }
            }ActivityLog::create(['user_id' => $r->user()->id, 'action' => $o->wasRecentlyCreated ? 'Booking offering created' : 'Booking offering updated', 'details' => json_encode(['tourist_spot_id' => $s->id, 'offering_id' => $o->id, 'price' => $o->price, 'is_active' => $o->is_active])]);

            return $o->load('fields');
        }, 3);
    }
}
