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
            'notes' => 'INTERNAL-ONLY-NOTE',
        ]);
        $this->contact(['name' => 'Unverified Hotline']);
        $this->contact(['name' => 'Inactive Fire', 'is_active' => false]);
        $archived = $this->contact(['name' => 'Archived Medical']);
        $archived->delete();

        $response = $this->getJson('/api/v1/emergency-contacts')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $active->id)
            ->assertJsonPath('data.0.is_verified', true)
            ->assertJsonMissing(['notes' => 'INTERNAL-ONLY-NOTE'])
            ->assertJsonMissingPath('data.0.updated_by');
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
            'name' => ' ',
        ]))->assertUnprocessable()
            ->assertJsonValidationErrors('name');

        $this->postJson('/api/v1/lgu/emergency-contacts', $this->payload([
            'latitude' => 9.9515,
        ]))->assertUnprocessable()
            ->assertJsonValidationErrors(['latitude', 'longitude']);
    }

    public function test_initial_directory_seed_is_idempotent_and_publishes_only_officially_sourced_records(): void
    {
        $seeder = new EmergencyContactSeeder;
        $seeder->run();
        $seeder->run();

        $official = [
            ['Tubigon Police', null, '0998-598-6445', 10],
            ['Bureau of Fire', null, '0963-774-5972', 20],
            ['Control Smart', null, '0930-785-0653', 30],
            ['Waterworks', null, '0966-749-6659', 40],
            ['TERSSU', 'Smart', '0930-785-0655', 50],
            ['TERSSU', 'Globe', '0927-454-5496', 60],
            ['MSWDO', null, '0912-887-7120', 70],
            ['Coast Guard', null, '0927-429-7581', 80],
        ];

        $this->assertDatabaseCount('emergency_contacts', 8);
        $this->assertSame(8, EmergencyContact::where('is_active', true)->count());
        $this->assertSame(8, EmergencyContact::where('is_verified', true)->count());
        foreach ($official as [$name, $label, $phone, $order]) {
            $this->assertDatabaseHas('emergency_contacts', [
                'name' => $name,
                'contact_label' => $label,
                'phone' => $phone,
                'display_order' => $order,
                'is_active' => true,
                'is_public' => true,
                'verification_status' => 'verified',
            ]);
        }
        $this->getJson('/api/v1/emergency-contacts')
            ->assertOk()
            ->assertJsonCount(8, 'data')
            ->assertJsonPath('data.0.agency_name', 'Tubigon Police')
            ->assertJsonPath('data.0.phone_number', '0998-598-6445')
            ->assertJsonPath('data.4.contact_label', 'Smart')
            ->assertJsonPath('data.5.contact_label', 'Globe')
            ->assertJsonPath('data.7.name', 'Coast Guard');
    }

    public function test_stale_management_write_returns_conflict_with_current_record(): void
    {
        Sanctum::actingAs($this->user($this->lguRole));
        $created = $this->postJson('/api/v1/lgu/emergency-contacts', $this->payload())
            ->assertCreated()
            ->json('data');

        EmergencyContact::whereKey($created['id'])->update(['updated_at' => now()->addMinute()]);

        $this->putJson("/api/v1/lgu/emergency-contacts/{$created['id']}", [
            'phone' => '0999-111-2222',
            'expected_updated_at' => $created['updated_at'],
        ])->assertConflict()
            ->assertJsonPath('code', 'stale_record')
            ->assertJsonPath('current.id', $created['id']);
    }

    public function test_duplicate_agency_label_and_phone_is_rejected(): void
    {
        Sanctum::actingAs($this->user($this->lguRole));
        $this->postJson('/api/v1/lgu/emergency-contacts', $this->payload())
            ->assertCreated();
        $this->postJson('/api/v1/lgu/emergency-contacts', $this->payload())
            ->assertUnprocessable();
    }

    public function test_seed_preserves_unrelated_records_and_only_deactivates_confirmed_legacy_seed(): void
    {
        $unrelated = $this->contact([
            'name' => 'Barangay Volunteer Hotline',
            'phone' => '0912-000-0000',
            'source_url' => 'https://example.gov.test/volunteer',
            'is_verified' => true,
        ]);
        $legacy = $this->contact([
            'name' => 'Tubigon Municipal Police Station',
            'phone' => '(038) 510-6094',
            'source_url' => 'https://itms.pnp.gov.ph/wp-content/uploads/2025/04/PRO-7.pdf',
            'is_verified' => true,
        ]);

        (new EmergencyContactSeeder)->run();

        $this->assertTrue($unrelated->fresh()->is_active);
        $this->assertTrue($unrelated->fresh()->is_verified);
        $this->assertFalse($legacy->fresh()->is_active);
        $this->assertFalse($legacy->fresh()->is_public);
        $this->assertSame('inactive', $legacy->fresh()->verification_status);
        $this->assertDatabaseHas('emergency_contacts', [
            'name' => 'Tubigon Police',
            'phone' => '0998-598-6445',
            'is_active' => true,
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
            'is_public' => true,
            'source' => 'Official test directory',
            'source_name' => 'Official test directory',
            'source_url' => 'https://example.gov.test/emergency',
        ], $overrides);
    }

    /** @param array<string, mixed> $overrides */
    private function contact(array $overrides = []): EmergencyContact
    {
        $values = array_merge($this->payload(), $overrides);
        $values['verification_status'] ??= ! ($values['is_active'] ?? true)
            ? 'inactive'
            : (($values['is_verified'] ?? false) ? 'verified' : 'draft');

        return EmergencyContact::create($values);
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
            $table->string('contact_label')->nullable();
            $table->unsignedInteger('display_order')->default(100);
            $table->string('category');
            $table->string('phone');
            $table->string('alternative_phone')->nullable();
            $table->text('address')->nullable();
            $table->string('barangay')->nullable();
            $table->text('description')->nullable();
            $table->string('operating_hours')->nullable();
            $table->text('availability_notes')->nullable();
            $table->text('emergency_instructions')->nullable();
            $table->string('classification')->default('emergency');
            $table->boolean('is_active')->default(true);
            $table->boolean('is_verified')->default(false);
            $table->boolean('is_public')->default(false);
            $table->string('verification_status')->default('draft');
            $table->string('source')->nullable();
            $table->string('source_name')->nullable();
            $table->text('source_url')->nullable();
            $table->text('notes')->nullable();
            $table->uuid('verified_by')->nullable();
            $table->timestamp('verified_at')->nullable();
            $table->timestamp('last_verified_at')->nullable();
            $table->uuid('created_by')->nullable();
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
