<?php

namespace Tests\Feature;

use App\Models\Profile;
use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class WasteReportFlowTest extends TestCase
{
    private Role $touristRole;
    private Role $lguRole;

    protected function setUp(): void
    {
        parent::setUp();
        $this->createSchema();
        $this->touristRole = Role::create(['name' => 'tourist']);
        $this->lguRole = Role::create(['name' => 'lgu_staff']);
        Role::create(['name' => 'admin']);
    }

    public function test_report_is_backend_persisted_for_authenticated_tourist_and_visible_to_lgu(): void
    {
        $owner = $this->user('owner', $this->touristRole);
        $other = $this->user('other', $this->touristRole);
        $lgu = $this->user('lgu', $this->lguRole);

        Sanctum::actingAs($owner);
        $response = $this->postJson('/api/v1/waste-reports', [
            'user_id' => $other->id,
            'category' => 'garbage',
            'description' => 'Plastic waste has accumulated beside the public walkway.',
            'location_description' => 'Near Tubigon port',
            'latitude' => 9.9515,
            'longitude' => 123.9618,
            'status' => 'resolved',
            'priority' => 'urgent',
        ])->assertCreated()
            ->assertJsonPath('data.user_id', $owner->id)
            ->assertJsonPath('data.status', 'submitted')
            ->assertJsonPath('data.priority', 'normal');
        $reportId = $response->json('data.id');

        $this->assertDatabaseHas('waste_reports', [
            'id' => $reportId,
            'user_id' => $owner->id,
            'category' => 'garbage',
            'status' => 'submitted',
        ]);
        $this->assertDatabaseHas('notifications', [
            'user_id' => $lgu->id,
            'type' => 'waste_report_submitted',
        ]);

        Sanctum::actingAs($other);
        $this->getJson('/api/v1/waste-reports')->assertOk()->assertJsonCount(0, 'data');
        $this->getJson("/api/v1/waste-reports/{$reportId}")->assertNotFound();

        Sanctum::actingAs($lgu);
        $this->getJson('/api/v1/waste-reports')
            ->assertOk()->assertJsonFragment(['id' => $reportId]);
        $this->putJson("/api/v1/lgu/waste-reports/{$reportId}/status", [
            'status' => 'under_review',
            'notes' => 'Inspection assigned.',
        ])->assertOk();
        $this->assertDatabaseHas('waste_reports', [
            'id' => $reportId,
            'status' => 'under_review',
        ]);
    }

    public function test_waste_report_writes_require_auth_tourist_role_and_tubigon_coordinates(): void
    {
        $payload = [
            'category' => 'garbage',
            'description' => 'A sufficiently detailed waste report description.',
            'latitude' => 9.9515,
            'longitude' => 123.9618,
        ];
        $this->postJson('/api/v1/waste-reports', $payload)->assertUnauthorized();

        Sanctum::actingAs($this->user('lgu-writer', $this->lguRole));
        $this->postJson('/api/v1/waste-reports', $payload)->assertForbidden();

        Sanctum::actingAs($this->user('tourist-writer', $this->touristRole));
        $this->postJson('/api/v1/waste-reports', [
            ...$payload,
            'latitude' => 10.3157,
            'longitude' => 123.8854,
        ])->assertUnprocessable();
        $this->assertDatabaseCount('waste_reports', 0);
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
        Profile::create([
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'role_id' => $role->id,
            'is_verified' => true,
        ]);
        return $user;
    }

    private function createSchema(): void
    {
        foreach (['personal_access_tokens', 'activity_logs', 'notifications', 'waste_reports', 'profiles', 'users', 'roles'] as $table) {
            Schema::dropIfExists($table);
        }
        Schema::create('roles', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->string('name')->unique(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('users', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->string('name'); $table->string('email')->unique(); $table->string('password'); $table->uuid('role_id'); $table->boolean('is_verified')->default(false); $table->rememberToken(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('profiles', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->string('name'); $table->string('email'); $table->uuid('role_id'); $table->boolean('is_verified')->default(false); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('waste_reports', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->uuid('user_id'); $table->string('category'); $table->text('description'); $table->text('location_description')->nullable(); $table->decimal('latitude', 10, 7); $table->decimal('longitude', 10, 7); $table->json('images')->nullable(); $table->string('status')->default('submitted'); $table->string('priority')->default('normal'); $table->uuid('assigned_to')->nullable(); $table->string('assigned_personnel')->nullable(); $table->timestamp('assigned_at')->nullable(); $table->text('lgu_notes')->nullable(); $table->json('resolution_evidence')->nullable(); $table->timestamp('reviewed_at')->nullable(); $table->timestamp('resolved_at')->nullable(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('notifications', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->uuid('user_id'); $table->string('type'); $table->string('title'); $table->text('body'); $table->json('data')->nullable(); $table->boolean('is_read')->default(false); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('activity_logs', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->uuid('user_id')->nullable(); $table->string('action'); $table->text('details')->nullable(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('personal_access_tokens', function (Blueprint $table): void {
            $table->id(); $table->string('tokenable_type'); $table->uuid('tokenable_id'); $table->string('name'); $table->string('token', 64)->unique(); $table->text('abilities')->nullable(); $table->timestamp('last_used_at')->nullable(); $table->timestamp('expires_at')->nullable(); $table->timestamps();
        });
    }
}
