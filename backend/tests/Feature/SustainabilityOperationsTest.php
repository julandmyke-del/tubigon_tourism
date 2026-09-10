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

class SustainabilityOperationsTest extends TestCase
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

    public function test_lgu_manages_validated_ferry_schedules_and_public_only_sees_active_service(): void
    {
        $lgu = $this->user('ferry-lgu', $this->lguRole);
        Sanctum::actingAs($lgu);

        $response = $this->postJson('/api/v1/lgu/ferry-schedules', [
            'operator' => 'Tubigon Ferry Cooperative',
            'origin' => 'Tubigon Port',
            'destination' => 'Cebu Pier 1',
            'vessel_name' => 'MV Bohol Star',
            'departure_date' => today()->addDay()->toDateString(),
            'departure_time' => '7:30 PM',
            'arrival_time' => '21:00',
            'fare' => 450,
            'days_of_week' => ['Mon', 'Wednesday'],
            'status' => 'scheduled',
            'advisory' => 'Check in at least 45 minutes before departure.',
            'contact_information' => '+63 900 000 0000',
            'reference_url' => 'https://example.test/ferry-advisory',
            'is_active' => true,
        ])->assertCreated()
            ->assertJsonPath('data.route', 'Tubigon Port to Cebu Pier 1')
            ->assertJsonPath('data.departure_time', '19:30')
            ->assertJsonPath('data.days_of_week.0', 'monday')
            ->assertJsonPath('data.updated_by', $lgu->id);

        $scheduleId = $response->json('data.id');
        $this->getJson('/api/v1/ferry-schedules')
            ->assertOk()->assertJsonFragment(['id' => $scheduleId]);
        $this->assertDatabaseHas('activity_logs', [
            'user_id' => $lgu->id,
            'action' => 'Ferry schedule created',
        ]);

        $this->putJson("/api/v1/lgu/ferry-schedules/{$scheduleId}", [
            'is_active' => false,
        ])->assertOk()->assertJsonPath('data.is_active', false);
        $this->getJson('/api/v1/ferry-schedules')->assertOk()->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/lgu/ferry-schedules')
            ->assertOk()->assertJsonFragment(['id' => $scheduleId]);

        $this->postJson('/api/v1/lgu/ferry-schedules', [
            'operator' => 'Invalid Time Ferry',
            'route' => 'Tubigon to Cebu',
            'departure_time' => '13:00 PM',
        ])->assertUnprocessable()->assertJsonValidationErrors('departure_time');

        Sanctum::actingAs($this->user('ferry-tourist', $this->touristRole));
        $this->postJson('/api/v1/lgu/ferry-schedules', [
            'operator' => 'Unauthorized Ferry',
            'route' => 'Tubigon to Cebu',
            'departure_time' => '08:00',
        ])->assertForbidden();
    }

    public function test_eco_tip_publication_window_controls_public_visibility(): void
    {
        $lgu = $this->user('eco-lgu', $this->lguRole);
        Sanctum::actingAs($lgu);

        $response = $this->postJson('/api/v1/lgu/eco-tips', [
            'title' => 'Refill before you leave town',
            'short_message' => 'Bring a reusable bottle.',
            'content' => 'Use a refill station before visiting coastal and marine destinations.',
            'category' => 'resources',
            'language' => 'en',
            'priority' => 80,
            'is_active' => true,
            'is_published' => false,
        ])->assertCreated()
            ->assertJsonPath('data.created_by', $lgu->id)
            ->assertJsonPath('data.is_published', false);
        $tipId = $response->json('data.id');

        $this->getJson('/api/v1/eco-tips')->assertOk()->assertJsonCount(0, 'data');

        $this->putJson("/api/v1/lgu/eco-tips/{$tipId}", [
            'is_published' => true,
            'starts_at' => now()->subHour()->toIso8601String(),
            'ends_at' => now()->addDay()->toIso8601String(),
        ])->assertOk()->assertJsonPath('data.is_published', true);
        $this->getJson('/api/v1/eco-tips')
            ->assertOk()->assertJsonFragment(['id' => $tipId]);

        $this->putJson("/api/v1/lgu/eco-tips/{$tipId}", [
            'starts_at' => now()->addDays(2)->toIso8601String(),
            'ends_at' => now()->addDay()->toIso8601String(),
        ])->assertUnprocessable()->assertJsonValidationErrors('ends_at');

        $this->deleteJson("/api/v1/lgu/eco-tips/{$tipId}")->assertOk();
        $this->getJson('/api/v1/eco-tips')->assertOk()->assertJsonCount(0, 'data');
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
        foreach (['personal_access_tokens', 'activity_logs', 'eco_tips', 'ferry_schedules', 'tourist_spots', 'profiles', 'users', 'roles'] as $table) {
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
        Schema::create('tourist_spots', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->string('name'); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('ferry_schedules', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->string('operator'); $table->string('route'); $table->string('origin')->nullable(); $table->string('destination')->nullable(); $table->string('vessel_name')->nullable(); $table->date('departure_date')->nullable(); $table->string('departure_time'); $table->string('arrival_time')->nullable(); $table->decimal('fare', 10, 2)->nullable(); $table->string('status')->default('scheduled'); $table->json('days_of_week')->nullable(); $table->text('advisory')->nullable(); $table->string('contact_information')->nullable(); $table->text('reference_url')->nullable(); $table->boolean('is_active')->default(true); $table->uuid('updated_by')->nullable(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('eco_tips', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->string('title'); $table->string('short_message', 500)->nullable(); $table->text('content'); $table->string('category')->nullable(); $table->uuid('spot_id')->nullable(); $table->string('language')->default('en'); $table->boolean('is_active')->default(true); $table->boolean('is_published')->default(false); $table->timestamp('starts_at')->nullable(); $table->timestamp('ends_at')->nullable(); $table->unsignedInteger('priority')->default(0); $table->uuid('created_by')->nullable(); $table->uuid('updated_by')->nullable(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('activity_logs', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->uuid('user_id')->nullable(); $table->string('action'); $table->text('details')->nullable(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('personal_access_tokens', function (Blueprint $table): void {
            $table->id(); $table->string('tokenable_type'); $table->uuid('tokenable_id'); $table->string('name'); $table->string('token', 64)->unique(); $table->text('abilities')->nullable(); $table->timestamp('last_used_at')->nullable(); $table->timestamp('expires_at')->nullable(); $table->timestamps();
        });
    }
}
