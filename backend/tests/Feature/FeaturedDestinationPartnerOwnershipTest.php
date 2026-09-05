<?php

namespace Tests\Feature;

use App\Models\Profile;
use App\Models\PartnerNotification;
use App\Models\Reservation;
use App\Models\ReservationStatus;
use App\Models\Role;
use App\Models\Review;
use App\Models\TouristSpot;
use App\Models\TouristSpotPartnerAssignment;
use App\Models\User;
use Database\Seeders\DevelopmentFeaturedDestinationPartnerSeeder;
use Database\Seeders\FeaturedDestinationSeeder;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Schema;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class FeaturedDestinationPartnerOwnershipTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        $this->createSchema();
        foreach (['tourist', 'msme_owner', 'lgu_staff', 'admin', 'tourism_partner'] as $name) {
            Role::create(['name' => $name]);
        }
        foreach (['pending', 'approved', 'confirmed', 'rejected', 'completed', 'cancelled'] as $name) {
            ReservationStatus::create(['name' => $name]);
        }
        config()->set('tourist_spot_partners.development_password', 'Partner123!');
    }

    public function test_controlled_seeder_creates_eight_idempotent_accounts_profiles_and_assignments(): void
    {
        $existing = $this->user('Original Partner', 'partner@gmail.com', 'tourism_partner');
        $existingPasswordHash = $existing->password;
        $controlledExisting = $this->user(
            'Previously Provisioned Mundong Partner',
            'mundong@gmail.com',
            'tourism_partner',
        );
        $controlledExistingHash = $controlledExisting->password;

        $this->seed(FeaturedDestinationSeeder::class);
        $this->seed(DevelopmentFeaturedDestinationPartnerSeeder::class);
        $firstIds = User::whereIn('email', array_keys(DevelopmentFeaturedDestinationPartnerSeeder::ACCOUNTS))
            ->orderBy('email')->pluck('id')->all();
        $this->seed(DevelopmentFeaturedDestinationPartnerSeeder::class);

        $this->assertCount(8, $firstIds);
        $this->assertSame($firstIds, User::whereIn('email', array_keys(DevelopmentFeaturedDestinationPartnerSeeder::ACCOUNTS))
            ->orderBy('email')->pluck('id')->all());
        $this->assertDatabaseCount('tourist_spot_partner_assignments', 8);
        $this->assertSame(8, Profile::whereIn('email', array_keys(DevelopmentFeaturedDestinationPartnerSeeder::ACCOUNTS))->count());
        $this->assertDatabaseHas('users', ['id' => $existing->id, 'email' => 'partner@gmail.com']);
        $this->assertSame($existingPasswordHash, $existing->fresh()->password);
        $this->assertNotSame($controlledExistingHash, $controlledExisting->fresh()->password);

        foreach (DevelopmentFeaturedDestinationPartnerSeeder::ACCOUNTS as $email => [, $slug]) {
            $user = User::with('role')->where('email', $email)->firstOrFail();
            $spot = TouristSpot::where('slug', $slug)->firstOrFail();
            $this->assertSame('tourism_partner', $user->role->name);
            $this->assertTrue(Hash::check('Partner123!', $user->password));
            $this->assertNotSame('Partner123!', $user->password);
            $this->assertDatabaseHas('profiles', ['id' => $user->id, 'role_id' => $user->role_id]);
            $this->assertDatabaseHas('tourist_spot_partner_assignments', [
                'tourist_spot_id' => $spot->id,
                'partner_profile_id' => $user->id,
                'is_primary' => true,
            ]);
            $this->assertTrue($spot->is_featured);
            $this->assertTrue($spot->is_active);
            $this->assertTrue($spot->is_published);
            $this->assertTrue($spot->is_bookable);
            $this->assertTrue($spot->booking_enabled);
            $this->assertSame('date_only', $spot->booking_mode);
            $this->postJson('/api/v1/auth/login', [
                'email' => $email,
                'password' => 'Partner123!',
            ])->assertOk()
                ->assertJsonPath('data.role', 'tourism_partner')
                ->assertJsonPath('data.user.email', $email);
        }
    }

    public function test_partner_content_and_availability_are_owner_scoped_while_lgu_can_supervise_all(): void
    {
        $this->seedAccounts();
        $mundong = TouristSpot::where('slug', 'mundong-sandbar')->firstOrFail();
        $dumog = TouristSpot::where('slug', 'dumog-sandbar')->firstOrFail();
        $mundongPartner = User::where('email', 'mundong@gmail.com')->firstOrFail();
        $dumogPartner = User::where('email', 'dumog@gmail.com')->firstOrFail();

        Sanctum::actingAs($mundongPartner);
        $this->getJson('/api/v1/partner/tourist-spots')
            ->assertOk()->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $mundong->id);
        $this->getJson("/api/v1/partner/tourist-spots/{$dumog->id}")->assertForbidden();
        $this->patchJson("/api/v1/partner/tourist-spots/{$mundong->id}", [
            'short_description' => 'Partner-owned authoritative summary.',
            'visitor_instructions' => 'Bring sun protection.',
        ])->assertOk();
        $this->getJson("/api/v1/tourist-spots/{$mundong->id}")
            ->assertOk()
            ->assertJsonPath('data.short_description', 'Partner-owned authoritative summary.')
            ->assertJsonPath('data.visitor_instructions', 'Bring sun protection.');

        $this->patchJson("/api/v1/partner/tourist-spots/{$mundong->id}/booking-availability", [
            'booking_enabled' => false,
        ])->assertUnprocessable()->assertJsonValidationErrors('reason_code');
        $this->patchJson("/api/v1/partner/tourist-spots/{$dumog->id}/booking-availability", [
            'booking_enabled' => false,
            'reason_code' => 'weather_conditions',
        ])->assertForbidden();
        $this->patchJson("/api/v1/partner/tourist-spots/{$mundong->id}/booking-availability", [
            'booking_enabled' => false,
            'reason_code' => 'weather_conditions',
            'reason' => 'Rough sea conditions.',
        ])->assertOk()
            ->assertJsonPath('data.booking_enabled', false)
            ->assertJsonPath('data.booking_unavailable_reason_code', 'weather_conditions');
        $this->assertDatabaseHas('tourist_spot_booking_availability_history', [
            'tourist_spot_id' => $mundong->id,
            'booking_enabled' => false,
            'changed_by' => $mundongPartner->id,
        ]);

        Sanctum::actingAs($dumogPartner);
        $this->patchJson("/api/v1/partner/tourist-spots/{$mundong->id}/booking-availability", [
            'booking_enabled' => true,
        ])->assertForbidden();

        $lgu = $this->user('LGU', 'ownership-lgu@example.test', 'lgu_staff');
        Sanctum::actingAs($lgu);
        $this->patchJson("/api/v1/lgu/tourist-spots/{$mundong->id}/booking-availability", [
            'booking_enabled' => true,
        ])->assertOk()->assertJsonPath('data.booking_enabled', true);

        foreach (['tourist', 'msme_owner', 'admin'] as $role) {
            Sanctum::actingAs($this->user($role, "$role-toggle@example.test", $role));
            $this->patchJson("/api/v1/lgu/tourist-spots/{$mundong->id}/booking-availability", [
                'booking_enabled' => false,
                'reason_code' => 'maintenance',
            ])->assertForbidden();
        }
    }

    public function test_disabled_booking_blocks_only_new_reservations_and_remains_public_with_reason(): void
    {
        $this->seedAccounts();
        $spot = TouristSpot::where('slug', 'mundong-sandbar')->firstOrFail();
        $tourist = $this->user('Tourist', 'booking-tourist@example.test', 'tourist');
        $existing = Reservation::create([
            'user_id' => $tourist->id,
            'reservable_type' => 'spot',
            'reservable_id' => $spot->id,
            'reservation_date' => now()->addDays(3),
            'guests' => 2,
            'status_id' => ReservationStatus::where('name', 'confirmed')->value('id'),
        ]);

        Sanctum::actingAs(User::where('email', 'mundong@gmail.com')->firstOrFail());
        $this->patchJson("/api/v1/partner/tourist-spots/{$spot->id}/booking-availability", [
            'booking_enabled' => false,
            'reason_code' => 'unsafe_sea_conditions',
            'reason' => 'Boat trips are temporarily suspended.',
        ])->assertOk();

        Sanctum::actingAs($tourist);
        $this->postJson('/api/v1/reservations', [
            'reservable_type' => 'spot',
            'reservable_id' => $spot->id,
            'reservation_date' => now()->addDays(2)->toDateString(),
            'guests' => 1,
        ])->assertUnprocessable()
            ->assertJsonFragment(['Booking is currently unavailable. Reason: Unsafe Sea Conditions. Boat trips are temporarily suspended.']);
        $this->assertDatabaseHas('reservations', [
            'id' => $existing->id,
            'status_id' => ReservationStatus::where('name', 'confirmed')->value('id'),
        ]);
        $this->getJson('/api/v1/tourist-spots?featured_only=1')
            ->assertOk()
            ->assertJsonFragment([
                'id' => $spot->id,
                'is_featured' => true,
                'booking_enabled' => false,
                'booking_unavailable_reason_code' => 'unsafe_sea_conditions',
            ]);
    }

    public function test_partner_reservations_use_assignment_ids_and_block_idor(): void
    {
        $this->seedAccounts();
        $mundong = TouristSpot::where('slug', 'mundong-sandbar')->firstOrFail();
        $dumog = TouristSpot::where('slug', 'dumog-sandbar')->firstOrFail();
        $tourist = $this->user('Reservation Tourist', 'reservation-tourist@example.test', 'tourist');
        $pending = ReservationStatus::where('name', 'pending')->firstOrFail();
        $mundongReservation = Reservation::create([
            'user_id' => $tourist->id,
            'reservable_type' => 'spot',
            'reservable_id' => $mundong->id,
            'reservation_date' => now()->addDays(2),
            'guests' => 2,
            'status_id' => $pending->id,
        ]);
        $dumogReservation = Reservation::create([
            'user_id' => $tourist->id,
            'partner_id' => User::where('email', 'mundong@gmail.com')->value('id'),
            'reservable_type' => 'spot',
            'reservable_id' => $dumog->id,
            'reservation_date' => now()->addDays(3),
            'guests' => 1,
            'status_id' => $pending->id,
        ]);

        Sanctum::actingAs(User::where('email', 'mundong@gmail.com')->firstOrFail());
        $this->getJson('/api/v1/partner/reservations')
            ->assertOk()
            ->assertJsonFragment(['id' => $mundongReservation->id])
            ->assertJsonMissing(['id' => $dumogReservation->id]);
        $this->getJson("/api/v1/partner/reservations/{$dumogReservation->id}")->assertForbidden();
        $this->putJson("/api/v1/partner/reservations/{$dumogReservation->id}/status", [
            'status_name' => 'confirmed',
        ])->assertForbidden();
        $this->putJson("/api/v1/partner/reservations/{$mundongReservation->id}/status", [
            'status_name' => 'confirmed',
        ])->assertOk();
        $this->assertDatabaseHas('notifications', [
            'user_id' => $tourist->id,
            'type' => 'reservation_confirmed',
        ]);
    }

    public function test_assigned_partner_sees_only_reviews_for_owned_destinations(): void
    {
        $this->seedAccounts();
        $tourist = $this->user('Reviewing Tourist', 'reviewer@example.test', 'tourist');
        $mundongPartner = User::where('email', 'mundong@gmail.com')->firstOrFail();
        $ilijanPartner = User::where('email', 'ilijan@gmail.com')->firstOrFail();
        $mundong = TouristSpot::where('slug', 'mundong-sandbar')->firstOrFail();
        $ilijan = TouristSpot::where('slug', 'enchanted-ilijan-hill')->firstOrFail();

        Sanctum::actingAs($tourist);
        $ownReviewId = $this->postJson('/api/v1/reviews', [
            'reviewable_type' => 'spot',
            'reviewable_id' => $mundong->id,
            'rating' => 5,
            'content' => 'A verified destination review.',
        ])->assertCreated()->json('data.id');
        $otherReviewId = $this->postJson('/api/v1/reviews', [
            'reviewable_type' => 'spot',
            'reviewable_id' => $ilijan->id,
            'rating' => 4,
            'content' => 'Another destination review.',
        ])->assertCreated()->json('data.id');

        $this->assertDatabaseHas('partner_notifications', [
            'user_id' => $mundongPartner->id,
            'type' => 'new_review',
        ]);

        Sanctum::actingAs($mundongPartner);
        $this->getJson('/api/v1/partner/reviews')
            ->assertOk()
            ->assertJsonFragment(['id' => $ownReviewId])
            ->assertJsonMissing(['id' => $otherReviewId]);
        $this->getJson('/api/v1/partner/review-stats')
            ->assertOk()
            ->assertJsonPath('data.totalReviews', 1);

        Sanctum::actingAs($ilijanPartner);
        $this->getJson('/api/v1/partner/reviews')
            ->assertOk()
            ->assertJsonFragment(['id' => $otherReviewId])
            ->assertJsonMissing(['id' => $ownReviewId]);
    }

    public function test_assignment_endpoint_profile_and_duplicate_listing_guard_use_authoritative_spot(): void
    {
        $this->seedAccounts();
        $partner = User::where('email', 'mundong@gmail.com')->firstOrFail();
        $spot = TouristSpot::where('slug', 'mundong-sandbar')->firstOrFail();

        Sanctum::actingAs($partner);
        $this->getJson('/api/v1/partner/assignment')
            ->assertOk()
            ->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.destination.id', $spot->id);
        $this->getJson('/api/v1/partner/profile')
            ->assertOk()
            ->assertJsonPath('data.assignment.destination.id', $spot->id);
        $count = DB::table('tourism_listings')->count();
        $this->postJson('/api/v1/partner/listings', [
            'listing_name' => 'Duplicate Mundong',
        ])->assertStatus(409);
        $this->assertSame($count, DB::table('tourism_listings')->count());

        Sanctum::actingAs($this->user('Unassigned Partner', 'unassigned-partner@example.test', 'tourism_partner'));
        $this->getJson('/api/v1/partner/assignment')->assertOk()->assertJsonPath('data', null);

        Sanctum::actingAs($this->user('Wrong Role', 'wrong-role@example.test', 'tourist'));
        $this->getJson('/api/v1/partner/assignment')->assertForbidden();
    }

    public function test_reservation_queue_filters_summary_history_and_rejection_reason_are_persisted(): void
    {
        $this->seedAccounts();
        $partner = User::where('email', 'mundong@gmail.com')->firstOrFail();
        $spot = TouristSpot::where('slug', 'mundong-sandbar')->firstOrFail();
        $tourist = $this->user('Queue Tourist', 'queue-tourist@example.test', 'tourist');
        $reservation = Reservation::create([
            'user_id' => $tourist->id,
            'reservable_type' => 'spot',
            'reservable_id' => $spot->id,
            'reservation_date' => now(),
            'guests' => 3,
            'status_id' => ReservationStatus::where('name', 'pending')->value('id'),
        ]);

        Sanctum::actingAs($partner);
        $this->getJson('/api/v1/partner/reservations?scope=today&status_filter=pending&search='.urlencode($reservation->public_reference))
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $reservation->id)
            ->assertJsonPath('meta.summary.pending', 1);
        $this->putJson("/api/v1/partner/reservations/{$reservation->id}/status", [
            'status_name' => 'rejected',
        ])->assertUnprocessable()->assertJsonValidationErrors('reason');
        $this->putJson("/api/v1/partner/reservations/{$reservation->id}/status", [
            'status_name' => 'rejected',
            'reason' => 'Destination capacity is unavailable for this visit.',
        ])->assertOk();
        $this->assertDatabaseHas('reservation_status_history', [
            'reservation_id' => $reservation->id,
            'notes' => 'Rejected by assigned Tourism Partner: Destination capacity is unavailable for this visit.',
        ]);
        $this->getJson("/api/v1/partner/reservations/{$reservation->id}")
            ->assertOk()->assertJsonPath('data.status.name', 'rejected')
            ->assertJsonCount(1, 'data.status_history');
    }

    public function test_admin_reassignment_immediately_revokes_old_destination_and_notifies_partner_and_lgu(): void
    {
        Mail::fake();
        $this->seedAccounts();
        $partner = User::where('email', 'mundong@gmail.com')->firstOrFail();
        $oldSpot = TouristSpot::where('slug', 'mundong-sandbar')->firstOrFail();
        $newSpot = TouristSpot::create([
            'name' => 'New Controlled Destination',
            'slug' => 'new-controlled-destination',
            'description' => 'Authoritative municipal destination.',
            'is_active' => true,
            'is_published' => true,
            'is_bookable' => true,
            'booking_enabled' => true,
        ]);
        $admin = $this->user('Assignment Admin', 'assignment-admin@example.test', 'admin');
        $lgu = $this->user('Assignment LGU', 'assignment-lgu@example.test', 'lgu_staff');

        Sanctum::actingAs($admin);
        $this->putJson("/api/v1/admin/users/{$partner->id}/partner-assignment", [
            'tourist_spot_id' => $newSpot->id,
        ])->assertOk()->assertJsonPath('data.tourist_spot_id', $newSpot->id);
        $this->assertDatabaseHas('partner_notifications', [
            'user_id' => $partner->id,
            'type' => 'admin_assignment_changed',
        ]);
        $this->assertDatabaseHas('notifications', [
            'user_id' => $lgu->id,
            'type' => 'partner_assignment_changed',
        ]);
        Mail::assertSent(\App\Mail\TourTubigonMessage::class, 1);

        Sanctum::actingAs($partner);
        $this->getJson("/api/v1/partner/tourist-spots/{$oldSpot->id}")->assertForbidden();
        $this->getJson("/api/v1/partner/tourist-spots/{$newSpot->id}")->assertOk();
        $this->getJson('/api/v1/partner/assignment')
            ->assertOk()->assertJsonPath('data.destination.id', $newSpot->id);
    }

    public function test_partner_analytics_and_notification_filters_are_assignment_and_user_scoped(): void
    {
        $this->seedAccounts();
        $partner = User::where('email', 'mundong@gmail.com')->firstOrFail();
        $otherPartner = User::where('email', 'ilijan@gmail.com')->firstOrFail();
        $spot = TouristSpot::where('slug', 'mundong-sandbar')->firstOrFail();
        $otherSpot = TouristSpot::where('slug', 'enchanted-ilijan-hill')->firstOrFail();
        $tourist = $this->user('Analytics Tourist', 'analytics-tourist@example.test', 'tourist');
        $pending = ReservationStatus::where('name', 'pending')->firstOrFail();
        foreach ([$spot, $otherSpot] as $target) {
            Reservation::create([
                'user_id' => $tourist->id,
                'reservable_type' => 'spot',
                'reservable_id' => $target->id,
                'reservation_date' => now(),
                'guests' => 2,
                'status_id' => $pending->id,
            ]);
            Review::create([
                'user_id' => $tourist->id,
                'reviewable_type' => 'spot',
                'reviewable_id' => $target->id,
                'rating' => 5,
                'content' => 'Assignment-scoped feedback.',
            ]);
        }
        $reviewNotice = PartnerNotification::create([
            'user_id' => $partner->id, 'type' => 'new_review',
            'title' => 'New Review', 'body' => 'Feedback received.',
        ]);
        PartnerNotification::create([
            'user_id' => $partner->id, 'type' => 'new_reservation',
            'title' => 'New Reservation', 'body' => 'Booking received.',
        ]);
        PartnerNotification::create([
            'user_id' => $otherPartner->id, 'type' => 'new_review',
            'title' => 'Other Review', 'body' => 'Must remain private.',
        ]);

        Sanctum::actingAs($partner);
        $this->getJson('/api/v1/partner/analytics?period=7_days')
            ->assertOk()
            ->assertJsonPath('data.totalReservations', 1)
            ->assertJsonPath('data.totalReviews', 1)
            ->assertJsonPath('data.ratingDistribution.5', 1);
        $this->getJson('/api/v1/partner/notifications?filter=reviews')
            ->assertOk()->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $reviewNotice->id)
            ->assertJsonMissing(['title' => 'Other Review']);
        $this->getJson('/api/v1/partner/notifications/unread-count')
            ->assertOk()->assertJsonPath('data.count', 2);
    }

    private function seedAccounts(): void
    {
        $this->seed(FeaturedDestinationSeeder::class);
        $this->seed(DevelopmentFeaturedDestinationPartnerSeeder::class);
    }

    private function user(string $name, string $email, string $role): User
    {
        $roleModel = Role::where('name', $role)->firstOrFail();
        $user = User::create([
            'name' => $name,
            'email' => $email,
            'password' => Hash::make('TestOnly!Secure2026'),
            'role_id' => $roleModel->id,
            'is_verified' => true,
            'email_verified_at' => now(),
        ]);
        Profile::create([
            'id' => $user->id,
            'name' => $name,
            'email' => $email,
            'role_id' => $roleModel->id,
            'is_verified' => true,
        ]);

        return $user;
    }

    private function createSchema(): void
    {
        foreach ([
            'tourist_spot_booking_availability_history', 'tourist_spot_partner_assignments',
            'personal_access_tokens',
            'reservation_status_history', 'notifications', 'partner_notifications', 'reviews', 'favorites',
            'reservations', 'reservation_status', 'activity_logs', 'tourist_spots',
            'tourism_listings', 'spot_categories', 'profiles', 'users', 'roles',
        ] as $table) {
            Schema::dropIfExists($table);
        }
        Schema::create('roles', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->string('name')->unique(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('users', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->string('name'); $table->string('email')->unique(); $table->string('password'); $table->uuid('role_id')->nullable(); $table->boolean('is_verified')->default(false); $table->timestamp('email_verified_at')->nullable(); $table->string('auth_provider')->nullable(); $table->rememberToken(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('profiles', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->string('name'); $table->string('email')->unique(); $table->uuid('role_id'); $table->string('avatar_url')->nullable(); $table->string('phone')->nullable(); $table->text('bio')->nullable(); $table->string('language')->default('en'); $table->boolean('is_verified')->default(false); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('personal_access_tokens', function (Blueprint $table): void {
            $table->id(); $table->string('tokenable_type'); $table->uuid('tokenable_id'); $table->string('name'); $table->string('token', 64)->unique(); $table->text('abilities')->nullable(); $table->timestamp('last_used_at')->nullable(); $table->timestamp('expires_at')->nullable(); $table->timestamps();
        });
        Schema::create('spot_categories', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->integer('integer_id')->nullable(); $table->string('name')->unique(); $table->string('slug')->unique(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('tourist_spots', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->integer('integer_id')->nullable(); $table->string('name'); $table->string('slug')->nullable(); $table->string('short_description')->nullable(); $table->text('description')->nullable(); $table->json('aliases')->nullable(); $table->uuid('category_id')->nullable(); $table->double('latitude')->nullable(); $table->double('longitude')->nullable(); $table->text('address')->nullable(); $table->decimal('entrance_fee', 10, 2)->nullable(); $table->text('opening_hours')->nullable(); $table->json('eco_tips')->nullable(); $table->json('images')->nullable(); $table->decimal('average_rating', 3, 2)->default(0); $table->integer('review_count')->default(0); $table->boolean('is_featured')->default(false); $table->boolean('is_active')->default(true); $table->boolean('is_published')->default(false); $table->boolean('is_bookable')->default(false); $table->string('booking_mode')->default('no_reservation'); $table->json('booking_available_days')->nullable(); $table->json('booking_time_slots')->nullable(); $table->integer('max_guests_per_reservation')->nullable(); $table->integer('capacity_per_slot')->nullable(); $table->integer('advance_booking_days')->nullable(); $table->integer('minimum_notice_hours')->nullable(); $table->decimal('reservation_fee', 10, 2)->nullable(); $table->text('booking_instructions')->nullable(); $table->text('cancellation_policy')->nullable(); $table->integer('cancellation_notice_hours')->nullable(); $table->boolean('is_preapproved')->default(false); $table->timestamp('preapproved_at')->nullable(); $table->timestamps(); $table->softDeletes();
        });
        $migration = require database_path('migrations/2026_08_29_000004_add_featured_destination_partner_ownership.php');
        $migration->up();
        Schema::create('tourism_listings', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->uuid('owner_id'); $table->string('listing_name'); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('reservation_status', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->string('name')->unique(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('reservations', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->string('public_reference')->nullable(); $table->uuid('user_id'); $table->uuid('partner_id')->nullable(); $table->string('reservable_type'); $table->uuid('reservable_id'); $table->dateTime('reservation_date'); $table->string('start_time')->nullable(); $table->string('end_time')->nullable(); $table->integer('guests')->default(1); $table->uuid('status_id'); $table->text('notes')->nullable(); $table->decimal('total_amount', 10, 2)->default(0); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('reservation_status_history', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->uuid('reservation_id'); $table->uuid('status_id'); $table->uuid('changed_by')->nullable(); $table->text('notes')->nullable(); $table->timestamps();
        });
        foreach (['notifications', 'partner_notifications'] as $tableName) {
            Schema::create($tableName, function (Blueprint $table): void {
                $table->uuid('id')->primary(); $table->uuid('user_id')->nullable(); $table->string('type'); $table->string('title'); $table->text('body')->nullable(); $table->json('data')->nullable(); $table->boolean('is_read')->default(false); $table->timestamps(); $table->softDeletes();
            });
        }
        Schema::create('reviews', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->uuid('user_id'); $table->string('reviewable_type'); $table->uuid('reviewable_id'); $table->unsignedTinyInteger('rating'); $table->text('content'); $table->json('images')->nullable(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('favorites', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->uuid('user_id'); $table->string('favoritable_type'); $table->uuid('favoritable_id'); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('activity_logs', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->uuid('user_id')->nullable(); $table->string('action'); $table->text('details')->nullable(); $table->timestamps(); $table->softDeletes();
        });
    }
}
