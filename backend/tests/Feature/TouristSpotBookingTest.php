<?php

namespace Tests\Feature;

use App\Models\Reservation;
use App\Models\ReservationStatus;
use App\Models\Role;
use App\Models\TouristSpot;
use App\Models\User;
use Database\Seeders\DevelopmentFeaturedDestinationBookingSeeder;
use Database\Seeders\FeaturedDestinationSeeder;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Schema;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class TouristSpotBookingTest extends TestCase
{
    private Role $touristRole;

    private Role $lguRole;

    private Role $partnerRole;

    private Role $msmeRole;

    protected function setUp(): void
    {
        parent::setUp();
        $this->createSchema();
        $this->touristRole = Role::create(['name' => 'tourist']);
        $this->lguRole = Role::create(['name' => 'lgu_staff']);
        $this->partnerRole = Role::create(['name' => 'tourism_partner']);
        $this->msmeRole = Role::create(['name' => 'msme_owner']);
        Role::create(['name' => 'admin']);
        foreach (['pending', 'approved', 'confirmed', 'rejected', 'completed', 'cancelled'] as $name) {
            ReservationStatus::create(['name' => $name]);
        }
    }

    public function test_guest_and_non_tourist_roles_cannot_create_spot_reservations(): void
    {
        $spot = $this->spot(['is_bookable' => true, 'booking_mode' => 'date_only']);
        $payload = $this->payload($spot);

        $this->postJson('/api/v1/reservations', $payload)->assertUnauthorized();

        Sanctum::actingAs($this->user('partner', $this->partnerRole));
        $this->postJson('/api/v1/reservations', $payload)->assertForbidden();

        Sanctum::actingAs($this->user('msme', $this->msmeRole));
        $this->postJson('/api/v1/reservations', $payload)->assertForbidden();
    }

    public function test_eight_featured_destinations_are_seeded_public_and_non_bookable_by_default(): void
    {
        $this->seed(FeaturedDestinationSeeder::class);

        $this->assertEqualsCanonicalizing(
            FeaturedDestinationSeeder::NAMES,
            TouristSpot::query()->pluck('name')->all(),
        );
        $this->assertSame(8, TouristSpot::where('is_featured', true)
            ->where('is_active', true)
            ->where('is_published', true)
            ->where('is_preapproved', true)
            ->where('is_bookable', false)
            ->count());
        foreach (FeaturedDestinationSeeder::DESTINATIONS as $expected) {
            $this->assertDatabaseHas('tourist_spots', [
                'id' => $expected['id'],
                'name' => $expected['name'],
                'slug' => $expected['slug'],
                'latitude' => $expected['latitude'],
                'longitude' => $expected['longitude'],
                'short_description' => $expected['short_description'],
                'description' => $expected['description'],
                'is_featured' => true,
                'is_active' => true,
                'is_published' => true,
                'is_preapproved' => true,
                'is_bookable' => false,
            ]);
        }
        $this->getJson('/api/v1/tourist-spots?featured_only=1')
            ->assertOk()
            ->assertJsonCount(8, 'data');
    }

    public function test_featured_seed_is_idempotent_preserves_staff_edits_and_canonicalizes_ilijan_alias(): void
    {
        $legacy = TouristSpot::create([
            'name' => 'Ilijan Hill',
            'slug' => 'ilijan-hill',
            'description' => 'Legacy description.',
            'is_active' => false,
            'is_published' => false,
        ]);

        $this->seed(FeaturedDestinationSeeder::class);
        $canonical = TouristSpot::where('slug', 'enchanted-ilijan-hill')->firstOrFail();
        $this->assertSame($legacy->id, $canonical->id);
        $this->assertSame('Enchanted Ilijan Hill Volcanic Nature Park', $canonical->name);
        $this->assertTrue($canonical->is_preapproved);

        $canonical->update([
            'short_description' => 'LGU-edited summary.',
            'description' => 'LGU-edited description.',
            'latitude' => 9.90001,
            'longitude' => 123.90001,
            'is_featured' => false,
            'is_active' => false,
            'is_published' => false,
        ]);
        $ids = TouristSpot::pluck('id')->sort()->values()->all();

        $this->seed(FeaturedDestinationSeeder::class);

        $this->assertSame($ids, TouristSpot::pluck('id')->sort()->values()->all());
        $canonical->refresh();
        $this->assertSame('LGU-edited summary.', $canonical->short_description);
        $this->assertSame('LGU-edited description.', $canonical->description);
        $this->assertSame(9.91339, $canonical->latitude);
        $this->assertSame(123.94232, $canonical->longitude);
        $this->assertFalse($canonical->is_featured);
        $this->assertFalse($canonical->is_active);
        $this->assertFalse($canonical->is_published);
    }

    public function test_tourist_spot_management_rejects_malformed_coordinates_and_accepts_controlled_marine_coordinates(): void
    {
        $this->seed(FeaturedDestinationSeeder::class);
        $spot = TouristSpot::where('slug', 'dumog-sandbar')->firstOrFail();
        Sanctum::actingAs($this->user('coordinate-lgu', $this->lguRole));

        $this->putJson("/api/v1/lgu/tourist-spots/{$spot->id}", [
            'latitude' => 91,
            'longitude' => 181,
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['latitude', 'longitude']);

        $this->putJson("/api/v1/lgu/tourist-spots/{$spot->id}", [
            'latitude' => 9.98820,
            'longitude' => 123.87830,
        ])->assertOk()
            ->assertJsonPath('data.latitude', 9.9882)
            ->assertJsonPath('data.longitude', 123.8783);
    }

    public function test_local_demo_booking_seed_is_opt_in_and_never_overwrites_later_staff_choice(): void
    {
        $this->seed(FeaturedDestinationSeeder::class);
        $spot = TouristSpot::where('slug', 'mundong-sandbar')->firstOrFail();

        config()->set('tourist_spot_booking.demo_enabled', false);
        config()->set('tourist_spot_booking.demo_slugs', ['mundong-sandbar']);
        $this->seed(DevelopmentFeaturedDestinationBookingSeeder::class);
        $this->assertFalse($spot->fresh()->is_bookable);

        config()->set('tourist_spot_booking.demo_enabled', true);
        $this->seed(DevelopmentFeaturedDestinationBookingSeeder::class);
        $spot->refresh();
        $this->assertTrue($spot->is_bookable);
        $this->assertSame('date_only', $spot->booking_mode);
        $this->assertNotNull($spot->demo_booking_seeded_at);

        $spot->update(['is_bookable' => false, 'booking_mode' => 'no_reservation']);
        $this->seed(DevelopmentFeaturedDestinationBookingSeeder::class);
        $this->assertFalse($spot->fresh()->is_bookable);
    }

    public function test_public_bookable_filter_excludes_disabled_unpublished_and_inactive_spots(): void
    {
        $included = $this->spot([
            'name' => 'Bookable Public Spot',
            'is_bookable' => true,
            'booking_mode' => 'date_only',
        ]);
        $this->spot(['name' => 'Disabled Spot']);
        $this->spot([
            'name' => 'Unpublished Bookable Spot',
            'is_bookable' => true,
            'booking_mode' => 'date_only',
            'is_published' => false,
        ]);
        $this->spot([
            'name' => 'Inactive Bookable Spot',
            'is_bookable' => true,
            'booking_mode' => 'date_only',
            'is_active' => false,
        ]);

        $this->getJson('/api/v1/tourist-spots?bookable_only=1')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $included->id);
    }

    public function test_preapproval_is_not_available_to_normal_management_writes(): void
    {
        $adminRole = Role::where('name', 'admin')->firstOrFail();
        Sanctum::actingAs($this->user('destination-admin', $adminRole));
        $response = $this->postJson('/api/v1/admin/tourist-spots', [
            'name' => 'Future Governed Destination',
            'is_preapproved' => true,
        ])->assertCreated()
            ->assertJsonPath('data.is_published', false)
            ->assertJsonPath('data.is_preapproved', false);

        $spotId = $response->json('data.id');
        Sanctum::actingAs($this->user('destination-lgu', $this->lguRole));
        $this->putJson("/api/v1/lgu/tourist-spots/$spotId", [
            'short_description' => 'LGU-managed summary.',
            'description' => 'LGU-managed full description.',
            'aliases' => ['Governed destination'],
            'is_preapproved' => true,
        ])->assertOk()
            ->assertJsonPath('data.short_description', 'LGU-managed summary.')
            ->assertJsonPath('data.is_preapproved', false);

        $this->assertDatabaseHas('tourist_spots', [
            'id' => $spotId,
            'short_description' => 'LGU-managed summary.',
            'description' => 'LGU-managed full description.',
            'is_preapproved' => false,
            'is_published' => false,
        ]);
    }

    public function test_non_bookable_unpublished_inactive_and_invalid_requests_are_rejected(): void
    {
        Sanctum::actingAs($this->user('tourist', $this->touristRole));

        $this->postJson('/api/v1/reservations', $this->payload($this->spot()))
            ->assertUnprocessable();
        $this->postJson('/api/v1/reservations', $this->payload($this->spot([
            'is_bookable' => true,
            'booking_mode' => 'date_only',
            'is_published' => false,
        ])))->assertUnprocessable();
        $this->postJson('/api/v1/reservations', $this->payload($this->spot([
            'is_bookable' => true,
            'booking_mode' => 'date_only',
            'is_active' => false,
        ])))->assertUnprocessable();

        $valid = $this->spot(['is_bookable' => true, 'booking_mode' => 'date_only']);
        $this->postJson('/api/v1/reservations', array_merge($this->payload($valid), [
            'reservation_date' => now()->subDay()->toDateString(),
        ]))->assertUnprocessable();
        $this->postJson('/api/v1/reservations', array_merge($this->payload($valid), [
            'guests' => 0,
        ]))->assertUnprocessable();
        $this->postJson('/api/v1/reservations', array_merge($this->payload($valid), [
            'reservation_date' => now()->addDays(366)->toDateString(),
        ]))->assertUnprocessable();
        $this->postJson('/api/v1/reservations', array_merge($this->payload($valid), [
            'reservable_id' => '00000000-0000-4000-8000-000000000000',
        ]))->assertNotFound();
    }

    public function test_capacity_date_day_and_time_slot_rules_are_authoritative(): void
    {
        $tourist = $this->user('capacity-tourist', $this->touristRole);
        $spot = $this->spot([
            'is_bookable' => true,
            'booking_mode' => 'date_time_slot',
            'booking_available_days' => [strtolower(now()->addDays(2)->format('l'))],
            'booking_time_slots' => [[
                'start' => '09:00',
                'end' => '10:00',
                'capacity' => 3,
            ]],
            'max_guests_per_reservation' => 3,
        ]);
        $pending = ReservationStatus::where('name', 'pending')->firstOrFail();
        Reservation::create([
            'user_id' => $tourist->id,
            'reservable_type' => 'spot',
            'reservable_id' => $spot->id,
            'reservation_date' => now()->addDays(2)->toDateString(),
            'start_time' => '09:00',
            'end_time' => '10:00',
            'guests' => 2,
            'status_id' => $pending->id,
        ]);

        Sanctum::actingAs($this->user('second-tourist', $this->touristRole));
        $base = array_merge($this->payload($spot), [
            'reservation_date' => now()->addDays(2)->toDateString(),
        ]);
        $this->postJson('/api/v1/reservations', array_merge($base, [
            'start_time' => '08:00',
        ]))->assertUnprocessable();
        $this->postJson('/api/v1/reservations', array_merge($base, [
            'start_time' => '09:00',
            'guests' => 2,
        ]))->assertUnprocessable();
        $this->postJson('/api/v1/reservations', array_merge($base, [
            'start_time' => '09:00',
            'guests' => 1,
        ]))->assertCreated();

        $this->assertSame(3, (int) Reservation::where('reservable_id', $spot->id)->sum('guests'));
    }

    public function test_tourist_idor_and_cancellation_rules_retain_auditable_rows(): void
    {
        $owner = $this->user('owner', $this->touristRole);
        $attacker = $this->user('attacker', $this->touristRole);
        $reservation = $this->reservation($owner, $this->spot([
            'is_bookable' => true,
            'booking_mode' => 'date_only',
        ]));

        Sanctum::actingAs($attacker);
        $this->getJson("/api/v1/reservations/{$reservation->id}")->assertForbidden();
        $this->putJson("/api/v1/reservations/{$reservation->id}/cancel")->assertForbidden();

        Sanctum::actingAs($owner);
        $this->putJson("/api/v1/reservations/{$reservation->id}/cancel")
            ->assertOk();
        $this->assertDatabaseHas('reservations', ['id' => $reservation->id]);
        $this->assertDatabaseHas('reservation_status_history', [
            'reservation_id' => $reservation->id,
            'notes' => 'Cancelled by tourist',
        ]);
    }

    public function test_lgu_configuration_tourist_booking_staff_confirmation_and_notification_flow(): void
    {
        $spot = $this->spot();
        $lgu = $this->user('lgu', $this->lguRole);
        $tourist = $this->user('flow-tourist', $this->touristRole);

        Sanctum::actingAs($tourist);
        $this->putJson("/api/v1/lgu/tourist-spots/{$spot->id}/booking", [])
            ->assertForbidden();

        Sanctum::actingAs($lgu);
        $this->putJson("/api/v1/lgu/tourist-spots/{$spot->id}/booking", [
            'is_bookable' => true,
            'booking_mode' => 'date_only',
            'booking_available_days' => [],
            'max_guests_per_reservation' => 5,
            'capacity_per_slot' => 10,
            'advance_booking_days' => 30,
            'minimum_notice_hours' => 0,
            'reservation_fee' => 75,
            'booking_instructions' => 'Bring the server-issued reference.',
            'cancellation_policy' => 'Cancel before the configured notice period.',
            'cancellation_notice_hours' => 12,
        ])->assertOk()->assertJsonPath('data.is_bookable', true);
        $this->patchJson("/api/v1/lgu/tourist-spots/{$spot->id}/booking-availability", [
            'booking_enabled' => true,
        ])->assertOk()->assertJsonPath('data.booking_enabled', true);

        Sanctum::actingAs($tourist);
        $created = $this->postJson('/api/v1/reservations', array_merge($this->payload($spot), [
            'guests' => 2,
        ]))->assertCreated()
            ->assertJsonPath('data.status.name', 'pending')
            ->assertJsonPath('data.total_amount', 150);
        $reservationId = $created->json('data.id');
        $this->assertMatchesRegularExpression(
            '/^TB-RSV-\d{4}-[A-Z0-9]{8}$/',
            $created->json('data.public_reference'),
        );
        $this->assertDatabaseHas('notifications', [
            'user_id' => $tourist->id,
            'type' => 'reservation_submitted',
        ]);

        Sanctum::actingAs($lgu);
        $this->getJson('/api/v1/lgu/reservations')
            ->assertOk()->assertJsonFragment(['id' => $reservationId]);
        $confirmed = ReservationStatus::where('name', 'confirmed')->firstOrFail();
        $this->putJson("/api/v1/lgu/reservations/{$reservationId}/status", [
            'status_id' => $confirmed->id,
        ])->assertOk();

        Sanctum::actingAs($tourist);
        $this->getJson("/api/v1/reservations/{$reservationId}")
            ->assertOk()
            ->assertJsonPath('data.status.name', 'confirmed')
            ->assertJsonPath('data.booking_instructions', 'Bring the server-issued reference.');
        $this->getJson('/api/v1/notifications')
            ->assertOk()
            ->assertJsonFragment([
                'type' => 'reservation_confirmed',
                'user_id' => $tourist->id,
            ]);
    }

    public function test_lgu_can_configure_verified_date_and_time_slots(): void
    {
        $spot = $this->spot();
        Sanctum::actingAs($this->user('slot-lgu', $this->lguRole));

        $this->putJson("/api/v1/lgu/tourist-spots/{$spot->id}/booking", [
            'is_bookable' => true,
            'booking_mode' => 'date_time_slot',
            'booking_available_days' => ['monday', 'friday'],
            'booking_time_slots' => [[
                'start' => '09:00',
                'end' => '10:00',
                'capacity' => 12,
            ]],
        ])->assertOk()
            ->assertJsonPath('data.booking_mode', 'date_time_slot')
            ->assertJsonPath('data.booking_time_slots.0.start', '09:00');
    }

    public function test_lgu_cannot_manage_non_spot_reservations(): void
    {
        $lgu = $this->user('scope-lgu', $this->lguRole);
        $tourist = $this->user('scope-tourist', $this->touristRole);
        $pending = ReservationStatus::where('name', 'pending')->firstOrFail();
        $reservation = Reservation::create([
            'user_id' => $tourist->id,
            'reservable_type' => 'tourism_listing',
            'reservable_id' => '00000000-0000-4000-8000-000000000001',
            'reservation_date' => now()->addDays(2),
            'guests' => 1,
            'status_id' => $pending->id,
        ]);
        $confirmed = ReservationStatus::where('name', 'confirmed')->firstOrFail();

        Sanctum::actingAs($lgu);
        $this->getJson('/api/v1/lgu/reservations')
            ->assertOk()->assertJsonMissing(['id' => $reservation->id]);
        $this->getJson("/api/v1/lgu/reservations/{$reservation->id}")
            ->assertForbidden();
        $this->putJson("/api/v1/lgu/reservations/{$reservation->id}/status", [
            'status_id' => $confirmed->id,
        ])->assertForbidden();
    }

    public function test_upcoming_reservation_reminder_is_real_and_idempotent(): void
    {
        Mail::fake();
        $tourist = $this->user('reminder-tourist', $this->touristRole);
        $reservation = Reservation::create([
            'user_id' => $tourist->id,
            'reservable_type' => 'spot',
            'reservable_id' => $this->spot()->id,
            'reservation_date' => today()->addDay(),
            'guests' => 1,
            'status_id' => ReservationStatus::where('name', 'confirmed')->value('id'),
        ]);

        $this->artisan('reservations:send-reminders')->assertSuccessful();
        $this->artisan('reservations:send-reminders')->assertSuccessful();

        $this->assertDatabaseCount('notifications', 1);
        $this->assertDatabaseHas('notifications', [
            'user_id' => $tourist->id,
            'type' => 'reservation_reminder',
        ]);
        Mail::assertSent(\App\Mail\TourTubigonMessage::class, 1);
        $notification = Schema::getConnection()->table('notifications')->first();
        $this->assertStringContainsString($reservation->id, $notification->data);
    }

    private function user(string $key, Role $role): User
    {
        $user = User::create([
            'name' => ucfirst($key),
            'email' => "{$key}@example.test",
            'password' => Hash::make('safe-password'),
            'role_id' => $role->id,
            'is_verified' => true,
        ]);
        Schema::getConnection()->table('profiles')->insert([
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'role_id' => $role->id,
            'is_verified' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $user;
    }

    private function spot(array $attributes = []): TouristSpot
    {
        $data = array_merge([
            'name' => 'Controlled Booking Destination '.fake()->unique()->numberBetween(1, 999999),
            'slug' => fake()->unique()->slug(),
            'is_active' => true,
            'is_published' => true,
            'is_bookable' => false,
            'booking_mode' => 'no_reservation',
        ], $attributes);
        if (! array_key_exists('booking_enabled', $attributes)) {
            $data['booking_enabled'] = (bool) $data['is_bookable'];
        }

        return TouristSpot::create($data);
    }

    private function payload(TouristSpot $spot): array
    {
        return [
            'reservable_type' => 'spot',
            'reservable_id' => $spot->id,
            'reservation_date' => now()->addDays(2)->toDateString(),
            'guests' => 1,
        ];
    }

    private function reservation(User $user, TouristSpot $spot): Reservation
    {
        return Reservation::create([
            'user_id' => $user->id,
            'reservable_type' => 'spot',
            'reservable_id' => $spot->id,
            'reservation_date' => now()->addDays(3),
            'guests' => 1,
            'status_id' => ReservationStatus::where('name', 'pending')->value('id'),
        ]);
    }

    private function createSchema(): void
    {
        foreach ([
            'tourist_spot_booking_availability_history', 'tourist_spot_partner_assignments',
            'reservation_status_history', 'notifications', 'favorites', 'activity_logs',
            'reservations', 'reservation_status', 'tourism_listings',
            'tourist_spots', 'profiles', 'users', 'roles',
            'spot_categories',
        ] as $table) {
            Schema::dropIfExists($table);
        }
        Schema::create('roles', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('name')->unique();
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('users', function (Blueprint $table): void {
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
        Schema::create('profiles', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->string('email')->unique();
            $table->uuid('role_id')->nullable();
            $table->boolean('is_verified')->default(false);
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('spot_categories', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('name')->unique();
            $table->string('slug')->unique();
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('tourist_spots', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->string('slug')->unique();
            $table->text('short_description')->nullable();
            $table->text('description')->nullable();
            $table->json('aliases')->nullable();
            $table->uuid('category_id')->nullable();
            $table->string('address')->nullable();
            $table->boolean('is_active')->default(true);
            $table->boolean('is_published')->default(false);
            $table->boolean('is_featured')->default(false);
            $table->boolean('is_preapproved')->default(false);
            $table->timestamp('preapproved_at')->nullable();
            $table->boolean('is_bookable')->default(false);
            $table->boolean('booking_enabled')->default(false);
            $table->string('booking_unavailable_reason_code')->nullable();
            $table->text('booking_unavailable_reason')->nullable();
            $table->timestamp('booking_availability_updated_at')->nullable();
            $table->uuid('booking_availability_updated_by')->nullable();
            $table->string('booking_mode')->default('no_reservation');
            $table->json('booking_available_days')->nullable();
            $table->json('booking_time_slots')->nullable();
            $table->unsignedInteger('max_guests_per_reservation')->nullable();
            $table->unsignedInteger('capacity_per_slot')->nullable();
            $table->unsignedInteger('advance_booking_days')->nullable();
            $table->unsignedInteger('minimum_notice_hours')->nullable();
            $table->decimal('reservation_fee', 10, 2)->nullable();
            $table->text('booking_instructions')->nullable();
            $table->text('cancellation_policy')->nullable();
            $table->unsignedInteger('cancellation_notice_hours')->nullable();
            $table->text('contact_information')->nullable();
            $table->text('visitor_instructions')->nullable();
            $table->json('amenities')->nullable();
            $table->timestamp('demo_booking_seeded_at')->nullable();
            $table->json('images')->nullable();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('tourism_listings', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('owner_id')->nullable();
            $table->string('listing_name')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('tourist_spot_partner_assignments', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->uuid('tourist_spot_id'); $table->uuid('partner_profile_id'); $table->boolean('is_primary')->default(true); $table->uuid('assigned_by')->nullable(); $table->timestamp('assigned_at'); $table->timestamps();
        });
        Schema::create('tourist_spot_booking_availability_history', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->uuid('tourist_spot_id'); $table->boolean('booking_enabled'); $table->string('reason_code')->nullable(); $table->text('reason')->nullable(); $table->uuid('changed_by')->nullable(); $table->timestamp('changed_at'); $table->timestamps();
        });
        Schema::create('reservation_status', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('name')->unique();
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('reservations', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('public_reference')->nullable()->unique();
            $table->uuid('user_id');
            $table->uuid('partner_id')->nullable();
            $table->string('reservable_type');
            $table->uuid('reservable_id');
            $table->dateTime('reservation_date');
            $table->string('start_time')->nullable();
            $table->string('end_time')->nullable();
            $table->unsignedInteger('guests')->default(1);
            $table->uuid('status_id')->nullable();
            $table->text('notes')->nullable();
            $table->decimal('total_amount', 10, 2)->default(0);
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('reservation_status_history', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('reservation_id');
            $table->uuid('status_id');
            $table->uuid('changed_by')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
        });
        Schema::create('notifications', function (Blueprint $table): void {
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
        Schema::create('favorites', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->uuid('user_id'); $table->string('favoritable_type'); $table->uuid('favoritable_id'); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('activity_logs', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('user_id')->nullable();
            $table->string('action');
            $table->text('details')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });
    }
}
