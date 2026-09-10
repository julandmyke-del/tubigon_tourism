<?php

namespace Tests\Feature;

use App\Mail\VerifyEmail;
use App\Models\Image;
use App\Models\Profile;
use App\Models\Role;
use App\Models\User;
use App\Notifications\ResetPasswordNotification;
use App\Services\GoogleIdTokenVerifier;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\Str;
use Mockery\MockInterface;
use Tests\TestCase;

class AuthFlowTest extends TestCase
{
    private Role $touristRole;

    protected function setUp(): void
    {
        parent::setUp();
        RateLimiter::clear('');
        $this->createAuthSchema();
        $this->touristRole = Role::create(['name' => 'tourist']);
        config([
            'auth.development_allowlist_bypass.enabled' => false,
            'auth.development_allowlist_bypass.emails' => [
                'user@gmail.com',
                'msme@gmail.com',
                'lgu@gmail.com',
                'admin@gmail.com',
                'partner@gmail.com',
            ],
        ]);
    }

    public function test_email_registration_creates_unverified_tourist_and_sends_smtp_code(): void
    {
        Mail::fake();

        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Tubigon Tourist',
            'email' => 'tourist@example.com',
            'password' => 'safe-password',
            'password_confirmation' => 'safe-password',
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.requires_email_verification', true)
            ->assertJsonPath('data.requires_verification', true)
            ->assertJsonPath('data.max_attempts', 5)
            ->assertJsonPath('data.attempts_used', 0)
            ->assertJsonMissingPath('data.token');

        $user = User::where('email', 'tourist@example.com')->firstOrFail();
        $this->assertFalse($user->is_verified);
        $this->assertSame('email', $user->auth_provider);
        $this->assertTrue(Hash::check('safe-password', $user->password));
        $this->assertFalse((bool) Profile::findOrFail($user->id)->is_verified);
        Mail::assertSent(VerifyEmail::class, fn (VerifyEmail $mail) => preg_match('/^\d{6}$/', $mail->verificationCode) === 1
            && $mail->envelope()->subject === 'Tour Tubigon Verification Code'
        );
    }

    public function test_correct_email_code_verifies_tourist_and_issues_restorable_sanctum_session(): void
    {
        Mail::fake();
        $verificationCode = null;

        $this->postJson('/api/v1/auth/register', [
            'name' => 'New Tourist',
            'email' => 'newtourist@gmail.com',
            'password' => 'safe-password',
            'password_confirmation' => 'safe-password',
        ])->assertCreated();

        Mail::assertSent(VerifyEmail::class, function (VerifyEmail $mail) use (&$verificationCode): bool {
            $verificationCode = $mail->verificationCode;

            return true;
        });

        $response = $this->postJson('/api/v1/auth/verify-email-code', [
            'email' => 'newtourist@gmail.com',
            'code' => $verificationCode,
        ])->assertOk()
            ->assertJsonPath('data.role', 'tourist')
            ->assertJsonPath('data.user.is_verified', true)
            ->assertJsonStructure(['data' => ['token']]);

        $user = User::where('email', 'newtourist@gmail.com')->firstOrFail();
        $this->assertTrue($user->is_verified);
        $this->assertNotNull($user->email_verified_at);
        $this->assertNull($user->email_verification_code_hash);
        $this->assertSame($this->touristRole->id, $user->role_id);
        $this->assertDatabaseCount('users', 1);
        $this->assertDatabaseCount('profiles', 1);

        $token = $response->json('data.token');
        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.role', 'tourist');

        $this->withToken($token)->postJson('/api/v1/auth/logout')->assertOk();
        Auth::forgetGuards();
        $this->withToken($token)->getJson('/api/v1/auth/me')->assertUnauthorized();
    }

    public function test_incorrect_email_code_never_verifies_or_issues_a_token(): void
    {
        $user = $this->makeUser([
            'email' => 'pending-tourist@gmail.com',
            'is_verified' => false,
            'email_verification_code_hash' => Hash::make('123456'),
            'email_verification_code_expires_at' => now()->addMinutes(10),
        ]);

        $this->postJson('/api/v1/auth/verify-email-code', [
            'email' => $user->email,
            'code' => '654321',
        ])->assertUnprocessable()
            ->assertJsonMissingPath('data.token');

        $user->refresh();
        $this->assertFalse($user->is_verified);
        $this->assertNull($user->email_verified_at);
        $this->assertSame(1, $user->email_verification_attempts);
    }

