<?php

namespace Database\Seeders;

use App\Models\FerrySchedule;
use Illuminate\Database\Seeder;

class FerryScheduleSeeder extends Seeder
{
    /**
     * Initial recurring Cebu-to-Tubigon departures published by Lite Ferries.
     * Source checked 2026-08-26: https://liteferries.com.ph/schedule/schedule.php/schedule
     * Fares are intentionally null because the official schedule result does
     * not publish a fare. Travelers should confirm operational changes with
     * the operator before departure.
     */
    public function run(): void
    {
        $daily = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        $mondayToSaturday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        $schedules = [
            ['departure_time' => '12:30 AM', 'arrival_time' => '03:30 AM', 'days_of_week' => $daily],
            ['departure_time' => '01:00 AM', 'arrival_time' => '03:00 AM', 'days_of_week' => $mondayToSaturday],
            ['departure_time' => '07:00 AM', 'arrival_time' => '09:00 AM', 'days_of_week' => $daily],
            ['departure_time' => '10:30 AM', 'arrival_time' => '01:30 PM', 'days_of_week' => $daily],
            ['departure_time' => '01:00 PM', 'arrival_time' => '03:00 PM', 'days_of_week' => $daily],
            ['departure_time' => '05:30 PM', 'arrival_time' => '08:30 PM', 'days_of_week' => $daily],
            ['departure_time' => '07:00 PM', 'arrival_time' => '09:00 PM', 'days_of_week' => $daily],
        ];

        foreach ($schedules as $schedule) {
            FerrySchedule::firstOrCreate(
                [
                    'operator' => 'Lite Ferries',
                    'route' => 'Cebu City → Tubigon',
                    'departure_time' => $schedule['departure_time'],
                ],
                $schedule + [
                    'operator' => 'Lite Ferries',
                    'route' => 'Cebu City → Tubigon',
                    'fare' => null,
                    'status' => 'scheduled',
                    'is_active' => true,
                    'is_published' => true,
                    'published_at' => now(),
                ],
            );
        }
    }
}
