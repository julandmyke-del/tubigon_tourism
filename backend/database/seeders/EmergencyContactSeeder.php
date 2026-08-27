<?php

namespace Database\Seeders;

use App\Models\EmergencyContact;
use Illuminate\Database\Seeder;

class EmergencyContactSeeder extends Seeder
{
    public function run(): void
    {
        $contacts = [
            [
                'name' => 'Tubigon Municipal Police Station',
                'category' => 'Police',
                'phone' => '(038) 510-6094',
                'alternative_phone' => '0998-598-6445',
                'address' => 'Tubigon, Bohol',
                'description' => 'Local direct police contact. Confirm the current number with the station before relying on it for non-urgent inquiries.',
                'source' => 'PNP telephone-directory material',
            ],
            [
                'name' => 'Tubigon Fire Station',
                'category' => 'Fire & Rescue',
                'phone' => '(038) 508-8111',
                'alternative_phone' => '(038) 510-7022',
                'address' => 'Potohan, Tubigon, Bohol',
                'description' => 'Local fire and rescue contact. Supplied sources list conflicting current and older telephone numbers; LGU verification is required.',
                'source' => 'Local directory and Bohol government material (conflicting numbers)',
            ],
            [
                'name' => 'Coast Guard Detachment Tubigon',
                'category' => 'Coast Guard / Maritime Emergency',
                'phone' => '0929-674-2112',
                'address' => 'Tubigon, Bohol',
                'description' => 'Local maritime emergency contact.',
                'source' => 'Philippine Coast Guard material',
            ],
            [
                'name' => 'Tubigon Rural Health Unit',
                'category' => 'Medical',
                'phone' => '0946-713-8362',
                'alternative_phone' => '0917-894-5676',
                'address' => 'Potohan, Tubigon, Bohol',
                'description' => 'Local rural health unit contact.',
                'source' => 'PhilHealth 2025 accredited-provider listing',
            ],
            [
                'name' => 'Tubigon Community Hospital',
                'category' => 'Medical / Hospital',
                'phone' => '0947-249-6029',
                'alternative_phone' => '(038) 411-4801',
                'address' => 'Potohan, Tubigon, Bohol',
                'description' => 'Local hospital contact.',
                'source' => 'PhilHealth hospital-provider information',
            ],
            [
                'name' => 'Emergency Hotline',
                'category' => 'National Emergency Hotline',
                'phone' => '911',
                'address' => 'Philippines',
                'description' => 'National emergency hotline. This is distinct from Tubigon local direct numbers.',
                'source' => 'National emergency hotline',
            ],
        ];

        foreach ($contacts as $contact) {
            EmergencyContact::firstOrCreate(
                [
                    'name' => $contact['name'],
                    'category' => $contact['category'],
                ],
                $contact + [
                    'classification' => 'emergency',
                    'is_active' => true,
                    'is_verified' => false,
                ],
            );
        }
    }
}
