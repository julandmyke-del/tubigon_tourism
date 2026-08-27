<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Mail\VerifyEmail;
use App\Models\ActivityLog;
use App\Models\AdminNotification;
use App\Models\Profile;
use App\Models\Role;
use App\Models\Setting;
use App\Models\User;
use App\Services\GoogleIdTokenVerifier;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\Str;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;
use Throwable;

class AuthController extends Controller
{
    /**
     * Existing password accounts allowed to skip email verification locally.
     *
     * This allowlist is intentionally kept server-side and is ineffective
     * unless APP_ENV resolves to "local".
     *
     * @var list<string>
     */
    private const LOCAL_UNVERIFIED_LOGIN_EMAILS = [
        'user@gmail.com',
        'msme@gmail.com',
        'lgu@gmail.com',
        'partner@gmail.com',
        'admin@gmail.com',
    ];

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

        if (! $user->is_verified && ! $this->canBypassEmailVerificationLocally($email)) {
            return response()->json([
                'status' => 'unverified',
                'message' => 'Please verify your email address before logging in.',
                'data' => ['email' => $user->email],
            ], 403);
        }

        return $this->authenticatedResponse($user, 'Login successful');
    }

    private function canBypassEmailVerificationLocally(string $email): bool
    {
        return config('app.env') === 'local'
            && in_array($email, self::LOCAL_UNVERIFIED_LOGIN_EMAILS, true);
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

            $user = User::create([
                'name' => $name !== '' ? $name : 'Google User',
                'email' => $email,
                'password' => Hash::make(Str::random(64)),
                'role_id' => $touristRole->id,
                'is_verified' => true,
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
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:254', 'unique:users,email'],
            'password' => ['required', 'confirmed', Password::min(8)],
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
                ? 'Registration successful. Check your email inbox to verify your account.'
                : 'Your account was created, but the verification email could not be sent. Please use Resend Email.',
            'data' => [
                'requires_verification' => true,
                'email' => $user->email,
                'email_sent' => $emailSent,
            ],
        ], 201);
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
            $user->forceFill(['is_verified' => true])->save();
            Profile::where('id', $user->id)->update(['is_verified' => true]);

            ActivityLog::create([
                'user_id' => $user->id,
                'action' => 'Email Verified',
                'details' => "User email address verified: {$user->email}",
            ]);
        });

        return response()->view('emails.verify-result', ['status' => 'success']);
    }

    /** POST /api/v1/auth/email/verification-notification */
    public function resendVerificationEmail(Request $request): JsonResponse
    {
        $validated = $request->validate(['email' => ['required', 'email']]);
        $email = Str::lower(trim($validated['email']));
        $user = User::whereRaw('LOWER(email) = ?', [$email])->first();

        // Deliberately return the same success response for unknown accounts.
        if (! $user) {
            return response()->json([
                'status' => 'success',
                'message' => 'If an account exists with this email, a verification link has been sent.',
            ]);
        }

        if ($user->is_verified) {
            return response()->json([
                'status' => 'already_verified',
                'message' => 'Your email address is already verified.',
            ]);
        }

        if (! $this->sendVerificationEmail($user)) {
            return response()->json([
                'status' => 'error',
                'message' => 'The verification email could not be sent. Please try again later.',
            ], 503);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'A new verification email has been sent to your email address.',
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
                'email' => $email,
                'is_verified' => (bool) $user?->is_verified,
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
                'user' => $this->userPayload($user),
                'role' => $user->role?->name ?? 'tourist',
            ],
        ]);
    }

    public function forgotPassword(Request $request): JsonResponse
    {
        $request->validate(['email' => ['required', 'email']]);

        return response()->json([
            'status' => 'success',
            'message' => 'If an account exists with this email, a password reset link has been sent.',
        ]);
    }

    public function updatePassword(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'current_password' => ['required', 'string'],
            'password' => ['required', 'confirmed', Password::min(8)],
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
        $minutes = max(5, min(1440, (int) config('auth.verification.expire', 60)));
        $verificationUrl = URL::temporarySignedRoute(
            'verification.verify',
            now()->addMinutes($minutes),
            ['id' => $user->id, 'hash' => sha1($user->email)]
        );

        try {
            Mail::to($user->email, $user->name)->send(new VerifyEmail(
                userName: $user->name,
                verificationUrl: $verificationUrl,
                expiresInMinutes: $minutes,
            ));

            return true;
        } catch (Throwable $exception) {
            // Never log the signed URL or credentials.
            Log::warning('Verification email delivery failed.', [
                'user_id' => $user->id,
                'exception' => $exception::class,
            ]);

            return false;
        }
    }
}