    public function test_expired_email_code_returns_authoritative_zero_timer(): void
    {
        $user = $this->makeUser([
            'email' => 'expired-tourist@gmail.com',
            'is_verified' => false,
            'email_verification_code_hash' => Hash::make('123456'),
            'email_verification_code_expires_at' => now()->subSecond(),
            'email_verification_attempts' => 2,
        ]);

        $this->postJson('/api/v1/auth/verify-email-code', [
            'email' => $user->email,
            'code' => '123456',
        ])->assertUnprocessable()
            ->assertJsonPath('message', 'The verification code has expired. Request a new code.')
            ->assertJsonPath('data.expires_in_seconds', 0)
            ->assertJsonPath('data.verification_code_sent', false)
            ->assertJsonMissingPath('data.token');
    }

    public function test_resend_cooldown_is_server_authoritative_and_resets_attempts(): void
    {
        Mail::fake();
        $user = $this->makeUser([
            'email' => 'resend-tourist@gmail.com',
            'is_verified' => false,
            'email_verification_code_hash' => Hash::make('123456'),
            'email_verification_code_expires_at' => now()->addMinutes(10),
            'email_verification_attempts' => 3,
            'email_verification_last_sent_at' => now(),
        ]);

        $this->postJson('/api/v1/auth/resend-verification-code', [
            'email' => $user->email,
        ])->assertStatus(429)
            ->assertJsonPath('data.attempts_used', 3);
        Mail::assertNothingSent();

        $this->travel(61)->seconds();
        $this->postJson('/api/v1/auth/resend-verification-code', [
            'email' => $user->email,
        ])->assertOk()
            ->assertJsonPath('data.attempts_used', 0)
            ->assertJsonPath('data.max_attempts', 5)
            ->assertJsonPath('data.verification_code_sent', true);
        Mail::assertSent(VerifyEmail::class, 1);
    }

    public function test_pending_email_change_updates_the_same_user_and_profile(): void
    {
        Mail::fake();
        $user = $this->makeUser([
            'email' => 'mistyped@gmail.com',
            'is_verified' => false,
            'email_verification_code_hash' => Hash::make('123456'),
            'email_verification_code_expires_at' => now()->addMinutes(10),
        ]);
        Profile::create([
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'role_id' => $user->role_id,
            'is_verified' => false,
        ]);

        $this->postJson('/api/v1/auth/change-unverified-email', [
            'email' => 'mistyped@gmail.com',
            'new_email' => 'corrected@gmail.com',
            'password' => 'safe-password',
        ])->assertOk()
            ->assertJsonPath('data.email', 'corrected@gmail.com')
            ->assertJsonPath('data.requires_email_verification', true);

        $this->assertDatabaseCount('users', 1);
        $this->assertDatabaseCount('profiles', 1);
        $this->assertSame($user->id, User::where('email', 'corrected@gmail.com')->firstOrFail()->id);
        $this->assertDatabaseHas('profiles', [
            'id' => $user->id,
            'email' => 'corrected@gmail.com',
        ]);
        Mail::assertSent(VerifyEmail::class, 1);
    }

