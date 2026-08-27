<?php

namespace Database\Seeders;

use App\Models\EcoTip;
use Illuminate\Database\Seeder;

class EcoTipSeeder extends Seeder
{
    public function run(): void
    {
        $tips = [
            ['title' => 'Keep Tubigon Clean', 'category' => 'Waste', 'content' => 'Dispose of waste only in designated bins and carry litter with you until a bin is available.'],
            ['title' => 'Leave No Trace', 'category' => 'Nature', 'content' => 'Leave natural and heritage sites as you found them. Do not carve, mark, or damage attractions.'],
            ['title' => 'Protect Coastal Areas', 'category' => 'Marine', 'content' => 'Keep beaches, mangroves, and coastal waters free from litter, chemicals, and other pollutants.'],
            ['title' => 'Protect Marine Life', 'category' => 'Wildlife', 'content' => 'Observe marine animals from a respectful distance and never touch, feed, chase, or disturb them.'],
            ['title' => 'Reduce Single-Use Plastics', 'category' => 'Waste', 'content' => 'Bring a reusable bottle, bag, and food container to reduce plastic waste during your visit.'],
            ['title' => 'Save Water', 'category' => 'Resources', 'content' => 'Use water responsibly in accommodations and public facilities, especially during dry periods.'],
            ['title' => 'Respect Nature', 'category' => 'Nature', 'content' => 'Stay on marked paths and follow local environmental rules in protected and sensitive areas.'],
            ['title' => 'Practice Responsible Tourism', 'category' => 'Community', 'content' => 'Respect local customs, follow site guidance, and help keep Tubigon safe and welcoming.'],
            ['title' => 'Support Local Businesses', 'category' => 'Community', 'content' => 'Choose locally owned food, products, guides, and services whenever practical.'],
            ['title' => 'Keep Tourist Areas Clean', 'category' => 'Waste', 'content' => 'Use available segregation bins and report overflowing bins or illegal dumping through the app.'],
            ['title' => 'Save Energy', 'category' => 'Resources', 'content' => 'Turn off lights, air conditioning, and appliances when they are not needed.'],
            ['title' => 'Do Not Collect Natural Souvenirs', 'category' => 'Wildlife', 'content' => 'Do not take shells, corals, plants, rocks, or wildlife from their natural habitat.'],
        ];

        foreach ($tips as $tip) {
            EcoTip::firstOrCreate(
                ['title' => $tip['title'], 'language' => 'English'],
                $tip + ['language' => 'English'],
            );
        }
    }
}
