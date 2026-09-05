<?php

namespace Database\Seeders;

use App\Models\Msme;
use App\Models\Profile;
use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Ramsey\Uuid\Uuid;
use RuntimeException;

class DevelopmentMsmeOwnerSeeder extends Seeder
{
    public const BUSINESSES = [
        'bazak@gmail.com' => [
            'owner_name' => 'BAZAK Food Park Owner',
            'name' => 'BAZAK Food Park',
            'aliases' => ['bazak food park', 'bazak foodpark'],
            'category' => 'Food & Dining',
            'type' => 'Food Park / Restaurant',
            'description' => 'Food Park / Restaurant in Tinangnan, Tubigon, Bohol.',
            'address' => 'Paseo Anacleta Building, Tinangnan, Tubigon, Bohol',
            'phone' => '+63 917 323 1755',
            'latitude' => 9.94996620,
            'longitude' => 123.96643210,
            'icon' => 'restaurant_rounded',
        ],
        'purpleyam@gmail.com' => [
            'owner_name' => 'Purple Yam - Tubigon Owner',
            'name' => 'Purple Yam - Tubigon',
            'aliases' => ['purple yam - tubigon', 'purple yam tubigon', 'purple yam'],
            'category' => 'Food & Dining',
            'type' => 'Cake Shop / Bakery',
            'description' => 'Cake Shop / Bakery in Putohan/Potohan, Tubigon, Bohol.',
            'address' => 'Putohan/Potohan, Tubigon, Bohol',
            'phone' => '+63 961 560 0567',
            'latitude' => null,
            'longitude' => null,
            'icon' => 'bakery_dining_rounded',
        ],
    ];

    public function run(): void
    {
        if (! app()->environment(['local', 'testing'])) {
            throw new RuntimeException('MSME owner development accounts may only be seeded locally or in tests.');
        }

        $role = Role::where('name', 'msme_owner')->firstOrFail();
        $password = $this->developmentPassword();

        DB::transaction(function () use ($role, $password): void {
            foreach (self::BUSINESSES as $email => $data) {
                $user = $this->provisionUser($email, $data['owner_name'], $role, $password);
                $this->provisionProfile($user, $role);
                $this->provisionBusiness($user, $data);
            }
        });
    }

    private function provisionUser(string $email, string $name, Role $role, string $password): User
    {
        $user = User::withTrashed()->whereRaw('LOWER(email) = ?', [strtolower($email)])->first();
        if (! $user) {
            $user = new User;
            $user->id = Uuid::uuid5(Uuid::NAMESPACE_URL, "tubigon-msme-owner:{$email}")->toString();
        } elseif ($user->trashed()) {
            $user->restore();
        }

        $user->forceFill([
            'name' => $name,
            'email' => $email,
            // This controlled local/testing seeder intentionally rotates only
            // the two named development accounts on every run.
            'password' => Hash::make($password),
            'role_id' => $role->id,
            'is_verified' => true,
            'email_verified_at' => $user->email_verified_at ?? now(),
            'auth_provider' => 'email',
        ])->save();

        return $user;
    }

    private function provisionProfile(User $user, Role $role): void
    {
        $profile = Profile::withTrashed()->whereKey($user->id)->first();
        if (! $profile) {
            $profile = new Profile;
            $profile->id = $user->id;
        } elseif ($profile->trashed()) {
            $profile->restore();
        }

        $profile->forceFill([
            'name' => $user->name,
            'email' => $user->email,
            'role_id' => $role->id,
            'phone' => $user->phone,
            'is_verified' => true,
        ])->save();
    }

    private function provisionBusiness(User $user, array $data): void
    {
        $business = Msme::withTrashed()->where('profile_id', $user->id)->first();
        if (! $business) {
            $aliases = array_map('strtolower', $data['aliases']);
            $business = Msme::withTrashed()
                ->whereIn(DB::raw('LOWER(TRIM(name))'), $aliases)
                ->orderByRaw('CASE WHEN LOWER(TRIM(name)) = ? THEN 0 ELSE 1 END', [strtolower($data['name'])])
                ->first();
        }
        if (! $business) {
            $business = new Msme;
            $business->id = Uuid::uuid5(Uuid::NAMESPACE_URL, 'tubigon-msme:'.strtolower($data['name']))->toString();
        } elseif ($business->trashed()) {
            $business->restore();
        }

        [$latitude, $longitude] = $data['latitude'] !== null
            ? [$data['latitude'], $data['longitude']]
            : $this->preservedCoordinatePair($business);

        $business->forceFill([
            'profile_id' => $user->id,
            'name' => $data['name'],
            'category' => $data['category'],
            'tagline' => $data['type'],
            'description' => $data['description'],
            'phone' => $data['phone'],
            'address' => $data['address'],
            'latitude' => $latitude,
            'longitude' => $longitude,
            'color' => '#F87171',
            'icon' => $data['icon'],
            'is_verified' => true,
            'verification_status' => 'verified',
            'verification_notes' => null,
            'submitted_at' => $business->submitted_at ?? now(),
            'reviewed_at' => $business->reviewed_at ?? now(),
            'operational_status' => 'open',
        ])->save();
    }

    /** Preserve Purple Yam coordinates only when a complete standard-range pair already exists. */
    private function preservedCoordinatePair(Msme $business): array
    {
        $latitude = $business->latitude;
        $longitude = $business->longitude;
        if ($latitude === null || $longitude === null
            || $latitude < -90 || $latitude > 90
            || $longitude < -180 || $longitude > 180) {
            return [null, null];
        }

        return [$latitude, $longitude];
    }

    private function developmentPassword(): string
    {
        $configured = trim((string) config('msme_owners.development_password'));
        if (strlen($configured) < 8) {
            throw new RuntimeException('DEV_MSME_OWNER_PASSWORD must be at least 8 characters.');
        }

        return $configured;
    }
}
