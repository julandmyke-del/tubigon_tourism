<?php

namespace App\Support;

use App\Models\MapLocation;
use App\Models\Msme;
use App\Models\TourismListing;
use App\Models\TouristSpot;

final class ItineraryPlaceResolver
{
    public const TYPES = ['map_location', 'tourist_spot', 'msme', 'tourism_listing'];

    public function resolve(string $type, string $id): ?array
    {
        return match ($type) {
            'map_location' => $this->mapLocation($id),
            'tourist_spot' => $this->touristSpot($id),
            'msme' => $this->msme($id),
            'tourism_listing' => $this->tourismListing($id),
            default => null,
        };
    }

    private function mapLocation(string $id): ?array
    {
        $place = MapLocation::with(['category', 'subcategory'])
            ->where('active', true)
            ->where('verified', true)
            ->where('published', true)
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->find($id);

        if (! $place) {
            return null;
        }

        $data = $place->toPlaceArray();

        return $this->shape(
            'map_location',
            (string) $place->id,
            $data['name'],
            $data['category'],
            $data['description'],
            $data['address'],
            $data['latitude'],
            $data['longitude'],
            $data['operating_hours'],
            $data['images'],
            (bool) $data['is_verified'],
        );
    }

    private function touristSpot(string $id): ?array
    {
        $place = TouristSpot::with('category')
            ->where('is_active', true)
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->find($id);

        return $place ? $this->shape(
            'tourist_spot',
            (string) $place->id,
            $place->name,
            $place->category?->name ?? 'Tourist Spot',
            $place->description,
            $place->address,
            $place->latitude,
            $place->longitude,
            $place->opening_hours,
            $place->images ?? [],
            true,
        ) : null;
    }

    private function msme(string $id): ?array
    {
        $place = Msme::where('is_verified', true)
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->find($id);

        return $place ? $this->shape(
            'msme',
            (string) $place->id,
            $place->name,
            $place->category ?? 'MSME',
            $place->description,
            $place->address,
            $place->latitude,
            $place->longitude,
            $place->business_hours,
            [],
            true,
        ) : null;
    }

    private function tourismListing(string $id): ?array
    {
        $place = TourismListing::where('is_active', true)
            ->whereIn('status', ['active', 'approved'])
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->find($id);

        return $place ? $this->shape(
            'tourism_listing',
            (string) $place->id,
            $place->listing_name,
            $place->listing_type ?? 'Tourism Listing',
            $place->description,
            $place->address,
            $place->latitude,
            $place->longitude,
            $place->operating_hours,
            $place->images ?? [],
            true,
        ) : null;
    }

    private function shape(
        string $type,
        string $id,
        string $name,
        string $category,
        ?string $description,
        ?string $address,
        float $latitude,
        float $longitude,
        ?string $operatingHours,
        array $images,
        bool $verified,
    ): array {
        return [
            'entity_type' => $type,
            'entity_id' => $id,
            'marker_id' => "$type:$id",
            'name' => $name,
            'category' => $category,
            'description' => $description,
            'address' => $address,
            'latitude' => $latitude,
            'longitude' => $longitude,
            'operating_hours' => $operatingHours,
            'images' => $images,
            'is_verified' => $verified,
        ];
    }
}
