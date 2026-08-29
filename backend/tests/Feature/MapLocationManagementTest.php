<?php

namespace Tests\Feature;

use App\Models\EmergencyContact;
use App\Models\MapLocation;
use App\Models\MapLocationCategory;
use App\Models\Role;
use App\Models\User;
use App\Support\TubigonBoundary;
use Database\Seeders\FeaturedDestinationSeeder;
use Database\Seeders\MapLocationSeeder;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MapLocationManagementTest extends TestCase
{
    private Role $touristRole;

    private Role $lguRole;

    private Role $adminRole;

    protected function setUp(): void
    {
        parent::setUp();
        config(['map.dev_seed_public_tubigon_places' => false]);
        $this->createSchema();
        $this->touristRole = Role::create(['name' => 'tourist']);
        $this->lguRole = Role::create(['name' => 'lgu_staff']);
        $this->adminRole = Role::create(['name' => 'admin']);
        (new MapLocationSeeder)->run();
    }

    public function test_initial_places_are_idempotent_unverified_unpublished_drafts(): void
    {
        (new MapLocationSeeder)->run();

        $this->assertDatabaseCount('map_locations', 12);
        $this->assertSame(0, MapLocation::where('verified', true)->count());
        $this->assertSame(0, MapLocation::where('published', true)->count());
        $this->assertDatabaseHas('map_locations', [
            'name' => 'Alturas Mall Tubigon',
            'latitude' => 9.95134,
            'longitude' => 123.96236,
        ]);
        $this->assertDatabaseHas('map_locations', [
            'name' => "McDonald's Tubigon",
            'latitude' => null,
            'longitude' => null,
        ]);
        $this->assertDatabaseHas('map_locations', [
            'name' => 'Tubigon Port',
            'latitude' => null,
            'longitude' => null,
            'verified' => false,
            'published' => false,
        ]);
        $this->getJson('/api/v1/map/locations')
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_preapproved_featured_destinations_share_the_public_smart_map_feed(): void
    {
        (new FeaturedDestinationSeeder)->run();

        $response = $this->getJson('/api/v1/map/locations')
            ->assertOk()
            ->assertJsonCount(8, 'data');

        $this->assertEqualsCanonicalizing(
            FeaturedDestinationSeeder::NAMES,
            collect($response->json('data'))->pluck('name')->all(),
        );
        $this->assertTrue(collect($response->json('data'))->every(
            fn (array $place) => $place['type'] === 'tourist_spot'
                && $place['is_verified'] === true
                && $place['is_preapproved'] === true,
        ));
        $this->assertTrue(collect($response->json('data'))->contains(
            fn (array $place) => $place['name'] === 'Mundong Sandbar'
                && $place['longitude'] === 123.8704844,
        ));
    }

    public function test_guarded_development_seed_publishes_only_the_six_supplied_locations(): void
    {
        config(['map.dev_seed_public_tubigon_places' => true]);

        (new MapLocationSeeder)->run();
        (new MapLocationSeeder)->run();

        $this->assertDatabaseCount('map_locations', 12);
        $this->assertSame(12, MapLocation::whereNotNull('seed_key')->distinct()->count('seed_key'));
        $this->assertSame(6, MapLocation::where('active', true)->where('verified', true)->where('published', true)->count());
        $this->assertSame(4, MapLocation::where('is_featured', true)->where('published', true)->count());

        $expectedNames = [
            "7'S Shopping Center",
            'Alturas Mall Tubigon',
            'BQ Superstore - Tubigon',
            'Jollibee Tubigon',
            'Mang Inasal Tubigon',
            "Paeng's Lechon Manok & Fried Chicken Tubigon",
        ];
        $this->assertSame($expectedNames, MapLocation::where('published', true)->orderBy('name')->pluck('name')->all());

        $boundary = app(TubigonBoundary::class);
        foreach (MapLocation::where('published', true)->get() as $location) {
            $this->assertTrue($boundary->contains($location->latitude, $location->longitude));
        }

        foreach (["McDonald's Tubigon", 'Bazak Foodpark', "MJ's Kitchen", 'Metrobank Tubigon', 'Guanzon Tubigon', 'Tubigon Port'] as $draftName) {
            $this->assertDatabaseHas('map_locations', [
                'name' => $draftName,
                'verified' => false,
                'published' => false,
            ]);
        }

        $response = $this->getJson('/api/v1/map/locations')
            ->assertOk()
            ->assertJsonCount(6, 'data')
            ->assertJsonPath('status', 'success');
        $this->assertEqualsCanonicalizing($expectedNames, collect($response->json('data'))->pluck('name')->all());
    }

    public function test_development_seed_does_not_undo_a_staff_verification_change(): void
    {
        config(['map.dev_seed_public_tubigon_places' => true]);
        (new MapLocationSeeder)->run();

        $location = MapLocation::where('name', 'Alturas Mall Tubigon')->firstOrFail();
        Sanctum::actingAs($this->user($this->adminRole));
        $this->patchJson("/api/v1/admin/map-locations/{$location->id}/verify", ['verified' => false])
            ->assertOk();

        (new MapLocationSeeder)->run();

        $location->refresh();
        $this->assertFalse($location->verified);
        $this->assertFalse($location->published);
        $this->assertNotNull($location->updated_by);
    }

    public function test_public_seed_flag_is_refused_in_production(): void
    {
        $originalEnvironment = app()->environment();
        $this->app->detectEnvironment(fn () => 'production');
        config(['map.dev_seed_public_tubigon_places' => true]);

        try {
            (new MapLocationSeeder)->run();
            $this->assertSame(0, MapLocation::where('published', true)->count());
        } finally {
            $this->app->detectEnvironment(fn () => $originalEnvironment);
        }
    }

    public function test_tourists_and_guests_cannot_manage_locations(): void
    {
        $this->postJson('/api/v1/lgu/map-locations', $this->payload())
            ->assertUnauthorized();

        Sanctum::actingAs($this->user($this->touristRole));
        $this->postJson('/api/v1/lgu/map-locations', $this->payload())
            ->assertForbidden();
        $this->postJson('/api/v1/admin/map-locations', $this->payload())
            ->assertForbidden();
    }

    public function test_admin_only_endpoint_rejects_every_non_admin_role(): void
    {
        $this->getJson('/api/v1/admin/map-locations')->assertUnauthorized();

        foreach (['tourist', 'msme_owner', 'tourism_partner', 'lgu_staff'] as $roleName) {
            $role = Role::firstOrCreate(['name' => $roleName]);
            Sanctum::actingAs($this->user($role));
            $this->getJson('/api/v1/admin/map-locations')->assertForbidden();
        }

        Sanctum::actingAs($this->user($this->adminRole));
        $this->getJson('/api/v1/admin/map-locations')->assertOk();
    }

    public function test_public_lists_hide_unverified_msmes_and_inactive_spot_details(): void
    {
        Schema::getConnection()->table('msmes')->insert([
            [
                'id' => '31111111-1111-4111-8111-111111111111',
                'name' => 'Verified Business',
                'category' => 'Shopping',
                'is_verified' => true,
                'verification_status' => 'verified',
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'id' => '32222222-2222-4222-8222-222222222222',
                'name' => 'Unverified Business',
                'category' => 'Shopping',
                'is_verified' => false,
                'verification_status' => 'pending',
                'created_at' => now(),
                'updated_at' => now(),
            ],
        ]);
        $this->getJson('/api/v1/msmes')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'Verified Business');

        $spotId = '33333333-3333-4333-8333-333333333333';
        Schema::getConnection()->table('tourist_spots')->insert([
            'id' => $spotId,
            'name' => 'Inactive Spot',
            'is_active' => false,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $this->getJson("/api/v1/tourist-spots/$spotId")->assertNotFound();
    }

    public function test_unverified_linked_msme_cannot_be_published(): void
    {
        $msmeId = '34444444-4444-4444-8444-444444444444';
        Schema::getConnection()->table('msmes')->insert([
            'id' => $msmeId,
            'name' => 'Pending Business',
            'category' => 'Shopping',
            'is_verified' => false,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        Sanctum::actingAs($this->user($this->adminRole));
        $id = $this->postJson('/api/v1/admin/map-locations', [
            ...$this->payload([
                'name' => 'Pending Business Map Record',
                'entity_type' => 'msme',
                'entity_id' => $msmeId,
            ]),
            'duplicate_override' => true,
        ])->assertCreated()->json('data.id');

        $this->patchJson("/api/v1/admin/map-locations/$id/publish", [
            'published' => true,
        ])->assertUnprocessable()->assertJsonValidationErrors('entity_id');
    }

    public function test_lgu_can_create_verify_publish_move_deactivate_and_archive(): void
    {
        $lgu = $this->user($this->lguRole);
        Sanctum::actingAs($lgu);

        $created = $this->postJson('/api/v1/lgu/map-locations', [
            ...$this->payload(),
            'duplicate_override' => true,
        ])
            ->assertCreated()
            ->assertJsonPath('data.verified', false)
            ->assertJsonPath('data.published', false)
            ->json('data');
        $id = $created['id'];

        $this->patchJson("/api/v1/lgu/map-locations/$id/publish", ['published' => true])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('verified');
        $this->patchJson("/api/v1/lgu/map-locations/$id/verify")
            ->assertOk()
            ->assertJsonPath('data.verified', true);
        $this->patchJson("/api/v1/lgu/map-locations/$id/publish", ['published' => true])
            ->assertOk()
            ->assertJsonPath('data.published', true);

        $this->getJson('/api/v1/map/locations')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.map_location_id', $id);
        $this->getJson("/api/v1/places/$id")
            ->assertOk()
            ->assertJsonPath('data.name', 'Tubigon Test Place');

        $this->putJson("/api/v1/lgu/map-locations/$id", [
            'latitude' => 9.9517,
            'longitude' => 123.9621,
            'duplicate_override' => true,
        ])->assertOk()
            ->assertJsonPath('data.verified', false)
            ->assertJsonPath('data.published', false);

        $this->patchJson("/api/v1/lgu/map-locations/$id/status", ['active' => false])
            ->assertOk()->assertJsonPath('data.active', false);
        $this->deleteJson("/api/v1/lgu/map-locations/$id")
            ->assertOk()
            ->assertJsonPath('message', 'Location archived. No record was permanently deleted.');
        $this->assertSoftDeleted('map_locations', ['id' => $id]);
        $this->assertDatabaseHas('activity_logs', ['action' => 'Location created']);
        $this->assertDatabaseHas('activity_logs', ['action' => 'Location moved']);
        $this->assertDatabaseHas('activity_logs', ['action' => 'Location archived']);
    }

    public function test_duplicate_name_requires_explicit_authorized_override(): void
    {
        Schema::getConnection()->table('msmes')->insert([
            'id' => '11111111-1111-4111-8111-111111111111',
            'name' => 'Existing Market',
            'category' => 'Shopping',
            'is_verified' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        Sanctum::actingAs($this->user($this->adminRole));
        $payload = $this->payload(['name' => 'Existing Market']);

        $this->postJson('/api/v1/admin/map-locations', $payload)
            ->assertStatus(409)
            ->assertJsonPath('status', 'possible_duplicate');
        $this->postJson('/api/v1/admin/map-locations', [
            ...$payload,
            'duplicate_override' => true,
        ])->assertCreated();
    }

    public function test_public_emergency_map_requires_verification_but_lgu_can_monitor_drafts(): void
    {
        $verified = EmergencyContact::create([
            'name' => 'Verified Emergency Center',
            'category' => 'Emergency',
            'latitude' => 9.9515,
            'longitude' => 123.9618,
            'is_active' => true,
            'is_verified' => true,
        ]);
        $unverified = EmergencyContact::create([
            'name' => 'Unverified Emergency Center',
            'category' => 'Emergency',
            'latitude' => 9.9516,
            'longitude' => 123.9619,
            'is_active' => true,
            'is_verified' => false,
        ]);

        $this->getJson('/api/v1/map/locations')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', "emergency:{$verified->id}");

        Sanctum::actingAs($this->user($this->lguRole));
        $this->getJson('/api/v1/map/locations/authenticated')
            ->assertOk()
            ->assertJsonPath('meta.role', 'lgu_staff')
            ->assertJsonFragment(['id' => "emergency:{$verified->id}"])
            ->assertJsonFragment(['id' => "emergency:{$unverified->id}"]);
    }

    public function test_linked_entity_updates_are_reflected_by_map_and_categories_are_public(): void
    {
        $msmeId = '22222222-2222-4222-8222-222222222222';
        Schema::getConnection()->table('msmes')->insert([
            'id' => $msmeId,
            'name' => 'Original MSME Name',
            'category' => 'Fast Food',
            'description' => 'Original description',
            'address' => 'Original address',
            'latitude' => 9.9515,
            'longitude' => 123.9618,
            'is_verified' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        Sanctum::actingAs($this->user($this->adminRole));
        $id = $this->postJson('/api/v1/admin/map-locations', [
            ...$this->payload([
                'name' => 'Managed MSME Label',
                'category_id' => MapLocationCategory::where('slug', 'fast-food')->value('id'),
                'entity_type' => 'msme',
                'entity_id' => $msmeId,
            ]),
            'duplicate_override' => true,
        ])->assertCreated()->json('data.id');
        $this->patchJson("/api/v1/admin/map-locations/$id/verify")->assertOk();
        $this->patchJson("/api/v1/admin/map-locations/$id/publish", [
            'published' => true,
        ])->assertOk();

        Schema::getConnection()->table('msmes')->where('id', $msmeId)->update([
            'name' => 'Updated MSME Name',
            'description' => 'Updated description',
            'address' => 'Updated address',
        ]);

        $this->getJson('/api/v1/map/locations')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'Updated MSME Name')
            ->assertJsonPath('data.0.description', 'Updated description')
            ->assertJsonPath('data.0.address', 'Updated address')
            ->assertJsonPath('data.0.category_slug', 'fast-food')
            ->assertJsonPath('data.0.category_keys.1', 'msmes');
        $this->getJson('/api/v1/place-categories')
            ->assertOk()
            ->assertJsonCount(14, 'data');
    }

    private function payload(array $overrides = []): array
    {
        return array_merge([
            'name' => 'Tubigon Test Place',
            'description' => 'A safe integration-test location.',
            'category_id' => MapLocationCategory::where('slug', 'important-places')->value('id'),
            'address' => 'Tubigon, Bohol',
            'latitude' => 9.9515,
            'longitude' => 123.9618,
            'active' => true,
        ], $overrides);
    }

    private function user(Role $role): User
    {
        return User::create([
            'name' => ucfirst(str_replace('_', ' ', $role->name)),
            'email' => $role->name.'@map.test',
            'password' => 'safe-password',
            'role_id' => $role->id,
            'is_verified' => true,
        ]);
    }

    private function createSchema(): void
    {
        foreach ([
            'activity_logs', 'map_locations', 'map_location_categories',
            'waste_reports', 'emergency_contacts', 'tourism_listings', 'msmes',
            'tourist_spots', 'spot_categories', 'users', 'roles',
        ] as $table) {
            Schema::dropIfExists($table);
        }
        Schema::create('roles', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name')->unique();
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('users', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->string('email')->unique();
            $table->string('password');
            $table->uuid('role_id')->nullable();
            $table->boolean('is_verified')->default(false);
            $table->rememberToken();
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('map_location_categories', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('parent_id')->nullable();
            $table->string('name')->unique();
            $table->string('slug')->unique();
            $table->string('icon');
            $table->string('marker_color');
            $table->boolean('active')->default(true);
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('map_locations', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->string('slug')->unique();
            $table->string('seed_key')->nullable()->unique();
            $table->text('description')->nullable();
            $table->uuid('category_id');
            $table->uuid('subcategory_id')->nullable();
            $table->string('entity_type')->nullable();
            $table->uuid('entity_id')->nullable();
            $table->text('address')->nullable();
            $table->double('latitude')->nullable();
            $table->double('longitude')->nullable();
            $table->string('marker_icon')->nullable();
            $table->text('image_url')->nullable();
            $table->boolean('is_featured')->default(false);
            $table->unsignedBigInteger('view_count')->default(0);
            $table->boolean('verified')->default(false);
            $table->boolean('published')->default(false);
            $table->boolean('active')->default(true);
            $table->uuid('created_by')->nullable();
            $table->uuid('updated_by')->nullable();
            $table->uuid('verified_by')->nullable();
            $table->timestamp('verified_at')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('spot_categories', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->string('slug');
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('tourist_spots', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->unsignedInteger('integer_id')->nullable();
            $table->string('name');
            $table->string('slug')->nullable();
            $table->text('short_description')->nullable();
            $table->text('description')->nullable();
            $table->json('aliases')->nullable();
            $table->uuid('category_id')->nullable();
            $table->double('latitude')->nullable();
            $table->double('longitude')->nullable();
            $table->text('address')->nullable();
            $table->string('opening_hours')->nullable();
            $table->json('images')->nullable();
            $table->double('average_rating')->default(0);
            $table->integer('review_count')->default(0);
            $table->boolean('is_featured')->default(false);
            $table->boolean('is_active')->default(true);
            $table->boolean('is_published')->default(false);
            $table->boolean('is_bookable')->default(false);
            $table->string('booking_mode')->default('no_reservation');
            $table->boolean('is_preapproved')->default(false);
            $table->timestamp('preapproved_at')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('msmes', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->unsignedInteger('integer_id')->nullable();
            $table->uuid('profile_id')->nullable();
            $table->string('name');
            $table->string('category');
            $table->text('description')->nullable();
            $table->string('phone')->nullable();
            $table->text('address')->nullable();
            $table->double('latitude')->nullable();
            $table->double('longitude')->nullable();
            $table->string('business_hours')->nullable();
            $table->double('rating')->default(0);
            $table->integer('review_count')->default(0);
            $table->boolean('is_verified')->default(false);
            $table->string('verification_status')->default('pending');
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('emergency_contacts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->unsignedInteger('integer_id')->nullable();
            $table->string('name');
            $table->string('category');
            $table->string('phone')->nullable();
            $table->text('description')->nullable();
            $table->text('address')->nullable();
            $table->double('latitude')->nullable();
            $table->double('longitude')->nullable();
            $table->string('operating_hours')->nullable();
            $table->string('classification')->nullable();
            $table->boolean('is_active')->default(true);
            $table->boolean('is_verified')->default(false);
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('tourism_listings', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('owner_id')->nullable();
            $table->string('listing_name');
            $table->string('listing_type');
            $table->text('description')->nullable();
            $table->text('address')->nullable();
            $table->double('latitude')->nullable();
            $table->double('longitude')->nullable();
            $table->string('contact_number')->nullable();
            $table->string('operating_hours')->nullable();
            $table->json('images')->nullable();
            $table->string('status')->nullable();
            $table->boolean('is_active')->default(true);
            $table->double('average_rating')->default(0);
            $table->integer('review_count')->default(0);
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('waste_reports', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('category');
            $table->text('description')->nullable();
            $table->text('location_description')->nullable();
            $table->double('latitude')->nullable();
            $table->double('longitude')->nullable();
            $table->json('images')->nullable();
            $table->string('status')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('activity_logs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id');
            $table->string('action');
            $table->text('details')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });
    }
}
