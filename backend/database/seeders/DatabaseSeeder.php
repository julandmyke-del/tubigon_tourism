<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        if (app()->environment('testing')) {
            User::firstOrCreate([
                'email' => 'test@example.com',
            ], [
                'name' => 'Test User',
                'password' => \Illuminate\Support\Str::random(32),
            ]);
        }

        $this->call(MapLocationSeeder::class);
        $this->call(FeaturedDestinationSeeder::class);
        $this->call(DevelopmentFeaturedDestinationBookingSeeder::class);
        if (app()->environment(['local', 'testing'])) {
            $this->call(DevelopmentFeaturedDestinationPartnerSeeder::class);
        }
    }
}