    public function test_manual_registration_rejects_an_invalid_email_address(): void
    {
        Mail::fake();

        $this->postJson('/api/v1/auth/register', [
            'name' => 'Tubigon Tourist',
            'email' => 'not-an-email',
            'password' => 'safe-password',
            'password_confirmation' => 'safe-password',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('email');

        $this->assertDatabaseMissing('users', ['email' => 'not-an-email']);
        Mail::assertNothingSent();
    }

    public function test_password_recovery_sends_a_real_link_and_resets_the_hash(): void
    {
        Notification::fake();
        $user = $this->makeUser(['email' => 'recover@example.test']);

        $this->postJson('/api/v1/auth/forgot-password', [
            'email' => $user->email,
        ])->assertOk();
        Notification::assertSentTo($user, ResetPasswordNotification::class);

        $token = Password::broker()->createToken($user);
        $user->createToken('existing-session');
        $this->postJson('/api/v1/auth/reset-password', [
            'email' => $user->email,
            'token' => $token,
            'password' => 'new-safe-password',
            'password_confirmation' => 'new-safe-password',
        ])->assertOk();

        $this->assertTrue(Hash::check('new-safe-password', $user->fresh()->password));
        $this->assertDatabaseMissing('personal_access_tokens', [
            'tokenable_id' => $user->id,
        ]);
    }

    public function test_tourist_profile_and_password_updates_are_owner_scoped_and_cannot_escalate(): void
    {
        $user = $this->makeUser(['email' => 'profile-owner@example.test']);
        $other = $this->makeUser(['email' => 'profile-other@example.test']);
        foreach ([$user, $other] as $profileUser) {
            Profile::create([
                'id' => $profileUser->id,
                'name' => $profileUser->name,
                'email' => $profileUser->email,
                'role_id' => $profileUser->role_id,
                'is_verified' => true,
            ]);
        }

        $this->actingAs($user, 'sanctum')
            ->putJson("/api/v1/users/{$user->id}", [
                'name' => 'Updated Tourist',
                'phone' => '09171234567',
                'role_id' => Role::create(['name' => 'admin'])->id,
                'is_verified' => false,
            ])->assertOk();
        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'name' => 'Updated Tourist',
            'role_id' => $this->touristRole->id,
            'is_verified' => true,
        ]);
        $this->getJson("/api/v1/users/{$other->id}")->assertForbidden();
        $this->putJson("/api/v1/users/{$other->id}", [
            'name' => 'Hijacked',
        ])->assertForbidden();

        $this->putJson('/api/v1/auth/password', [
            'current_password' => 'wrong-password',
            'password' => 'changed-password',
            'password_confirmation' => 'changed-password',
        ])->assertUnprocessable();
        $this->putJson('/api/v1/auth/password', [
            'current_password' => 'safe-password',
            'password' => 'changed-password',
            'password_confirmation' => 'changed-password',
        ])->assertOk();
        $this->assertTrue(Hash::check('changed-password', $user->fresh()->password));
    }

    public function test_unverified_password_account_cannot_log_in(): void
    {
        $user = $this->makeUser(['is_verified' => false]);

        $this->postJson('/api/v1/auth/login', [
            'email' => $user->email,
            'password' => 'safe-password',
        ])->assertForbidden()
            ->assertJsonPath('status', 'unverified')
            ->assertJsonMissingPath('data.token');
    }

    public function test_enabled_development_bypass_allows_only_the_five_exact_unverified_accounts(): void
    {
        config(['auth.development_allowlist_bypass.enabled' => true]);

        $accounts = [
            'user@gmail.com' => 'tourist',
            'msme@gmail.com' => 'msme_owner',
            'lgu@gmail.com' => 'lgu_staff',
            'partner@gmail.com' => 'tourism_partner',
            'admin@gmail.com' => 'admin',
        ];

        foreach ($accounts as $email => $roleName) {
            $role = $roleName === 'tourist'
                ? $this->touristRole
                : Role::create(['name' => $roleName]);
            $user = $this->makeUser([
                'email' => $email,
                'role_id' => $role->id,
                'is_verified' => false,
            ]);

            $usersBeforeLogin = User::count();
            $profilesBeforeLogin = Profile::count();
            $response = $this->postJson('/api/v1/auth/login', [
                'email' => strtoupper($email),
                'password' => 'safe-password',
            ])->assertOk()
                ->assertJsonPath('data.role', $roleName)
                ->assertJsonPath('data.user.is_verified', false)
                ->assertJsonStructure(['data' => ['token']]);

            $token = $response->json('data.token');
            $this->withToken($token)->getJson('/api/v1/auth/me')
                ->assertOk()
                ->assertJsonPath('data.role', $roleName)
                ->assertJsonPath('data.user.email', $email);
            $this->withToken($token)->postJson('/api/v1/auth/logout')->assertOk();
            Auth::forgetGuards();
            $this->withToken($token)->getJson('/api/v1/auth/me')->assertUnauthorized();

            $user->refresh();
            $this->assertFalse($user->is_verified);
            $this->assertSame($role->id, $user->role_id);
            $this->assertSame($usersBeforeLogin, User::count());
            $this->assertSame($profilesBeforeLogin, Profile::count());
        }

        $otherUser = $this->makeUser([
            'email' => 'other@gmail.com',
            'is_verified' => false,
        ]);

        $this->postJson('/api/v1/auth/login', [
            'email' => $otherUser->email,
            'password' => 'safe-password',
        ])->assertForbidden()
            ->assertJsonPath('status', 'unverified')
            ->assertJsonMissingPath('data.token');
    }

