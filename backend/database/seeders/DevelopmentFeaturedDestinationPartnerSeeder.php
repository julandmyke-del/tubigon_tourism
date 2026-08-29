<?php

namespace Database\Seeders;

use App\Models\Profile;
use App\Models\Role;
use App\Models\TouristSpot;
use App\Models\TouristSpotPartnerAssignment;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Ramsey\Uuid\Uuid;
use RuntimeException;

class DevelopmentFeaturedDestinationPartnerSeeder extends Seeder
{
    public const ACCOUNTS = [
        'mundong@gmail.com' => ['Mundong Sandbar Partner', 'mundong-sandbar'],
        'dumog@gmail.com' => ['Dumog Sandbar Partner', 'dumog-sandbar'],
        'mocaboc@gmail.com' => ['Mocaboc Sandbar Partner', 'mocaboc-sandbar'],
        'batasan@gmail.com' => ['Mangrove Forest Batasan Partner', 'mangrove-forest-batasan'],
        'nakins@gmail.com' => ["Nakin's Floating Cottage Partner", 'nakins-floating-cottage'],
        'delan@gmail.com' => ['Delan Cliffside Open Cabana Partner', 'delan-cliffside-open-cabana'],
        'ilijan@gmail.com' => ['Enchanted Ilijan Hill Partner', 'enchanted-ilijan-hill'],
        'loomweaving@gmail.com' => ['Tubigon Loom Weaving Partner', 'tubigon-loom-weaving'],
    ];

    public function run(): void
    {
        if (! app()->environment(['local', 'testing'])) {
            throw new RuntimeException('Featured Partner development accounts may only be seeded locally or in tests.');
        }

        $role = Role::where('name', 'tourism_partner')->firstOrFail();
        $password = $this->developmentPassword();

        DB::transaction(function () use ($role, $password): void {
            foreach (self::ACCOUNTS as $email => [$name, $slug]) {
                $spot = TouristSpot::where('slug', $slug)->lockForUpdate()->firstOrFail();
                $user = User::withTrashed()->whereRaw('LOWER(email) = ?', [strtolower($email)])->first();

                if (! $user) {
                    $user = new User;
                    $user->id = Uuid::uuid5(Uuid::NAMESPACE_URL, "tubigon-featured-partner:{$email}")->toString();
                    $user->forceFill([
                        'name' => $name,
                        'email' => $email,
                        'password' => Hash::make($password),
                        'role_id' => $role->id,
                        'is_verified' => true,
                        'email_verified_at' => now(),
                        'auth_provider' => 'email',
                    ])->save();
                } else {
                    if ($user->trashed()) {
                        $user->restore();
                    }
                    // Never reset an existing seeded account's password on rerun.
                    $user->forceFill([
                        'name' => $name,
                        'role_id' => $role->id,
                        'is_verified' => true,
                        'email_verified_at' => $user->email_verified_at ?? now(),
                    ])->save();
                }

                $profile = Profile::withTrashed()->whereKey($user->id)->first();
                if (! $profile) {
                    $profile = new Profile;
                    $profile->id = $user->id;
                } elseif ($profile->trashed()) {
                    $profile->restore();
                }
                $profile->forceFill([
                        'name' => $name,
                        'email' => $email,
                        'role_id' => $role->id,
                        'is_verified' => true,
                ])->save();

                $assignment = TouristSpotPartnerAssignment::firstOrCreate(
                    [
                        'tourist_spot_id' => $spot->id,
                        'partner_profile_id' => $user->id,
                    ],
                    [
                        'is_primary' => true,
                        'assigned_at' => now(),
                    ],
                );

                // Initial provisioning only. Later Partner/LGU availability choices win.
                if ($assignment->wasRecentlyCreated) {
                    $spot->forceFill([
                        'is_featured' => true,
                        'is_active' => true,
                        'is_published' => true,
                        'is_bookable' => true,
                        'booking_enabled' => true,
                        'booking_mode' => 'date_only',
                        'booking_unavailable_reason_code' => null,
                        'booking_unavailable_reason' => null,
                    ])->save();
                }
            }
        });
    }

    private function developmentPassword(): string
    {
        $configured = trim((string) config('tourist_spot_partners.development_password'));
        if ($configured !== '') {
            if (strlen($configured) < 12) {
                throw new RuntimeException('DEV_FEATURED_PARTNER_PASSWORD must be at least 12 characters.');
            }

            return $configured;
        }

        $path = storage_path('app/private/featured_partner_seed_password.txt');
        File::ensureDirectoryExists(dirname($path), 0700);
        if (File::exists($path)) {
            $stored = trim(File::get($path));
            if (strlen($stored) >= 12) {
                return $stored;
            }
        }

        $generated = Str::password(24, true, true, true, false);
        File::put($path, $generated);
        @chmod($path, 0600);
        $this->command?->warn('Generated a local Featured Partner seed password at storage/app/private/featured_partner_seed_password.txt.');

        return $generated;
    }
}
