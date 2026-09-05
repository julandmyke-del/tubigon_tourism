<?php

namespace Tests\Feature;

use App\Models\Announcement;
use App\Models\Profile;
use App\Models\Role;
use App\Models\SystemSetting;
use App\Models\User;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminCommunicationManagementTest extends TestCase
{
    private Role $adminRole;
    private Role $touristRole;
    private Role $msmeRole;
    private Role $partnerRole;
    private Role $lguRole;
    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();
        $this->schema();
        $this->adminRole = Role::create(['name' => 'admin']);
        $this->touristRole = Role::create(['name' => 'tourist']);
        $this->msmeRole = Role::create(['name' => 'msme_owner']);
        $this->partnerRole = Role::create(['name' => 'tourism_partner']);
        $this->lguRole = Role::create(['name' => 'lgu_staff']);
        $this->admin = $this->user('admin', $this->adminRole);
        SystemSetting::create(['app_name' => 'Tubigon Smart Tourism']);
    }

    public function test_admin_user_management_is_authorized_audited_and_never_exposes_passwords(): void
    {
        $tourist = $this->user('tourist-user', $this->touristRole);
        Sanctum::actingAs($this->admin);

        $this->getJson('/api/v1/admin/users?role=tourist&status=active')
            ->assertOk()
            ->assertJsonFragment(['email' => $tourist->email, 'status' => 'Active'])
            ->assertJsonMissingPath('data.0.password');

        $this->putJson("/api/v1/admin/users/{$tourist->id}/verify", ['is_verified' => true])
            ->assertOk();
        $this->putJson("/api/v1/admin/users/{$tourist->id}/status", ['active' => false])
            ->assertOk();
        $this->assertSoftDeleted('users', ['id' => $tourist->id]);
        $this->assertDatabaseHas('profiles', ['id' => $tourist->id]);
        $this->assertDatabaseHas('activity_logs', ['action' => 'User deactivated']);

        $this->putJson("/api/v1/admin/users/{$tourist->id}/status", ['active' => true])
            ->assertOk();
        $this->assertDatabaseHas('users', ['id' => $tourist->id, 'deleted_at' => null]);
    }

    public function test_user_role_allowlist_and_admin_authorization_are_server_enforced(): void
    {
        $tourist = $this->user('ordinary-user', $this->touristRole);
        Sanctum::actingAs($tourist);
        $this->getJson('/api/v1/admin/users')->assertForbidden();
        $this->putJson("/api/v1/admin/users/{$tourist->id}/status", ['active' => false])
            ->assertForbidden();

        $unexpected = Role::create(['name' => 'superuser']);
        Sanctum::actingAs($this->admin);
        $this->putJson("/api/v1/admin/users/{$tourist->id}/role", [
            'role_id' => $unexpected->id,
        ])->assertUnprocessable();
        $this->putJson("/api/v1/admin/users/{$this->admin->id}/role", [
            'role_id' => $this->touristRole->id,
        ])->assertUnprocessable();
    }

    public function test_announcement_audience_unread_and_per_user_read_state_are_real(): void
    {
        $touristA = $this->user('tourist-a', $this->touristRole);
        $touristB = $this->user('tourist-b', $this->touristRole);
        $owner = $this->user('owner', $this->msmeRole);
        Sanctum::actingAs($this->admin);
        $response = $this->postJson('/api/v1/admin/announcements', [
            'title' => 'Tourist Advisory',
            'body' => 'A role-targeted municipal advisory.',
            'type' => 'advisory',
            'audience' => 'tourist',
            'priority' => 'important',
            'status' => 'published',
        ])->assertCreated();
        $id = $response->json('data.id');
        $this->assertDatabaseHas('activity_logs', ['action' => 'Announcement created']);

        Sanctum::actingAs($touristA);
        $feedA = $this->getJson('/api/v1/notifications')
            ->assertOk()->assertJsonFragment(['title' => 'Tourist Advisory']);
        $notificationId = collect($feedA->json('data'))->firstWhere('announcement_id', $id)['id'];
        $this->getJson('/api/v1/notifications/unread-count')->assertJsonPath('data.count', 1);
        $this->putJson("/api/v1/notifications/{$notificationId}/read")->assertOk();
        $this->getJson('/api/v1/notifications/unread-count')->assertJsonPath('data.count', 0);

        Sanctum::actingAs($touristB);
        $this->getJson('/api/v1/notifications/unread-count')->assertJsonPath('data.count', 1);

        Sanctum::actingAs($owner);
        $this->getJson('/api/v1/notifications')->assertOk()
            ->assertJsonMissing(['title' => 'Tourist Advisory']);
    }

    public function test_scheduled_expired_and_archived_announcements_obey_backend_time(): void
    {
        $tourist = $this->user('time-tourist', $this->touristRole);
        Announcement::create([
            'title' => 'Future Notice', 'body' => 'Later', 'type' => 'general',
            'audience' => 'everyone', 'priority' => 'normal', 'status' => 'scheduled',
            'starts_at' => now()->addHour(), 'is_active' => true,
        ]);
        Announcement::create([
            'title' => 'Expired Notice', 'body' => 'Past', 'type' => 'general',
            'audience' => 'everyone', 'priority' => 'normal', 'status' => 'published',
            'starts_at' => now()->subHours(2), 'expires_at' => now()->subHour(), 'is_active' => true,
        ]);
        $active = Announcement::create([
            'title' => 'Current Notice', 'body' => 'Now', 'type' => 'general',
            'audience' => 'everyone', 'priority' => 'urgent', 'status' => 'published',
            'starts_at' => now()->subMinute(), 'is_active' => true,
        ]);

        Sanctum::actingAs($tourist);
        $this->getJson('/api/v1/announcements')->assertOk()
            ->assertJsonFragment(['title' => 'Current Notice'])
            ->assertJsonMissing(['title' => 'Future Notice'])
            ->assertJsonMissing(['title' => 'Expired Notice']);

        Sanctum::actingAs($this->admin);
        $this->deleteJson("/api/v1/admin/announcements/{$active->id}")->assertOk();
        Sanctum::actingAs($tourist);
        $this->getJson('/api/v1/announcements')->assertJsonMissing(['title' => 'Current Notice']);
    }

    public function test_settings_are_allowlisted_audited_and_feature_toggle_is_enforced(): void
    {
        $settings = SystemSetting::firstOrFail();
        Sanctum::actingAs($this->admin);
        $this->putJson("/api/v1/admin/system-settings/{$settings->id}", [
            'reviews_enabled' => false,
            'municipality_name' => 'Municipality of Tubigon',
        ])->assertOk()->assertJsonPath('data.reviews_enabled', false);
        $this->assertDatabaseHas('activity_logs', ['action' => 'System Settings updated']);
        $this->getJson('/api/v1/system-settings')
            ->assertOk()->assertJsonMissingPath('data.app_key')
            ->assertJsonMissingPath('data.db_password');

        $tourist = $this->user('review-tourist', $this->touristRole);
        $msmeId = Str::uuid()->toString();
        Schema::getConnection()->table('msmes')->insert([
            'id' => $msmeId, 'name' => 'Verified Business', 'category' => 'Food',
            'is_verified' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);
        Sanctum::actingAs($tourist);
        $this->postJson('/api/v1/reviews', [
            'reviewable_type' => 'msme', 'reviewable_id' => $msmeId,
            'rating' => 5, 'content' => 'Should be blocked by the global setting.',
        ])->assertForbidden();
    }

    public function test_non_admin_cannot_modify_system_settings_or_announcements(): void
    {
        $tourist = $this->user('blocked-tourist', $this->touristRole);
        Sanctum::actingAs($tourist);
        $this->putJson('/api/v1/admin/system-settings/'.SystemSetting::first()->id, [
            'reviews_enabled' => false,
        ])->assertForbidden();
        $this->postJson('/api/v1/admin/announcements', [])->assertForbidden();
    }

    private function user(string $key, Role $role): User
    {
        $user = User::create([
            'name' => $key,
            'email' => "$key@example.test",
            'password' => Hash::make('safe-password'),
            'role_id' => $role->id,
            'is_verified' => false,
        ]);
        Profile::create([
            'id' => $user->id, 'name' => $user->name, 'email' => $user->email,
            'role_id' => $role->id, 'is_verified' => false,
        ]);
        return $user;
    }

    private function schema(): void
    {
        foreach ([
            'personal_access_tokens', 'tourist_spot_partner_assignments', 'tourist_spots',
            'reviews', 'msmes', 'partner_notifications', 'notifications', 'announcements',
            'system_settings', 'activity_logs', 'profiles', 'users', 'roles',
        ] as $table) Schema::dropIfExists($table);

        Schema::create('roles', function (Blueprint $t) { $t->uuid('id')->primary(); $t->string('name')->unique(); $t->timestamps(); $t->softDeletes(); });
        Schema::create('users', function (Blueprint $t) { $t->uuid('id')->primary(); $t->string('name'); $t->string('email')->unique(); $t->string('password'); $t->uuid('role_id')->nullable(); $t->string('avatar_url')->nullable(); $t->string('phone')->nullable(); $t->text('bio')->nullable(); $t->string('language')->nullable(); $t->boolean('is_verified')->default(false); $t->string('auth_provider')->nullable(); $t->rememberToken(); $t->timestamps(); $t->softDeletes(); });
        Schema::create('profiles', function (Blueprint $t) { $t->uuid('id')->primary(); $t->string('name'); $t->string('email')->unique(); $t->uuid('role_id'); $t->string('phone')->nullable(); $t->text('bio')->nullable(); $t->string('language')->nullable(); $t->boolean('is_verified')->default(false); $t->timestamps(); $t->softDeletes(); });
        Schema::create('activity_logs', function (Blueprint $t) { $t->uuid('id')->primary(); $t->uuid('user_id')->nullable(); $t->string('action'); $t->text('details')->nullable(); $t->timestamps(); $t->softDeletes(); });
        Schema::create('announcements', function (Blueprint $t) { $t->uuid('id')->primary(); $t->string('title'); $t->text('body'); $t->string('category')->nullable(); $t->string('type')->default('general'); $t->string('audience')->default('everyone'); $t->string('priority')->default('normal'); $t->string('status')->default('published'); $t->timestamp('starts_at')->nullable(); $t->timestamp('expires_at')->nullable(); $t->timestamp('published_at')->nullable(); $t->uuid('created_by')->nullable(); $t->boolean('is_active')->default(true); $t->timestamps(); $t->softDeletes(); });
        foreach (['notifications', 'partner_notifications'] as $name) Schema::create($name, function (Blueprint $t) { $t->uuid('id')->primary(); $t->uuid('user_id'); $t->uuid('announcement_id')->nullable(); $t->string('type'); $t->string('title'); $t->text('body')->nullable(); $t->json('data')->nullable(); $t->boolean('is_read')->default(false); $t->timestamps(); $t->softDeletes(); $t->unique(['user_id', 'announcement_id']); });
        Schema::create('system_settings', function (Blueprint $t) { $t->uuid('id')->primary(); $t->string('app_name'); $t->string('municipality_name')->default('Municipality of Tubigon'); $t->string('contact_email')->nullable(); $t->string('contact_phone')->nullable(); $t->string('tourism_office_address')->nullable(); $t->string('support_contact')->nullable(); $t->boolean('tourist_registration_enabled')->default(true); $t->boolean('msme_registration_enabled')->default(true); $t->boolean('require_msme_verification')->default(true); $t->boolean('reviews_enabled')->default(true); $t->boolean('waste_reporting_enabled')->default(true); $t->boolean('global_booking_enabled')->default(true); $t->decimal('map_default_latitude', 10, 7)->default(9.9512); $t->decimal('map_default_longitude', 10, 7)->default(123.962); $t->decimal('map_default_zoom', 4, 1)->default(12); $t->text('maintenance_notice')->nullable(); $t->text('privacy_policy')->nullable(); $t->text('terms_of_service')->nullable(); $t->uuid('updated_by')->nullable(); $t->timestamps(); });
        Schema::create('msmes', function (Blueprint $t) { $t->uuid('id')->primary(); $t->uuid('profile_id')->nullable(); $t->string('name'); $t->string('category'); $t->boolean('is_verified')->default(false); $t->timestamps(); $t->softDeletes(); });
        Schema::create('reviews', function (Blueprint $t) { $t->uuid('id')->primary(); $t->uuid('user_id'); $t->string('reviewable_type'); $t->uuid('reviewable_id'); $t->unsignedTinyInteger('rating'); $t->text('content'); $t->json('images')->nullable(); $t->timestamps(); $t->softDeletes(); });
        Schema::create('tourist_spots', function (Blueprint $t) { $t->uuid('id')->primary(); $t->string('name'); $t->timestamps(); $t->softDeletes(); });
        Schema::create('tourist_spot_partner_assignments', function (Blueprint $t) { $t->id(); $t->uuid('tourist_spot_id'); $t->uuid('partner_profile_id'); $t->boolean('is_primary')->default(false); $t->uuid('assigned_by')->nullable(); $t->timestamp('assigned_at')->nullable(); $t->timestamps(); });
        Schema::create('personal_access_tokens', function (Blueprint $t) { $t->id(); $t->string('tokenable_type'); $t->uuid('tokenable_id'); $t->string('name'); $t->string('token', 64)->unique(); $t->text('abilities')->nullable(); $t->timestamp('last_used_at')->nullable(); $t->timestamp('expires_at')->nullable(); $t->timestamps(); });
    }
}
