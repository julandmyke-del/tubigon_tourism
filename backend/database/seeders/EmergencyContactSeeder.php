<?php

namespace Database\Seeders;

use App\Models\EmergencyContact;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Schema;

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
                'source' => 'Philippine National Police directory material',
                'source_url' => 'https://itms.pnp.gov.ph/wp-content/uploads/2025/04/PRO-7.pdf',
                'verification_status' => 'needs_reverification',
            ],
            [
                'name' => 'Tubigon Fire Station',
                'category' => 'Fire & Rescue',
                'phone' => '(038) 508-8111',
                'alternative_phone' => '(038) 510-7022',
                'address' => 'Potohan, Tubigon, Bohol',
                'description' => 'Local fire and rescue contact. Supplied sources list conflicting current and older telephone numbers; LGU verification is required.',
                'source' => 'PPDO Bohol / BFP-Bohol material (published phone references conflict)',
                'source_url' => 'https://ppdo.bohol.gov.ph/profile/socio-economic-profile/development-administration/justice-and-safety/fire-incidence-protection-services/fire-fighting-force-and-facilities-jan-2014/',
                'verification_status' => 'needs_reverification',
            ],
            [
                'name' => 'Coast Guard Detachment Tubigon',
                'category' => 'Coast Guard / Maritime Emergency',
                'phone' => '0929-674-2112',
                'address' => 'Tubigon, Bohol',
                'description' => 'Local maritime emergency contact.',
                'source' => 'Philippine Coast Guard National Oil Spill Contingency Plan directory',
                'source_url' => 'https://www.coastguard.gov.ph/images/2017_Files/Memorandum_Circulars/NOSCOP2.pdf',
                'verification_status' => 'needs_reverification',
            ],
            [
                'name' => 'Tubigon Rural Health Unit',
                'category' => 'Medical',
                'phone' => '0946-713-8362',
                'alternative_phone' => '0917-894-5676',
                'address' => 'Potohan, Tubigon, Bohol',
                'description' => 'Local rural health unit contact.',
                'source' => 'PhilHealth List of Accredited TB-DOTS Package Providers, 31 December 2025',
                'source_url' => 'https://www.philhealth.gov.ph/partners/providers/facilities/accredited/DOTS_123125.pdf',
                'verification_status' => 'verified',
            ],
            [
                'name' => 'Tubigon Community Hospital',
                'category' => 'Medical / Hospital',
                'phone' => '0947-249-6029',
                'alternative_phone' => '(038) 411-4801',
                'address' => 'Potohan, Tubigon, Bohol',
                'description' => 'Local hospital contact.',
                'source' => 'PhilHealth provider information; current direct verification required',
                'source_url' => 'https://www.philhealth.gov.ph/partners/providers/institutional/map/',
                'verification_status' => 'needs_reverification',
            ],
            [
                'name' => 'Emergency Hotline',
                'category' => 'National Emergency Hotline',
                'phone' => '911',
                'address' => 'Philippines',
                'description' => 'National emergency hotline. This is distinct from Tubigon local direct numbers.',
                'source' => 'Philippine Government Emergency Hotlines directory',
                'source_url' => 'https://ehotlines.e.gov.ph/',
                'verification_status' => 'verified',
            ],
        ];

        foreach ($contacts as $contact) {
            $record = EmergencyContact::firstOrCreate(
                [
                    'name' => $contact['name'],
                    'category' => $contact['category'],
                ],
                $this->supportedAttributes($contact + [
                    'classification' => 'emergency',
                    'is_active' => true,
                    'is_verified' => $contact['verification_status'] === 'verified',
                    'is_public' => $contact['verification_status'] === 'verified',
                    'source_name' => $contact['source'],
                    'verified_at' => $contact['verification_status'] === 'verified' ? now() : null,
                    'last_verified_at' => $contact['verification_status'] === 'verified' ? now() : null,
                ]),
            );
            // Safely repair earlier installs that had the same exact official
            // source and number but were seeded before the publication
            // lifecycle existed. Conflicting or staff-edited records are not
            // auto-promoted.
            if ($contact['verification_status'] === 'verified'
                && ! $record->is_verified
                && $record->phone === $contact['phone']
                && $record->source_url === $contact['source_url']) {
                $record->update($this->supportedAttributes([
                    'is_verified' => true,
                    'is_public' => true,
                    'verification_status' => 'verified',
                    'source_name' => $contact['source'],
                    'verified_at' => now(),
                    'last_verified_at' => now(),
                ]));
            }
        }
    }

    private function supportedAttributes(array $attributes): array
    {
        return array_filter(
            $attributes,
            fn (string $column): bool => Schema::hasColumn('emergency_contacts', $column),
            ARRAY_FILTER_USE_KEY,
        );
    }
}
