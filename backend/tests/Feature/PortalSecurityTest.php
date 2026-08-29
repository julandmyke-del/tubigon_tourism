<?php

namespace Tests\Feature;

use App\Models\PartnerNotification;
use App\Models\Reservation;
use App\Models\ReservationStatus;
use App\Models\Role;
use App\Models\TourismListing;
use App\Models\User;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PortalSecurityTest extends TestCase
{
    private Role $partnerRole;
    private Role $touristRole;
    private Role $msmeRole;
    private Role $lguRole;

    protected function setUp(): void
    {
        parent::setUp();
        $this->createSchema();
        $this->partnerRole = Role::create(['name' => 'tourism_partner']);
        $this->touristRole = Role::create(['name' => 'tourist']);
        $this->msmeRole = Role::create(['name' => 'msme_owner']);
        $this->lguRole = Role::create(['name' => 'lgu_staff']);
        foreach (['pending', 'approved', 'confirmed', 'rejected', 'completed', 'cancelled'] as $status) {
            ReservationStatus::create(['name' => $status]);
        }
    }

    public function test_partner_cannot_view_or_update_another_partners_reservation(): void
    {
        $partnerA = $this->user('partner-a', $this->partnerRole);
        $partnerB = $this->user('partner-b', $this->partnerRole);
        $tourist = $this->user('tourist', $this->touristRole);
        $listingA = $this->listing($partnerA, 'Listing A');
        $listingB = $this->listing($partnerB, 'Listing B');
        $reservationA = $this->reservation($tourist, $partnerA, $listingA, 'pending');
        $reservationB = $this->reservation($tourist, $partnerB, $listingB, 'pending');

        Sanctum::actingAs($partnerA);

        $this->getJson("/api/v1/partner/reservations/{$reservationB->id}")->assertNotFound();
        $this->putJson("/api/v1/partner/reservations/{$reservationB->id}/status", [
            'status_name' => 'confirmed',
        ])->assertNotFound();
        $this->assertDatabaseHas('reservations', [
            'id' => $reservationB->id,
            'status_id' => $this->reservationStatus('pending')->id,
        ]);

        $this->getJson("/api/v1/partner/reservations/{$reservationA->id}")
            ->assertOk()->assertJsonPath('data.id', $reservationA->id);
        $this->putJson("/api/v1/partner/reservations/{$reservationA->id}/status", [
            'status_name' => 'confirmed',
        ])->assertOk();
        $this->assertDatabaseHas('reservations', [
            'id' => $reservationA->id,
            'status_id' => $this->reservationStatus('confirmed')->id,
        ]);
    }

    public function test_terminal_reservation_status_cannot_be_reopened(): void
    {
        $partner = $this->user('partner', $this->partnerRole);
        $tourist = $this->user('tourist', $this->touristRole);
        $listing = $this->listing($partner, 'Completed Tour');
        $reservation = $this->reservation($tourist, $partner, $listing, 'completed');

        Sanctum::actingAs($partner);
        $this->putJson("/api/v1/partner/reservations/{$reservation->id}/status", [
            'status_name' => 'confirmed',
        ])->assertUnprocessable()->assertJsonPath('allowed_statuses', []);
        $this->assertDatabaseHas('reservations', [
            'id' => $reservation->id,
            'status_id' => $this->reservationStatus('completed')->id,
        ]);
    }

    public function test_partner_listing_and_notifications_are_owner_scoped(): void
    {
        $partnerA = $this->user('partner-a', $this->partnerRole);
        $partnerB = $this->user('partner-b', $this->partnerRole);
        $listingA = $this->listing($partnerA, 'Listing A');
        $listingB = $this->listing($partnerB, 'Listing B');
        $notificationB = PartnerNotification::create([
            'user_id' => $partnerB->id,
            'type' => 'listing_approved',
            'title' => 'Approved',
            'body' => 'Private partner update',
        ]);

        Sanctum::actingAs($partnerA);
        $this->putJson("/api/v1/partner/listings/{$listingB->id}", [
            'listing_name' => 'Hijacked',
        ])->assertNotFound();
        $this->putJson("/api/v1/partner/listings/{$listingA->id}", [
            'listing_name' => 'Updated by owner',
        ])->assertOk();
        $this->getJson('/api/v1/partner/notifications')
            ->assertOk()->assertJsonMissing(['id' => $notificationB->id]);
        $this->putJson("/api/v1/partner/notifications/{$notificationB->id}/read")->assertOk();
        $this->assertDatabaseHas('partner_notifications', [
            'id' => $notificationB->id,
            'is_read' => false,
        ]);
    }

    public function test_msme_creation_and_lgu_endpoints_enforce_roles(): void
    {
        $tourist = $this->user('tourist', $this->touristRole);
        Sanctum::actingAs($tourist);
        $this->postJson('/api/v1/msmes', [
            'name' => 'Unauthorized Business',
            'category' => 'Food',
        ])->assertForbidden();
        $this->getJson('/api/v1/lgu/dashboard-stats')->assertForbidden();

        $owner = $this->user('owner', $this->msmeRole);
        Sanctum::actingAs($owner);
        $this->postJson('/api/v1/msmes', [
            'name' => 'Owner Business',
            'category' => 'Food',
        ])->assertCreated();
    }

    public function test_non_tourist_roles_cannot_use_tourist_mutation_endpoints(): void
    {
        $partner = $this->user('partner-boundary', $this->partnerRole);
        Sanctum::actingAs($partner);

        $this->postJson('/api/v1/reservations', [])->assertForbidden();
        $this->postJson('/api/v1/reviews', [])->assertForbidden();
        $this->getJson('/api/v1/favorites')->assertForbidden();
        $this->postJson('/api/v1/favorites/toggle', [])->assertForbidden();
        $this->postJson('/api/v1/waste-reports', [])->assertForbidden();
        $this->postJson('/api/v1/sync/push', [])->assertForbidden();
    }

    public function test_reviews_require_an_existing_public_target(): void
    {
        $tourist = $this->user('tourist', $this->touristRole);
        $privateId = $this->msme(false, null);
        $publicId = $this->msme(true, null);
        Sanctum::actingAs($tourist);

        $this->postJson('/api/v1/reviews', [
            'reviewable_type' => 'msme',
            'reviewable_id' => $privateId,
            'rating' => 5,
            'content' => 'Should not be accepted',
        ])->assertUnprocessable();
        $this->postJson('/api/v1/reviews', [
            'reviewable_type' => 'msme',
            'reviewable_id' => Str::uuid()->toString(),
            'rating' => 5,
            'content' => 'Does not exist',
        ])->assertUnprocessable();
        $this->postJson('/api/v1/reviews', [
            'reviewable_type' => 'msme',
            'reviewable_id' => $publicId,
            'rating' => 5,
            'content' => 'A real public business',
        ])->assertCreated();
        $this->postJson('/api/v1/reviews', [
            'reviewable_type' => 'msme',
            'reviewable_id' => $publicId,
            'rating' => 4,
            'content' => 'A duplicate review',
        ])->assertUnprocessable();

        $this->getJson('/api/v1/reviews')->assertUnprocessable();
        $this->getJson("/api/v1/reviews?reviewable_type=msme&reviewable_id={$publicId}")
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonMissingPath('data.0.user.email');
    }

    public function test_sync_pull_hides_unpublished_records_but_keeps_owner_private_msme(): void
    {
        $tourist = $this->user('tourist', $this->touristRole);
        $owner = $this->user('owner', $this->msmeRole);
        $publicMsme = $this->msme(true, null);
        $privateMsme = $this->msme(false, null);
        $ownedMsme = $this->msme(false, $owner->id);

        Sanctum::actingAs($tourist);
        $this->getJson('/api/v1/sync/pull?table=msmes')
            ->assertOk()
            ->assertJsonFragment(['id' => $publicMsme])
            ->assertJsonMissing(['id' => $privateMsme])
            ->assertJsonMissing(['id' => $ownedMsme]);

        Sanctum::actingAs($owner);
        $this->getJson('/api/v1/sync/pull?table=msmes')
            ->assertOk()
            ->assertJsonFragment(['id' => $publicMsme])
            ->assertJsonFragment(['id' => $ownedMsme])
            ->assertJsonMissing(['id' => $privateMsme]);
    }

    public function test_msme_submission_review_public_booking_and_owner_management_flow(): void
    {
        $owner = $this->user('msme-flow-owner', $this->msmeRole);
        $lgu = $this->user('msme-flow-lgu', $this->lguRole);
        $tourist = $this->user('msme-flow-tourist', $this->touristRole);

        Sanctum::actingAs($owner);
        $created = $this->postJson('/api/v1/msmes', [
            'name' => 'Tubigon Local Kitchen',
            'category' => 'Food & Dining',
            'description' => 'Local dining by reservation.',
            'operational_status' => 'open',
        ])->assertCreated()->assertJsonPath('data.verification_status', 'pending');
        $msmeId = $created->json('data.id');
        $this->getJson('/api/v1/msmes')->assertOk()->assertJsonMissing(['id' => $msmeId]);

        Sanctum::actingAs($lgu);
        $this->putJson("/api/v1/lgu/msmes/{$msmeId}/verify", [
            'verification_status' => 'verified',
            'notes' => 'Municipal verification completed.',
        ])->assertOk()->assertJsonPath('data.verification_status', 'verified');

        Sanctum::actingAs($tourist);
        $this->getJson('/api/v1/msmes')->assertOk()->assertJsonFragment(['id' => $msmeId]);
        $reservation = $this->postJson('/api/v1/reservations', [
            'reservable_type' => 'msme',
            'reservable_id' => $msmeId,
            'reservation_date' => now()->addDays(2)->toDateString(),
            'start_time' => '09:00',
            'guests' => 2,
        ])->assertCreated();
        $reservationId = $reservation->json('data.id');

        Sanctum::actingAs($owner);
        $this->getJson('/api/v1/msme/reservations')
            ->assertOk()->assertJsonFragment(['id' => $reservationId]);
        $this->putJson("/api/v1/msme/reservations/{$reservationId}/status", [
            'status_name' => 'confirmed',
        ])->assertOk();
    }

    public function test_partner_draft_review_public_booking_and_secure_management_flow(): void
    {
        $partner = $this->user('partner-flow-owner', $this->partnerRole);
        $lgu = $this->user('partner-flow-lgu', $this->lguRole);
        $tourist = $this->user('partner-flow-tourist', $this->touristRole);
        $bookingDate = now()->addDays(3);

        Sanctum::actingAs($partner);
        $created = $this->postJson('/api/v1/partner/listings', [
            'listing_name' => 'Tubigon Heritage Walk',
            'listing_type' => 'guided_tour',
            'description' => 'A guided heritage experience in Tubigon.',
            'address' => 'Tubigon town center, Bohol',
            'latitude' => 9.9515,
            'longitude' => 123.9618,
            'price' => 250,
            'capacity' => 12,
            'available_days' => [strtolower($bookingDate->format('l'))],
        ])->assertCreated()->assertJsonPath('data.approval_status', 'draft');
        $listingId = $created->json('data.id');
        $this->postJson("/api/v1/partner/listings/{$listingId}/submit")
            ->assertOk()->assertJsonPath('data.approval_status', 'submitted');
        $this->getJson("/api/v1/tourism-listings/{$listingId}")->assertNotFound();

        Sanctum::actingAs($lgu);
        $this->putJson("/api/v1/lgu/tourism-listings/{$listingId}/review", [
            'approval_status' => 'approved',
            'notes' => 'Location and offering verified.',
        ])->assertOk()->assertJsonPath('data.approval_status', 'approved');

        Sanctum::actingAs($tourist);
        $this->getJson("/api/v1/tourism-listings/{$listingId}")
            ->assertOk()->assertJsonPath('data.listing_name', 'Tubigon Heritage Walk');
        $reservation = $this->postJson('/api/v1/reservations', [
            'reservable_type' => 'tourism_listing',
            'reservable_id' => $listingId,
            'reservation_date' => $bookingDate->toDateString(),
            'start_time' => '09:00',
            'guests' => 3,
        ])->assertCreated()->assertJsonPath('data.total_amount', 750);
        $reservationId = $reservation->json('data.id');

        Sanctum::actingAs($partner);
        $this->getJson('/api/v1/partner/reservations')
            ->assertOk()->assertJsonFragment(['id' => $reservationId]);
        $this->putJson("/api/v1/partner/reservations/{$reservationId}/status", [
            'status_name' => 'confirmed',
        ])->assertOk();
    }

    private function user(string $key, Role $role): User
    {
        $user = User::create([
            'name' => ucfirst($key),
            'email' => "$key@example.test",
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

    private function listing(User $owner, string $name): TourismListing
    {
        return TourismListing::create([
            'owner_id' => $owner->id,
            'listing_name' => $name,
            'listing_type' => 'tour',
            'status' => 'approved',
            'is_active' => true,
        ]);
    }

    private function reservation(User $tourist, User $partner, TourismListing $listing, string $status): Reservation
    {
        return Reservation::create([
            'user_id' => $tourist->id,
            'partner_id' => $partner->id,
            'reservable_type' => 'tourism_listing',
            'reservable_id' => $listing->id,
            'reservation_date' => now()->addDay(),
            'guests' => 2,
            'status_id' => $this->reservationStatus($status)->id,
        ]);
    }

    private function reservationStatus(string $name): ReservationStatus
    {
        return ReservationStatus::firstOrCreate(['name' => $name]);
    }

    private function msme(bool $verified, ?string $profileId): string
    {
        $id = Str::uuid()->toString();
        Schema::getConnection()->table('msmes')->insert([
            'id' => $id,
            'profile_id' => $profileId,
            'name' => 'Business '.$id,
            'category' => 'Food',
            'is_verified' => $verified,
            'verification_status' => $verified ? 'verified' : 'pending',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        return $id;
    }

    private function createSchema(): void
    {
        foreach (['notifications', 'partner_notifications', 'reviews', 'reservations', 'reservation_status', 'tourism_listings', 'msmes', 'profiles', 'activity_logs', 'users', 'roles'] as $table) {
            Schema::dropIfExists($table);
        }
        Schema::create('roles', function (Blueprint $table) {
            $table->uuid('id')->primary(); $table->string('name')->unique(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('users', function (Blueprint $table) {
            $table->uuid('id')->primary(); $table->string('name'); $table->string('email')->unique(); $table->string('password'); $table->uuid('role_id')->nullable(); $table->boolean('is_verified')->default(false); $table->rememberToken(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('profiles', function (Blueprint $table) {
            $table->uuid('id')->primary(); $table->string('name'); $table->string('email')->unique(); $table->uuid('role_id')->nullable(); $table->boolean('is_verified')->default(false); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('msmes', function (Blueprint $table) {
            $table->uuid('id')->primary(); $table->uuid('profile_id')->nullable(); $table->string('name'); $table->string('category'); $table->string('tagline')->nullable(); $table->text('description')->nullable(); $table->string('phone')->nullable(); $table->text('address')->nullable(); $table->decimal('latitude', 10, 7)->nullable(); $table->decimal('longitude', 10, 7)->nullable(); $table->string('business_hours')->nullable(); $table->string('color')->nullable(); $table->string('icon')->nullable(); $table->json('products')->nullable(); $table->boolean('is_verified')->default(false); $table->string('verification_status')->default('pending'); $table->text('verification_notes')->nullable(); $table->string('operational_status')->default('open'); $table->timestamp('submitted_at')->nullable(); $table->timestamp('reviewed_at')->nullable(); $table->uuid('reviewed_by')->nullable(); $table->json('opening_hours')->nullable(); $table->json('unavailable_dates')->nullable(); $table->json('images')->nullable(); $table->decimal('rating', 3, 2)->default(0); $table->unsignedInteger('review_count')->default(0); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('tourism_listings', function (Blueprint $table) {
            $table->uuid('id')->primary(); $table->uuid('owner_id'); $table->string('listing_name'); $table->string('listing_type')->nullable(); $table->text('description')->nullable(); $table->text('address')->nullable(); $table->decimal('latitude', 10, 7)->nullable(); $table->decimal('longitude', 10, 7)->nullable(); $table->string('contact_number')->nullable(); $table->string('email')->nullable(); $table->string('operating_hours')->nullable(); $table->json('images')->nullable(); $table->string('status')->default('approved'); $table->boolean('is_active')->default(true); $table->string('approval_status')->default('draft'); $table->timestamp('submitted_at')->nullable(); $table->timestamp('reviewed_at')->nullable(); $table->uuid('reviewed_by')->nullable(); $table->text('review_notes')->nullable(); $table->timestamp('published_at')->nullable(); $table->decimal('price', 10, 2)->nullable(); $table->unsignedInteger('capacity')->nullable(); $table->unsignedInteger('duration_minutes')->nullable(); $table->json('available_days')->nullable(); $table->unsignedInteger('booking_cutoff_hours')->nullable(); $table->decimal('average_rating', 3, 2)->default(0); $table->unsignedInteger('review_count')->default(0); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('reservation_status', function (Blueprint $table) {
            $table->uuid('id')->primary(); $table->string('name')->unique(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('reservations', function (Blueprint $table) {
            $table->uuid('id')->primary(); $table->uuid('user_id'); $table->uuid('partner_id')->nullable(); $table->string('reservable_type'); $table->uuid('reservable_id'); $table->date('reservation_date'); $table->time('start_time')->nullable(); $table->time('end_time')->nullable(); $table->integer('guests')->default(1); $table->uuid('status_id')->nullable(); $table->text('notes')->nullable(); $table->decimal('total_amount', 10, 2)->default(0); $table->timestamps(); $table->softDeletes();
        });
        foreach (['notifications', 'partner_notifications'] as $tableName) {
            Schema::create($tableName, function (Blueprint $table) {
                $table->uuid('id')->primary(); $table->uuid('user_id'); $table->string('type'); $table->string('title'); $table->text('body'); $table->json('data')->nullable(); $table->boolean('is_read')->default(false); $table->timestamps(); $table->softDeletes();
            });
        }
        Schema::create('reviews', function (Blueprint $table) {
            $table->uuid('id')->primary(); $table->uuid('user_id'); $table->string('reviewable_type'); $table->uuid('reviewable_id'); $table->unsignedTinyInteger('rating'); $table->text('content'); $table->json('images')->nullable(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('activity_logs', function (Blueprint $table) {
            $table->uuid('id')->primary(); $table->uuid('user_id')->nullable(); $table->string('action'); $table->text('details')->nullable(); $table->timestamps(); $table->softDeletes();
        });
    }
}
