<?php

namespace Database\Seeders;

use App\Models\FerryOperator;
use App\Models\FerryPort;
use App\Models\FerryRoute;
use App\Models\FerrySchedule;
use App\Models\FerryVessel;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class FerryScheduleSeeder extends Seeder
{
    public function run(): void
    {
        DB::transaction(function (): void {
            [$cebuToTubigon, $tubigonToCebu] = $this->routes();

            $lite = $this->operator('Lite Ferries');
            $fastCat = $this->operator('FastCat');
            $starcraft = $this->operator('MV Starcraft');

            $lite17 = $this->vessel($lite, 'Lite Ferry 17');
            $sc2 = $this->vessel($starcraft, 'SC 2');
            $sc9 = $this->vessel($starcraft, 'SC 9');

            $this->deactivateLegacyLiteSeederRows();

            foreach (['00:30', '10:30', '17:30'] as $departure) {
                $this->schedule($lite, $lite17, $cebuToTubigon, $departure, [
                    'valid_from' => '2026-08-15',
                    'source_reference' => 'User-provided Lite Ferry 17 updated sailing schedule, effective August 15, 2026.',
                ]);
            }
            foreach (['07:00', '14:00', '21:00'] as $departure) {
                $this->schedule($lite, $lite17, $tubigonToCebu, $departure, [
                    'valid_from' => '2026-08-15',
                    'source_reference' => 'User-provided Lite Ferry 17 updated sailing schedule, effective August 15, 2026.',
                ]);
            }

            foreach ([
                ['01:30', '03:30', false],
                ['07:30', '09:30', false],
                ['13:30', '15:30', false],
                ['20:00', '22:00', false],
            ] as [$departure, $arrival, $nextDay]) {
                $this->schedule($fastCat, null, $cebuToTubigon, $departure, [
                    'arrival_time' => $arrival,
                    'arrival_next_day' => $nextDay,
                    'source_reference' => 'User-provided FastCat schedule images.',
                ]);
            }
            foreach ([
                ['05:00', '07:00', false],
                ['10:30', '12:30', false],
                ['17:30', '19:30', false],
                ['22:30', '00:30', true],
            ] as [$departure, $arrival, $nextDay]) {
                $this->schedule($fastCat, null, $tubigonToCebu, $departure, [
                    'arrival_time' => $arrival,
                    'arrival_next_day' => $nextDay,
                    'source_reference' => 'User-provided FastCat schedule images.',
                ]);
            }

            foreach ([
                ['06:30', $sc2], ['09:45', $sc9], ['12:30', $sc2],
                ['15:00', $sc9], ['17:00', $sc2], ['18:45', $sc9],
            ] as [$departure, $vessel]) {
                $this->schedule($starcraft, $vessel, $cebuToTubigon, $departure, [
                    'departure_date' => '2026-08-19',
                    'source_reference' => 'User-provided MV Starcraft schedule image dated August 19, 2026.',
                ]);
            }
            foreach ([
                ['06:30', $sc9], ['09:20', $sc2], ['11:45', $sc9],
                ['15:00', $sc2], ['17:00', $sc9], ['18:45', $sc2],
            ] as [$departure, $vessel]) {
                $this->schedule($starcraft, $vessel, $tubigonToCebu, $departure, [
                    'departure_date' => '2026-08-19',
                    'source_reference' => 'User-provided MV Starcraft schedule image dated August 19, 2026.',
                ]);
            }
        });
    }

    private function operator(string $name): FerryOperator
    {
        $operator = FerryOperator::whereRaw('LOWER(name) = ?', [Str::lower($name)])->first();
        if (! $operator) {
            $operator = FerryOperator::create(['name' => $name, 'is_active' => true]);
        } elseif ($operator->name !== $name || ! $operator->is_active) {
            $operator->update(['name' => $name, 'is_active' => true]);
        }

        return $operator;
    }

    private function vessel(FerryOperator $operator, string $name): FerryVessel
    {
        $vessel = FerryVessel::where('ferry_operator_id', $operator->id)
            ->whereRaw('LOWER(vessel_name) = ?', [Str::lower($name)])->first();

        return $vessel ?: FerryVessel::create([
            'ferry_operator_id' => $operator->id,
            'vessel_name' => $name,
            'is_active' => true,
        ]);
    }

    /** @return array{FerryRoute, FerryRoute} */
    private function routes(): array
    {
        $cebu = FerryPort::firstOrCreate(['code' => 'CEBU'], [
            'name' => 'Cebu Port', 'municipality' => 'Cebu City', 'province' => 'Cebu', 'is_active' => true,
        ]);
        $tubigon = FerryPort::firstOrCreate(['code' => 'TUB'], [
            'name' => 'Tubigon Port', 'municipality' => 'Tubigon', 'province' => 'Bohol', 'is_active' => true,
        ]);
        $cebuToTubigon = FerryRoute::firstOrCreate([
            'origin_port_id' => $cebu->id, 'destination_port_id' => $tubigon->id,
        ], ['name' => 'Cebu to Tubigon', 'is_active' => true]);
        $tubigonToCebu = FerryRoute::firstOrCreate([
            'origin_port_id' => $tubigon->id, 'destination_port_id' => $cebu->id,
        ], ['name' => 'Tubigon to Cebu', 'is_active' => true]);

        return [$cebuToTubigon->load(['originPort', 'destinationPort']), $tubigonToCebu->load(['originPort', 'destinationPort'])];
    }

    private function schedule(
        FerryOperator $operator,
        ?FerryVessel $vessel,
        FerryRoute $route,
        string $departure,
        array $values,
    ): void {
        $identity = [
            'ferry_operator_id' => $operator->id,
            'ferry_vessel_id' => $vessel?->id,
            'origin' => $route->originPort->name,
            'destination' => $route->destinationPort->name,
            'departure_time' => $departure,
            'departure_date' => $values['departure_date'] ?? null,
            'valid_from' => $values['valid_from'] ?? null,
        ];
        FerrySchedule::withTrashed()->updateOrCreate($identity, $values + [
            'operator' => $operator->name,
            'vessel_name' => $vessel?->vessel_name,
            'route' => $route->name,
            'ferry_route_id' => $route->id,
            'origin_port_id' => $route->origin_port_id,
            'destination_port_id' => $route->destination_port_id,
            'arrival_time' => null,
            'arrival_next_day' => false,
            'status' => 'scheduled',
            'days_of_week' => null,
            'fare' => null,
            'is_active' => true,
            'is_published' => true,
            'published_at' => now(),
            'archived_at' => null,
            'deleted_at' => null,
        ]);
    }

    private function deactivateLegacyLiteSeederRows(): void
    {
        $legacy = [
            '12:30 AM' => '03:30 AM', '01:00 AM' => '03:00 AM',
            '07:00 AM' => '09:00 AM', '10:30 AM' => '01:30 PM',
            '01:00 PM' => '03:00 PM', '05:30 PM' => '08:30 PM',
            '07:00 PM' => '09:00 PM',
        ];
        foreach ($legacy as $departure => $arrival) {
            FerrySchedule::query()
                ->whereRaw('LOWER(operator) = ?', ['lite ferries'])
                ->where('departure_time', $departure)
                ->where('arrival_time', $arrival)
                ->whereNull('departure_date')
                ->whereNull('valid_from')
                ->whereNull('source_reference')
                ->where('route', 'like', '%Cebu City%Tubigon%')
                ->update(['is_active' => false, 'is_published' => false, 'archived_at' => now()]);
        }
    }
}
