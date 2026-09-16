<?php

namespace Tests\Feature;

use App\Models\Profile;
use App\Models\Role;
use App\Models\RoleApplication;
use App\Models\SystemSetting;
use App\Models\TouristSpot;
use App\Models\User;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Schema;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RoleApplicationWorkflowTest extends TestCase
{
    private array $roles;
    private User $tourist;
    private User $lgu;
    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();
        $this->schema();
        foreach (['tourist', 'msme_owner', 'tourism_partner', 'lgu_staff', 'admin'] as $name) {
            $this->roles[$name] = Role::create(['name' => $name]);
        }
        $this->tourist = $this->user('applicant', 'tourist');
        $this->lgu = $this->user('lgu-reviewer', 'lgu_staff');
        $this->admin = $this->user('final-admin', 'admin');
        SystemSetting::create(['app_name' => 'Tubigon Smart Tourism']);
    }

    public function test_msme_application_runs_end_to_end_without_granting_access_early(): void
    {
        Mail::fake();
        Sanctum::actingAs($this->tourist);
        $draft = $this->postJson('/api/v1/role-applications', ['application_type' => 'msme_owner'])
            ->assertCreated()->assertJsonPath('data.status', 'draft');
        $id = $draft->json('data.id');
        $this->postJson('/api/v1/role-applications', ['application_type' => 'msme_owner'])
            ->assertOk()->assertJsonPath('data.id', $id);
        $this->putJson("/api/v1/role-applications/$id", ['status' => 'approved'])
            ->assertUnprocessable();

        $payload = [
            'applicant_contact' => '09170000000',
            'business_name' => 'Applicant Food House',
            'business_category' => 'Food & Dining',
            'business_address' => 'Poblacion, Tubigon, Bohol',
            'business_phone' => '09170000000',
            'business_description' => 'A locally operated food business.',
            'latitude' => 9.9515,
            'longitude' => 123.9618,
            'reason' => 'Manage the official business profile.',
            'supporting_evidence' => 'Permit reference TUB-2026-100',
            'declaration' => true,
        ];
        $this->postJson("/api/v1/role-applications/$id/submit", $payload)
            ->assertOk()->assertJsonPath('data.status', 'submitted');
        $this->assertDatabaseHas('users', ['id' => $this->tourist->id, 'role_id' => $this->roles['tourist']->id]);
        $this->assertDatabaseHas('msmes', ['profile_id' => $this->tourist->id, 'is_verified' => false, 'verification_status' => 'pending']);
        $this->getJson('/api/v1/msme/profile')->assertForbidden();

        Sanctum::actingAs($this->lgu);
        $this->postJson("/api/v1/lgu/role-applications/$id/start-review")->assertOk();
        $this->postJson("/api/v1/lgu/role-applications/$id/recommend", [
            'checklist' => ['applicant_identity_complete' => true],
        ])->assertUnprocessable();
        $this->postJson("/api/v1/lgu/role-applications/$id/recommend", [
            'notes' => 'Business identity and location verified.',
            'checklist' => [
                'applicant_identity_complete' => true,
                'business_information_complete' => true,
                'address_valid' => true,
                'coordinates_valid' => true,
                'category_appropriate' => true,
                'contact_information_valid' => true,
                'required_proof_complete' => true,
            ],
        ])->assertOk()->assertJsonPath('data.status', 'recommended_for_approval');
        $this->assertDatabaseHas('users', ['id' => $this->tourist->id, 'role_id' => $this->roles['tourist']->id]);

        Sanctum::actingAs($this->admin);
        $this->postJson("/api/v1/admin/access-requests/$id/approve", ['notes' => 'Final access checks complete.'])
            ->assertOk()->assertJsonPath('data.status', 'approved');
        $this->assertDatabaseHas('users', ['id' => $this->tourist->id, 'role_id' => $this->roles['msme_owner']->id]);
        $this->assertDatabaseHas('profiles', ['id' => $this->tourist->id, 'role_id' => $this->roles['msme_owner']->id]);
        $this->assertDatabaseCount('msmes', 1);
        Mail::assertSent(\App\Mail\TourTubigonMessage::class, 1);
        $this->assertDatabaseHas('notifications', ['user_id' => $this->tourist->id, 'type' => 'role_application', 'title' => 'Application approved']);
        $this->assertDatabaseHas('activity_logs', ['action' => 'Role application approved and provisioned']);

        Sanctum::actingAs($this->tourist->fresh());
        $this->getJson('/api/v1/msme/profile')->assertOk()->assertJsonPath('data.name', 'Applicant Food House');
    }

    public function test_partner_approval_links_existing_spot_and_refuses_assignment_conflict(): void
    {
        $spot = TouristSpot::create(['name' => 'Existing Destination', 'is_active' => true, 'is_published' => true]);
        $applicationId = $this->submitPartner($this->tourist, $spot->id);

        Sanctum::actingAs($this->lgu);
        $this->postJson("/api/v1/lgu/role-applications/$applicationId/start-review")->assertOk();
        $this->postJson("/api/v1/lgu/role-applications/$applicationId/recommend", [
            'checklist' => [
                'applicant_identity_complete' => true,
                'organization_relationship_verified' => true,
                'requested_destination_valid' => true,
                'required_proof_complete' => true,
                'destination_assignment_available' => true,
            ],
        ])->assertOk();

        Sanctum::actingAs($this->admin);
        $this->postJson("/api/v1/admin/access-requests/$applicationId/approve")
            ->assertOk();
        $this->assertDatabaseCount('tourist_spots', 1);
        $this->assertDatabaseHas('tourist_spot_partner_assignments', [
            'tourist_spot_id' => $spot->id,
            'partner_profile_id' => $this->tourist->id,
        ]);

        $other = $this->user('second-applicant', 'tourist');
        $secondId = $this->submitPartner($other, $spot->id);
        Sanctum::actingAs($this->lgu);
        $this->postJson("/api/v1/lgu/role-applications/$secondId/start-review")->assertOk();
        $this->postJson("/api/v1/lgu/role-applications/$secondId/recommend", ['checklist' => [
            'applicant_identity_complete' => true,
            'organization_relationship_verified' => true,
            'requested_destination_valid' => true,
            'required_proof_complete' => true,
            'destination_assignment_available' => true,
        ]])->assertOk();
        Sanctum::actingAs($this->admin);
        $this->postJson("/api/v1/admin/access-requests/$secondId/approve")
            ->assertUnprocessable();
        $this->assertDatabaseHas('users', ['id' => $other->id, 'role_id' => $this->roles['tourist']->id]);
    }

    public function test_needs_changes_reuses_same_record_and_authorization_blocks_idor(): void
    {
        Mail::fake();
        Sanctum::actingAs($this->tourist);
        $id = $this->postJson('/api/v1/role-applications', ['application_type' => 'msme_owner'])->json('data.id');
        $payload = ['applicant_contact' => '0917', 'business_name' => 'Draft Business', 'business_category' => 'Retail', 'business_address' => 'Tubigon', 'business_phone' => '0917', 'business_description' => 'Retail shop', 'latitude' => 9.9515, 'longitude' => 123.9618, 'reason' => 'Business access', 'declaration' => true];
        $this->postJson("/api/v1/role-applications/$id/submit", $payload)->assertOk();

        $stranger = $this->user('stranger', 'tourist');
        Sanctum::actingAs($stranger);
        $this->getJson("/api/v1/role-applications/$id")->assertForbidden();
        $this->putJson("/api/v1/role-applications/$id", ['business_name' => 'Hijacked'])->assertForbidden();

        Sanctum::actingAs($this->lgu);
        $this->postJson("/api/v1/lgu/role-applications/$id/start-review")->assertOk();
        $this->postJson("/api/v1/lgu/role-applications/$id/needs-changes", ['notes' => 'Correct the business address.'])->assertOk();
        Mail::assertSent(\App\Mail\TourTubigonMessage::class, 1);

        Sanctum::actingAs($this->tourist);
        $this->putJson("/api/v1/role-applications/$id", ['business_address' => 'Corrected Tubigon address'])->assertOk();
        $this->postJson("/api/v1/role-applications/$id/submit", [])->assertOk()->assertJsonPath('data.id', $id);
        $this->assertDatabaseCount('role_applications', 1);
        $this->assertDatabaseCount('msmes', 1);
        $this->assertGreaterThanOrEqual(5, Schema::getConnection()->table('role_application_history')->where('application_id', $id)->count());
    }

    public function test_non_lgu_and_non_admin_cannot_review_or_provision(): void
    {
        Sanctum::actingAs($this->tourist);
        $id = $this->postJson('/api/v1/role-applications', ['application_type' => 'msme_owner'])->json('data.id');
        $this->getJson('/api/v1/lgu/role-applications')->assertForbidden();
        $this->postJson("/api/v1/admin/access-requests/$id/approve")->assertForbidden();
        $this->postJson('/api/v1/role-applications', ['application_type' => 'admin'])->assertUnprocessable();
    }

    public function test_stale_admin_final_decision_is_rejected_before_provisioning(): void
    {
        $application = RoleApplication::create([
            'applicant_user_id' => $this->tourist->id,
            'application_type' => RoleApplication::TYPE_MSME,
            'status' => RoleApplication::STATUS_RECOMMENDED,
            'active_slot' => true,
            'payload' => [
                'business_name' => 'Concurrent Business',
                'business_category' => 'Food & Dining',
                'business_address' => 'Tubigon, Bohol',
                'business_phone' => '09170000000',
                'business_description' => 'A local business.',
                'latitude' => 9.9515,
                'longitude' => 123.9618,
            ],
        ]);
        $expected = $application->updated_at->toIso8601String();
        Schema::getConnection()->table('role_applications')->where('id', $application->id)->update([
            'lgu_notes' => 'A newer review note.',
            'updated_at' => now()->addMinute(),
        ]);

        Sanctum::actingAs($this->admin);
        $this->postJson("/api/v1/admin/access-requests/{$application->id}/approve", [
            'expected_updated_at' => $expected,
        ])->assertStatus(409)
            ->assertJsonPath('code', 'stale_record')
            ->assertJsonPath('current.status', RoleApplication::STATUS_RECOMMENDED);

        $this->assertDatabaseHas('users', [
            'id' => $this->tourist->id,
            'role_id' => $this->roles['tourist']->id,
        ]);
        $this->assertDatabaseMissing('activity_logs', [
            'action' => 'Role application approved and provisioned',
        ]);
    }

    private function submitPartner(User $user, string $spotId): string
    {
        Sanctum::actingAs($user);
        $id = $this->postJson('/api/v1/role-applications', ['application_type' => 'tourism_partner'])->json('data.id');
        $this->postJson("/api/v1/role-applications/$id/submit", [
            'applicant_contact' => '09170000000',
            'organization' => 'Destination Operators Group',
            'contact_phone' => '09170000000',
            'relationship' => 'Authorized destination operator.',
            'reason' => 'Manage the existing official destination.',
            'supporting_evidence' => 'Authorization reference 100',
            'requested_tourist_spot_id' => $spotId,
            'declaration' => true,
        ])->assertOk();
        return $id;
    }

    private function user(string $key, string $role): User
    {
        $user = User::create(['name' => $key, 'email' => "$key@example.test", 'password' => Hash::make('safe-password'), 'role_id' => $this->roles[$role]->id, 'is_verified' => true]);
        Profile::create(['id' => $user->id, 'name' => $user->name, 'email' => $user->email, 'role_id' => $this->roles[$role]->id, 'is_verified' => true]);
        return $user;
    }

    private function schema(): void
    {
        foreach (['personal_access_tokens', 'role_application_history', 'role_applications', 'tourist_spot_partner_assignments', 'notifications', 'activity_logs', 'msmes', 'tourist_spots', 'system_settings', 'profiles', 'users', 'roles'] as $table) Schema::dropIfExists($table);
        Schema::create('roles', function (Blueprint $t) { $t->uuid('id')->primary(); $t->string('name')->unique(); $t->timestamps(); $t->softDeletes(); });
        Schema::create('users', function (Blueprint $t) { $t->uuid('id')->primary(); $t->string('name'); $t->string('email')->unique(); $t->string('password'); $t->uuid('role_id'); $t->string('phone')->nullable(); $t->boolean('is_verified')->default(false); $t->rememberToken(); $t->timestamps(); $t->softDeletes(); });
        Schema::create('profiles', function (Blueprint $t) { $t->uuid('id')->primary(); $t->string('name'); $t->string('email'); $t->uuid('role_id'); $t->boolean('is_verified')->default(false); $t->timestamps(); $t->softDeletes(); });
        Schema::create('system_settings', function (Blueprint $t) { $t->uuid('id')->primary(); $t->string('app_name'); $t->boolean('msme_applications_enabled')->default(true); $t->boolean('partner_applications_enabled')->default(true); $t->timestamps(); });
        Schema::create('tourist_spots', function (Blueprint $t) { $t->uuid('id')->primary(); $t->string('name'); $t->text('address')->nullable(); $t->boolean('is_active')->default(true); $t->boolean('is_published')->default(true); $t->timestamps(); $t->softDeletes(); });
        Schema::create('msmes', function (Blueprint $t) { $t->uuid('id')->primary(); $t->uuid('profile_id')->nullable()->unique(); $t->string('name'); $t->string('category'); $t->text('description')->nullable(); $t->string('phone')->nullable(); $t->text('address')->nullable(); $t->double('latitude')->nullable(); $t->double('longitude')->nullable(); $t->boolean('is_verified')->default(false); $t->string('verification_status')->default('pending'); $t->timestamp('submitted_at')->nullable(); $t->boolean('booking_enabled')->default(false); $t->timestamps(); $t->softDeletes(); });
        Schema::create('activity_logs', function (Blueprint $t) { $t->uuid('id')->primary(); $t->uuid('user_id')->nullable(); $t->string('action'); $t->text('details')->nullable(); $t->timestamps(); $t->softDeletes(); });
        Schema::create('notifications', function (Blueprint $t) { $t->uuid('id')->primary(); $t->uuid('user_id'); $t->uuid('announcement_id')->nullable(); $t->string('type'); $t->string('title'); $t->text('body')->nullable(); $t->json('data')->nullable(); $t->boolean('is_read')->default(false); $t->timestamps(); $t->softDeletes(); });
        Schema::create('tourist_spot_partner_assignments', function (Blueprint $t) { $t->uuid('id')->primary(); $t->uuid('tourist_spot_id')->unique(); $t->uuid('partner_profile_id')->unique(); $t->boolean('is_primary')->default(true); $t->uuid('assigned_by')->nullable(); $t->timestamp('assigned_at'); $t->timestamps(); });
        Schema::create('role_applications', function (Blueprint $t) { $t->uuid('id')->primary(); $t->uuid('applicant_user_id'); $t->string('application_type'); $t->string('status')->default('draft'); $t->boolean('active_slot')->nullable()->default(true); $t->json('payload')->nullable(); $t->uuid('requested_tourist_spot_id')->nullable(); $t->uuid('linked_msme_id')->nullable(); $t->json('lgu_checklist')->nullable(); $t->uuid('reviewed_by_lgu_id')->nullable(); $t->timestamp('lgu_reviewed_at')->nullable(); $t->text('lgu_notes')->nullable(); $t->uuid('admin_reviewed_by_id')->nullable(); $t->timestamp('admin_reviewed_at')->nullable(); $t->text('admin_notes')->nullable(); $t->timestamp('submitted_at')->nullable(); $t->timestamp('approved_at')->nullable(); $t->timestamp('rejected_at')->nullable(); $t->timestamp('withdrawn_at')->nullable(); $t->timestamps(); $t->unique(['applicant_user_id', 'application_type', 'active_slot']); });
        Schema::create('role_application_history', function (Blueprint $t) { $t->uuid('id')->primary(); $t->uuid('application_id'); $t->uuid('actor_user_id')->nullable(); $t->string('action'); $t->string('from_status')->nullable(); $t->string('to_status')->nullable(); $t->text('notes')->nullable(); $t->json('metadata')->nullable(); $t->timestamp('created_at')->nullable(); });
        Schema::create('personal_access_tokens', function (Blueprint $t) { $t->id(); $t->string('tokenable_type'); $t->uuid('tokenable_id'); $t->string('name'); $t->string('token', 64)->unique(); $t->text('abilities')->nullable(); $t->timestamp('last_used_at')->nullable(); $t->timestamp('expires_at')->nullable(); $t->timestamps(); });
    }
}
