<?php

namespace Database\Seeders;

use App\Models\EmergencyContact;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class EmergencyContactSeeder extends Seeder
{
    private const SOURCE = 'Municipality of Tubigon Emergency Hotline image supplied by the LGU';

    public function run(): void
    {
        $contacts = [
            ['name' => 'Tubigon Police', 'category' => 'Police', 'phone' => '0998-598-6445', 'display_order' => 10],
            ['name' => 'Bureau of Fire', 'category' => 'Fire', 'phone' => '0963-774-5972', 'display_order' => 20],
            ['name' => 'Control Smart', 'category' => 'Disaster Risk', 'phone' => '0930-785-0653', 'display_order' => 30],
            ['name' => 'Waterworks', 'category' => 'Government', 'phone' => '0966-749-6659', 'display_order' => 40],
            ['name' => 'TERSSU', 'contact_label' => 'Smart', 'category' => 'Disaster Risk', 'phone' => '0930-785-0655', 'display_order' => 50],
            ['name' => 'TERSSU', 'contact_label' => 'Globe', 'category' => 'Disaster Risk', 'phone' => '0927-454-5496', 'display_order' => 60],
            ['name' => 'MSWDO', 'category' => 'Government', 'phone' => '0912-887-7120', 'display_order' => 70],
            ['name' => 'Coast Guard', 'category' => 'Coast Guard', 'phone' => '0927-429-7581', 'display_order' => 80],
        ];

        foreach ($contacts as $contact) {
            $query = EmergencyContact::query()
                ->whereRaw('LOWER(name) = ?', [Str::lower($contact['name'])]);

            if (Schema::hasColumn('emergency_contacts', 'contact_label')) {
                isset($contact['contact_label'])
                    ? $query->whereRaw('LOWER(contact_label) = ?', [Str::lower($contact['contact_label'])])
                    : $query->whereNull('contact_label');
            } else {
                $query->where('phone', $contact['phone']);
            }

            $record = $query->first();
            $attributes = $this->supportedAttributes($contact + [
                'address' => 'Municipality of Tubigon, Bohol',
                'classification' => 'emergency',
                'is_active' => true,
                'is_public' => true,
                'is_verified' => true,
                'verification_status' => 'verified',
                'source' => self::SOURCE,
                'source_name' => self::SOURCE,
                'verified_at' => $record?->verified_at ?? now(),
                'last_verified_at' => now(),
            ]);

            if ($record) {
                $record->update($attributes);
            } else {
                EmergencyContact::create($attributes);
            }
        }

        $this->deactivateConfirmedLegacyRows();
    }

    private function deactivateConfirmedLegacyRows(): void
    {
        $legacy = [
            ['Tubigon Municipal Police Station', '(038) 510-6094', 'https://itms.pnp.gov.ph/wp-content/uploads/2025/04/PRO-7.pdf'],
            ['Tubigon Fire Station', '(038) 508-8111', 'https://ppdo.bohol.gov.ph/profile/socio-economic-profile/development-administration/justice-and-safety/fire-incidence-protection-services/fire-fighting-force-and-facilities-jan-2014/'],
            ['Coast Guard Detachment Tubigon', '0929-674-2112', 'https://www.coastguard.gov.ph/images/2017_Files/Memorandum_Circulars/NOSCOP2.pdf'],
        ];

        foreach ($legacy as [$name, $phone, $sourceUrl]) {
            EmergencyContact::query()
                ->where('name', $name)
                ->where('phone', $phone)
                ->where('source_url', $sourceUrl)
                ->update($this->supportedAttributes([
                    'is_active' => false,
                    'is_public' => false,
                    'is_verified' => false,
                    'verification_status' => 'inactive',
                ]));
        }
    }

    /** @param array<string, mixed> $attributes */
    private function supportedAttributes(array $attributes): array
    {
        return array_filter(
            $attributes,
            fn (string $column): bool => Schema::hasColumn('emergency_contacts', $column),
            ARRAY_FILTER_USE_KEY,
        );
    }
}
