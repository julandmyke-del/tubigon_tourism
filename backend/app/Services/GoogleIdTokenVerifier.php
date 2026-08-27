<?php

namespace App\Services;

use Google\Client as GoogleClient;
use RuntimeException;

class GoogleIdTokenVerifier
{
    /**
     * Verify a Google-issued OpenID Connect ID token for this application.
     *
     * @return array<string, mixed>
     */
    public function verify(string $idToken): array
    {
        $clientId = (string) config('services.google.client_id');

        if ($clientId === '') {
            throw new RuntimeException('Google authentication is not configured.');
        }

        $client = new GoogleClient(['client_id' => $clientId]);
        $payload = $client->verifyIdToken($idToken);

        if (! is_array($payload)) {
            throw new RuntimeException('The Google identity token is invalid or expired.');
        }

        if (($payload['email_verified'] ?? false) !== true && ($payload['email_verified'] ?? null) !== 'true') {
            throw new RuntimeException('The Google account email is not verified.');
        }

        if (empty($payload['sub']) || empty($payload['email'])) {
            throw new RuntimeException('The Google identity token is missing required claims.');
        }

        return $payload;
    }
}
