<?php

namespace App\Support;

use RuntimeException;

final class TubigonBoundary
{
    public const NAME = 'Municipality of Tubigon, Bohol, Philippines';

    public const PSGC = '0701245000';

    public const CENTER_LATITUDE = 9.9515287;

    public const CENTER_LONGITUDE = 123.9618897;

    private const MIN_LATITUDE = 9.884021;

    private const MAX_LATITUDE = 10.072237;

    private const MIN_LONGITUDE = 123.881415;

    private const MAX_LONGITUDE = 124.029692;

    // The authoritative land polygon ends at the shoreline. These tight
    // bounds cover only Tubigon's passenger-port service area so seaport pins
    // are not incorrectly rejected as outside the municipality.
    private const PORT_MIN_LATITUDE = 9.9545;

    private const PORT_MAX_LATITUDE = 9.9575;

    private const PORT_MIN_LONGITUDE = 123.9565;

    private const PORT_MAX_LONGITUDE = 123.9595;

    private ?array $polygons = null;

    public function contains(float $latitude, float $longitude): bool
    {
        if ($latitude < self::MIN_LATITUDE || $latitude > self::MAX_LATITUDE
            || $longitude < self::MIN_LONGITUDE || $longitude > self::MAX_LONGITUDE) {
            return false;
        }

        foreach ($this->polygons() as $polygon) {
            if (empty($polygon) || ! $this->ringContains($polygon[0], $latitude, $longitude)) {
                continue;
            }

            foreach (array_slice($polygon, 1) as $hole) {
                if ($this->ringContains($hole, $latitude, $longitude)) {
                    continue 2;
                }
            }

            return true;
        }

        return false;
    }

    public function containsPortServiceArea(float $latitude, float $longitude): bool
    {
        return $latitude >= self::PORT_MIN_LATITUDE
            && $latitude <= self::PORT_MAX_LATITUDE
            && $longitude >= self::PORT_MIN_LONGITUDE
            && $longitude <= self::PORT_MAX_LONGITUDE;
    }

    private function polygons(): array
    {
        if ($this->polygons !== null) {
            return $this->polygons;
        }

        $path = resource_path('data/tubigon_boundary.geojson');
        $feature = json_decode((string) file_get_contents($path), true);
        if (($feature['geometry']['type'] ?? null) !== 'MultiPolygon'
            || empty($feature['geometry']['coordinates'])) {
            throw new RuntimeException('The Tubigon municipal boundary asset is invalid.');
        }

        return $this->polygons = $feature['geometry']['coordinates'];
    }

    private function ringContains(array $ring, float $latitude, float $longitude): bool
    {
        $inside = false;
        $count = count($ring);
        for ($current = 0, $previous = $count - 1; $current < $count; $previous = $current++) {
            [$aLongitude, $aLatitude] = $ring[$previous];
            [$bLongitude, $bLatitude] = $ring[$current];

            if ($this->onSegment(
                (float) $aLatitude,
                (float) $aLongitude,
                (float) $bLatitude,
                (float) $bLongitude,
                $latitude,
                $longitude,
            )) {
                return true;
            }

            $crosses = ($aLatitude > $latitude) !== ($bLatitude > $latitude);
            if ($crosses) {
                $intersection = ($bLongitude - $aLongitude)
                    * ($latitude - $aLatitude)
                    / ($bLatitude - $aLatitude)
                    + $aLongitude;
                if ($longitude < $intersection) {
                    $inside = ! $inside;
                }
            }
        }

        return $inside;
    }

    private function onSegment(
        float $aLatitude,
        float $aLongitude,
        float $bLatitude,
        float $bLongitude,
        float $latitude,
        float $longitude,
    ): bool {
        $epsilon = 1e-9;
        $cross = ($longitude - $aLongitude) * ($bLatitude - $aLatitude)
            - ($latitude - $aLatitude) * ($bLongitude - $aLongitude);
        if (abs($cross) > $epsilon) {
            return false;
        }

        return $longitude >= min($aLongitude, $bLongitude) - $epsilon
            && $longitude <= max($aLongitude, $bLongitude) + $epsilon
            && $latitude >= min($aLatitude, $bLatitude) - $epsilon
            && $latitude <= max($aLatitude, $bLatitude) + $epsilon;
    }
}
