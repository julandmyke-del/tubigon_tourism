<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Mail\VerifyEmail;
use App\Models\ActivityLog;
use App\Models\AdminNotification;
use App\Models\Profile;
use App\Models\Role;
use App\Models\Setting;
use App\Models\SystemSetting;
use App\Models\User;
use App\Models\UserPreference;
use App\Services\GoogleIdTokenVerifier;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Illuminate\Validation\Rules\Password as PasswordRule;
use Illuminate\Validation\ValidationException;
use Throwable;

class AuthController extends Controller
{
    public function __construct(private readonly GoogleIdTokenVerifier $googleTokenVerifier)
    {
    }

    /** POST /api/v1/auth/login */
    public function login(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $email = Str::lower(trim($validated['email']));
        $user = User::withTrashed()->whereRaw('LOWER(email) = ?', [$email])->first();

        if (! $user || ! is_string($user->password) || ! Hash::check($validated['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['The provided credentials are incorrect.'],
            ]);
        }

        if ($user->trashed()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Account is disabled or suspended. Please contact support.',
            ], 403);
        }

        if (! $user->is_verified && ! $this->canBypassEmailVerificationForDevelopment($email)) {
            return response()->json([
                'status' => 'unverified',
                'message' => 'Please verify your email address before logging in.',
                'data' => $this->verificationPayload($user),
            ], 403);
        }

        return $this->authenticatedResponse($user, 'Login successful');
    }

    private function canBypassEmailVerificationForDevelopment(string $email): bool
    {
        if (! (bool) config('auth.development_allowlist_bypass.enabled', false)) {
            return false;
        }

        $allowlist = array_map(
            static fn (mixed $allowed): string => Str::lower(trim((string) $allowed)),
            (array) config('auth.development_allowlist_bypass.emails', [])
        );

        return in_array(Str::lower(trim($email)), $allowlist, true);
    }

    /** POST /api/v1/auth/google */
    public function googleAuth(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'id_token' => ['required', 'string', 'max:10000'],
        ]);

        try {
            $google = $this->googleTokenVerifier->verify($validated['id_token']);
        } catch (Throwable $exception) {
            $verifierMessage = $exception->getMessage();
            $configurationFailure = $verifierMessage === 'Google authentication is not configured.';
            $connectionFailure = $exception instanceof \GuzzleHttp\Exception\ConnectException;
            $unverifiedEmail = $verifierMessage === 'The Google account email is not verified.';
            $invalidOrExpiredToken = $verifierMessage === 'The Google identity token is invalid or expired.';
            Log::warning('Google authentication rejected.', [
                'exception' => $exception::class,
                'ip' => $request->ip(),
            ]);

            if ($unverifiedEmail) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Your Google account email must be verified before you can continue.',
                ], 403);
            }

            if ($invalidOrExpiredToken) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Google authentication expired. Please try again.',
                ], 401);
            }

            return response()->json([
                'status' => 'error',
                'message' => $configurationFailure || $connectionFailure
                    ? 'Google authentication is temporarily unavailable.'
                    : 'Unable to authenticate with Google. Please try again.',
            ], $configurationFailure || $connectionFailure ? 503 : 401);
        }

        $googleId = (string) $google['sub'];
        $email = Str::lower(trim((string) $google['email']));
        $name = trim((string) ($google['name'] ?? Str::before($email, '@')));
        $avatarUrl = isset($google['picture']) ? (string) $google['picture'] : null;

        if (! filter_var($email, FILTER_VALIDATE_EMAIL)) {
            return response()->json([
                'status' => 'error',
                'message' => 'Google did not provide a valid email address.',
            ], 422);
        }

        $result = DB::transaction(function () use ($googleId, $email, $name, $avatarUrl) {
            $googleUser = User::withTrashed()->where('google_id', $googleId)->lockForUpdate()->first();
            $emailUser = User::withTrashed()->whereRaw('LOWER(email) = ?', [$email])->lockForUpdate()->first();

            if ($googleUser?->trashed()) {
                return ['error' => 'Account is disabled or suspended. Please contact support.', 'code' => 403];
            }

            if ($googleUser) {
                if ($emailUser && $googleUser->id !== $emailUser->id) {
                    return ['error' => 'This email is already associated with another account.', 'code' => 409];
                }

                if (! hash_equals(Str::lower(trim((string) $googleUser->email)), $email)) {
                    return ['error' => 'This Google identity conflicts with another existing account.', 'code' => 409];
                }

                // An already-linked Google account may sign in, but Google auth
                // must never rewrite its password, role, status, or profile.
                return ['user' => $googleUser, 'created' => false];
            }

            if ($emailUser) {
                if ($emailUser->trashed()) {
                    return ['error' => 'Account is disabled or suspended. Please contact support.', 'code' => 403];
                }

                // Email equality alone is not proof that the existing account
                // owner authorized linking. Linking requires a separate secure flow.
                return ['error' => 'This email is already associated with another account.', 'code' => 409];
            }

            $touristRole = Role::where('name', 'tourist')->first();
            if (! $touristRole) {
                return ['error' => 'The default tourist role is not configured.', 'code' => 503];
            }
            if (! SystemSetting::enabled('tourist_registration_enabled')) {
                return ['error' => 'Tourist registration is currently disabled.', 'code' => 403];
            }

            $user = User::create([
                'name' => $name !== '' ? $name : 'Google User',
                'email' => $email,
                'password' => Hash::make(Str::random(64)),
                'role_id' => $touristRole->id,
                'is_verified' => true,
                'email_verified_at' => now(),
                'avatar_url' => $avatarUrl,
                'google_id' => $googleId,
                'auth_provider' => 'google',
            ]);

            $this->createAccountDependencies($user);
            $this->recordRegistration($user, 'google');

            return ['user' => $user, 'created' => true];
        });

        if (isset($result['error'])) {
            return response()->json([
                'status' => 'error',
                'message' => $result['error'],
            ], $result['code']);
        }

        return $this->authenticatedResponse(
            $result['user'],
            $result['created'] ? 'Google registration successful' : 'Google authentication successful'
        );
    }

    /** POST /api/v1/auth/register */
    public function register(Request $request): JsonResponse
    {
        abort_unless(SystemSetting::enabled('tourist_registration_enabled'), 403, 'Tourist registration is currently disabled.');
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:254', 'unique:users,email'],
            'password' => ['required', 'confirmed', PasswordRule::min(8)],
        ]);

        $email = Str::lower(trim($validated['email']));
        $touristRole = Role::where('name', 'tourist')->first();

        if (! $touristRole) {
            return response()->json([
                'status' => 'error',
                'message' => 'Registration is temporarily unavailable.',
            ], 503);
        }

        $user = DB::transaction(function () use ($validated, $email, $touristRole) {
            $user = User::create([
                'name' => trim($validated['name']),
                'email' => $email,
                'password' => $validated['password'],
                'role_id' => $touristRole->id,
                'is_verified' => false,
                'email_verified_at' => null,
                'auth_provider' => 'email',
            ]);

            $this->createAccountDependencies($user);
            $this->recordRegistration($user, 'email');

            return $user;
        });

        $emailSent = $this->sendVerificationEmail($user);

        return response()->json([
            'status' => 'success',
            'message' => $emailSent
                ? 'Registration successful. Enter the code sent to your email to verify your account.'
                : 'Your account was created, but the verification email could not be sent. Please use Resend Email.',
            'data' => [
                'requires_email_verification' => true,
                'requires_verification' => true,
                'email' => $user->email,
                'email_sent' => $emailSent,
                ...$this->verificationPayload($user),
            ],
        ], 201);
    }

    /** POST /api/v1/auth/verify-email-code */
    public function verifyEmailCode(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
            'code' => ['required', 'string', 'regex:/^\d{6}$/'],
        ]);
        $email = Str::lower(trim($validated['email']));
        $maxAttempts = max(1, min(20, (int) config('auth.verification.max_attempts', 5)));

        $result = DB::transaction(function () use ($email, $validated, $maxAttempts): array {
            $user = User::whereRaw('LOWER(email) = ?', [$email])->lockForUpdate()->first();

            if (! $user) {
                return ['error' => 'The verification code is invalid or expired.', 'code' => 422, 'user' => null];
            }

            if ($user->is_verified) {
                return ['error' => 'This email address is already verified.', 'code' => 409, 'user' => $user];
            }

            if (! is_string($user->email_verification_code_hash)) {
                return ['error' => 'Request a new verification code to continue.', 'code' => 422, 'user' => $user];
            }

            if (! $user->email_verification_code_expires_at
                || $user->email_verification_code_expires_at->isPast()) {
                $user->forceFill([
                    'email_verification_code_hash' => null,
                    'email_verification_code_expires_at' => null,
                    'email_verification_attempts' => 0,
                ])->save();

                return ['error' => 'The verification code has expired. Request a new code.', 'code' => 422, 'user' => $user];
            }

            if ($user->email_verification_attempts >= $maxAttempts) {
                return ['error' => 'Too many incorrect attempts. Request a new code.', 'code' => 429, 'user' => $user];
            }

            if (! Hash::check($validated['code'], $user->email_verification_code_hash)) {
                $nextAttempts = $user->email_verification_attempts + 1;
                $user->forceFill(['email_verification_attempts' => $nextAttempts])->save();

                return [
                    'error' => $nextAttempts >= $maxAttempts
                        ? 'Too many incorrect attempts. Request a new code.'
                        : 'The verification code is incorrect.',
                    'code' => $nextAttempts >= $maxAttempts ? 429 : 422,
                    'user' => $user,
                ];
            }

            $user->forceFill([
                'is_verified' => true,
                'email_verified_at' => now(),
                'email_verification_code_hash' => null,
                'email_verification_code_expires_at' => null,
                'email_verification_attempts' => 0,
                'email_verification_last_sent_at' => null,
            ])->save();
            Profile::where('id', $user->id)->update(['is_verified' => true]);

            ActivityLog::create([
                'user_id' => $user->id,
                'action' => 'Email Verified',
                'details' => "User email address verified: {$user->email}",
            ]);

            return ['user' => $user];
        });

        if (isset($result['error'])) {
            return response()->json([
                'status' => 'error',
                'message' => $result['error'],
                'data' => $this->verificationPayload($result['user']),
            ], $result['code']);
        }

        return $this->authenticatedResponse($result['user'], 'Email verified successfully');
    }

    /** GET /api/v1/auth/email/verify/{id}/{hash} */
    public function verifyEmail(Request $request, string $id, string $hash)
    {
        $user = User::find($id);

        if (! $user || ! $request->hasValidSignature() || ! hash_equals(sha1($user->email), $hash)) {
            return response()->view('emails.verify-result', ['status' => 'error'], 403);
        }

        if ($user->is_verified) {
            return response()->view('emails.verify-result', ['status' => 'already_verified']);
        }

        DB::transaction(function () use ($user) {
            $user->forceFill([
                'is_verified' => true,
                'email_verified_at' => $user->email_verified_at ?? now(),
                'email_verification_code_hash' => null,
                'email_verification_code_expires_at' => null,
                'email_verification_attempts' => 0,
                'email_verification_last_sent_at' => null,
            ])->save();
            Profile::where('id', $user->id)->update(['is_verified' => true]);

            ActivityLog::create([
                'user_id' => $user->id,
                'action' => 'Email Verified',
                'details' => "User email address verified: {$user->email}",
            ]);
        });

        return response()->view('emails.verify-result', ['status' => 'success']);
    }

    /** POST /api/v1/auth/resend-verification-code */
    public function resendVerificationEmail(Request $request): JsonResponse
    {
        $validated = $request->validate(['email' => ['required', 'email']]);
        $email = Str::lower(trim($validated['email']));
        $user = User::whereRaw('LOWER(email) = ?', [$email])->first();

        // Deliberately return the same success response for unknown accounts.
        if (! $user) {
            return response()->json([
                'status' => 'success',
                'message' => 'If an account exists with this email, a verification code has been sent.',
                'data' => $this->verificationPayload(null),
            ]);
        }

        if ($user->is_verified) {
            return response()->json([
                'status' => 'already_verified',
                'message' => 'Your email address is already verified.',
                'data' => $this->verificationPayload($user),
            ]);
        }

        $retryAfter = $this->resendAvailableInSeconds($user);
        if ($retryAfter > 0) {
            return response()->json([
                'status' => 'error',
                'message' => "Please wait {$retryAfter} seconds before requesting another code.",
                'data' => $this->verificationPayload($user),
            ], 429);
        }

        if (! $this->sendVerificationEmail($user)) {
            return response()->json([
                'status' => 'error',
                'message' => 'The verification email could not be sent. Please try again later.',
                'data' => $this->verificationPayload($user->fresh()),
            ], 503);
        }

        $user->refresh();

        return response()->json([
            'status' => 'success',
            'message' => 'A new verification code has been sent to your email address.',
            'data' => $this->verificationPayload($user),
        ]);
    }

    /** POST /api/v1/auth/change-unverified-email */
    public function changeUnverifiedEmail(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
            'new_email' => ['required', 'email', 'max:254', 'different:email'],
        ]);
        $email = Str::lower(trim($validated['email']));
        $newEmail = Str::lower(trim($validated['new_email']));
        $user = User::withTrashed()->whereRaw('LOWER(email) = ?', [$email])->first();

        if (! $user || ! is_string($user->password) || ! Hash::check($validated['password'], $user->password)) {
            throw ValidationException::withMessages([
                'password' => ['The password is incorrect.'],
            ]);
        }

        if ($user->trashed() || $user->is_verified || ($user->auth_provider && $user->auth_provider !== 'email')) {
            return response()->json([
                'status' => 'error',
                'message' => 'This email address cannot be changed from the verification screen.',
            ], 403);
        }

        if (User::withTrashed()->whereRaw('LOWER(email) = ?', [$newEmail])->exists()) {
            throw ValidationException::withMessages([
                'new_email' => ['An account with this email already exists.'],
            ]);
        }

        DB::transaction(function () use ($user, $newEmail): void {
            $user->forceFill([
                'email' => $newEmail,
                'email_verification_code_hash' => null,
                'email_verification_code_expires_at' => null,
                'email_verification_attempts' => 0,
                'email_verification_last_sent_at' => null,
            ])->save();
            Profile::where('id', $user->id)->update(['email' => $newEmail]);
        });

        if (! $this->sendVerificationEmail($user)) {
            return response()->json([
                'status' => 'error',
                'message' => 'Your email was changed, but the verification code could not be sent. Try Resend Code.',
                'data' => $this->verificationPayload($user->fresh()),
            ], 503);
        }

        $user->refresh();

        return response()->json([
            'status' => 'success',
            'message' => 'Your email was updated and a new verification code was sent.',
            'data' => $this->verificationPayload($user),
        ]);
    }

    /** GET /api/v1/auth/verification-status */
    public function verificationStatus(Request $request): JsonResponse
    {
        $validated = $request->validate(['email' => ['required', 'email']]);
        $email = Str::lower(trim($validated['email']));
        $user = User::whereRaw('LOWER(email) = ?', [$email])->first();

        return response()->json([
            'status' => 'success',
            'data' => [
                ...$this->verificationPayload($user),
            ],
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()?->delete();

        return response()->json(['status' => 'success', 'message' => 'Logged out successfully']);
    }

    public function me(Request $request): JsonResponse
    {
        $user = $request->user();
        $user->loadMissing('role');

        return response()->json([
            'status' => 'success',
            'data' => [
                'requires_email_verification' => false,
                'user' => $this->userPayload($user),
                'role' => $user->role?->name ?? 'tourist',
            ],
        ]);
    }

    public function forgotPassword(Request $request): JsonResponse
    {
        $validated = $request->validate(['email' => ['required', 'email']]);

        $status = Password::sendResetLink([
            'email' => Str::lower(trim($validated['email'])),
        ]);

        if ($status === Password::RESET_THROTTLED) {
            return response()->json([
                'status' => 'error',
                'message' => 'Please wait before requesting another password reset link.',
            ], 429);
        }

        // Keep the response deliberately identical for known and unknown emails.
        return response()->json([
            'status' => 'success',
            'message' => 'If an account exists with this email, a password reset link has been sent.',
        ]);
    }

    public function resetPassword(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'token' => ['required', 'string'],
            'email' => ['required', 'email'],
            'password' => ['required', 'confirmed', PasswordRule::min(8)],
        ]);

        $status = Password::reset($validated, function (User $user, string $password): void {
            $user->forceFill([
                'password' => $password,
                'remember_token' => Str::random(60),
            ])->save();
            $user->tokens()->delete();
        });

        if ($status !== Password::PASSWORD_RESET) {
            throw ValidationException::withMessages([
                'email' => [__($status)],
            ]);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'Password reset successfully. You can now sign in.',
        ]);
    }

    public function updatePassword(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'current_password' => ['required', 'string'],
            'password' => ['required', 'confirmed', PasswordRule::min(8)],
        ]);

        $user = $request->user();
        if (! is_string($user->password) || ! Hash::check($validated['current_password'], $user->password)) {
            throw ValidationException::withMessages([
                'current_password' => ['The current password is incorrect.'],
            ]);
        }

        $user->update(['password' => $validated['password']]);

        return response()->json(['status' => 'success', 'message' => 'Password updated successfully']);
    }

    private function authenticatedResponse(User $user, string $message): JsonResponse
    {
        $user->loadMissing('role');
        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'status' => 'success',
            'message' => $message,
            'data' => [
                'user' => $this->userPayload($user),
                'token' => $token,
                'role' => $user->role?->name ?? 'tourist',
            ],
        ]);
    }

    /** @return array<string, mixed> */
    private function userPayload(User $user): array
    {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'role_id' => $user->role_id,
            'role' => $user->role?->name ?? 'tourist',
            'avatar_url' => $user->avatar_url,
            'is_verified' => (bool) $user->is_verified,
            'auth_provider' => $user->auth_provider ?: 'email',
            'created_at' => $user->created_at?->toIso8601String(),
        ];
    }

    private function createAccountDependencies(User $user): void
    {
        $this->syncProfile($user);
        Setting::firstOrCreate(['user_id' => $user->id]);
        if (Schema::hasTable('user_preferences')) {
            UserPreference::firstOrCreate(['user_id' => $user->id]);
        }
    }

    private function syncProfile(User $user): void
    {
        Profile::updateOrCreate(
            ['id' => $user->id],
            [
                'name' => $user->name,
                'email' => $user->email,
                'role_id' => $user->role_id,
                'is_verified' => (bool) $user->is_verified,
                'avatar_url' => $user->avatar_url,
            ]
        );
    }

    private function recordRegistration(User $user, string $method): void
    {
        $label = $method === 'google' ? 'Google' : 'Email';

        AdminNotification::create([
            'title' => "New {$label} User Registered",
            'body' => "{$user->name} ({$user->email}) registered via {$label}.",
            'type' => 'user_registration',
            'data' => [
                'user_id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => 'tourist',
                'is_verified' => (bool) $user->is_verified,
                'auth_provider' => $method,
            ],
            'is_read' => false,
        ]);

        ActivityLog::create([
            'user_id' => $user->id,
            'action' => "{$label} Account Registered",
            'details' => "New tourist account registered via {$label}: {$user->email}",
        ]);
    }

    private function sendVerificationEmail(User $user): bool
    {
        $minutes = max(5, min(60, (int) config('auth.verification.expire', 10)));
        $verificationCode = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        $user->forceFill([
            'email_verification_code_hash' => Hash::make($verificationCode),
            'email_verification_code_expires_at' => now()->addMinutes($minutes),
            'email_verification_attempts' => 0,
        ])->save();

        try {
            Mail::to($user->email, $user->name)->send(new VerifyEmail(
                userName: $user->name,
                verificationCode: $verificationCode,
                expiresInMinutes: $minutes,
            ));

            $user->forceFill(['email_verification_last_sent_at' => now()])->save();

            return true;
        } catch (Throwable $exception) {
            $user->forceFill([
                'email_verification_code_hash' => null,
                'email_verification_code_expires_at' => null,
                'email_verification_attempts' => 0,
                'email_verification_last_sent_at' => null,
            ])->save();

            // Never log the verification code or SMTP credentials.
            Log::warning('Verification email delivery failed.', [
                'user_id' => $user->id,
                'exception' => $exception::class,
            ]);

            return false;
        }
    }

    /** @return array<string, mixed> */
    private function verificationPayload(?User $user): array
    {
        $maxAttempts = max(1, min(20, (int) config('auth.verification.max_attempts', 5)));
        $attemptsUsed = min($maxAttempts, max(0, (int) ($user?->email_verification_attempts ?? 0)));
        $expiresAt = $user?->email_verification_code_expires_at;
        $expiresInSeconds = $expiresAt
            ? max(0, (int) now()->diffInSeconds($expiresAt, false))
            : 0;

        return [
            'requires_email_verification' => $user ? ! (bool) $user->is_verified : true,
            'is_verified' => (bool) $user?->is_verified,
            'email' => $user?->email,
            'attempts_used' => $attemptsUsed,
            'attempts_remaining' => max(0, $maxAttempts - $attemptsUsed),
            'max_attempts' => $maxAttempts,
            'expires_at' => $expiresAt?->toIso8601String(),
            'expires_in_seconds' => $expiresInSeconds,
            'resend_available_in_seconds' => $this->resendAvailableInSeconds($user),
            'verification_code_sent' => $user
                ? is_string($user->email_verification_code_hash) && $expiresInSeconds > 0
                : false,
        ];
    }

    private function resendAvailableInSeconds(?User $user): int
    {
        if (! $user?->email_verification_last_sent_at) {
            return 0;
        }

        $cooldown = max(1, min(3600, (int) config('auth.verification.resend_cooldown', 60)));

        return max(0, (int) now()->diffInSeconds(
            $user->email_verification_last_sent_at->copy()->addSeconds($cooldown),
            false
        ));
    }
}
