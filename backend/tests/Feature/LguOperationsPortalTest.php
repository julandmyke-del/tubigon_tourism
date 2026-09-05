<?php

namespace Tests\Feature;

use App\Models\ActivityLog;
use App\Models\Announcement;
use App\Models\EmergencyContact;
use App\Models\MapLocation;
use App\Models\Msme;
use App\Models\Profile;
use App\Models\Reservation;
use App\Models\ReservationStatus;
use App\Models\Role;
use App\Models\TouristSpot;
use App\Models\TouristSpotPartnerAssignment;
use App\Models\User;
use App\Models\WasteReport;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class LguOperationsPortalTest extends TestCase
{
    private Role $lguRole;
    private Role $touristRole;
    private Role $partnerRole;
    private User $lgu;

    protected function setUp(): void
    {
        parent::setUp();
        $this->schema();
        $this->lguRole = Role::create(['name' => 'lgu_staff']);
        $this->touristRole = Role::create(['name' => 'tourist']);
        $this->partnerRole = Role::create(['name' => 'tourism_partner']);
        $this->lgu = $this->user('LGU Operator', 'lgu-operator@example.test', $this->lguRole);
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    public function test_dashboard_uses_authoritative_counts_and_safe_recent_activity(): void
    {
        $spot = $this->spot('Mangrove Forest Batasan');
        Msme::create(['name' => 'Pending Store', 'category' => 'Retail', 'verification_status' => 'pending']);
        Msme::create(['name' => 'Verified Store', 'category' => 'Food', 'verification_status' => 'verified', 'is_verified' => true]);
        $pending = ReservationStatus::create(['name' => 'pending']);
        Reservation::create([
            'user_id' => $this->lgu->id, 'reservable_type' => 'spot', 'reservable_id' => $spot->id,
            'reservation_date' => now()->addDay(), 'guests' => 2, 'status_id' => $pending->id,
        ]);
        WasteReport::create(['category' => 'garbage', 'description' => 'Pending municipal case', 'status' => 'submitted']);
        WasteReport::create(['category' => 'garbage', 'description' => 'Resolved municipal case', 'status' => 'resolved', 'resolved_at' => now()]);
        EmergencyContact::create(['name' => 'Municipal Rescue', 'category' => 'Rescue', 'phone' => '911', 'is_active' => true, 'is_verified' => false]);
        MapLocation::create(['name' => 'Review Pin', 'slug' => 'review-pin', 'verified' => false, 'published' => false, 'active' => true]);
        Announcement::create([
            'title' => 'LGU Advisory', 'body' => 'Current advisory', 'type' => 'advisory',
            'audience' => 'lgu_staff', 'priority' => 'important', 'status' => 'published',
            'starts_at' => now()->subMinute(), 'is_active' => true,
        ]);
        ActivityLog::create([
            'user_id' => $this->lgu->id, 'action' => 'Tourist Spot booking disabled',
            'details' => json_encode(['tourist_spot_id' => $spot->id, 'tourist_spot_name' => $spot->name]),
        ]);

        Sanctum::actingAs($this->lgu);
        $this->getJson('/api/v1/lgu/dashboard-stats')
            ->assertOk()
            ->assertJsonPath('data.totalSpots', 1)
            ->assertJsonPath('data.verifiedMsmes', 1)
            ->assertJsonPath('data.actionCenter.msmesAwaitingReview', 1)
            ->assertJsonPath('data.activeReservations', 1)
            ->assertJsonPath('data.pendingWasteReports', 1)
            ->assertJsonPath('data.resolvedWasteReports', 1)
            ->assertJsonPath('data.actionCenter.emergencyContactsNeedingVerification', 1)
            ->assertJsonPath('data.actionCenter.mapLocationsNeedingReview', 1)
            ->assertJsonPath('data.activeAnnouncements', 1)
            ->assertJsonPath('data.recentActivity.0.target', 'Mangrove Forest Batasan')
            ->assertJsonMissingPath('data.recentActivity.0.before');
    }

    public function test_analytics_and_report_share_the_same_backend_period_totals(): void
    {
        Carbon::setTestNow('2026-09-15 12:00:00');
        $spot = $this->spot('Mundong Sandbar');
        $pending = ReservationStatus::create(['name' => 'pending']);
        $current = Reservation::create([
            'user_id' => $this->lgu->id, 'reservable_type' => 'spot', 'reservable_id' => $spot->id,
            'reservation_date' => now()->addDay(), 'guests' => 2, 'status_id' => $pending->id,
        ]);
        $current->forceFill(['created_at' => now()->subDay(), 'updated_at' => now()->subDay()])->saveQuietly();
        $previous = Reservation::create([
            'user_id' => $this->lgu->id, 'reservable_type' => 'spot', 'reservable_id' => $spot->id,
            'reservation_date' => now()->addDay(), 'guests' => 1, 'status_id' => $pending->id,
        ]);
        $previous->forceFill(['created_at' => now()->subMonth(), 'updated_at' => now()->subMonth()])->saveQuietly();
        Msme::create(['name' => 'September MSME', 'category' => 'Food', 'verification_status' => 'verified', 'is_verified' => true]);
        WasteReport::create(['category' => 'garbage', 'description' => 'Resolved in September', 'status' => 'resolved', 'resolved_at' => now()->subDay()]);

        Sanctum::actingAs($this->lgu);
        $analytics = $this->getJson('/api/v1/lgu/analytics?period=monthly')
            ->assertOk()
            ->assertJsonPath('data.totalReservations', 1)
            ->assertJsonPath('data.reservationStatuses.pending', 1)
            ->assertJsonPath('data.mostBookedDestinations.0.name', 'Mundong Sandbar')
            ->json('data');
        $report = $this->getJson('/api/v1/lgu/reports?period=monthly&category=tourism_operations')
            ->assertOk()
            ->assertJsonPath('data.generatedBy', 'LGU Operator')
            ->assertJsonPath('data.period.from', '2026-09-01')
            ->json('data');

        $this->assertSame($analytics['totalReservations'], $report['summary']['reservations']);
        $this->assertSame($analytics['reservationStatuses'], $report['reservationStatuses']);
        $this->assertSame($analytics['wasteStatuses'], $report['wasteStatuses']);
    }

    public function test_maintenance_is_persisted_without_deleting_spot_or_reservations_and_partner_is_notified(): void
    {
        $spot = $this->spot('Dumog Sandbar');
        $partner = $this->user('Destination Partner', 'partner@example.test', $this->partnerRole);
        TouristSpotPartnerAssignment::create([
            'tourist_spot_id' => $spot->id, 'partner_profile_id' => $partner->id,
            'is_primary' => true, 'assigned_by' => $this->lgu->id, 'assigned_at' => now(),
        ]);
        $pending = ReservationStatus::create(['name' => 'pending']);
        $reservation = Reservation::create([
            'user_id' => $this->lgu->id, 'reservable_type' => 'spot', 'reservable_id' => $spot->id,
            'reservation_date' => now()->addDay(), 'guests' => 2, 'status_id' => $pending->id,
        ]);

        Sanctum::actingAs($this->lgu);
        $this->putJson("/api/v1/lgu/tourist-spots/{$spot->id}/status", ['status' => 'maintenance'])
            ->assertOk()
            ->assertJsonPath('data.operational_status', 'maintenance')
            ->assertJsonPath('data.is_active', false);
        $this->assertDatabaseHas('tourist_spots', ['id' => $spot->id, 'operational_status' => 'maintenance', 'deleted_at' => null]);
        $this->assertDatabaseHas('reservations', ['id' => $reservation->id, 'deleted_at' => null]);
        $this->assertDatabaseHas('partner_notifications', [
            'user_id' => $partner->id, 'type' => 'tourist_spot_status_changed',
        ]);
        $this->assertDatabaseHas('activity_logs', ['action' => 'Tourist spot maintenance']);
    }

    public function test_lgu_announcement_history_is_targeted_and_unread_state_is_per_user(): void
    {
        $otherLgu = $this->user('Second LGU', 'second-lgu@example.test', $this->lguRole);
        foreach ([
            ['Everyone Current', 'everyone', 'published', now()->subMinute(), null],
            ['LGU Scheduled', 'lgu_staff', 'scheduled', now()->addHour(), null],
            ['LGU Expired', 'lgu_staff', 'published', now()->subHours(2), now()->subHour()],
            ['Tourist Only', 'tourist', 'published', now()->subMinute(), null],
        ] as [$title, $audience, $status, $starts, $expires]) {
            Announcement::create([
                'title' => $title, 'body' => 'Municipal advisory', 'type' => 'advisory',
                'audience' => $audience, 'priority' => 'important', 'status' => $status,
                'starts_at' => $starts, 'expires_at' => $expires, 'is_active' => true,
            ]);
        }

        Sanctum::actingAs($this->lgu);
        $this->getJson('/api/v1/lgu/announcements')
            ->assertOk()
            ->assertJsonFragment(['title' => 'Everyone Current'])
            ->assertJsonFragment(['title' => 'LGU Scheduled'])
            ->assertJsonFragment(['title' => 'LGU Expired'])
            ->assertJsonMissing(['title' => 'Tourist Only']);
        $feed = $this->getJson('/api/v1/notifications')->assertOk();
        $notificationId = collect($feed->json('data'))->firstWhere('title', 'Everyone Current')['id'];
        $this->getJson('/api/v1/notifications/unread-count')->assertJsonPath('data.count', 1);
        $this->putJson("/api/v1/notifications/{$notificationId}/read")->assertOk();
        $this->getJson('/api/v1/notifications/unread-count')->assertJsonPath('data.count', 0);

        Sanctum::actingAs($otherLgu);
        $this->getJson('/api/v1/notifications/unread-count')->assertJsonPath('data.count', 1);
    }

    public function test_partner_booking_update_uses_same_spot_and_notifies_lgu(): void
    {
        $spot = $this->spot('Nakin Floating Cottage');
        $partner = $this->user('Booking Partner', 'booking-partner@example.test', $this->partnerRole);
        TouristSpotPartnerAssignment::create([
            'tourist_spot_id' => $spot->id,
            'partner_profile_id' => $partner->id,
            'is_primary' => true,
            'assigned_by' => $this->lgu->id,
            'assigned_at' => now(),
        ]);

        Sanctum::actingAs($partner);
        $this->patchJson("/api/v1/partner/tourist-spots/{$spot->id}/booking-availability", [
            'booking_enabled' => false,
            'reason_code' => 'maintenance',
            'reason' => 'Scheduled safety inspection.',
        ])->assertOk()->assertJsonPath('data.booking_enabled', false);

        $this->assertDatabaseHas('tourist_spots', [
            'id' => $spot->id,
            'booking_enabled' => false,
            'booking_unavailable_reason_code' => 'maintenance',
        ]);
        $this->assertDatabaseHas('notifications', [
            'user_id' => $this->lgu->id,
            'type' => 'partner_booking_availability_changed',
        ]);
    }

    public function test_lgu_endpoints_enforce_authentication_and_role(): void
    {
        $this->getJson('/api/v1/lgu/dashboard-stats')->assertUnauthorized();
        $tourist = $this->user('Tourist', 'tourist@example.test', $this->touristRole);
        Sanctum::actingAs($tourist);
        foreach (['dashboard-stats', 'activity', 'analytics', 'reports', 'announcements'] as $endpoint) {
            $this->getJson("/api/v1/lgu/{$endpoint}")->assertForbidden();
        }
        $spot = $this->spot('Protected Spot');
        $this->putJson("/api/v1/lgu/tourist-spots/{$spot->id}/status", ['status' => 'active'])
            ->assertForbidden();
    }

    private function user(string $name, string $email, Role $role): User
    {
        $user = User::create([
            'name' => $name, 'email' => $email, 'password' => Hash::make('safe-password'),
            'role_id' => $role->id, 'is_verified' => true,
        ]);
        Profile::create([
            'id' => $user->id, 'name' => $name, 'email' => $email,
            'role_id' => $role->id, 'is_verified' => true,
        ]);
        return $user;
    }

    private function spot(string $name): TouristSpot
    {
        return TouristSpot::create([
            'name' => $name,
            'is_active' => true,
            'operational_status' => 'active',
            'is_bookable' => true,
            'booking_enabled' => true,
        ]);
    }

    private function schema(): void
    {
        foreach ([
            'personal_access_tokens', 'tourist_spot_booking_availability_history',
            'tourist_spot_partner_assignments', 'partner_notifications', 'notifications', 'favorites',
            'emergency_contact_audits', 'activity_logs', 'reservations', 'reservation_status',
            'map_locations', 'emergency_contacts', 'waste_reports', 'msmes',
            'announcements', 'tourist_spots', 'profiles', 'users', 'roles',
        ] as $table) Schema::dropIfExists($table);

        Schema::create('roles', function (Blueprint $t) { $t->uuid('id')->primary(); $t->string('name')->unique(); $t->timestamps(); $t->softDeletes(); });
        Schema::create('users', function (Blueprint $t) { $t->uuid('id')->primary(); $t->string('name'); $t->string('email')->unique(); $t->string('password'); $t->uuid('role_id')->nullable(); $t->boolean('is_verified')->default(false); $t->rememberToken(); $t->timestamps(); $t->softDeletes(); });
        Schema::create('profiles', function (Blueprint $t) { $t->uuid('id')->primary(); $t->string('name'); $t->string('email')->unique(); $t->uuid('role_id'); $t->boolean('is_verified')->default(false); $t->timestamps(); $t->softDeletes(); });
        Schema::create('tourist_spots', function (Blueprint $t) { $t->uuid('id')->primary(); $t->string('name'); $t->boolean('is_active')->default(true); $t->string('operational_status')->default('active'); $t->boolean('is_published')->default(true); $t->boolean('is_bookable')->default(false); $t->boolean('booking_enabled')->default(false); $t->string('booking_unavailable_reason_code')->nullable(); $t->text('booking_unavailable_reason')->nullable(); $t->timestamp('booking_availability_updated_at')->nullable(); $t->uuid('booking_availability_updated_by')->nullable(); $t->timestamps(); $t->softDeletes(); });
        Schema::create('msmes', function (Blueprint $t) { $t->uuid('id')->primary(); $t->uuid('profile_id')->nullable(); $t->string('name'); $t->string('category'); $t->boolean('is_verified')->default(false); $t->string('verification_status')->default('pending'); $t->text('verification_notes')->nullable(); $t->timestamp('reviewed_at')->nullable(); $t->uuid('reviewed_by')->nullable(); $t->timestamps(); $t->softDeletes(); });
        Schema::create('reservation_status', function (Blueprint $t) { $t->uuid('id')->primary(); $t->string('name')->unique(); $t->timestamps(); $t->softDeletes(); });
        Schema::create('reservations', function (Blueprint $t) { $t->uuid('id')->primary(); $t->uuid('user_id'); $t->string('public_reference')->nullable(); $t->uuid('partner_id')->nullable(); $t->string('reservable_type'); $t->uuid('reservable_id'); $t->dateTime('reservation_date'); $t->string('start_time')->nullable(); $t->string('end_time')->nullable(); $t->unsignedInteger('guests')->default(1); $t->uuid('status_id')->nullable(); $t->text('notes')->nullable(); $t->decimal('total_amount')->default(0); $t->timestamps(); $t->softDeletes(); });
        Schema::create('favorites', function (Blueprint $t) { $t->uuid('id')->primary(); $t->uuid('user_id'); $t->string('favoritable_type'); $t->uuid('favoritable_id'); $t->timestamps(); $t->softDeletes(); });
        Schema::create('waste_reports', function (Blueprint $t) { $t->uuid('id')->primary(); $t->uuid('user_id')->nullable(); $t->string('category'); $t->text('description'); $t->string('status')->default('submitted'); $t->string('priority')->default('normal'); $t->text('lgu_notes')->nullable(); $t->timestamp('resolved_at')->nullable(); $t->timestamps(); $t->softDeletes(); });
        Schema::create('emergency_contacts', function (Blueprint $t) { $t->uuid('id')->primary(); $t->string('name'); $t->string('category'); $t->string('phone'); $t->boolean('is_active')->default(true); $t->boolean('is_verified')->default(false); $t->timestamp('last_verified_at')->nullable(); $t->timestamps(); $t->softDeletes(); });
        Schema::create('map_locations', function (Blueprint $t) { $t->uuid('id')->primary(); $t->string('name'); $t->string('slug'); $t->boolean('verified')->default(false); $t->boolean('published')->default(false); $t->boolean('active')->default(true); $t->timestamps(); $t->softDeletes(); });
        Schema::create('announcements', function (Blueprint $t) { $t->uuid('id')->primary(); $t->string('title'); $t->text('body'); $t->string('category')->nullable(); $t->string('type')->default('general'); $t->string('audience')->default('everyone'); $t->string('priority')->default('normal'); $t->string('status')->default('published'); $t->timestamp('starts_at')->nullable(); $t->timestamp('expires_at')->nullable(); $t->timestamp('published_at')->nullable(); $t->uuid('created_by')->nullable(); $t->boolean('is_active')->default(true); $t->timestamps(); $t->softDeletes(); });
        Schema::create('activity_logs', function (Blueprint $t) { $t->uuid('id')->primary(); $t->uuid('user_id')->nullable(); $t->string('action'); $t->text('details')->nullable(); $t->timestamps(); $t->softDeletes(); });
        Schema::create('emergency_contact_audits', function (Blueprint $t) { $t->uuid('id')->primary(); $t->uuid('contact_id'); $t->string('action'); $t->json('old_value')->nullable(); $t->json('new_value')->nullable(); $t->uuid('updated_by'); $t->timestamps(); });
        Schema::create('tourist_spot_partner_assignments', function (Blueprint $t) { $t->uuid('id')->primary(); $t->uuid('tourist_spot_id'); $t->uuid('partner_profile_id'); $t->boolean('is_primary')->default(false); $t->uuid('assigned_by')->nullable(); $t->timestamp('assigned_at')->nullable(); $t->timestamps(); });
        foreach (['notifications', 'partner_notifications'] as $name) Schema::create($name, function (Blueprint $t) { $t->uuid('id')->primary(); $t->uuid('user_id'); $t->uuid('announcement_id')->nullable(); $t->string('type'); $t->string('title'); $t->text('body')->nullable(); $t->json('data')->nullable(); $t->boolean('is_read')->default(false); $t->timestamps(); $t->softDeletes(); $t->unique(['user_id', 'announcement_id']); });
        Schema::create('tourist_spot_booking_availability_history', function (Blueprint $t) { $t->uuid('id')->primary(); $t->uuid('tourist_spot_id'); $t->boolean('booking_enabled'); $t->string('reason_code')->nullable(); $t->text('reason')->nullable(); $t->uuid('changed_by'); $t->timestamp('changed_at'); $t->timestamps(); });
        Schema::create('personal_access_tokens', function (Blueprint $t) { $t->id(); $t->string('tokenable_type'); $t->uuid('tokenable_id'); $t->string('name'); $t->string('token', 64)->unique(); $t->text('abilities')->nullable(); $t->timestamp('last_used_at')->nullable(); $t->timestamp('expires_at')->nullable(); $t->timestamps(); });
    }
}
