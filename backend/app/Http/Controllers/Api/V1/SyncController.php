<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\ValidatesTubigonCoordinates;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class SyncController extends Controller
{
    use ValidatesTubigonCoordinates;

    /**
     * POST /api/v1/sync/push
     * Receives dirty records from the Flutter client and upserts them.
     */
    public function push(Request $request): JsonResponse
    {
        $request->validate([
            'table' => 'required|string',
            'records' => 'required|array',
        ]);

        $table = $request->table;
        $records = $request->records;

        $allowedTables = [
            'reservations', 'reviews', 'favorites', 'waste_reports',
        ];

        if (!in_array($table, $allowedTables)) {
            return response()->json([
                'status' => 'error',
                'message' => "Table '$table' is not syncable.",
            ], 400);
        }

        $synced = 0;
        foreach ($records as $record) {
            if (! is_array($record)) {
                continue;
            }

            $clean = $this->validatedCreatePayload($table, $record, (string) $request->user()->id);
            $existing = DB::table($table)->where('id', $clean['id'])->first();
            if ($existing !== null) {
                if ((string) $existing->user_id !== (string) $request->user()->id) {
                    abort(403, 'A synchronized record cannot replace another user\'s data.');
                }
                // Sync creates are immutable after acceptance; protected updates use feature APIs.
                continue;
            }

            if ($table === 'favorites') {
                $alreadyFavorite = DB::table($table)
                    ->where('user_id', $clean['user_id'])
                    ->where('favoritable_type', $clean['favoritable_type'])
                    ->where('favoritable_id', $clean['favoritable_id'])
                    ->exists();
                if ($alreadyFavorite) {
                    continue;
                }
                DB::table($table)->insert($clean);
            } else {
                DB::table($table)->insert($clean);
            }
            $synced++;
        }

        return response()->json([
            'status' => 'success',
            'message' => "Synced $synced records to $table",
            'data' => ['synced_count' => $synced],
        ]);
    }

    private function validatedCreatePayload(string $table, array $record, string $userId): array
    {
        $record['user_id'] = $userId;

        if ($table === 'reservations') {
            $data = Validator::make($record, [
                'id' => 'required|uuid',
                'reservable_type' => 'required|in:spot,msme,tourism_listing',
                'reservable_id' => 'required|uuid',
                'reservation_date' => 'required|date|after_or_equal:today',
                'start_time' => 'nullable|date_format:H:i',
                'end_time' => 'nullable|date_format:H:i|after:start_time',
                'guests' => 'required|integer|min:1|max:100',
                'notes' => 'nullable|string|max:1000',
            ])->validate();

            $source = match ($data['reservable_type']) {
                'spot' => DB::table('tourist_spots')->where('id', $data['reservable_id'])->where('is_active', true)->first(),
                'msme' => DB::table('msmes')->where('id', $data['reservable_id'])->where('is_verified', true)->first(),
                'tourism_listing' => DB::table('tourism_listings')->where('id', $data['reservable_id'])->where('is_active', true)->first(),
            };
            abort_if($source === null, 422, 'The selected destination is not available for reservations.');

            $duplicate = DB::table('reservations')
                ->where('user_id', $userId)
                ->where('reservable_type', $data['reservable_type'])
                ->where('reservable_id', $data['reservable_id'])
                ->where('reservation_date', $data['reservation_date'])
                ->where('start_time', $data['start_time'] ?? null)
                ->whereNotIn('status_id', DB::table('reservation_status')->whereIn('name', ['cancelled', 'rejected'])->pluck('id'))
                ->exists();
            abort_if($duplicate, 422, 'A matching reservation already exists.');

            $pendingStatusId = DB::table('reservation_status')->where('name', 'pending')->value('id');
            abort_if($pendingStatusId === null, 500, 'Pending reservation status is not configured.');

            return array_merge($data, [
                'user_id' => $userId,
                'partner_id' => $data['reservable_type'] === 'tourism_listing' ? $source->owner_id : null,
                'status_id' => $pendingStatusId,
                'total_amount' => $data['reservable_type'] === 'spot'
                    ? ((float) ($source->entrance_fee ?? 0) * (int) $data['guests'])
                    : 0,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        if ($table === 'reviews') {
            $data = Validator::make($record, [
                'id' => 'required|uuid',
                'reviewable_type' => 'required|in:spot,msme,tourism_listing',
                'reviewable_id' => 'required|uuid',
                'rating' => 'required|integer|min:1|max:5',
                'content' => 'required|string|min:3|max:1000',
            ])->validate();
            return array_merge($data, [
                'user_id' => $userId,
                'images' => json_encode([]),
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        if ($table === 'favorites') {
            $data = Validator::make($record, [
                'id' => 'required|uuid',
                'favoritable_type' => 'required|in:spot,msme,tourism_listing,map_location',
                'favoritable_id' => 'required|uuid',
            ])->validate();
            return array_merge($data, [
                'user_id' => $userId,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        $record['images'] = is_string($record['images'] ?? null)
            ? json_decode($record['images'], true)
            : ($record['images'] ?? []);
        $data = Validator::make($record, [
            'id' => 'required|uuid',
            'category' => 'required|in:Plastic Waste,Coastal Pollution,Illegal Dumping,Overflowing Bin,Hazardous Material,Other',
            'description' => 'required|string|min:10|max:2000',
            'location_description' => 'nullable|string|max:500',
            'latitude' => 'required|numeric|between:-90,90',
            'longitude' => 'required|numeric|between:-180,180',
            'images' => 'nullable|array|max:5',
            'images.*' => 'string|max:2048',
        ])->validate();
        $this->validateTubigonCoordinates($data);

        return array_merge($data, [
            'user_id' => $userId,
            'images' => json_encode($data['images'] ?? []),
            'status' => 'pending',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    /**
     * GET /api/v1/sync/pull
     * Returns records updated after a given timestamp.
     */
    public function pull(Request $request): JsonResponse
    {
        $request->validate([
            'table' => 'required|string',
            'last_synced' => 'nullable|date',
        ]);

        $table = $request->table;
        $lastSynced = $request->last_synced;

        $allowedTables = [
            'tourist_spots', 'spot_categories', 'establishments', 'msmes',
            'ferry_schedules', 'eco_tips', 'emergency_contacts', 'announcements',
            'reservations', 'reviews', 'favorites', 'waste_reports', 'notifications',
            'tourism_listings', 'partner_notifications',
        ];

        if (!in_array($table, $allowedTables)) {
            return response()->json([
                'status' => 'error',
                'message' => "Table '$table' is not syncable.",
            ], 400);
        }

        $query = DB::table($table);
        if (in_array($table, ['reservations', 'reviews', 'favorites', 'waste_reports', 'notifications'], true)) {
            $query->where('user_id', $request->user()->id);
        } elseif ($table === 'partner_notifications') {
            $query->where('user_id', $request->user()->id);
        } elseif ($table === 'tourism_listings') {
            $query->where('owner_id', $request->user()->id);
        }
        if ($lastSynced) {
            $query->where('updated_at', '>', $lastSynced);
        }

        $records = $query->get();

        return response()->json([
            'status' => 'success',
            'data' => $records,
        ]);
    }

    /**
     * GET /api/v1/sync/status
     */
    public function status(): JsonResponse
    {
        return response()->json([
            'status' => 'success',
            'data' => ['server_time' => now()->toIso8601String()],
        ]);
    }
}
