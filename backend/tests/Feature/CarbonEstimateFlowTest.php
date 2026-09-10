<?php

namespace Tests\Feature;

use App\Models\EmissionFactor;
use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CarbonEstimateFlowTest extends TestCase
{
    private Role $touristRole;
    private Role $lguRole;
    private EmissionFactor $car;
    private EmissionFactor $ferry;

    protected function setUp(): void
    {
        parent::setUp();
        $this->createSchema();
        $this->touristRole = Role::create(['name' => 'tourist']);
        $this->lguRole = Role::create(['name' => 'lgu_staff']);
        $this->car = $this->factor('private_car', 'Private car', .17);
        $this->ferry = $this->factor('ferry_foot', 'Ferry', .019);
        $this->factor('inactive', 'Inactive', 9, false);
    }

    public function test_public_catalog_exposes_only_effective_active_versioned_factors(): void
    {
        $this->getJson('/api/v1/carbon/factors')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonFragment([
                'transport_mode' => 'private_car',
                'version' => '2026.1',
                'source_year' => 2026,
            ])
            ->assertJsonPath('meta.method', 'distance × passenger-km factor × travelers × trip multiplier');
    }

    public function test_server_calculates_and_scopes_authenticated_history(): void
    {
        $owner = $this->user('carbon-owner', $this->touristRole);
        $other = $this->user('carbon-other', $this->touristRole);
        Sanctum::actingAs($owner);

        $id = $this->postJson('/api/v1/carbon/estimates', [
            'emission_factor_id' => $this->car->id,
            'origin_name' => 'Tubigon Port',
            'destination_name' => 'Town center',
            'origin_entity_type' => 'manual',
            'destination_entity_type' => 'manual',
            'distance_km' => 10,
            'distance_source' => 'manual',
            'travelers' => 2,
            'trip_type' => 'round_trip',
        ])->assertCreated()
            ->assertJsonPath('data.estimated_kg_co2e', 6.8)
            ->assertJsonPath('data.per_traveler_kg_co2e', 3.4)
            ->assertJsonPath('data.factor_version', '2026.1')
            ->json('data.id');

        $this->getJson('/api/v1/carbon/estimates')
            ->assertOk()->assertJsonPath('data.0.id', $id);

        Sanctum::actingAs($other);
        $this->getJson('/api/v1/carbon/estimates')
            ->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_ferry_rejects_road_distance_and_non_tourist_cannot_save(): void
    {
        $payload = [
            'emission_factor_id' => $this->ferry->id,
            'distance_km' => 12,
            'distance_source' => 'osrm',
            'travelers' => 1,
            'trip_type' => 'one_way',
        ];
        Sanctum::actingAs($this->user('ferry-tourist', $this->touristRole));
        $this->postJson('/api/v1/carbon/estimates', $payload)
            ->assertUnprocessable();

        Sanctum::actingAs($this->user('carbon-lgu', $this->lguRole));
        $this->postJson('/api/v1/carbon/estimates', [
            ...$payload,
            'emission_factor_id' => $this->car->id,
            'distance_source' => 'manual',
        ])->assertForbidden();
    }

    private function factor(string $mode, string $name, float $value, bool $active = true): EmissionFactor
    {
        return EmissionFactor::create([
            'transport_mode' => $mode,
            'display_name' => $name,
            'emission_factor' => $value,
            'unit' => 'kg_co2e_per_passenger_km',
            'occupancy_assumption' => 'Test planning assumption',
            'source_name' => 'Official test source',
            'source_year' => 2026,
            'source_url' => 'https://example.gov.test/factors',
            'version' => '2026.1',
            'is_active' => $active,
            'effective_from' => '2026-01-01',
        ]);
    }

    private function user(string $key, Role $role): User
    {
        return User::create([
            'name' => $key,
            'email' => "$key@example.test",
            'password' => Hash::make('safe-password'),
            'role_id' => $role->id,
            'is_verified' => true,
        ]);
    }

    private function createSchema(): void
    {
        foreach (['personal_access_tokens', 'carbon_estimates', 'emission_factors', 'itineraries', 'users', 'roles'] as $table) {
            Schema::dropIfExists($table);
        }
        Schema::create('roles', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->string('name')->unique(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('users', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->string('name'); $table->string('email')->unique(); $table->string('password'); $table->uuid('role_id'); $table->boolean('is_verified')->default(false); $table->rememberToken(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('itineraries', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->uuid('user_id'); $table->timestamps();
        });
        Schema::create('emission_factors', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->string('transport_mode'); $table->string('display_name'); $table->decimal('emission_factor', 12, 6); $table->string('unit'); $table->string('occupancy_assumption')->nullable(); $table->string('source_name'); $table->unsignedSmallInteger('source_year'); $table->text('source_url'); $table->string('version'); $table->text('notes')->nullable(); $table->boolean('is_active')->default(true); $table->date('effective_from')->nullable(); $table->date('effective_to')->nullable(); $table->timestamps();
        });
        Schema::create('carbon_estimates', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->uuid('user_id'); $table->uuid('emission_factor_id'); $table->string('origin_name')->nullable(); $table->string('destination_name')->nullable(); $table->string('origin_entity_type')->nullable(); $table->uuid('origin_entity_id')->nullable(); $table->string('destination_entity_type')->nullable(); $table->uuid('destination_entity_id')->nullable(); $table->decimal('distance_km', 12, 3); $table->string('distance_source'); $table->timestamp('route_calculated_at')->nullable(); $table->unsignedSmallInteger('travelers'); $table->string('trip_type'); $table->decimal('estimated_kg_co2e', 14, 4); $table->decimal('per_traveler_kg_co2e', 14, 4); $table->string('factor_version'); $table->string('factor_unit'); $table->uuid('itinerary_id')->nullable(); $table->json('leg_breakdown')->nullable(); $table->timestamps();
        });
        Schema::create('personal_access_tokens', function (Blueprint $table): void {
            $table->id(); $table->string('tokenable_type'); $table->uuid('tokenable_id'); $table->string('name'); $table->string('token', 64)->unique(); $table->text('abilities')->nullable(); $table->timestamp('last_used_at')->nullable(); $table->timestamp('expires_at')->nullable(); $table->timestamps();
        });
    }
}
