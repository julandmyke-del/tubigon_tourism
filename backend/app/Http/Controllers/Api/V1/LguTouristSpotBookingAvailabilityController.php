<?php

namespace App\Http\Controllers\Api\V1;

use App\Actions\UpdateTouristSpotBookingAvailabilityAction;
use App\Http\Controllers\Controller;
use App\Models\TouristSpot;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

class LguTouristSpotBookingAvailabilityController extends Controller
{
    public function update(
        Request $request,
        string $id,
        UpdateTouristSpotBookingAvailabilityAction $action,
    ): JsonResponse {
        $spot = TouristSpot::findOrFail($id);
        Gate::forUser($request->user())->authorize('manageBookingAvailability', $spot);
        $validated = $request->validate([
            'booking_enabled' => 'required|boolean',
            'reason_code' => [
                Rule::requiredIf(! $request->boolean('booking_enabled')),
                'nullable',
                Rule::in(config('tourist_spot_partners.unavailable_reason_codes', [])),
            ],
            'reason' => 'nullable|string|max:2000',
        ]);

        return response()->json([
            'status' => 'success',
            'data' => $action->execute(
                $spot,
                $request->user(),
                (bool) $validated['booking_enabled'],
                $validated['reason_code'] ?? null,
                $validated['reason'] ?? null,
            ),
        ]);
    }
}
