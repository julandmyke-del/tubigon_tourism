<?php

namespace Database\Seeders;

use App\Models\TouristSpot;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class DevelopmentFeaturedDestinationBookingSeeder extends Seeder
{
    public function run(): void
    {
        if (! app()->environment(['local', 'testing'])
            || ! config('tourist_spot_booking.demo_enabled')
            || ! Schema::hasColumn('tourist_spots', 'demo_booking_seeded_at')) {
            return;
        }

        $slugs = config('tourist_spot_booking.demo_slugs', []);
        if (! is_array($slugs) || $slugs === []) {
            return;
        }

        DB::transaction(function () use ($slugs): void {
            TouristSpot::query()
                ->whereIn('slug', $slugs)
                ->where('is_preapproved', true)
                ->where('is_active', true)
                ->where('is_published', true)
                ->lockForUpdate()
                ->get()
                ->each(function (TouristSpot $spot): void {
                    // Apply only once. Later LGU/Admin choices, including
                    // disabling reservations, remain authoritative.
                    if ($spot->demo_booking_seeded_at !== null) {
                        return;
                    }

                    $spot->forceFill([
                        'is_bookable' => true,
                        'booking_mode' => 'date_only',
                        'demo_booking_seeded_at' => now(),
                    ])->save();
                });
        });
    }
}
