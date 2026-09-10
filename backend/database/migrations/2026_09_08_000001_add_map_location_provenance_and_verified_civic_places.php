<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('map_locations')) {
            return;
        }

        Schema::table('map_locations', function (Blueprint $table): void {
            if (! Schema::hasColumn('map_locations', 'barangay')) {
                $table->string('barangay', 120)->nullable()->after('address');
            }
            if (! Schema::hasColumn('map_locations', 'municipality')) {
                $table->string('municipality', 120)->nullable()->after('barangay');
            }
            if (! Schema::hasColumn('map_locations', 'province')) {
                $table->string('province', 120)->nullable()->after('municipality');
            }
            if (! Schema::hasColumn('map_locations', 'coordinate_source_name')) {
                $table->string('coordinate_source_name')->nullable()->after('longitude');
            }
            if (! Schema::hasColumn('map_locations', 'coordinate_source_url')) {
                $table->text('coordinate_source_url')->nullable()->after('coordinate_source_name');
            }
            if (! Schema::hasColumn('map_locations', 'coordinate_source_id')) {
                $table->string('coordinate_source_id', 120)->nullable()->after('coordinate_source_url');
            }
            if (! Schema::hasColumn('map_locations', 'coordinate_source_license')) {
                $table->string('coordinate_source_license', 120)->nullable()->after('coordinate_source_id');
            }
            if (! Schema::hasColumn('map_locations', 'coordinate_verified_at')) {
                $table->timestamp('coordinate_verified_at')->nullable()->after('coordinate_source_license');
            }
        });

        if (! Schema::hasTable('map_location_categories')) {
            return;
        }

        $now = now();
        $categories = [
            [
                'id' => '8b1607c4-5f89-4b27-9ee8-e16c66ae8d01',
                'name' => 'Plazas & Parks',
                'slug' => 'plaza-park',
                'icon' => 'park',
                'marker_color' => '#16A34A',
                'sort_order' => 85,
            ],
            [
                'id' => '90c37f7d-b48f-41d8-ac27-66da3668a002',
                'name' => 'Churches & Places of Worship',
                'slug' => 'church-place-of-worship',
                'icon' => 'church',
                'marker_color' => '#7C3AED',
                'sort_order' => 86,
            ],
        ];

        foreach ($categories as $category) {
            if (! DB::table('map_location_categories')->where('slug', $category['slug'])->exists()) {
                DB::table('map_location_categories')->insert([
                    ...$category,
                    'active' => true,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        }

        $categoryIds = DB::table('map_location_categories')
            ->whereIn('slug', ['plaza-park', 'church-place-of-worship'])
            ->pluck('id', 'slug');

        $places = [
            [
                'id' => 'f53349d9-065e-4d2a-8d56-54f72458a101',
                'seed_key' => 'verified-osm-tubigon-town-plaza',
                'name' => 'Tubigon Town Plaza',
                'slug' => 'tubigon-town-plaza',
                'description' => 'The public town plaza in central Tubigon, Bohol.',
                'category_slug' => 'plaza-park',
                'address' => 'Pooc Occidental (Poblacion), Tubigon, Bohol',
                'barangay' => 'Pooc Occidental (Poblacion)',
                'latitude' => 9.9512209,
                'longitude' => 123.9620116,
                'marker_icon' => 'park',
                'coordinate_source_id' => 'OpenStreetMap way 143346516',
                'coordinate_source_url' => 'https://www.openstreetmap.org/way/143346516',
            ],
            [
                'id' => '089d8ed9-22a5-40b2-a01b-8a264c09a102',
                'seed_key' => 'verified-osm-saint-isidore-tubigon',
                'name' => 'Saint Isidore the Farmer Parish Church',
                'slug' => 'saint-isidore-the-farmer-parish-church-tubigon',
                'description' => 'Roman Catholic parish church in the Tubigon poblacion.',
                'category_slug' => 'church-place-of-worship',
                'address' => 'T. Mascarinas Street, Poblacion, Tubigon, Bohol',
                'barangay' => 'Poblacion',
                'latitude' => 9.9502983,
                'longitude' => 123.9629650,
                'marker_icon' => 'church',
                'coordinate_source_id' => 'OpenStreetMap way 943081282',
                'coordinate_source_url' => 'https://www.openstreetmap.org/way/943081282',
            ],
            [
                'id' => '5daef65c-3a46-4766-bb19-030f5c9ca103',
                'seed_key' => 'verified-osm-saint-john-cross-cahayag',
                'name' => 'Saint John of the Cross Parish Church',
                'slug' => 'saint-john-of-the-cross-parish-church-cahayag',
                'description' => 'Roman Catholic parish church serving Cahayag and nearby communities in Tubigon.',
                'category_slug' => 'church-place-of-worship',
                'address' => 'Cahayag, Tubigon, Bohol',
                'barangay' => 'Cahayag',
                'latitude' => 9.9208119,
                'longitude' => 123.9308790,
                'marker_icon' => 'church',
                'coordinate_source_id' => 'OpenStreetMap way 661954412',
                'coordinate_source_url' => 'https://www.openstreetmap.org/way/661954412',
            ],
        ];

        foreach ($places as $place) {
            $categoryId = $categoryIds[$place['category_slug']] ?? null;
            if (! $categoryId) {
                continue;
            }

            $existing = DB::table('map_locations')
                ->where(function ($query) use ($place): void {
                    $query->where('seed_key', $place['seed_key'])
                        ->orWhere('slug', $place['slug'])
                        ->orWhereRaw('LOWER(name) = ?', [strtolower($place['name'])]);
                })
                ->first();

            unset($place['category_slug']);
            $record = [
                ...$place,
                'category_id' => $categoryId,
                'municipality' => 'Tubigon',
                'province' => 'Bohol',
                'coordinate_source_name' => 'OpenStreetMap contributors',
                'coordinate_source_license' => 'ODbL 1.0',
                'coordinate_verified_at' => $now,
                'is_featured' => false,
                'view_count' => 0,
                'verified' => true,
                'published' => true,
                'active' => true,
                'verified_at' => $now,
                'updated_at' => $now,
            ];

            if ($existing) {
                unset($record['id']);
                DB::table('map_locations')->where('id', $existing->id)->update($record);
            } else {
                DB::table('map_locations')->insert([
                    ...$record,
                    'created_at' => $now,
                ]);
            }
        }
    }

    public function down(): void
    {
        // Verified civic records are intentionally retained on rollback. A
        // deployment rollback must not destructively remove managed content.
    }
};
