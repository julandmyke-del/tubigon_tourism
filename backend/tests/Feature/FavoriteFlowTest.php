<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class FavoriteFlowTest extends TestCase
{
    private Role $touristRole;

    protected function setUp(): void
    {
        parent::setUp();
        $this->createSchema();
        $this->touristRole = Role::create(['name' => 'tourist']);
    }

    public function test_guest_cannot_create_or_list_favorites(): void
    {
        $this->getJson('/api/v1/favorites')->assertUnauthorized();
        $this->postJson('/api/v1/favorites/toggle', [
            'favoritable_type' => 'spot',
            'favoritable_id' => Str::uuid()->toString(),
        ])->assertUnauthorized();
    }

    public function test_tourist_can_add_and_remove_a_public_favorite_without_duplicates(): void
    {
        $user = $this->user('owner');
        $spotId = $this->spot(true);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/favorites/toggle', [
            'favoritable_type' => 'tourist_spot',
            'favoritable_id' => $spotId,
        ])->assertUnprocessable()->assertJsonValidationErrors('favoritable_type');

        $payload = ['favoritable_type' => 'spot', 'favoritable_id' => $spotId];
        $this->postJson('/api/v1/favorites/toggle', $payload)
            ->assertOk()->assertJsonPath('data.is_favorite', true);
        $this->assertDatabaseCount('favorites', 1);
        $this->getJson('/api/v1/favorites')->assertOk()->assertJsonCount(1, 'data');

        $this->postJson('/api/v1/favorites/toggle', $payload)
            ->assertOk()->assertJsonPath('data.is_favorite', false);
        $this->assertDatabaseCount('favorites', 0);
    }

    public function test_favorites_are_owner_scoped_and_unpublished_entities_are_rejected(): void
    {
        $first = $this->user('first');
        $second = $this->user('second');
        $publicSpot = $this->spot(true);
        $privateSpot = $this->spot(false);

        Sanctum::actingAs($first);
        $this->postJson('/api/v1/favorites/toggle', [
            'favoritable_type' => 'spot', 'favoritable_id' => $publicSpot,
        ])->assertOk();

        Sanctum::actingAs($second);
        $this->getJson('/api/v1/favorites')->assertOk()->assertJsonCount(0, 'data');
        $this->postJson('/api/v1/favorites/toggle', [
            'favoritable_type' => 'spot', 'favoritable_id' => $privateSpot,
        ])->assertUnprocessable()->assertJsonValidationErrors('favoritable_id');

        $this->assertDatabaseHas('favorites', ['user_id' => $first->id]);
        $this->assertDatabaseMissing('favorites', ['user_id' => $second->id]);
    }

    public function test_active_partner_drafts_and_inconsistent_msmes_cannot_be_favorited(): void
    {
        $tourist = $this->user('publication-check');
        Sanctum::actingAs($tourist);

        $draftListing = Str::uuid()->toString();
        Schema::getConnection()->table('tourism_listings')->insert([
            'id' => $draftListing,
            'is_active' => true,
            'approval_status' => 'draft',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $this->postJson('/api/v1/favorites/toggle', [
            'favoritable_type' => 'tourism_listing',
            'favoritable_id' => $draftListing,
        ])->assertUnprocessable();

        $inconsistentMsme = Str::uuid()->toString();
        Schema::getConnection()->table('msmes')->insert([
            'id' => $inconsistentMsme,
            'is_verified' => true,
            'verification_status' => 'suspended',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $this->postJson('/api/v1/favorites/toggle', [
            'favoritable_type' => 'msme',
            'favoritable_id' => $inconsistentMsme,
        ])->assertUnprocessable();
    }

    private function user(string $key): User
    {
        return User::create([
            'name' => ucfirst($key),
            'email' => "$key@example.test",
            'password' => Hash::make('safe-password'),
            'role_id' => $this->touristRole->id,
            'is_verified' => true,
        ]);
    }

    private function spot(bool $public): string
    {
        $id = Str::uuid()->toString();
        Schema::getConnection()->table('tourist_spots')->insert([
            'id' => $id,
            'name' => $public ? 'Public Spot' : 'Private Spot',
            'is_active' => $public,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        return $id;
    }

    private function createSchema(): void
    {
        foreach (['favorites', 'map_locations', 'tourism_listings', 'msmes', 'tourist_spots', 'users', 'roles'] as $table) {
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
        Schema::create('favorites', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id')->index();
            $table->string('favoritable_type');
            $table->uuid('favoritable_id');
            $table->timestamps();
            $table->softDeletes();
            $table->unique(['user_id', 'favoritable_type', 'favoritable_id']);
        });
        Schema::create('tourist_spots', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();
        });
        foreach (['msmes', 'tourism_listings'] as $tableName) {
            Schema::create($tableName, function (Blueprint $table) use ($tableName) {
                $table->uuid('id')->primary();
                $table->boolean($tableName === 'msmes' ? 'is_verified' : 'is_active')->default(true);
                if ($tableName === 'msmes') {
                    $table->string('verification_status')->default('pending');
                } else {
                    $table->string('approval_status')->default('draft');
                }
                $table->timestamps();
                $table->softDeletes();
            });
        }
        Schema::create('map_locations', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->boolean('published')->default(false);
            $table->boolean('active')->default(true);
            $table->timestamps();
            $table->softDeletes();
        });
    }
}
