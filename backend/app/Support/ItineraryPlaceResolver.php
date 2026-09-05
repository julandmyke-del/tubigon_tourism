<?php

namespace App\Support;

use App\Models\MapLocation;
use App\Models\Msme;
use App\Models\TourismListing;
use App\Models\TouristSpot;
use Illuminate\Support\Facades\Schema;

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
            ->whereNotNull('latitude')->whereBetween('latitude', [-90, 90])
            ->whereNotNull('longitude')->whereBetween('longitude', [-180, 180])
            ->find($id);

        if (! $place) {
            return null;
        }

        $data = $place->toPlaceArray();
        if (($data['category_slug'] ?? null) === 'emergency') {
            return null;
        }

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
            $data['source_integer_id'] ?? null,
            (bool) ($data['is_bookable'] ?? false),
            (bool) ($data['booking_enabled'] ?? false),
            $data['booking_unavailable_reason'] ?? null,
        );
    }

    private function touristSpot(string $id): ?array
    {
        $place = TouristSpot::with('category')
            ->where('is_active', true)
            ->when(
                Schema::hasColumn('tourist_spots', 'is_published'),
                fn ($query) => $query->where('is_published', true),
            )
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
            $place->integer_id === null ? null : (int) $place->integer_id,
            (bool) ($place->is_bookable ?? false),
            (bool) ($place->booking_enabled ?? false),
            $place->booking_unavailable_reason,
        ) : null;
    }

    private function msme(string $id): ?array
    {
        $place = Msme::where('is_verified', true)
            ->where('verification_status', 'verified')
            ->when(
                Schema::hasColumn('msmes', 'operational_status'),
                fn ($query) => $query->whereIn('operational_status', ['open', 'temporarily_closed', 'fully_booked']),
            )
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
            $place->images ?? [],
            true,
            $place->integer_id === null ? null : (int) $place->integer_id,
            (bool) ($place->booking_enabled ?? false),
            (bool) ($place->booking_enabled ?? false),
        ) : null;
    }

    private function tourismListing(string $id): ?array
    {
        $place = TourismListing::where('is_active', true)
            ->whereIn('status', ['active', 'approved'])
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
            $place->integer_id,
        ) : null;
    }

    private function shape(
        string $type,
        string $id,
        string $name,
        string $category,
        ?string $description,
        ?string $address,
        ?float $latitude,
        ?float $longitude,
        ?string $operatingHours,
        array $images,
        bool $verified,
        ?int $integerId = null,
        bool $isBookable = false,
        bool $bookingEnabled = false,
        ?string $bookingUnavailableReason = null,
    ): array {
        return [
            'entity_type' => $type,
            'entity_id' => $id,
            'source_integer_id' => $integerId,
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
            'is_bookable' => $isBookable,
            'booking_enabled' => $bookingEnabled,
            'booking_unavailable_reason' => $bookingUnavailableReason,
        ];
    }
}
