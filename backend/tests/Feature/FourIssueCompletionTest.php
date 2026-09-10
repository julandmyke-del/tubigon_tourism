<?php

namespace Tests\Feature;

use App\Models\ActivityLog;
use App\Models\Msme;
use App\Models\MsmeCategory;
use App\Models\Notification;
use App\Models\Profile;
use App\Models\Role;
use App\Models\SpotCategory;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class FourIssueCompletionTest extends TestCase
{
    use RefreshDatabase;

    private array $roles = [];

    protected function setUp(): void
    {
        parent::setUp();
        foreach (['tourist', 'msme_owner', 'tourism_partner', 'lgu_staff', 'admin'] as $name) {
            $this->roles[$name] = Role::firstOrCreate(['name' => $name]);
        }
    }

    public function test_authoritative_msme_category_is_preserved_through_review_and_map_publication(): void
    {
        Mail::fake();
        $tourist = $this->user('category-applicant', 'tourist');
        $lgu = $this->user('category-lgu', 'lgu_staff');
        $admin = $this->user('category-admin', 'admin');
        $requested = MsmeCategory::where('slug', 'food-dining')->firstOrFail();
        $recommended = MsmeCategory::where('slug', 'retail')->firstOrFail();
        $final = MsmeCategory::where('slug', 'transport')->firstOrFail();

        Sanctum::actingAs($tourist);
        $this->getJson('/api/v1/role-applications/options')
            ->assertOk()->assertJsonFragment(['id' => $requested->id, 'name' => 'Food & Dining']);
        $id = $this->postJson('/api/v1/role-applications', ['application_type' => 'msme_owner'])
            ->assertCreated()->json('data.id');
        $this->postJson("/api/v1/role-applications/$id/submit", [
            'applicant_contact' => '09170000000', 'business_name' => 'Stable Category Tours',
            'business_category_id' => $requested->id, 'business_category' => $requested->name,
            'business_address' => 'Poblacion, Tubigon, Bohol', 'business_phone' => '09170000000',
            'business_description' => 'A local transport service.', 'latitude' => 9.9515,
            'longitude' => 123.9618, 'reason' => 'Manage the verified business listing.', 'declaration' => true,
        ])->assertOk()->assertJsonPath('data.requested_msme_category.id', $requested->id);

        Sanctum::actingAs($lgu);
        $this->postJson("/api/v1/lgu/role-applications/$id/start-review")->assertOk();
        $this->postJson("/api/v1/lgu/role-applications/$id/recommend", [
            'recommended_msme_category_id' => $recommended->id,
            'checklist' => [
                'applicant_identity_complete' => true, 'business_information_complete' => true,
                'address_valid' => true, 'coordinates_valid' => true, 'category_appropriate' => true,
                'contact_information_valid' => true, 'required_proof_complete' => true,
            ],
        ])->assertOk()
            ->assertJsonPath('data.requested_msme_category.id', $requested->id)
            ->assertJsonPath('data.recommended_msme_category.id', $recommended->id);

        Sanctum::actingAs($admin);
        $this->postJson("/api/v1/admin/access-requests/$id/approve", ['final_msme_category_id' => $final->id])
            ->assertOk()->assertJsonPath('data.final_msme_category.id', $final->id);
        $this->postJson("/api/v1/admin/access-requests/$id/approve", ['final_msme_category_id' => $final->id])
            ->assertUnprocessable();
        $this->assertDatabaseCount('msmes', 1);
        $msme = Msme::firstOrFail();
        $this->assertSame($final->id, $msme->category_id);
        $this->assertSame('Transport', $msme->category);

        $this->getJson('/api/v1/map/locations')->assertOk()->assertJsonMissing(['source_id' => $msme->id]);
        $msme->update(['is_verified' => true, 'verification_status' => 'verified', 'operational_status' => 'open']);
        $this->getJson('/api/v1/map/locations')->assertOk()->assertJsonFragment([
            'source_id' => $msme->id, 'category' => 'Transport',
            'source_category_id' => $final->id, 'source_category_slug' => 'transport',
        ]);
    }

    public function test_activity_log_snapshots_role_and_admin_endpoint_filters_and_paginates(): void
    {
        $lgu = $this->user('audit-lgu', 'lgu_staff');
        $admin = $this->user('audit-admin', 'admin');
        $tourist = $this->user('audit-tourist', 'tourist');

        ActivityLog::create([
            'user_id' => $lgu->id, 'action' => 'Tourist Spot published',
            'details' => json_encode(['target_type' => 'tourist_spot', 'target_id' => 'spot-100', 'token' => 'never-store']),
        ]);
        $lgu->update(['role_id' => $this->roles['admin']->id]);
        Profile::whereKey($lgu->id)->update(['role_id' => $this->roles['admin']->id]);

        $log = ActivityLog::firstOrFail();
        $this->assertSame('lgu_staff', $log->actor_role);
        $this->assertSame('tourist_spot_published', $log->action_type);
        $this->assertSame('tourist_spot', $log->target_type);
        $this->assertArrayNotHasKey('token', $log->metadata);

        Sanctum::actingAs($tourist);
        $this->getJson('/api/v1/admin/activity-logs')->assertForbidden();
        Sanctum::actingAs($admin);
        $this->getJson('/api/v1/admin/activity-logs?role=lgu_staff&action=tourist_spot_published&per_page=10')
            ->assertOk()->assertJsonPath('data.total', 1)
            ->assertJsonPath('data.data.0.actor_role', 'lgu_staff')
            ->assertJsonPath('data.data.0.target_id', 'spot-100');
        $this->getJson('/api/v1/admin/activity-logs?date_from=2026-10-10&date_to=2026-01-01')
            ->assertUnprocessable();
    }

    public function test_profile_preferences_are_owner_only_validated_and_not_duplicated_into_business_data(): void
    {
        $owner = $this->user('profile-owner', 'tourist');
        $other = $this->user('profile-other', 'tourist');
        $admin = $this->user('profile-admin', 'admin');
        $spotCategoryId = SpotCategory::query()->value('id');

        Sanctum::actingAs($owner);
        $this->putJson("/api/v1/users/{$owner->id}", [
            'name' => 'Profile Owner', 'phone' => '+63 917 000 0000',
            'address' => 'Tubigon, Bohol', 'barangay' => 'Poblacion', 'language' => 'ceb',
            'preferences' => [
                'personalization_enabled' => true,
                'preferred_destination_category_ids' => $spotCategoryId ? [$spotCategoryId] : [],
                'travel_interests' => ['nature', 'food'], 'travel_pace' => 'balanced',
                'nearby_suggestions' => true, 'wheelchair_friendly' => true,
                'reservation_updates' => false, 'location_recommendations' => false,
            ],
        ])->assertOk()->assertJsonPath('data.preferences.personalization_enabled', true)
            ->assertJsonPath('data.address', 'Tubigon, Bohol');
        $this->assertDatabaseHas('profiles', ['id' => $owner->id, 'barangay' => 'Poblacion']);
        $this->assertDatabaseHas('user_preferences', ['user_id' => $owner->id, 'nearby_suggestions' => true]);
        $this->assertDatabaseHas('activity_logs', ['user_id' => $owner->id, 'action' => 'Profile updated']);
        Notification::create([
            'user_id' => $owner->id, 'type' => 'reservation_confirmed',
            'title' => 'Reservation confirmed', 'body' => 'This should be suppressed.', 'is_read' => false,
        ]);
        Notification::create([
            'user_id' => $owner->id, 'type' => 'security_notice',
            'title' => 'Security notice', 'body' => 'Security notices are never suppressed.', 'is_read' => false,
        ]);
        $this->assertDatabaseMissing('notifications', ['user_id' => $owner->id, 'type' => 'reservation_confirmed']);
        $this->assertDatabaseHas('notifications', ['user_id' => $owner->id, 'type' => 'security_notice']);

        $this->putJson("/api/v1/users/{$owner->id}", ['phone' => 'not-a-phone'])->assertUnprocessable();
        Sanctum::actingAs($other);
        $this->getJson("/api/v1/users/{$owner->id}")->assertForbidden();
        Sanctum::actingAs($admin);
        $response = $this->getJson("/api/v1/users/{$owner->id}")->assertOk();
        $this->assertArrayNotHasKey('preferences', $response->json('data'));
        $this->putJson("/api/v1/users/{$owner->id}", ['preferences' => ['nearby_suggestions' => false]])
            ->assertForbidden();
    }

    private function user(string $prefix, string $role): User
    {
        $user = User::create([
            'name' => ucfirst($prefix), 'email' => "$prefix@example.test", 'password' => 'Password123!',
            'role_id' => $this->roles[$role]->id, 'is_verified' => true, 'auth_provider' => 'email',
        ]);
        Profile::create([
            'id' => $user->id, 'name' => $user->name, 'email' => $user->email,
            'role_id' => $user->role_id, 'is_verified' => true, 'language' => 'en',
        ]);

        return $user->load('role');
    }
}
