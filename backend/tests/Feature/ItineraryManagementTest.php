<?php

namespace Tests\Feature;

use App\Models\Itinerary;
use App\Models\MapLocation;
use App\Models\MapLocationCategory;
use App\Models\Reservation;
use App\Models\ReservationStatus;
use App\Models\Role;
use App\Models\SpotCategory;
use App\Models\TouristSpot;
use App\Models\User;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ItineraryManagementTest extends TestCase
{
    private Role $touristRole;

    private Role $adminRole;

    protected function setUp(): void
    {
        parent::setUp();
        $this->createSchema();
        $this->touristRole = Role::create(['name' => 'tourist']);
        $this->adminRole = Role::create(['name' => 'admin']);
    }

    public function test_tourist_can_create_update_list_and_archive_an_owned_itinerary(): void
    {
        Sanctum::actingAs($this->user('one', $this->touristRole));

        $created = $this->postJson('/api/v1/itineraries', [
            'name' => 'Weekend in Tubigon',
            'description' => 'Food and shopping',
            'start_date' => now()->addDay()->toDateString(),
            'end_date' => now()->addDays(2)->toDateString(),
            'travelers' => 2,
            'status' => 'upcoming',
        ])->assertCreated()
            ->assertJsonPath('data.name', 'Weekend in Tubigon')
            ->assertJsonPath('data.day_count', 2)
            ->json('data');

        $this->getJson('/api/v1/itineraries')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.place_count', 0);

        $this->putJson("/api/v1/itineraries/{$created['id']}", ['name' => 'Updated Tubigon Weekend'])
            ->assertOk()
            ->assertJsonPath('data.name', 'Updated Tubigon Weekend');

        $this->deleteJson("/api/v1/itineraries/{$created['id']}")->assertOk();
        $this->assertSoftDeleted('itineraries', ['id' => $created['id']]);
    }

    public function test_itinerary_ownership_prevents_idor_and_non_tourist_access(): void
    {
        $owner = $this->user('owner', $this->touristRole);
        $other = $this->user('other', $this->touristRole);
        $admin = $this->user('admin', $this->adminRole);
        $itinerary = Itinerary::create([
            'user_id' => $owner->id,
            'name' => 'Private Trip',
            'start_date' => now()->toDateString(),
            'end_date' => now()->toDateString(),
        ]);

        Sanctum::actingAs($other);
        $this->getJson("/api/v1/itineraries/{$itinerary->id}")->assertNotFound();
        $this->putJson("/api/v1/itineraries/{$itinerary->id}", ['name' => 'Stolen'])->assertNotFound();
        $this->deleteJson("/api/v1/itineraries/{$itinerary->id}")->assertNotFound();

        Sanctum::actingAs($admin);
        $this->getJson('/api/v1/itineraries')->assertForbidden();
    }

    public function test_only_public_places_can_be_added_and_duplicates_require_confirmation(): void
    {
        $tourist = $this->user('places', $this->touristRole);
        Sanctum::actingAs($tourist);
        $itinerary = $this->itinerary($tourist);
        $public = $this->place('Alturas Mall Tubigon', true);
        $private = $this->place('Private Draft', false);

        $payload = [
            'entity_type' => 'map_location',
            'entity_id' => $public->id,
            'day_number' => 1,
            'planned_start_time' => '09:00',
            'planned_end_time' => '10:00',
            'notes' => 'Shopping',
        ];
        $first = $this->postJson("/api/v1/itineraries/{$itinerary->id}/items", $payload)
            ->assertCreated()
            ->assertJsonPath('data.place.name', 'Alturas Mall Tubigon')
            ->json('data');

        $this->postJson("/api/v1/itineraries/{$itinerary->id}/items", $payload)
            ->assertStatus(409)
            ->assertJsonPath('status', 'duplicate')
            ->assertJsonPath('data.existing_item_id', $first['id']);

        $this->postJson("/api/v1/itineraries/{$itinerary->id}/items", [
            ...$payload,
            'allow_duplicate' => true,
        ])->assertCreated();

        $this->postJson("/api/v1/itineraries/{$itinerary->id}/items", [
            'entity_type' => 'map_location',
            'entity_id' => $private->id,
            'day_number' => 1,
        ])->assertUnprocessable()->assertJsonValidationErrors('entity_id');

        $this->assertDatabaseCount('itinerary_items', 2);
    }

    public function test_tourist_can_reorder_move_and_mark_stops_without_cross_itinerary_updates(): void
    {
        $tourist = $this->user('order', $this->touristRole);
        Sanctum::actingAs($tourist);
        $itinerary = $this->itinerary($tourist, 2);
        $first = $itinerary->items()->create([
            'entity_type' => 'map_location', 'entity_id' => $this->place('First', true)->id,
            'day_number' => 1, 'sort_order' => 1,
        ]);
        $second = $itinerary->items()->create([
            'entity_type' => 'map_location', 'entity_id' => $this->place('Second', true)->id,
            'day_number' => 1, 'sort_order' => 2,
        ]);

        $this->putJson("/api/v1/itineraries/{$itinerary->id}/items/reorder", [
            'items' => [
                ['id' => $second->id, 'day_number' => 1, 'sort_order' => 1],
                ['id' => $first->id, 'day_number' => 2, 'sort_order' => 1],
            ],
        ])->assertOk();

        $this->putJson("/api/v1/itineraries/{$itinerary->id}/items/{$first->id}", [
            'visit_status' => 'visited',
            'planned_start_time' => '11:00',
            'planned_end_time' => '12:00',
        ])->assertOk()->assertJsonPath('data.visit_status', 'visited');

        $this->assertDatabaseHas('itinerary_items', [
            'id' => $first->id, 'day_number' => 2, 'sort_order' => 1, 'visit_status' => 'visited',
        ]);
    }

    public function test_dates_days_times_and_entity_types_are_validated(): void
    {
        $tourist = $this->user('validation', $this->touristRole);
        Sanctum::actingAs($tourist);

        $this->postJson('/api/v1/itineraries', [
            'name' => 'Bad dates',
            'start_date' => '2026-09-10',
            'end_date' => '2026-09-09',
        ])->assertUnprocessable()->assertJsonValidationErrors('end_date');

        $itinerary = $this->itinerary($tourist);
        $this->postJson("/api/v1/itineraries/{$itinerary->id}/items", [
            'entity_type' => 'emergency',
            'entity_id' => $this->place('Emergency', true)->id,
            'day_number' => 2,
            'planned_start_time' => '13:00',
            'planned_end_time' => '12:00',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['entity_type', 'planned_end_time']);
    }

    public function test_matching_reservation_is_linked_without_creating_a_duplicate_booking(): void
    {
        $tourist = $this->user('reservation', $this->touristRole);
        Sanctum::actingAs($tourist);
        $itinerary = $this->itinerary($tourist);
        $category = SpotCategory::create(['name' => 'Heritage', 'slug' => 'heritage']);
        $spot = TouristSpot::create([
            'name' => 'Tubigon Heritage Walk',
            'slug' => 'tubigon-heritage-walk',
            'category_id' => $category->id,
            'latitude' => 9.951,
            'longitude' => 123.962,
            'is_active' => true,
        ]);
        $status = ReservationStatus::create(['name' => 'confirmed']);
        $reservation = Reservation::create([
            'user_id' => $tourist->id,
            'reservable_type' => 'spot',
            'reservable_id' => $spot->id,
            'reservation_date' => $itinerary->start_date,
            'guests' => 2,
            'status_id' => $status->id,
        ]);

        $this->postJson("/api/v1/itineraries/{$itinerary->id}/items", [
            'entity_type' => 'tourist_spot',
            'entity_id' => $spot->id,
            'day_number' => 1,
        ])->assertCreated()
            ->assertJsonPath('data.reservation.id', $reservation->id)
            ->assertJsonPath('data.reservation.status', 'confirmed');

        $this->assertDatabaseCount('reservations', 1);
        $this->assertDatabaseHas('itinerary_items', [
            'itinerary_id' => $itinerary->id,
            'reservation_id' => $reservation->id,
        ]);
    }

    public function test_tomorrow_reminder_reuses_notifications_and_is_idempotent(): void
    {
        $tourist = $this->user('reminder', $this->touristRole);
        Itinerary::create([
            'user_id' => $tourist->id,
            'name' => 'Tomorrow in Tubigon',
            'start_date' => today()->addDay(),
            'end_date' => today()->addDay(),
            'status' => 'upcoming',
        ]);

        $this->artisan('itineraries:send-reminders')->assertSuccessful();
        $this->artisan('itineraries:send-reminders')->assertSuccessful();

        $this->assertDatabaseCount('notifications', 1);
        $this->assertDatabaseHas('notifications', [
            'user_id' => $tourist->id,
            'type' => 'itinerary_reminder',
            'is_read' => false,
        ]);
    }

    private function user(string $key, Role $role): User
    {
        return User::create([
            'name' => ucfirst($key),
            'email' => "$key@itinerary.test",
            'password' => 'safe-password',
            'role_id' => $role->id,
            'is_verified' => true,
        ]);
    }

    private function itinerary(User $user, int $days = 1): Itinerary
    {
        return Itinerary::create([
            'user_id' => $user->id,
            'name' => 'Tubigon Plan',
            'start_date' => now()->toDateString(),
            'end_date' => now()->addDays($days - 1)->toDateString(),
            'status' => 'draft',
        ]);
    }

    private function place(string $name, bool $public): MapLocation
    {
        $category = MapLocationCategory::firstOrCreate(['slug' => 'shopping'], [
            'name' => 'Shopping', 'icon' => 'shopping_bag', 'marker_color' => '#EC4899', 'active' => true,
        ]);

        return MapLocation::create([
            'name' => $name,
            'slug' => str($name)->slug().'-'.str()->random(5),
            'category_id' => $category->id,
            'latitude' => 9.95134,
            'longitude' => 123.96236,
            'active' => true,
            'verified' => $public,
            'published' => $public,
        ]);
    }

    private function createSchema(): void
    {
        foreach (['itinerary_items', 'itineraries', 'notifications', 'reservations', 'reservation_status', 'tourist_spots', 'spot_categories', 'map_locations', 'map_location_categories', 'users', 'roles'] as $table) {
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
            $table->string('slug')->unique();
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('tourist_spots', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->string('slug')->unique();
            $table->text('description')->nullable();
            $table->uuid('category_id')->nullable();
            $table->double('latitude')->nullable();
            $table->double('longitude')->nullable();
            $table->text('address')->nullable();
            $table->decimal('entrance_fee')->default(0);
            $table->string('opening_hours')->nullable();
            $table->json('eco_tips')->nullable();
            $table->json('images')->nullable();
            $table->decimal('average_rating')->default(0);
            $table->unsignedInteger('review_count')->default(0);
            $table->boolean('is_featured')->default(false);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('reservation_status', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name')->unique();
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('reservations', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id');
            $table->uuid('partner_id')->nullable();
            $table->string('reservable_type');
            $table->uuid('reservable_id');
            $table->date('reservation_date');
            $table->time('start_time')->nullable();
            $table->time('end_time')->nullable();
            $table->unsignedInteger('guests')->default(1);
            $table->uuid('status_id')->nullable();
            $table->text('notes')->nullable();
            $table->decimal('total_amount')->default(0);
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('notifications', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id');
            $table->string('type');
            $table->string('title');
            $table->text('body');
            $table->json('data')->nullable();
            $table->boolean('is_read')->default(false);
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('itineraries', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id');
            $table->string('name');
            $table->text('description')->nullable();
            $table->date('start_date');
            $table->date('end_date');
            $table->unsignedSmallInteger('travelers')->nullable();
            $table->string('status')->default('draft');
            $table->string('start_location_type')->default('first_stop');
            $table->string('start_location_name')->nullable();
            $table->uuid('start_location_id')->nullable();
            $table->double('start_latitude')->nullable();
            $table->double('start_longitude')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('itinerary_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('itinerary_id');
            $table->string('entity_type');
            $table->uuid('entity_id');
            $table->unsignedSmallInteger('day_number')->default(1);
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->time('planned_start_time')->nullable();
            $table->time('planned_end_time')->nullable();
            $table->text('notes')->nullable();
            $table->uuid('reservation_id')->nullable();
            $table->string('visit_status')->default('planned');
            $table->timestamps();
            $table->softDeletes();
        });
    }
}
