<?php

namespace Database\Seeders;

use App\Models\SpotCategory;
use App\Models\TouristSpot;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class FeaturedDestinationSeeder extends Seeder
{
    public const NAMES = [
        'Mundong Sandbar',
        'Dumog Sandbar',
        'Mocaboc Sandbar',
        'Mangrove Forest Batasan',
        "Nakin's Floating Cottage",
        'Delan Cliffside Open Cabana',
        'Enchanted Ilijan Hill Volcanic Nature Park',
        'Tubigon Loom Weaving Experience',
    ];

    /**
     * Project-owner-approved initial content. Coordinates are centers of the
     * supplied public Plus Codes, except the two documented OSM place nodes.
     */
    public const DESTINATIONS = [
        [
            'id' => '5db393e3-27e9-5bde-bc6e-b3aa619996c3',
            'name' => 'Mundong Sandbar',
            'slug' => 'mundong-sandbar',
            'category' => ['Island / Beach', 'island-beach'],
            'latitude' => 9.9496625,
            'longitude' => 123.8704844,
            'address' => 'WVXC+V59, Tubigon, Bohol',
            'short_description' => 'A scenic sandbar destination in Tubigon offering an island and coastal experience.',
            'description' => "Mundong Sandbar is a coastal attraction in Tubigon, Bohol known for its exposed sandbar setting and surrounding sea views. It can be featured as part of Tubigon's island and coastal tourism experiences.",
            'aliases' => [],
        ],
        [
            'id' => 'fb3e498f-91fd-58bf-8c7a-e57ee429ab48',
            'name' => 'Dumog Sandbar',
            'slug' => 'dumog-sandbar',
            'category' => ['Island / Beach', 'island-beach'],
            'latitude' => 9.9742875,
            'longitude' => 123.8951406,
            'address' => 'XVFW+P36, Tubigon, Bohol',
            'short_description' => 'A Tubigon sandbar destination surrounded by the coastal waters of Bohol.',
            'description' => "Dumog Sandbar is one of Tubigon's mapped coastal attractions and can be explored as part of the municipality's island and marine tourism destinations.",
            'aliases' => [],
        ],
        [
            'id' => '37ad0d9e-e4bc-5d7d-9d4c-1f1965c5a1d7',
            'name' => 'Mocaboc Sandbar',
            'slug' => 'mocaboc-sandbar',
            'category' => ['Island / Beach', 'island-beach'],
            'latitude' => 10.0714875,
            'longitude' => 123.9269219,
            'address' => '3WCG+HQV, Tubigon, Bohol',
            'short_description' => 'A sandbar attraction associated with Mocaboc Island in Tubigon.',
            'description' => "Mocaboc Sandbar is a coastal attraction in Tubigon, Bohol that highlights the municipality's island landscape and marine surroundings.",
            'aliases' => [],
        ],
        [
            'id' => '1d8caa43-327e-5470-97f8-2c15176dfcfe',
            'name' => 'Mangrove Forest Batasan',
            'slug' => 'mangrove-forest-batasan',
            'category' => ['Eco Tourism / Mangrove', 'eco-tourism-mangrove'],
            'latitude' => 10.0469330,
            'longitude' => 123.9793320,
            'address' => 'Cebu Strait, Batasan Island, Tubigon, Bohol',
            'short_description' => "A mangrove attraction in Batasan showcasing Tubigon's coastal ecosystem.",
            'description' => "Mangrove Forest Batasan is a nature-oriented destination in Tubigon that highlights the municipality's mangrove and coastal environment.",
            'aliases' => ['Batasan Mangrove Forest', 'Batasan Marine Sanctuary and Man Made Mangrove Tour'],
        ],
        [
            'id' => '3421d841-6bd4-5d2c-b380-2b00fe5c0358',
            'name' => "Nakin's Floating Cottage",
            'slug' => 'nakins-floating-cottage',
            'category' => ['Recreation / Community Tourism', 'recreation-community-tourism'],
            'latitude' => 9.9329875,
            'longitude' => 123.9223281,
            'address' => 'WWMC+5WW, Tubigon, Bohol',
            'short_description' => 'A floating cottage attraction offering a relaxed coastal recreation experience in Tubigon.',
            'description' => "Nakin's Floating Cottage is a mapped recreation attraction in Tubigon, providing visitors with a community-based coastal leisure destination.",
            'aliases' => [],
        ],
        [
            'id' => '80776515-9fcb-528e-9fc7-2d546f890f5c',
            'name' => 'Delan Cliffside Open Cabana',
            'slug' => 'delan-cliffside-open-cabana',
            'category' => ['Nature / Recreation', 'nature-recreation'],
            'latitude' => 9.9110875,
            'longitude' => 123.9660469,
            'address' => 'WX68+CCM, Tan-awan, Tubigon, Bohol',
            'short_description' => 'A scenic open-cabana attraction in Tan-awan, Tubigon.',
            'description' => 'Delan Cliffside Open Cabana is a mapped attraction in Tan-awan, Tubigon offering a scenic recreation setting.',
            'aliases' => [],
        ],
        [
            'id' => 'e0eb5c7a-4e1e-54c1-9501-9aea355ecbcb',
            'name' => 'Enchanted Ilijan Hill Volcanic Nature Park',
            'slug' => 'enchanted-ilijan-hill',
            'category' => ['Nature / Heritage', 'nature-heritage'],
            'latitude' => 9.9209375,
            'longitude' => 123.9477344,
            'address' => 'WWCX+93H, Tubigon, Bohol',
            'short_description' => "A nature and heritage destination centered on Tubigon's distinctive volcanic hill landscape.",
            'description' => 'Enchanted Ilijan Hill Volcanic Nature Park is a developing nature and heritage destination in Tubigon centered on the Ilijan volcanic plug and its surrounding landscape.',
            'aliases' => ['Ilijan Hill', 'Ilihan Hill'],
        ],
        [
            'id' => 'bdf5a4db-e88e-5722-a81c-21908ca7c801',
            'name' => 'Tubigon Loom Weaving Experience',
            'slug' => 'tubigon-loom-weaving',
            'category' => ['Culture / Community Tourism', 'culture-community-tourism'],
            'latitude' => 9.9356220,
            'longitude' => 123.9482880,
            'address' => 'P3, Pinayagan Norte, Tubigon, Bohol',
            'short_description' => "Experience Tubigon's raffia loom-weaving tradition and local craftsmanship.",
            'description' => "The Tubigon Loom Weaving Experience highlights the municipality's raffia weaving tradition and the craftsmanship of local loom weavers in Pinayagan Norte.",
            'aliases' => ['Tubigon Loom Weaving', 'Tubigon Loomweavers Multi-Purpose Cooperative'],
        ],
    ];

    public function run(): void
    {
        DB::transaction(function (): void {
            foreach (self::DESTINATIONS as $destination) {
                $category = $this->category(...$destination['category']);
                $spot = $this->matchingSpot($destination);

                // A later staff archive is authoritative. An archived legacy
                // match is restored only once when it is first adopted as one
                // of the eight controlled initial destinations.
                if ($spot?->trashed() && $spot->is_preapproved) {
                    continue;
                }

                if (! $spot) {
                    $spot = new TouristSpot;
                    $spot->id = $destination['id'];
                } elseif ($spot->trashed()) {
                    $spot->restore();
                }

                // Preserve all later LGU/Admin edits and publication choices.
                // Legacy rows created by the earlier partial seed have the
                // default false marker and are upgraded exactly once here.
                if (! $spot->is_preapproved) {
                    $spot->forceFill([
                        'name' => $destination['name'],
                        'slug' => $destination['slug'],
                        'short_description' => $destination['short_description'],
                        'description' => $destination['description'],
                        'aliases' => $destination['aliases'],
                        'category_id' => $category->id,
                        'latitude' => $destination['latitude'],
                        'longitude' => $destination['longitude'],
                        'address' => $destination['address'],
                        'is_featured' => true,
                        'is_active' => true,
                        'is_published' => true,
                        'is_bookable' => false,
                        'booking_mode' => 'no_reservation',
                        'is_preapproved' => true,
                        'preapproved_at' => now(),
                    ])->save();
                }
            }
        });
    }

    private function category(string $name, string $slug): SpotCategory
    {
        $category = SpotCategory::withTrashed()
            ->whereRaw('LOWER(slug) = ?', [strtolower($slug)])
            ->orWhereRaw('LOWER(name) = ?', [strtolower($name)])
            ->first();

        if (! $category) {
            return SpotCategory::create(['name' => $name, 'slug' => $slug]);
        }

        if ($category->trashed()) {
            $category->restore();
        }

        return $category;
    }

    private function matchingSpot(array $destination): ?TouristSpot
    {
        $names = array_merge([$destination['name']], $destination['aliases']);
        $slugs = array_values(array_unique(array_merge(
            [$destination['slug'], Str::slug($destination['name'])],
            array_map(Str::slug(...), $destination['aliases']),
        )));

        return TouristSpot::withTrashed()
            ->where(fn ($query) => $query
                ->whereIn(DB::raw('LOWER(name)'), array_map('strtolower', $names))
                ->orWhereIn(DB::raw('LOWER(slug)'), array_map('strtolower', $slugs)))
            ->first();
    }
}
