<?php

namespace Database\Seeders;

use App\Models\MapLocation;
use App\Models\MapLocationCategory;
use App\Support\TubigonBoundary;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class MapLocationSeeder extends Seeder
{
    public function run(): void
    {
        if (! Schema::hasTable('map_location_categories') || ! Schema::hasTable('map_locations')) {
            return;
        }

        $this->seedCategories();

        $publicSeedRequested = (bool) config('map.dev_seed_public_tubigon_places', false);
        $allowedEnvironments = (array) config('map.public_seed_environments', ['local', 'testing']);
        $publicSeedEnabled = $publicSeedRequested
            && in_array(app()->environment(), $allowedEnvironments, true);

        if ($publicSeedRequested && ! $publicSeedEnabled) {
            Log::warning('Tubigon public demo seed was refused outside an allowed development environment.', [
                'environment' => app()->environment(),
            ]);
        }

        $boundary = app(TubigonBoundary::class);
        $hasSeedKey = Schema::hasColumn('map_locations', 'seed_key');

        foreach ($this->places() as $place) {
            $category = MapLocationCategory::query()
                ->where('slug', $place['category_slug'])
                ->where('active', true)
                ->first();

            if (! $category) {
                Log::warning('Tubigon seed place was left unpublished because its category is missing or inactive.', [
                    'seed_key' => $place['seed_key'],
                    'category' => $place['category_slug'],
                ]);

                continue;
            }

            [$entityType, $entity] = $this->matchingEntity($place['name']);
            $latitude = $entity->latitude ?? $place['latitude'];
            $longitude = $entity->longitude ?? $place['longitude'];
            $coordinatesValid = $latitude !== null
                && $longitude !== null
                && $boundary->contains((float) $latitude, (float) $longitude);

            $location = $this->findExistingLocation(
                $place['seed_key'],
                $place['name'],
                $entityType,
                $entity?->id,
                $hasSeedKey,
            );

            if ($location?->trashed()) {
                Log::warning('Tubigon seed place matched an archived record and was not restored.', [
                    'seed_key' => $place['seed_key'],
                    'location_id' => $location->id,
                ]);

                continue;
            }

            // Seed-owned records have never been changed through the LGU/Admin
            // workflow. Once staff touch a record, later seed runs preserve it.
            $seedOwned = $location === null
                || ($location->created_by === null && $location->updated_by === null);

            if ($location === null) {
                $location = new MapLocation;
                $location->slug = Str::slug($place['seed_key']);
                $location->verified = false;
                $location->published = false;
                $location->active = true;
            }

            if ($seedOwned) {
                $location->fill([
                    'name' => $entity->name ?? $place['name'],
                    'description' => filled($entity->description ?? null)
                        ? $entity->description
                        : $place['description'],
                    'category_id' => $category->id,
                    'entity_type' => $entityType,
                    'entity_id' => $entity?->id,
                    'address' => filled($entity->address ?? null)
                        ? $entity->address
                        : 'Tubigon, Bohol',
                    'latitude' => $latitude,
                    'longitude' => $longitude,
                    'is_featured' => $place['featured'],
                    'active' => true,
                ]);
            }

            if ($hasSeedKey && blank($location->seed_key)) {
                $location->seed_key = $place['seed_key'];
            }

            $mayPublishForDevelopment = $publicSeedEnabled
                && $place['public_demo']
                && $coordinatesValid
                && $seedOwned;

            if ($mayPublishForDevelopment) {
                $location->verified = true;
                $location->published = true;
                $location->active = true;
                $location->verified_at ??= now();
            } elseif ($publicSeedEnabled && $place['public_demo'] && ! $coordinatesValid) {
                $location->verified = false;
                $location->published = false;
                $location->verified_at = null;
                Log::warning('Tubigon seed place was left unpublished because its coordinates failed boundary validation.', [
                    'seed_key' => $place['seed_key'],
                    'latitude' => $latitude,
                    'longitude' => $longitude,
                ]);
            }

            $location->save();
        }
    }

    private function seedCategories(): void
    {
        $categories = [
            ['Tourist Spots', 'tourist-spots', 'landscape', '#F59E0B'],
            ['MSMEs', 'msmes', 'storefront', '#0284C7'],
            ['Shopping', 'shopping', 'shopping_bag', '#EC4899'],
            ['Fast Food', 'fast-food', 'fastfood', '#F97316'],
            ['Restaurants', 'restaurants', 'restaurant', '#EF4444'],
            ['Food Parks', 'food-parks', 'deck', '#FB7185'],
            ['Accommodation', 'accommodation', 'hotel', '#7C3AED'],
            ['Nature', 'nature', 'forest', '#16A34A'],
            ['Heritage', 'heritage', 'account_balance', '#A16207'],
            ['Government', 'government', 'account_balance', '#475569'],
            ['Emergency', 'emergency', 'emergency', '#E11D48'],
            ['Port / Transport', 'port-transport', 'directions_boat', '#0891B2'],
            ['Banks / Services', 'banks-services', 'account_balance_wallet', '#2563EB'],
            ['Important Places', 'important-places', 'place', '#F59E0B'],
        ];

        foreach ($categories as $index => [$name, $slug, $icon, $color]) {
            MapLocationCategory::firstOrCreate(
                ['slug' => $slug],
                [
                    'name' => $name,
                    'icon' => $icon,
                    'marker_color' => $color,
                    'active' => true,
                    'sort_order' => ($index + 1) * 10,
                ],
            );
        }
    }

    private function places(): array
    {
        return [
            [
                'seed_key' => 'tubigon-initial-alturas-mall',
                'name' => 'Alturas Mall Tubigon',
                'category_slug' => 'shopping',
                'latitude' => 9.95134,
                'longitude' => 123.96236,
                'featured' => true,
                'public_demo' => true,
                'description' => 'A major shopping destination in central Tubigon offering groceries, retail products, household goods, fashion, and convenient services.',
            ],
            [
                'seed_key' => 'tubigon-initial-bq-superstore',
                'name' => 'BQ Superstore - Tubigon',
                'category_slug' => 'shopping',
                'latitude' => 9.94961,
                'longitude' => 123.96133,
                'featured' => true,
                'public_demo' => true,
                'description' => 'A convenient local shopping destination serving residents and visitors in Tubigon.',
            ],
            [
                'seed_key' => 'tubigon-initial-7s-shopping-center',
                'name' => "7'S Shopping Center",
                'category_slug' => 'shopping',
                'latitude' => 9.95309,
                'longitude' => 123.96202,
                'featured' => false,
                'public_demo' => true,
                'description' => "A local shopping center near Tubigon's commercial and market area.",
            ],
            [
                'seed_key' => 'tubigon-initial-jollibee',
                'name' => 'Jollibee Tubigon',
                'category_slug' => 'fast-food',
                'latitude' => 9.95154,
                'longitude' => 123.96292,
                'featured' => true,
                'public_demo' => true,
                'description' => 'A popular Filipino fast-food restaurant serving familiar favorites for travelers and local residents.',
            ],
            [
                'seed_key' => 'tubigon-initial-mang-inasal',
                'name' => 'Mang Inasal Tubigon',
                'category_slug' => 'fast-food',
                'latitude' => 9.95194,
                'longitude' => 123.96258,
                'featured' => true,
                'public_demo' => true,
                'description' => 'A Filipino grilled-food restaurant known for chicken inasal and rice meals.',
            ],
            [
                'seed_key' => 'tubigon-initial-paengs-chicken',
                'name' => "Paeng's Lechon Manok & Fried Chicken Tubigon",
                'category_slug' => 'fast-food',
                'latitude' => 9.95139,
                'longitude' => 123.96136,
                'featured' => false,
                'public_demo' => true,
                'description' => 'A local quick-service food destination serving roasted and fried chicken meals.',
            ],
            [
                'seed_key' => 'tubigon-draft-mcdonalds',
                'name' => "McDonald's Tubigon",
                'category_slug' => 'fast-food',
                'latitude' => null,
                'longitude' => null,
                'featured' => false,
                'public_demo' => false,
                'description' => 'Draft place awaiting exact pin verification by Tubigon LGU.',
            ],
            [
                'seed_key' => 'tubigon-draft-bazak-foodpark',
                'name' => 'Bazak Foodpark',
                'category_slug' => 'food-parks',
                'latitude' => null,
                'longitude' => null,
                'featured' => false,
                'public_demo' => false,
                'description' => 'Draft place awaiting exact pin verification by Tubigon LGU.',
            ],
            [
                'seed_key' => 'tubigon-draft-mjs-kitchen',
                'name' => "MJ's Kitchen",
                'category_slug' => 'restaurants',
                'latitude' => null,
                'longitude' => null,
                'featured' => false,
                'public_demo' => false,
                'description' => 'Draft place awaiting exact pin verification by Tubigon LGU.',
            ],
            [
                'seed_key' => 'tubigon-draft-metrobank',
                'name' => 'Metrobank Tubigon',
                'category_slug' => 'banks-services',
                'latitude' => null,
                'longitude' => null,
                'featured' => false,
                'public_demo' => false,
                'description' => 'Draft place awaiting exact pin verification by Tubigon LGU.',
            ],
            [
                'seed_key' => 'tubigon-draft-guanzon',
                'name' => 'Guanzon Tubigon',
                'category_slug' => 'shopping',
                'latitude' => null,
                'longitude' => null,
                'featured' => false,
                'public_demo' => false,
                'description' => 'Draft place awaiting exact pin verification by Tubigon LGU.',
            ],
            [
                'seed_key' => 'tubigon-draft-tubigon-port',
                'name' => 'Tubigon Port',
                'category_slug' => 'port-transport',
                'latitude' => null,
                'longitude' => null,
                'featured' => false,
                'public_demo' => false,
                'description' => 'Draft visitor location awaiting exact port pin and detail verification by Tubigon LGU.',
            ],
        ];
    }

    private function findExistingLocation(
        string $seedKey,
        string $name,
        ?string $entityType,
        ?string $entityId,
        bool $hasSeedKey,
    ): ?MapLocation {
        if ($hasSeedKey) {
            $bySeedKey = MapLocation::withTrashed()->where('seed_key', $seedKey)->first();
            if ($bySeedKey) {
                return $bySeedKey;
            }
        }

        if ($entityType && $entityId) {
            $byEntity = MapLocation::withTrashed()
                ->where('entity_type', $entityType)
                ->where('entity_id', $entityId)
                ->first();
            if ($byEntity) {
                return $byEntity;
            }
        }

        return MapLocation::withTrashed()
            ->whereRaw('LOWER(name) = ?', [Str::lower($name)])
            ->first();
    }

    private function matchingEntity(string $name): array
    {
        foreach (['msmes' => 'msme', 'tourist_spots' => 'tourist_spot'] as $table => $type) {
            if (! Schema::hasTable($table)) {
                continue;
            }
            $entity = DB::table($table)
                ->whereNull('deleted_at')
                ->whereRaw('LOWER(name) = ?', [Str::lower($name)])
                ->first();
            if ($entity) {
                return [$type, $entity];
            }
        }

        return [null, null];
    }
}
