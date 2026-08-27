<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\EmergencyContact;
use App\Models\MapLocation;
use App\Models\MapLocationCategory;
use App\Models\Msme;
use App\Models\TourismListing;
use App\Models\TouristSpot;
use App\Models\WasteReport;
use App\Support\TubigonBoundary;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class MapController extends Controller
{
    private ?Collection $categoryMetadataBySlug = null;

    public function __construct(private readonly TubigonBoundary $boundary) {}

    /** Public, deliberately limited map data for guests. */
    public function publicIndex(): JsonResponse
    {
        return $this->responseFor(null, null);
    }

    /** Role-aware map data. Sanctum and role checks remain the security boundary. */
    public function authenticatedIndex(Request $request): JsonResponse
    {
        $user = $request->user();
        $user->loadMissing('role');

        return $this->responseFor($user->role?->name, (string) $user->id);
    }

    private function responseFor(?string $role, ?string $userId): JsonResponse
    {
        $managed = $this->managedLocations();
        $linkedSpotIds = $managed->where('type', 'tourist_spot')->pluck('source_id')->all();
        $linkedMsmeIds = $managed->where('type', 'msme')->pluck('source_id')->all();
        $locations = collect()
            ->concat($managed)
            ->concat($this->touristSpots($linkedSpotIds))
            ->concat($this->publicMsmes($linkedMsmeIds))
            ->concat($this->emergencyLocations($role))
            ->concat($this->publicPartnerListings());

        if ($role === 'msme_owner' && $userId) {
            $locations = $locations->concat($this->ownedMsmes($userId, $linkedMsmeIds));
        }

        if ($role === 'tourism_partner' && $userId) {
            $locations = $locations->concat($this->ownedPartnerListings($userId));
        }

        if (in_array($role, ['lgu_staff', 'admin'], true)) {
            $locations = $locations->concat($this->wasteReports());
        }

        if ($role === 'admin') {
            $locations = $locations->concat($this->allMsmes($linkedMsmeIds));
        }

        // The API is the authoritative scope boundary. Existing out-of-scope
        // records remain in MySQL but can never leak into the Smart Map feed.
        $locations = $locations
            ->filter(fn (array $location) => $this->boundary->contains(
                (float) $location['latitude'],
                (float) $location['longitude'],
            ))
            // Later role-specific records win so owners retain their flags.
            ->reverse()->unique('id')->reverse()->values();

        return response()->json([
            'status' => 'success',
            'data' => $locations,
            'meta' => [
                'role' => $role ?? 'guest',
                'geographic_scope' => [
                    'name' => TubigonBoundary::NAME,
                    'psgc' => TubigonBoundary::PSGC,
                    'center' => [
                        'latitude' => TubigonBoundary::CENTER_LATITUDE,
                        'longitude' => TubigonBoundary::CENTER_LONGITUDE,
                    ],
                ],
                'capabilities' => [
                    'navigation' => in_array($role, [null, 'guest', 'tourist'], true),
                    'favorites' => $role === 'tourist',
                    'waste_monitoring' => in_array($role, ['lgu_staff', 'admin'], true),
                    'manage_map_data' => in_array($role, ['lgu_staff', 'admin'], true),
                ],
            ],
        ]);
    }

    private function managedLocations(): Collection
    {
        if (! Schema::hasTable('map_locations')) {
            return collect();
        }

        return MapLocation::with(['category', 'subcategory'])
            ->where('published', true)
            ->where('verified', true)
            ->where('active', true)
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->whereHas('category', fn ($query) => $query->where('active', true))
            ->get()
            ->map(fn (MapLocation $location) => $location->toPlaceArray());
    }

    private function touristSpots(array $excludedIds = []): Collection
    {
        $query = TouristSpot::with('category')
            ->where('is_active', true)
            ->whereNotNull('latitude')->whereNotNull('longitude');
        if ($excludedIds) {
            $query->whereNotIn('id', $excludedIds);
        }

        return $query->get()->map(function (TouristSpot $spot) {
            $specific = Str::slug($spot->category?->name ?? '');
            $meta = $this->categoryMeta($specific, 'tourist-spots', 'Tourist Spots', 'landscape', '#F59E0B', 10);

            return array_merge([
                'id' => "tourist_spot:{$spot->id}",
                'source_id' => (string) $spot->id,
                'source_integer_id' => $spot->integer_id,
                'type' => 'tourist_spot',
                'name' => $spot->name,
                'category' => $spot->category?->name ?? 'Attraction',
                'category_keys' => array_values(array_unique(array_filter(['tourist-spots', $specific]))),
                'description' => $spot->description,
                'address' => $spot->address,
                'latitude' => $spot->latitude,
                'longitude' => $spot->longitude,
                'images' => $spot->images ?? [],
                'rating' => $spot->average_rating,
                'review_count' => $spot->review_count,
                'operating_hours' => $spot->opening_hours,
                'is_verified' => true,
                'is_owned' => false,
                'is_featured' => (bool) $spot->is_featured,
                'view_count' => 0,
                'created_at' => $spot->created_at?->toISOString(),
            ], $meta);
        });
    }

    private function publicMsmes(array $excludedIds = []): Collection
    {
        $query = Msme::where('is_verified', true)
            ->whereNotNull('latitude')->whereNotNull('longitude');
        if ($excludedIds) {
            $query->whereNotIn('id', $excludedIds);
        }

        return $query->get()->map(fn (Msme $msme) => $this->msmeLocation($msme, false));
    }

    private function ownedMsmes(string $userId, array $excludedIds = []): Collection
    {
        $query = Msme::where('profile_id', $userId)
            ->whereNotNull('latitude')->whereNotNull('longitude');
        if ($excludedIds) {
            $query->whereNotIn('id', $excludedIds);
        }

        return $query->get()->map(fn (Msme $msme) => $this->msmeLocation($msme, true));
    }

    private function allMsmes(array $excludedIds = []): Collection
    {
        $query = Msme::whereNotNull('latitude')->whereNotNull('longitude');
        if ($excludedIds) {
            $query->whereNotIn('id', $excludedIds);
        }

        return $query->get()->map(fn (Msme $msme) => $this->msmeLocation($msme, false));
    }

    private function msmeLocation(Msme $msme, bool $owned): array
    {
        $specific = Str::slug($msme->category ?? '');
        $meta = $this->categoryMeta($specific, 'msmes', 'MSMEs', 'storefront', '#0284C7', 20);

        return array_merge([
            'id' => "msme:{$msme->id}",
            'source_id' => (string) $msme->id,
            'source_integer_id' => $msme->integer_id,
            'type' => 'msme',
            'name' => $msme->name,
            'category' => $msme->category,
            'category_keys' => array_values(array_unique(array_filter(['msmes', $specific]))),
            'description' => $msme->description,
            'address' => $msme->address,
            'latitude' => $msme->latitude,
            'longitude' => $msme->longitude,
            'images' => [],
            'rating' => $msme->rating,
            'review_count' => $msme->review_count,
            'operating_hours' => $msme->business_hours,
            'contact' => $msme->phone,
            'is_verified' => (bool) $msme->is_verified,
            'is_owned' => $owned,
            'is_featured' => false,
            'view_count' => 0,
            'created_at' => $msme->created_at?->toISOString(),
        ], $meta);
    }

    private function emergencyLocations(?string $role): Collection
    {
        $query = EmergencyContact::where('is_active', true)
            ->whereNotNull('latitude')->whereNotNull('longitude')
            ->when(
                ! in_array($role, ['lgu_staff', 'admin'], true),
                fn ($query) => $query->where('is_verified', true),
            );

        return $query->get()->map(fn (EmergencyContact $contact) => array_merge([
            'id' => "emergency:{$contact->id}",
            'source_id' => (string) $contact->id,
            'source_integer_id' => $contact->integer_id,
            'type' => 'emergency',
            'name' => $contact->name,
            'category' => $contact->category,
            'category_keys' => ['emergency'],
            'description' => $contact->description ?? 'Public emergency service location',
            'address' => $contact->address,
            'latitude' => $contact->latitude,
            'longitude' => $contact->longitude,
            'images' => [],
            'operating_hours' => $contact->operating_hours,
            'contact' => $contact->phone,
            'status' => $contact->classification,
            'is_verified' => $contact->is_verified,
            'is_owned' => false,
            'is_featured' => false,
            'view_count' => 0,
            'created_at' => $contact->created_at?->toISOString(),
        ], $this->categoryMeta('emergency', 'emergency', 'Emergency', 'emergency', '#E11D48', 110)));
    }

    private function publicPartnerListings(): Collection
    {
        return TourismListing::where('is_active', true)
            ->whereIn('status', ['active', 'approved'])
            ->whereNotNull('latitude')->whereNotNull('longitude')
            ->get()->map(fn (TourismListing $listing) => $this->partnerLocation($listing, false));
    }

    private function ownedPartnerListings(string $userId): Collection
    {
        return TourismListing::where('owner_id', $userId)
            ->where('is_active', true)
            ->whereIn('status', ['active', 'approved'])
            ->whereNotNull('latitude')->whereNotNull('longitude')
            ->get()->map(fn (TourismListing $listing) => $this->partnerLocation($listing, true));
    }

    private function partnerLocation(TourismListing $listing, bool $owned): array
    {
        $specific = Str::slug($listing->listing_type ?? '');
        $fallback = str_contains($specific, 'hotel') || str_contains($specific, 'accommodation')
            ? ['accommodation', 'Accommodation', 'hotel', '#7C3AED', 70]
            : ['important-places', 'Important Places', 'place', '#7C3AED', 140];
        $meta = $this->categoryMeta($specific, ...$fallback);

        return array_merge([
            'id' => "tourism_listing:{$listing->id}",
            'source_id' => (string) $listing->id,
            'type' => 'tourism_listing',
            'name' => $listing->listing_name,
            'category' => $listing->listing_type,
            'category_keys' => array_values(array_unique(array_filter([$fallback[0], $specific]))),
            'description' => $listing->description,
            'address' => $listing->address,
            'latitude' => $listing->latitude,
            'longitude' => $listing->longitude,
            'images' => $listing->images ?? [],
            'rating' => $listing->average_rating,
            'review_count' => $listing->review_count,
            'operating_hours' => $listing->operating_hours,
            'contact' => $listing->contact_number,
            'status' => $listing->status,
            'is_verified' => in_array($listing->status, ['active', 'approved'], true),
            'is_owned' => $owned,
            'is_featured' => false,
            'view_count' => 0,
            'created_at' => $listing->created_at?->toISOString(),
        ], $meta);
    }

    private function wasteReports(): Collection
    {
        return WasteReport::whereNotNull('latitude')->whereNotNull('longitude')
            ->latest()->limit(500)->get()->map(fn (WasteReport $report) => [
                'id' => "waste_report:{$report->id}",
                'source_id' => (string) $report->id,
                'type' => 'waste_report',
                'name' => $report->category,
                'category' => $report->category,
                'description' => $report->description,
                'address' => $report->location_description,
                'latitude' => $report->latitude,
                'longitude' => $report->longitude,
                'images' => $report->images ?? [],
                'status' => $report->status,
                'is_verified' => false,
                'is_owned' => false,
                'category_slug' => 'waste-reports',
                'category_keys' => ['waste-reports'],
                'category_icon' => 'delete_sweep',
                'marker_color' => '#DC2626',
                'category_sort_order' => 999,
            ]);
    }

    private function categoryMeta(
        string $preferredSlug,
        string $fallbackSlug,
        string $fallbackName,
        string $fallbackIcon,
        string $fallbackColor,
        int $fallbackOrder,
    ): array {
        $categories = $this->activeCategoryMetadata();
        $category = $categories->get($preferredSlug) ?? $categories->get($fallbackSlug);

        return [
            'category_id' => $category?->id,
            'category_slug' => $category?->slug ?? $fallbackSlug,
            'category_icon' => $category?->icon ?? $fallbackIcon,
            'marker_color' => $category?->marker_color ?? $fallbackColor,
            'category_sort_order' => $category?->sort_order ?? $fallbackOrder,
            'category_label' => $category?->name ?? $fallbackName,
        ];
    }

    /** Load category styling once per map-feed request instead of once per entity. */
    private function activeCategoryMetadata(): Collection
    {
        if ($this->categoryMetadataBySlug !== null) {
            return $this->categoryMetadataBySlug;
        }

        if (! Schema::hasTable('map_location_categories')) {
            return $this->categoryMetadataBySlug = collect();
        }

        return $this->categoryMetadataBySlug = MapLocationCategory::where('active', true)
            ->get()
            ->keyBy('slug');
    }
}
