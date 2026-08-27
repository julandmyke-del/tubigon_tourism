<?php

namespace App\Http\Controllers\Concerns;

use App\Support\TubigonBoundary;
use Illuminate\Validation\ValidationException;

trait ValidatesTubigonCoordinates
{
    protected function validateTubigonCoordinates(
        array $data,
        ?float $currentLatitude = null,
        ?float $currentLongitude = null,
    ): void {
        $hasLatitude = array_key_exists('latitude', $data);
        $hasLongitude = array_key_exists('longitude', $data);
        if (! $hasLatitude && ! $hasLongitude) {
            return;
        }

        $latitude = $hasLatitude ? $data['latitude'] : $currentLatitude;
        $longitude = $hasLongitude ? $data['longitude'] : $currentLongitude;
        if ($latitude === null && $longitude === null) {
            return;
        }
        if ($latitude === null || $longitude === null) {
            throw ValidationException::withMessages([
                'latitude' => ['Latitude and longitude must be supplied together.'],
                'longitude' => ['Latitude and longitude must be supplied together.'],
            ]);
        }

        if (! app(TubigonBoundary::class)->contains((float) $latitude, (float) $longitude)) {
            $message = 'The selected location must be within the Municipality of Tubigon, Bohol.';
            throw ValidationException::withMessages([
                'latitude' => [$message],
                'longitude' => [$message],
            ]);
        }
    }
}
