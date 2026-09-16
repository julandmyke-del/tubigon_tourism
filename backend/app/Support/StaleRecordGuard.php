<?php

namespace App\Support;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

final class StaleRecordGuard
{
    public static function expectedUpdatedAt(Request $request): ?string
    {
        $validated = $request->validate([
            'expected_updated_at' => ['sometimes', 'required', 'date'],
        ]);

        return $validated['expected_updated_at'] ?? null;
    }

    /**
     * Assert that a client is still editing the version it originally loaded.
     * The enclosing transaction must hold a row lock before calling this.
     *
     * @param  array<string, mixed>  $current
     */
    public static function assertCurrent(
        Model $model,
        ?string $expectedUpdatedAt,
        array $current = [],
        string $message = 'This record was updated in another session. Refresh and try again.',
    ): void {
        if ($expectedUpdatedAt === null) {
            // Backward-compatible rollout for older installed clients. Updated
            // clients always send the version; no timestamp means no false 409.
            return;
        }

        $actual = $model->getAttribute('updated_at');
        $matches = $actual !== null
            && Carbon::parse($expectedUpdatedAt)->utc()->equalTo(Carbon::parse($actual)->utc());

        if ($matches) {
            return;
        }

        abort(response()->json([
            'status' => 'error',
            'message' => $message,
            'code' => 'stale_record',
            'current' => array_merge([
                'id' => $model->getKey(),
                'updated_at' => $actual?->toIso8601String(),
            ], $current),
        ], 409));
    }
}