    public function test_disabled_flag_applies_normal_verification_even_to_an_allowlisted_email(): void
    {
        config([
            'app.env' => 'local',
            'app.debug' => true,
            'auth.development_allowlist_bypass.enabled' => false,
        ]);
        $user = $this->makeUser([
            'email' => 'admin@gmail.com',
            'is_verified' => false,
        ]);

        $this->postJson('/api/v1/auth/login', [
            'email' => $user->email,
            'password' => 'safe-password',
        ])->assertForbidden()
            ->assertJsonPath('status', 'unverified')
            ->assertJsonMissingPath('data.token');
    }

    public function test_enabled_development_bypass_still_requires_the_existing_password(): void
    {
        config(['auth.development_allowlist_bypass.enabled' => true]);
        $this->makeUser([
            'email' => 'admin@gmail.com',
            'is_verified' => false,
        ]);

        $this->postJson('/api/v1/auth/login', [
            'email' => 'admin@gmail.com',
            'password' => 'wrong-password',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('email')
            ->assertJsonMissingPath('data.token');
    }

    public function test_signed_verification_link_is_single_use(): void
    {
        $user = $this->makeUser(['is_verified' => false]);
        Profile::create([
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'role_id' => $user->role_id,
            'is_verified' => false,
        ]);
        $url = URL::temporarySignedRoute(
            'verification.verify',
            now()->addMinutes(60),
            ['id' => $user->id, 'hash' => sha1($user->email)]
        );

        $this->get($url)->assertOk()->assertSee('Email Verified');
        $this->assertTrue(User::findOrFail($user->id)->is_verified);
        $this->get($url)->assertOk()->assertSee('Already Verified');
    }

    public function test_expired_verification_link_does_not_verify_account(): void
    {
        $user = $this->makeUser(['is_verified' => false]);
        $url = URL::temporarySignedRoute(
            'verification.verify',
            now()->subMinute(),
            ['id' => $user->id, 'hash' => sha1($user->email)]
        );

        $this->get($url)->assertForbidden()->assertSee('Verification Failed');
        $this->assertFalse(User::findOrFail($user->id)->is_verified);
    }

    public function test_verified_existing_roles_keep_their_portal_role_after_login(): void
    {
        $accounts = [
            'user@gmail.com' => 'tourist',
            'msme@gmail.com' => 'msme_owner',
            'lgu@gmail.com' => 'lgu_staff',
            'partner@gmail.com' => 'tourism_partner',
            'admin@gmail.com' => 'admin',
        ];

        foreach ($accounts as $email => $roleName) {
            $role = $roleName === 'tourist'
                ? $this->touristRole
                : Role::create(['name' => $roleName]);
            $user = $this->makeUser([
                'email' => $email,
                'role_id' => $role->id,
            ]);

            $this->postJson('/api/v1/auth/login', [
                'email' => $user->email,
                'password' => 'safe-password',
            ])->assertOk()->assertJsonPath('data.role', $roleName);
        }
    }

    public function test_google_auth_rejects_invalid_identity_token(): void
    {
        $this->mock(GoogleIdTokenVerifier::class, function (MockInterface $mock) {
            $mock->shouldReceive('verify')->once()->andThrow(
                new \RuntimeException('The Google identity token is invalid or expired.')
            );
        });

        $this->postJson('/api/v1/auth/google', ['id_token' => 'not-a-token'])
            ->assertUnauthorized()
            ->assertJsonPath('status', 'error')
            ->assertJsonPath('message', 'Google authentication expired. Please try again.');
        $this->assertDatabaseCount('users', 0);
    }

    public function test_google_auth_rejects_an_unverified_google_email(): void
    {
        $this->mock(GoogleIdTokenVerifier::class, function (MockInterface $mock) {
            $mock->shouldReceive('verify')->once()->andThrow(
                new \RuntimeException('The Google account email is not verified.')
            );
        });

        $this->postJson('/api/v1/auth/google', ['id_token' => 'unverified-token'])
            ->assertForbidden()
            ->assertJsonPath('status', 'error')
            ->assertJsonPath(
                'message',
                'Your Google account email must be verified before you can continue.'
            );
        $this->assertDatabaseCount('users', 0);
    }

    public function test_verified_google_identity_creates_verified_tourist_and_sanctum_token(): void
    {
        $this->fakeGoogleIdentity('google-subject', 'google.user@gmail.com');

        $this->postJson('/api/v1/auth/google', ['id_token' => 'verified-token'])
            ->assertOk()
            ->assertJsonPath('data.role', 'tourist')
            ->assertJsonPath('data.user.is_verified', true)
            ->assertJsonStructure(['data' => ['token']]);

        $this->assertDatabaseHas('users', [
            'email' => 'google.user@gmail.com',
            'google_id' => 'google-subject',
            'auth_provider' => 'google',
            'is_verified' => true,
            'role_id' => $this->touristRole->id,
        ]);
    }

    public function test_google_never_auto_links_the_five_protected_password_accounts(): void
    {
        $accounts = [
            'user@gmail.com' => 'tourist',
            'msme@gmail.com' => 'msme_owner',
            'lgu@gmail.com' => 'lgu_staff',
            'partner@gmail.com' => 'tourism_partner',
            'admin@gmail.com' => 'admin',
        ];
        $originals = [];

        foreach ($accounts as $email => $roleName) {
            $role = $roleName === 'tourist'
                ? $this->touristRole
                : Role::create(['name' => $roleName]);
            $user = $this->makeUser([
                'email' => $email,
                'role_id' => $role->id,
                'auth_provider' => null,
            ]);
            $originals[$email] = [
                'id' => $user->id,
                'password' => $user->password,
                'role_id' => $user->role_id,
                'is_verified' => $user->is_verified,
            ];
        }

        $this->mock(GoogleIdTokenVerifier::class, function (MockInterface $mock) use ($accounts) {
            $mock->shouldReceive('verify')->times(count($accounts))->andReturnUsing(
                function (string $token) use ($accounts): array {
                    $email = array_keys($accounts)[(int) Str::after($token, 'token-')];

                    return [
                        'sub' => 'google-subject-'.$email,
                        'email' => $email,
                        'email_verified' => true,
                        'name' => 'Google User',
                    ];
                }
            );
        });

        foreach (array_keys($accounts) as $index => $email) {
            $this->postJson('/api/v1/auth/google', ['id_token' => "token-{$index}"])
                ->assertConflict()
                ->assertJsonPath('message', 'This email is already associated with another account.');

            $user = User::findOrFail($originals[$email]['id']);
            $this->assertNull($user->google_id);
            $this->assertNull($user->auth_provider);
            $this->assertSame($originals[$email]['password'], $user->password);
            $this->assertSame($originals[$email]['role_id'], $user->role_id);
            $this->assertSame($originals[$email]['is_verified'], $user->is_verified);
        }
    }

    public function test_already_linked_google_user_logs_in_without_role_or_account_rewrites(): void
    {
        $partnerRole = Role::create(['name' => 'tourism_partner']);
        $user = $this->makeUser([
            'email' => 'linked.partner@gmail.com',
            'role_id' => $partnerRole->id,
            'google_id' => 'partner-google-subject',
            'auth_provider' => 'google',
            'avatar_url' => 'https://example.test/existing-avatar.png',
        ]);
        $originalPassword = $user->password;
        $this->fakeGoogleIdentity('partner-google-subject', $user->email);

        $this->postJson('/api/v1/auth/google', ['id_token' => 'verified-token'])
            ->assertOk()
            ->assertJsonPath('data.role', 'tourism_partner')
            ->assertJsonStructure(['data' => ['token']]);

        $user->refresh();
        $this->assertSame($partnerRole->id, $user->role_id);
        $this->assertSame('google', $user->auth_provider);
        $this->assertSame('partner-google-subject', $user->google_id);
        $this->assertSame($originalPassword, $user->password);
        $this->assertSame('https://example.test/existing-avatar.png', $user->avatar_url);
        $this->assertTrue($user->is_verified);
    }

    public function test_new_google_user_appears_in_existing_admin_user_management(): void
    {
        $adminRole = Role::create(['name' => 'admin']);
        $admin = $this->makeUser([
            'email' => 'admin@gmail.com',
            'role_id' => $adminRole->id,
        ]);
        $this->fakeGoogleIdentity('new-google-subject', 'new.tourist@gmail.com');

        $this->postJson('/api/v1/auth/google', ['id_token' => 'verified-token'])
            ->assertOk();

        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/v1/admin/users')
            ->assertOk()
            ->assertJsonFragment([
                'email' => 'new.tourist@gmail.com',
                'role' => 'tourist',
                'registration_method' => 'google',
                'status' => 'Active',
            ]);
    }

    public function test_google_sanctum_session_restores_and_logout_revokes_its_token(): void
    {
        $this->fakeGoogleIdentity('session-google-subject', 'session.user@gmail.com');

        $response = $this->postJson('/api/v1/auth/google', ['id_token' => 'verified-token'])
            ->assertOk();
        $token = $response->json('data.token');

        $this->withToken($token)
            ->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.user.email', 'session.user@gmail.com')
            ->assertJsonPath('data.role', 'tourist');

        $this->withToken($token)
            ->postJson('/api/v1/auth/logout')
            ->assertOk();

        // Each production API call has a fresh guard; mirror that boundary in
        // this multi-request feature test before reusing the revoked token.
        Auth::forgetGuards();

        $this->withToken($token)
            ->getJson('/api/v1/auth/me')
            ->assertUnauthorized();
    }

    public function test_admin_create_user_builds_matching_profile_setting_and_audit(): void
    {
        $adminRole = Role::create(['name' => 'admin']);
        $admin = $this->makeUser([
            'email' => 'admin-create@example.com',
            'role_id' => $adminRole->id,
        ]);
        Profile::create([
            'id' => $admin->id,
            'name' => $admin->name,
            'email' => $admin->email,
            'role_id' => $adminRole->id,
            'is_verified' => true,
        ]);

        $createdId = $this->actingAs($admin, 'sanctum')
            ->postJson('/api/v1/admin/users', [
                'name' => 'Managed Tourist',
                'email' => 'managed@example.com',
                'password' => 'safe-password',
                'role_id' => $this->touristRole->id,
                'is_verified' => true,
            ])->assertCreated()->json('data.id');

        $this->assertDatabaseHas('profiles', ['id' => $createdId]);
        $this->assertDatabaseHas('settings', ['user_id' => $createdId]);
        $this->assertDatabaseHas('activity_logs', [
            'user_id' => $admin->id,
            'action' => 'User created',
        ]);
    }

    public function test_identity_reconciliation_backfills_legitimate_profile_mirrors_idempotently(): void
    {
        $user = $this->makeUser(['email' => 'legacy-import@example.com']);
        $this->assertNull(Profile::find($user->id));

        $migration = require database_path(
            'migrations/2026_08_27_000002_reconcile_user_profile_identity.php'
        );
        $migration->up();
        $migration->up();

        $profile = Profile::findOrFail($user->id);
        $this->assertSame($user->id, $profile->id);
        $this->assertSame($user->email, $profile->email);
        $this->assertSame($user->role_id, $profile->role_id);
        $this->assertDatabaseCount('profiles', 1);
    }

    public function test_admin_cannot_archive_self_or_demote_the_last_admin(): void
    {
        $adminRole = Role::create(['name' => 'admin']);
        $admin = $this->makeUser([
            'email' => 'only-admin@example.com',
            'role_id' => $adminRole->id,
        ]);
        Profile::create([
            'id' => $admin->id,
            'name' => $admin->name,
            'email' => $admin->email,
            'role_id' => $adminRole->id,
            'is_verified' => true,
        ]);

        $this->actingAs($admin, 'sanctum')
            ->deleteJson("/api/v1/admin/users/{$admin->id}")
            ->assertUnprocessable()
            ->assertJsonValidationErrors('user');
        $this->actingAs($admin, 'sanctum')
            ->putJson("/api/v1/admin/users/{$admin->id}/role", [
                'role_id' => $this->touristRole->id,
            ])->assertUnprocessable()
            ->assertJsonValidationErrors('role_id');
    }

    public function test_random_authenticated_user_cannot_delete_another_users_image(): void
    {
        $owner = $this->makeUser(['email' => 'image-owner@example.com']);
        $other = $this->makeUser(['email' => 'image-other@example.com']);
        $image = Image::create([
            'url' => 'https://example.test/image.jpg',
            'bucket' => 'test',
            'owner_id' => $owner->id,
        ]);

        $this->actingAs($other, 'sanctum')
            ->deleteJson("/api/v1/images/{$image->id}")
            ->assertForbidden();
        $this->assertDatabaseHas('images', [
            'id' => $image->id,
            'deleted_at' => null,
        ]);
    }

    /** @param array<string, mixed> $overrides */
    private function makeUser(array $overrides = []): User
    {
        return User::create(array_merge([
            'name' => 'Existing User',
            'email' => 'existing@gmail.com',
            'password' => 'safe-password',
            'role_id' => $this->touristRole->id,
            'is_verified' => true,
            'auth_provider' => 'email',
        ], $overrides));
    }

    private function fakeGoogleIdentity(string $subject, string $email): void
    {
        $this->mock(GoogleIdTokenVerifier::class, function (MockInterface $mock) use ($subject, $email) {
            $mock->shouldReceive('verify')->once()->andReturn([
                'sub' => $subject,
                'email' => $email,
                'email_verified' => true,
                'name' => 'Google User',
                'picture' => 'https://example.test/avatar.png',
            ]);
        });
    }

    private function createAuthSchema(): void
    {
        foreach (['personal_access_tokens', 'password_reset_tokens', 'images', 'activity_logs', 'admin_notifications', 'settings', 'profiles', 'users', 'roles'] as $table) {
            Schema::dropIfExists($table);
        }

        Schema::create('roles', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name')->unique();
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('users', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->string('email')->unique();
            $table->string('google_id')->nullable()->unique();
            $table->string('auth_provider')->nullable();
            $table->string('password');
            $table->uuid('role_id')->nullable();
            $table->text('avatar_url')->nullable();
            $table->string('phone')->nullable();
            $table->text('bio')->nullable();
            $table->string('language')->default('en');
            $table->boolean('is_verified')->default(false);
            $table->timestamp('email_verified_at')->nullable();
            $table->string('email_verification_code_hash')->nullable();
            $table->timestamp('email_verification_code_expires_at')->nullable();
            $table->unsignedSmallInteger('email_verification_attempts')->default(0);
            $table->timestamp('email_verification_last_sent_at')->nullable();
            $table->rememberToken();
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('profiles', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->string('email');
            $table->uuid('role_id');
            $table->text('avatar_url')->nullable();
            $table->string('phone')->nullable();
            $table->text('bio')->nullable();
            $table->string('language')->default('en');
            $table->boolean('is_verified')->default(false);
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('settings', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id')->unique();
            $table->boolean('notifications_enabled')->default(true);
            $table->boolean('location_enabled')->default(true);
            $table->boolean('offline_mode')->default(false);
            $table->string('language')->default('en');
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('admin_notifications', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('title');
            $table->text('body');
            $table->string('type');
            $table->json('data')->nullable();
            $table->boolean('is_read')->default(false);
            $table->timestamp('created_at')->nullable();
        });
        Schema::create('activity_logs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id')->nullable();
            $table->string('action');
            $table->text('details')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('images', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->text('url');
            $table->string('bucket');
            $table->uuid('owner_id');
            $table->timestamps();
            $table->softDeletes();
        });
        Schema::create('personal_access_tokens', function (Blueprint $table) {
            $table->id();
            $table->string('tokenable_type');
            $table->uuid('tokenable_id');
            $table->string('name');
            $table->string('token', 64)->unique();
            $table->text('abilities')->nullable();
            $table->timestamp('last_used_at')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->timestamps();
            $table->index(['tokenable_type', 'tokenable_id']);
        });
        Schema::create('password_reset_tokens', function (Blueprint $table) {
            $table->string('email')->primary();
            $table->string('token');
            $table->timestamp('created_at')->nullable();
        });
    }
}
