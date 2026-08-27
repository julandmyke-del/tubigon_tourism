<?php

namespace Tests\Feature;

use App\Models\EmergencyContact;
use App\Models\Role;
use App\Models\User;
use Database\Seeders\EmergencyContactSeeder;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class EmergencyContactManagementTest extends TestCase
{
    private Role $touristRole;

    private Role $lguRole;

    private Role $adminRole;

    protected function setUp(): void
    {
        parent::setUp();
        $this->createSchema();
        $this->touristRole = Role::create(['name' => 'tourist']);
        $this->lguRole = Role::create(['name' => 'lgu_staff']);
        $this->adminRole = Role::create(['name' => 'admin']);
    }

    public function test_public_directory_returns_only_active_verified_non_archived_contacts(): void
    {
        $active = $this->contact([
            'name' => 'Active Police',
            'is_verified' => true,
        ]);
        $this->contact(['name' => 'Unverified Hotline']);
        $this->contact(['name' => 'Inactive Fire', 'is_active' => false]);
        $archived = $this->contact(['name' => 'Archived Medical']);
        $archived->delete();

        $response = $this->getJson('/api/v1/emergency-contacts')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $active->id)
            ->assertJsonPath('data.0.is_verified', true);
        $this->assertStringContainsString(
            'no-store',
            (string) $response->headers->get('Cache-Control')
        );
    }

    public function test_tourists_and_guests_cannot_modify_contacts(): void
    {
        $payload = $this->payload();

        $this->postJson('/api/v1/lgu/emergency-contacts', $payload)
            ->assertUnauthorized();

        Sanctum::actingAs($this->user($this->touristRole));
        $this->postJson('/api/v1/lgu/emergency-contacts', $payload)
            ->assertForbidden();

        $this->assertDatabaseCount('emergency_contacts', 0);
    }

    public function test_lgu_can_manage_verify_deactivate_and_archive_with_audit_history(): void
    {
        $lgu = $this->user($this->lguRole);
        Sanctum::actingAs($lgu);

        $created = $this->postJson('/api/v1/lgu/emergency-contacts', $this->payload())
            ->assertCreated()
            ->assertJsonPath('data.is_verified', false)
            ->assertJsonPath('data.is_active', true)
            ->json('data');
        $id = $created['id'];

        $this->assertDatabaseHas('emergency_contacts', [
            'id' => $id,
            'updated_by' => $lgu->id,
            'is_verified' => false,
        ]);
        $this->assertDatabaseHas('emergency_contact_audits', [
            'contact_id' => $id,
            'action' => 'created',
            'updated_by' => $lgu->id,
        ]);

        $this->patchJson("/api/v1/lgu/emergency-contacts/$id/verify")
            ->assertOk()
            ->assertJsonPath('data.is_verified', true)
            ->assertJsonPath('data.verifier.id', $lgu->id);
        $this->assertDatabaseHas('emergency_contact_audits', [
            'contact_id' => $id,
            'action' => 'verified',
        ]);

        $this->putJson("/api/v1/lgu/emergency-contacts/$id", [
            'phone' => '0999-123-4567',
        ])->assertOk()
            ->assertJsonPath('data.phone', '0999-123-4567')
            ->assertJsonPath('data.is_verified', false)
            ->assertJsonPath('data.verified_by', null);

        $audit = Schema::getConnection()->table('emergency_contact_audits')
            ->where('contact_id', $id)
            ->where('action', 'updated')
            ->first();
        $this->assertNotNull($audit);
        $this->assertSame('(038) 510-6094', json_decode($audit->old_value, true)['phone']);
        $this->assertSame('0999-123-4567', json_decode($audit->new_value, true)['phone']);

        $this->patchJson("/api/v1/lgu/emergency-contacts/$id/status", [
            'is_active' => false,
        ])->assertOk()->assertJsonPath('data.is_active', false);
        $this->getJson('/api/v1/emergency-contacts')
            ->assertOk()->assertJsonCount(0, 'data');

        $this->patchJson("/api/v1/lgu/emergency-contacts/$id/status", [
            'is_active' => true,
        ])->assertOk()->assertJsonPath('data.is_active', true);
        $this->getJson('/api/v1/emergency-contacts')
            ->assertOk()->assertJsonCount(0, 'data');

        $this->deleteJson("/api/v1/lgu/emergency-contacts/$id")
            ->assertOk()
            ->assertJsonPath(
                'message',
                'Emergency contact archived. No record was permanently deleted.'
            );
        $this->assertSoftDeleted('emergency_contacts', ['id' => $id]);
        $this->assertDatabaseHas('emergency_contact_audits', [
            'contact_id' => $id,
            'action' => 'archived',
            'updated_by' => $lgu->id,
        ]);
        $this->assertDatabaseCount('emergency_contact_audits', 6);
    }

    public function test_admin_uses_existing_admin_scope_to_manage_contacts(): void
    {
        Sanctum::actingAs($this->user($this->adminRole));

        $id = $this->postJson('/api/v1/admin/emergency-contacts', $this->payload([
            'name' => 'Admin Created Contact',
        ]))->assertCreated()->json('data.id');

        $this->getJson('/api/v1/admin/emergency-contacts')
            ->assertOk()
            ->assertJsonPath('data.0.id', $id);
        $this->patchJson("/api/v1/admin/emergency-contacts/$id/verify")
            ->assertOk()->assertJsonPath('data.is_verified', true);
    }

    public function test_validation_requires_paired_tubigon_coordinates_and_safe_phone_values(): void
    {
        Sanctum::actingAs($this->user($this->lguRole));

        $this->postJson('/api/v1/lgu/emergency-contacts', $this->payload([
            'phone' => 'call-me-now',
        ]))->assertUnprocessable()
            ->assertJsonValidationErrors('phone');

        $this->postJson('/api/v1/lgu/emergency-contacts', $this->payload([
            'latitude' => 9.9515,
        ]))->assertUnprocessable()
            ->assertJsonValidationErrors(['latitude', 'longitude']);
    }

    public function test_initial_directory_seed_is_idempotent_and_requires_lgu_verification(): void
    {
        $seeder = new EmergencyContactSeeder;
        $seeder->run();
        $seeder->run();

        $this->assertDatabaseCount('emergency_contacts', 6);
        $this->assertSame(6, EmergencyContact::where('is_active', true)->count());
        $this->assertSame(0, EmergencyContact::where('is_verified', true)->count());
        $this->assertDatabaseHas('emergency_contacts', [
            'name' => 'Emergency Hotline',
            'phone' => '911',
            'category' => 'National Emergency Hotline',
        ]);
    }

    /** @param array<string, mixed> $overrides */
    private function payload(array $overrides = []): array
    {
        return array_merge([
            'name' => 'Tubigon Municipal Police Station',
            'category' => 'Police',
            'phone' => '(038) 510-6094',
            'alternative_phone' => '0998-598-6445',
            'address' => 'Tubigon, Bohol',
            'description' => 'Call for police emergencies.',
            'operating_hours' => '24/7',
            'classification' => 'emergency',
            'is_active' => true,
        ], $overrides);
    }

    /** @param array<string, mixed> $overrides */
    private function contact(array $overrides = []): EmergencyContact
    {
        return EmergencyContact::create(array_merge($this->payload(), $overrides));
    }

    private function user(Role $role): User
    {
        return User::create([
            'name' => $role->name === 'lgu_staff' ? 'LGU Staff' : ucfirst($role->name),
            'email' => $role->name.'@example.test',
            'password' => 'safe-password',
            'role_id' => $role->id,
            'is_verified' => true,
        ]);
    }

    private function createSchema(): void
    {
        foreach (['emergency_contact_audits', 'emergency_contacts', 'users', 'roles'] as $table) {
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
        Schema::create('emergency_contacts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->unsignedInteger('integer_id')->nullable()->unique();
            $table->string('name');
            $table->string('category');
            $table->string('phone');
            $table->string('alternative_phone')->nullable();
            $table->text('address')->nullable();
            $table->text('description')->nullable();
            $table->string('operating_hours')->nullable();
            $table->string('classification')->default('emergency');
            $table->boolean('is_active')->default(true);
            $table->boolean('is_verified')->default(false);
            $table->string('source')->nullable();
            $table->text('source_url')->nullable();
            $table->uuid('verified_by')->nullable();
            $table->timestamp('verified_at')->nullable();
            $table->timestamp('last_verified_at')->nullable();
            $table->uuid('updated_by')->nullable();
            $table->uuid('archived_by')->nullable();
            $table->double('latitude')->nullable();
            $table->double('longitude')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('emergency_contact_audits', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('contact_id');
            $table->string('action');
            $table->json('old_value')->nullable();
            $table->json('new_value')->nullable();
            $table->uuid('updated_by');
            $table->timestamps();
        });
    }
}
