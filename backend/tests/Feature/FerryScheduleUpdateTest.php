<?php

namespace Tests\Feature;

use App\Models\FerryOperator;
use App\Models\FerryRoute;
use App\Models\FerrySchedule;
use App\Models\FerryVessel;
use App\Models\Profile;
use App\Models\Role;
use App\Models\User;
use Database\Seeders\FerryScheduleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class FerryScheduleUpdateTest extends TestCase
{
    use RefreshDatabase;

    public function test_real_schedule_import_is_idempotent_and_preserves_source_semantics(): void
    {
        $this->seed(FerryScheduleSeeder::class);
        $this->seed(FerryScheduleSeeder::class);

        $this->assertSame(3, FerryOperator::count());
        $this->assertSame(3, FerryVessel::count());
        $this->assertSame(26, FerrySchedule::count());

        $lite = FerryOperator::where('name', 'Lite Ferries')->firstOrFail();
        $fastCat = FerryOperator::where('name', 'FastCat')->firstOrFail();
        $starcraft = FerryOperator::where('name', 'MV Starcraft')->firstOrFail();
        $this->assertSame(['Lite Ferry 17'], $lite->vessels()->pluck('vessel_name')->all());
        $this->assertEqualsCanonicalizing(['SC 2', 'SC 9'], $starcraft->vessels()->pluck('vessel_name')->all());

        $this->assertDatabaseHas('ferry_schedules', [
            'ferry_operator_id' => $fastCat->id,
            'origin' => 'Tubigon Port',
            'destination' => 'Cebu Port',
            'departure_time' => '22:30',
            'arrival_time' => '00:30',
            'arrival_next_day' => true,
        ]);
        $this->assertDatabaseHas('ferry_schedules', [
            'ferry_operator_id' => $lite->id,
            'valid_from' => '2026-08-15',
            'arrival_time' => null,
        ]);
        $this->assertDatabaseHas('ferry_schedules', [
            'ferry_operator_id' => $starcraft->id,
            'departure_date' => '2026-08-19',
            'arrival_time' => null,
        ]);
    }

    public function test_public_list_filters_active_operator_and_date_specific_schedules(): void
    {
        Carbon::setTestNow('2026-08-19 09:00:00');
        $this->seed(FerryScheduleSeeder::class);
        $fastCat = FerryOperator::where('name', 'FastCat')->firstOrFail();
        $lite = FerryOperator::where('name', 'Lite Ferries')->firstOrFail();

        $this->getJson('/api/v1/ferry-schedules')
            ->assertOk()
            ->assertJsonCount(26, 'data')
            ->assertJsonFragment([
                'operator_name' => 'MV Starcraft',
                'schedule_date' => '2026-08-19',
            ])
            ->assertJsonFragment([
                'operator_name' => 'FastCat',
                'arrival_time' => '00:30',
                'arrival_next_day' => true,
            ]);

        $this->getJson("/api/v1/ferry-schedules?operator_id={$lite->id}")
            ->assertOk()->assertJsonCount(6, 'data')
            ->assertJsonMissing(['operator_name' => 'FastCat']);

        FerrySchedule::where('ferry_operator_id', $fastCat->id)->firstOrFail()
            ->update(['is_active' => false]);
        $this->getJson("/api/v1/ferry-schedules?operator_id={$fastCat->id}")
            ->assertOk()->assertJsonCount(7, 'data');

        Carbon::setTestNow('2026-09-16 09:00:00');
        $this->getJson('/api/v1/ferry-schedules')
            ->assertOk()
            ->assertJsonMissing(['operator_name' => 'MV Starcraft']);
    }

    public function test_admin_manages_catalogs_lgu_manages_schedules_and_vessel_pairing_is_enforced(): void
    {
        $this->seed(FerryScheduleSeeder::class);
        $admin = $this->user('ferry-admin', 'admin');
        Sanctum::actingAs($admin);

        $operatorId = $this->postJson('/api/v1/admin/ferry-operators', [
            'name' => 'Future Ferry',
            'is_active' => true,
        ])->assertCreated()->json('data.id');
        $vesselId = $this->postJson('/api/v1/admin/ferry-vessels', [
            'ferry_operator_id' => $operatorId,
            'vessel_name' => 'FF 1',
            'is_active' => true,
        ])->assertCreated()->json('data.id');
        $this->putJson("/api/v1/admin/ferry-vessels/{$vesselId}", [
            'ferry_operator_id' => $operatorId,
            'vessel_name' => 'FF One',
            'is_active' => false,
        ])->assertOk()->assertJsonPath('data.is_active', false);

        $lgu = $this->user('ferry-lgu-update', 'lgu_staff');
        Sanctum::actingAs($lgu);
        $lite = FerryOperator::where('name', 'Lite Ferries')->firstOrFail();
        $starcraftVessel = FerryVessel::where('vessel_name', 'SC 2')->firstOrFail();
        $route = FerryRoute::firstOrFail();
        $this->postJson('/api/v1/lgu/ferry-schedules', [
            'ferry_operator_id' => $lite->id,
            'ferry_vessel_id' => $starcraftVessel->id,
            'ferry_route_id' => $route->id,
            'departure_time' => '08:00',
            'is_active' => true,
            'is_published' => true,
        ])->assertUnprocessable();

        $schedule = $this->postJson('/api/v1/lgu/ferry-schedules', [
            'ferry_operator_id' => $lite->id,
            'ferry_vessel_id' => $lite->vessels()->firstOrFail()->id,
            'ferry_route_id' => $route->id,
            'departure_time' => '08:00',
            'arrival_time' => null,
            'is_active' => true,
            'is_published' => true,
        ])->assertCreated()->assertJsonPath('data.arrival_time', null);
        $scheduleId = $schedule->json('data.id');
        $this->putJson("/api/v1/lgu/ferry-schedules/{$scheduleId}", [
            'is_active' => false,
            'expected_updated_at' => $schedule->json('data.updated_at'),
        ])->assertOk()->assertJsonPath('data.is_active', false);
        $this->putJson("/api/v1/lgu/ferry-schedules/{$scheduleId}", [
            'is_active' => true,
        ])->assertOk()->assertJsonPath('data.is_active', true);

        $tourist = $this->user('ferry-tourist-update', 'tourist');
        Sanctum::actingAs($tourist);
        $this->postJson('/api/v1/admin/ferry-operators', ['name' => 'Denied'])
            ->assertForbidden();
        $this->postJson('/api/v1/lgu/ferry-schedules', [
            'operator' => 'Denied', 'route' => 'A to B', 'departure_time' => '08:00',
        ])->assertForbidden();
    }

    private function user(string $key, string $roleName): User
    {
        $role = Role::where('name', $roleName)->firstOrFail();
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
}
