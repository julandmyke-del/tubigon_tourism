<?php

namespace App\Support;

final class ReservationStatusTransitions
{
    /** @var array<string, list<string>> */
    private const ALLOWED = [
        'pending' => ['approved', 'confirmed', 'rejected', 'cancelled'],
        'approved' => ['confirmed', 'completed', 'cancelled'],
        'confirmed' => ['completed', 'cancelled'],
        'rejected' => [],
        'completed' => [],
        'cancelled' => [],
    ];

    public static function allows(?string $from, string $to): bool
    {
        if ($from === $to) {
            return true;
        }

        return in_array($to, self::ALLOWED[$from ?? ''] ?? [], true);
    }

    /** @return list<string> */
    public static function allowedFrom(?string $from): array
    {
        return self::ALLOWED[$from ?? ''] ?? [];
    }
}
