<?php

namespace Tests\Feature;

use App\Models\Msme;
use App\Models\PartnerNotification;
use App\Models\Reservation;
use App\Models\ReservationStatus;
use App\Models\Role;
use App\Models\TourismListing;
use App\Models\User;
use Database\Seeders\DevelopmentMsmeOwnerSeeder;
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

    private Role $adminRole;

    protected function setUp(): void
    {
        parent::setUp();
        $this->createSchema();
        $this->partnerRole = Role::create(['name' => 'tourism_partner']);
        $this->touristRole = Role::create(['name' => 'tourist']);
        $this->msmeRole = Role::create(['name' => 'msme_owner']);
        $this->lguRole = Role::create(['name' => 'lgu_staff']);
        $this->adminRole = Role::create(['name' => 'admin']);
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

    public function test_msme_categories_are_authoritative_and_arbitrary_values_are_rejected(): void
    {
        Schema::create('msme_categories', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->string('slug')->unique();
            $table->text('description')->nullable();
            $table->boolean('is_active')->default(true);
            $table->integer('display_order')->default(0);
            $table->timestamps();
            $table->softDeletes();
        });
        $categoryId = Str::uuid()->toString();
        Schema::getConnection()->table('msme_categories')->insert([
            'id' => $categoryId,
            'name' => 'Restaurants',
            'slug' => 'restaurants',
            'is_active' => true,
            'display_order' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->getJson('/api/v1/msme-categories')
            ->assertOk()
            ->assertJsonPath('data.0.slug', 'restaurants');

        Sanctum::actingAs($this->user('taxonomy-owner', $this->msmeRole));
        $this->postJson('/api/v1/msmes', [
            'name' => 'Typo Category Business',
            'category' => 'Restuarants',
        ])->assertUnprocessable();
        $this->postJson('/api/v1/msmes', [
            'name' => 'Controlled Category Business',
            'category_id' => $categoryId,
        ])->assertCreated()->assertJsonPath('data.category', 'Restaurants');
    }

    public function test_development_msme_seeder_is_idempotent_authentic_and_owner_scoped(): void
    {
        config()->set('msme_owners.development_password', 'msme123!');

        $this->seed(DevelopmentMsmeOwnerSeeder::class);
        $firstBusinessIds = Msme::whereIn('name', ['BAZAK Food Park', 'Purple Yam - Tubigon'])
            ->orderBy('name')->pluck('id')->all();
        $firstUserIds = User::whereIn('email', ['bazak@gmail.com', 'purpleyam@gmail.com'])
            ->orderBy('email')->pluck('id')->all();
        $this->seed(DevelopmentMsmeOwnerSeeder::class);

        $this->assertCount(2, $firstBusinessIds);
        $this->assertCount(2, $firstUserIds);
        $this->assertSame($firstBusinessIds, Msme::whereIn('name', ['BAZAK Food Park', 'Purple Yam - Tubigon'])
            ->orderBy('name')->pluck('id')->all());
        $this->assertSame($firstUserIds, User::whereIn('email', ['bazak@gmail.com', 'purpleyam@gmail.com'])
            ->orderBy('email')->pluck('id')->all());

        $bazak = Msme::where('name', 'BAZAK Food Park')->firstOrFail();
        $purpleYam = Msme::where('name', 'Purple Yam - Tubigon')->firstOrFail();
        $this->assertEqualsWithDelta(9.9499662, $bazak->latitude, 0.0000001);
        $this->assertEqualsWithDelta(123.9664321, $bazak->longitude, 0.0000001);
        $this->assertNull($purpleYam->latitude);
        $this->assertNull($purpleYam->longitude);

        foreach ([
            'bazak@gmail.com' => $bazak,
            'purpleyam@gmail.com' => $purpleYam,
        ] as $email => $business) {
            $user = User::with('role')->where('email', $email)->firstOrFail();
            $this->assertSame('msme_owner', $user->role->name);
            $this->assertTrue(Hash::check('msme123!', $user->password));
            $this->assertNotSame('msme123!', $user->password);
            $this->assertSame($user->id, $business->profile_id);
            $this->assertDatabaseHas('profiles', [
                'id' => $user->id,
                'email' => $email,
                'role_id' => $this->msmeRole->id,
            ]);

            $this->postJson('/api/v1/auth/login', [
                'email' => $email,
                'password' => 'msme123!',
            ])->assertOk()
                ->assertJsonPath('data.role', 'msme_owner')
                ->assertJsonPath('data.user.email', $email);

            Sanctum::actingAs($user);
            $this->getJson('/api/v1/msme/profile')
                ->assertOk()
                ->assertJsonPath('data.id', $business->id)
                ->assertJsonPath('data.profile_id', $user->id);
        }

        $this->getJson('/api/v1/msmes')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonFragment(['id' => $bazak->id, 'name' => 'BAZAK Food Park'])
            ->assertJsonFragment(['id' => $purpleYam->id, 'name' => 'Purple Yam - Tubigon']);
        foreach (['BAZAK', 'Food Park', 'Food & Dining', 'Purple Yam', 'Cake Shop', 'Bakery'] as $term) {
            $this->getJson('/api/v1/msmes?search='.urlencode($term))
                ->assertOk()
                ->assertJsonCount($term === 'Food & Dining' ? 2 : 1, 'data');
        }

        $purpleYam->update(['latitude' => 9.9512345, 'longitude' => 123.9612345]);
        $this->seed(DevelopmentMsmeOwnerSeeder::class);
        $purpleYam->refresh();
        $this->assertEqualsWithDelta(9.9512345, $purpleYam->latitude, 0.0000001);
        $this->assertEqualsWithDelta(123.9612345, $purpleYam->longitude, 0.0000001);
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

    public function test_review_edit_delete_and_admin_moderation_are_owner_scoped_and_audited(): void
    {
        $owner = $this->user('review-owner', $this->touristRole);
        $other = $this->user('review-other', $this->touristRole);
        $admin = $this->user('review-admin', $this->adminRole);
        $businessId = $this->msme(true, null);

        Sanctum::actingAs($owner);
        $created = $this->postJson('/api/v1/reviews', [
            'reviewable_type' => 'msme',
            'reviewable_id' => $businessId,
            'rating' => 5,
            'content' => 'A useful original review.',
        ])->assertCreated();
        $reviewId = $created->json('data.id');

        Sanctum::actingAs($other);
        $this->putJson("/api/v1/reviews/{$reviewId}", [
            'rating' => 1,
            'content' => 'Attempted takeover.',
        ])->assertForbidden();
        $this->deleteJson("/api/v1/reviews/{$reviewId}")->assertForbidden();

        Sanctum::actingAs($owner);
        $this->putJson("/api/v1/reviews/{$reviewId}", [
            'rating' => 3,
            'content' => 'Updated by the actual owner.',
        ])->assertOk()->assertJsonPath('data.rating', 3);
        $this->assertDatabaseHas('msmes', [
            'id' => $businessId,
            'rating' => 3,
            'review_count' => 1,
        ]);

        Sanctum::actingAs($admin);
        $this->deleteJson("/api/v1/reviews/{$reviewId}")
            ->assertUnprocessable();
        $this->deleteJson("/api/v1/reviews/{$reviewId}", [
            'reason_code' => 'other',
        ])->assertUnprocessable();
        $this->deleteJson("/api/v1/reviews/{$reviewId}", [
            'reason_code' => 'spam',
        ])->assertOk();

        $this->assertSoftDeleted('reviews', ['id' => $reviewId]);
        $this->assertDatabaseHas('msmes', [
            'id' => $businessId,
            'rating' => 0,
            'review_count' => 0,
        ]);
        $this->assertDatabaseHas('notifications', [
            'user_id' => $owner->id,
            'type' => 'review_removed',
            'title' => 'Review Removed',
        ]);
        $this->assertDatabaseHas('activity_logs', [
            'user_id' => $admin->id,
            'action' => 'Review removed by administrator',
        ]);
    }

    public function test_review_owner_can_delete_without_a_moderation_reason(): void
    {
        $owner = $this->user('deleting-review-owner', $this->touristRole);
        $businessId = $this->msme(true, null);
        Sanctum::actingAs($owner);
        $reviewId = $this->postJson('/api/v1/reviews', [
            'reviewable_type' => 'msme',
            'reviewable_id' => $businessId,
            'rating' => 4,
            'content' => 'Review to remove myself.',
        ])->assertCreated()->json('data.id');

        $this->deleteJson("/api/v1/reviews/{$reviewId}")->assertOk();
        $this->assertSoftDeleted('reviews', ['id' => $reviewId]);
        $this->assertDatabaseMissing('notifications', [
            'user_id' => $owner->id,
            'type' => 'review_removed',
        ]);
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
            'booking_enabled' => false,
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
        $bookingDate = now()->addDays(2)->toDateString();
        $bookingPayload = [
            'reservable_type' => 'msme',
            'reservable_id' => $msmeId,
            'reservation_date' => $bookingDate,
            'start_time' => '09:00',
            'guests' => 2,
        ];
        $this->postJson('/api/v1/reservations', $bookingPayload)
            ->assertUnprocessable()
            ->assertJsonPath('message', 'Reservations are currently unavailable for this business.');

        Sanctum::actingAs($owner);
        $this->putJson('/api/v1/msme/profile', [
            'booking_enabled' => true,
            'unavailable_dates' => [$bookingDate],
        ])->assertOk();

        Sanctum::actingAs($tourist);
        $this->postJson('/api/v1/reservations', $bookingPayload)
            ->assertUnprocessable()
            ->assertJsonPath('message', 'The business is unavailable on the selected date.');

        Sanctum::actingAs($owner);
        $this->putJson('/api/v1/msme/profile', [
            'booking_enabled' => true,
            'unavailable_dates' => [],
        ])->assertOk();

        Sanctum::actingAs($tourist);
        $reservation = $this->postJson('/api/v1/reservations', [
            ...$bookingPayload,
        ])->assertCreated();
        $reservationId = $reservation->json('data.id');

        Sanctum::actingAs($owner);
        $this->putJson('/api/v1/msme/profile', [
            'booking_enabled' => false,
        ])->assertOk();
        $this->getJson('/api/v1/msme/reservations')
            ->assertOk()->assertJsonFragment(['id' => $reservationId]);

        Sanctum::actingAs($tourist);
        $this->postJson('/api/v1/reservations', [
            ...$bookingPayload,
            'reservation_date' => now()->addDays(3)->toDateString(),
        ])->assertUnprocessable()
            ->assertJsonPath('message', 'Reservations are currently unavailable for this business.');

        Sanctum::actingAs($owner);
        $this->getJson('/api/v1/msme/reservations')
            ->assertOk()->assertJsonFragment(['id' => $reservationId]);
        $this->putJson("/api/v1/msme/reservations/{$reservationId}/status", [
            'status_name' => 'confirmed',
        ])->assertOk();
        $this->assertDatabaseHas('reservation_status_history', [
            'reservation_id' => $reservationId,
            'changed_by' => $owner->id,
        ]);

        Sanctum::actingAs($tourist);
        $this->getJson("/api/v1/reservations/{$reservationId}")
            ->assertOk()
            ->assertJsonPath('data.status.name', 'confirmed')
            ->assertJsonCount(2, 'data.status_history');
        $this->postJson('/api/v1/reviews', [
            'reviewable_type' => 'msme',
            'reviewable_id' => $msmeId,
            'rating' => 5,
            'content' => 'Excellent local service.',
        ])->assertCreated();

        Sanctum::actingAs($owner);
        $this->getJson('/api/v1/msme/reviews')
            ->assertOk()
            ->assertJsonPath('data.reviewCount', 1)
            ->assertJsonPath('data.ratingDistribution.5', 1)
            ->assertJsonMissingPath('data.reviews.0.user.email');
        $this->getJson('/api/v1/msme/analytics?period=30_days')
            ->assertOk()
            ->assertJsonPath('data.totalReservations', 1)
            ->assertJsonPath('data.reviewCount', 1);
        $this->assertDatabaseHas('notifications', [
            'user_id' => $owner->id,
            'type' => 'new_review',
        ]);
    }

    public function test_msme_owner_without_business_gets_a_controlled_setup_state(): void
    {
        $owner = $this->user('setup-required-owner', $this->msmeRole);
        Sanctum::actingAs($owner);

        $this->getJson('/api/v1/msme/profile')
            ->assertOk()
            ->assertJsonPath('data', null)
            ->assertJsonPath('profile_required', true)
            ->assertJsonPath('relationship', 'zero_or_one_business_per_owner');
        $this->getJson('/api/v1/msme/dashboard-stats')
            ->assertOk()
            ->assertJsonPath('profile_required', true)
            ->assertJsonPath('data.totalReservations', 0);
        $this->getJson('/api/v1/msme/reservations')
            ->assertOk()
            ->assertJsonPath('profile_required', true)
            ->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/msme/reviews')
            ->assertOk()
            ->assertJsonPath('profile_required', true)
            ->assertJsonPath('data.reviewCount', 0);
        $this->getJson('/api/v1/msme/analytics')
            ->assertOk()
            ->assertJsonPath('profile_required', true);
        $this->putJson('/api/v1/msme/profile', ['description' => 'No business yet'])
            ->assertStatus(409)
            ->assertJsonPath('code', 'profile_required')
            ->assertJsonMissing(['exception' => 'Illuminate\\Database\\Eloquent\\ModelNotFoundException']);
    }

    public function test_msme_draft_is_single_owner_scoped_and_can_be_submitted(): void
    {
        $owner = $this->user('draft-owner', $this->msmeRole);
        Sanctum::actingAs($owner);

        $draft = $this->postJson('/api/v1/msmes', [
            'name' => 'Tubigon Craft Studio',
            'category' => 'Shopping',
            'save_as_draft' => true,
        ])->assertCreated()
            ->assertJsonPath('data.verification_status', 'draft')
            ->assertJsonPath('data.submitted_at', null);
        $msmeId = $draft->json('data.id');

        $this->postJson('/api/v1/msmes', [
            'name' => 'Duplicate Business',
            'category' => 'Shopping',
            'save_as_draft' => true,
        ])->assertUnprocessable();
        $this->putJson('/api/v1/msme/profile', [
            'phone' => '+63 917 000 0000',
            'address' => 'Tubigon, Bohol',
            'latitude' => 9.9515,
            'longitude' => 123.9618,
            'opening_hours' => [
                'monday' => ['closed' => false, 'open' => '08:00', 'close' => '17:00'],
            ],
        ])->assertOk();
        $this->putJson('/api/v1/msme/profile', [
            'opening_hours' => [
                'monday' => ['closed' => false, 'open' => '17:00', 'close' => '08:00'],
            ],
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('opening_hours.monday');
        $this->postJson('/api/v1/msme/profile/submit')
            ->assertOk()
            ->assertJsonPath('data.verification_status', 'pending');

        $this->assertSame(1, Msme::where('profile_id', $owner->id)->count());
        $this->assertDatabaseHas('activity_logs', [
            'user_id' => $owner->id,
            'action' => 'MSME business submitted',
        ]);
        $this->assertDatabaseHas('msmes', [
            'id' => $msmeId,
            'profile_id' => $owner->id,
            'verification_status' => 'pending',
        ]);

        Msme::findOrFail($msmeId)->delete();
        $this->postJson('/api/v1/msmes', [
            'name' => 'Replacement for archived business',
            'category' => 'Shopping',
            'save_as_draft' => true,
        ])->assertUnprocessable()
            ->assertJsonPath(
                'message',
                'This account already has a business profile, including an archived record. Contact LGU staff if it needs to be restored.',
            );
    }

    public function test_msme_reservation_detail_and_status_are_owner_scoped(): void
    {
        $ownerA = $this->user('msme-owner-a', $this->msmeRole);
        $ownerB = $this->user('msme-owner-b', $this->msmeRole);
        $tourist = $this->user('msme-idor-tourist', $this->touristRole);
        $businessA = $this->msme(true, $ownerA->id);
        $businessB = $this->msme(true, $ownerB->id);
        $reservation = Reservation::create([
            'user_id' => $tourist->id,
            'partner_id' => $ownerB->id,
            'reservable_type' => 'msme',
            'reservable_id' => $businessB,
            'reservation_date' => now()->addDay(),
            'guests' => 2,
            'status_id' => $this->reservationStatus('pending')->id,
        ]);
        $this->assertNotSame($businessA, $businessB);

        Sanctum::actingAs($ownerA);
        $this->getJson("/api/v1/msme/reservations/{$reservation->id}")
            ->assertForbidden();
        $this->putJson("/api/v1/msme/reservations/{$reservation->id}/status", [
            'status_name' => 'confirmed',
        ])->assertForbidden();
        $this->assertDatabaseHas('reservations', [
            'id' => $reservation->id,
            'status_id' => $this->reservationStatus('pending')->id,
        ]);
    }

    public function test_lgu_msme_summary_source_and_status_lists_use_the_same_business_state(): void
    {
        $verified = $this->msme(true, null);
        $pending = $this->msme(false, null);
        Sanctum::actingAs($this->user('verification-list-lgu', $this->lguRole));

        $this->getJson('/api/v1/lgu/msmes')
            ->assertOk()
            ->assertJsonFragment(['id' => $verified])
            ->assertJsonFragment(['id' => $pending]);
        $this->getJson('/api/v1/lgu/msmes?status=verified')
            ->assertOk()
            ->assertJsonFragment(['id' => $verified])
            ->assertJsonMissing(['id' => $pending]);
        $this->getJson('/api/v1/lgu/msmes?status=pending')
            ->assertOk()
            ->assertJsonFragment(['id' => $pending])
            ->assertJsonMissing(['id' => $verified]);
        $this->getJson('/api/v1/lgu/msmes?status=UNKNOWN')
            ->assertUnprocessable();
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
        foreach (['personal_access_tokens', 'notifications', 'partner_notifications', 'reviews', 'reservation_status_history', 'reservations', 'reservation_status', 'tourism_listings', 'msmes', 'msme_categories', 'profiles', 'activity_logs', 'users', 'roles'] as $table) {
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
            $table->string('phone')->nullable();
            $table->boolean('is_verified')->default(false);
            $table->timestamp('email_verified_at')->nullable();
            $table->string('auth_provider')->nullable();
            $table->rememberToken();
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('profiles', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->string('email')->unique();
            $table->uuid('role_id')->nullable();
            $table->string('phone')->nullable();
            $table->boolean('is_verified')->default(false);
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('msmes', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('profile_id')->nullable();
            $table->string('name');
            $table->string('category');
            $table->uuid('category_id')->nullable();
            $table->string('tagline')->nullable();
            $table->text('description')->nullable();
            $table->string('phone')->nullable();
            $table->text('address')->nullable();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->string('business_hours')->nullable();
            $table->string('color')->nullable();
            $table->string('icon')->nullable();
            $table->json('products')->nullable();
            $table->boolean('is_verified')->default(false);
            $table->boolean('booking_enabled')->default(false);
            $table->string('verification_status')->default('pending');
            $table->text('verification_notes')->nullable();
            $table->string('operational_status')->default('open');
            $table->timestamp('submitted_at')->nullable();
            $table->timestamp('reviewed_at')->nullable();
            $table->uuid('reviewed_by')->nullable();
            $table->json('opening_hours')->nullable();
            $table->json('unavailable_dates')->nullable();
            $table->json('images')->nullable();
            $table->decimal('rating', 3, 2)->default(0);
            $table->unsignedInteger('review_count')->default(0);
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('tourism_listings', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('owner_id');
            $table->string('listing_name');
            $table->string('listing_type')->nullable();
            $table->text('description')->nullable();
            $table->text('address')->nullable();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->string('contact_number')->nullable();
            $table->string('email')->nullable();
            $table->string('operating_hours')->nullable();
            $table->json('images')->nullable();
            $table->string('status')->default('approved');
            $table->boolean('is_active')->default(true);
            $table->string('approval_status')->default('draft');
            $table->timestamp('submitted_at')->nullable();
            $table->timestamp('reviewed_at')->nullable();
            $table->uuid('reviewed_by')->nullable();
            $table->text('review_notes')->nullable();
            $table->timestamp('published_at')->nullable();
            $table->decimal('price', 10, 2)->nullable();
            $table->unsignedInteger('capacity')->nullable();
            $table->unsignedInteger('duration_minutes')->nullable();
            $table->json('available_days')->nullable();
            $table->unsignedInteger('booking_cutoff_hours')->nullable();
            $table->decimal('average_rating', 3, 2)->default(0);
            $table->unsignedInteger('review_count')->default(0);
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
            $table->integer('guests')->default(1);
            $table->uuid('status_id')->nullable();
            $table->text('notes')->nullable();
            $table->decimal('total_amount', 10, 2)->default(0);
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('reservation_status_history', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('reservation_id');
            $table->uuid('status_id');
            $table->uuid('changed_by')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
        });
        foreach (['notifications', 'partner_notifications'] as $tableName) {
            Schema::create($tableName, function (Blueprint $table) {
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
        }
        Schema::create('reviews', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id');
            $table->string('reviewable_type');
            $table->uuid('reviewable_id');
            $table->unsignedTinyInteger('rating');
            $table->text('content');
            $table->json('images')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('activity_logs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id')->nullable();
            $table->string('action');
            $table->text('details')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('personal_access_tokens', function (Blueprint $table) {
            $table->id();
            $table->string('tokenable_type');
            $table->uuid('tokenable_id');
            $table->string('name');
            $table->string('token', 64)->unique();
            $table->text('abilities')->nullable();
            $table->timestamp('last_used_at')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->timestamps();
        });
    }
}
