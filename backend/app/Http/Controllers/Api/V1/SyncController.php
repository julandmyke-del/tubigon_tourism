<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\ValidatesTubigonCoordinates;
use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Notification;
use App\Models\PartnerNotification;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
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
        $request->user()->loadMissing('role');
        abort_unless($request->user()->role?->name === 'tourist', 403, 'Offline Tourist mutations are not available to this role.');

        $request->validate([
            'table' => 'required|string',
            'records' => 'required|array',
        ]);

        $table = $request->table;
        $records = $request->records;

        $allowedTables = [
            'reviews', 'favorites', 'waste_reports',
        ];

        if (! in_array($table, $allowedTables)) {
            return response()->json([
                'status' => 'error',
                'message' => "Table '$table' is not syncable.",
            ], 400);
        }

        $synced = 0;
        $syncedIds = [];
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
                $syncedIds[] = $clean['id'];

                continue;
            }

            if ($table === 'favorites') {
                $alreadyFavorite = DB::table($table)
                    ->where('user_id', $clean['user_id'])
                    ->where('favoritable_type', $clean['favoritable_type'])
                    ->where('favoritable_id', $clean['favoritable_id'])
                    ->exists();
                if ($alreadyFavorite) {
                    $syncedIds[] = $clean['id'];

                    continue;
                }
                DB::table($table)->insert($clean);
            } else {
                DB::table($table)->insert($clean);
            }
            $this->afterSyncedCreate($table, $clean);
            $synced++;
            $syncedIds[] = $clean['id'];
        }

        return response()->json([
            'status' => 'success',
            'message' => "Synced $synced records to $table",
            'data' => [
                'synced_count' => $synced,
                'synced_ids' => $syncedIds,
            ],
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
                'msme' => DB::table('msmes')->where('id', $data['reservable_id'])
                    ->where('is_verified', true)
                    ->where('verification_status', 'verified')
                    ->where('operational_status', 'open')
                    ->when(
                        Schema::hasColumn('msmes', 'booking_enabled'),
                        fn ($query) => $query->where('booking_enabled', true),
                    )->first(),
                'tourism_listing' => DB::table('tourism_listings')->where('id', $data['reservable_id'])->where('is_active', true)->where('approval_status', 'approved')->first(),
            };
            abort_if($source === null, 422, 'The selected destination is not available for reservations.');

            $bookingMoment = Carbon::parse($data['reservation_date'].' '.($data['start_time'] ?? '00:00'));
            abort_if($bookingMoment->isPast(), 422, 'The selected booking time has already passed.');
            if ($data['reservable_type'] === 'msme') {
                $unavailable = is_string($source->unavailable_dates ?? null)
                    ? json_decode($source->unavailable_dates, true)
                    : ($source->unavailable_dates ?? []);
                abort_if(in_array($data['reservation_date'], $unavailable ?: [], true), 422, 'The business is unavailable on the selected date.');
                $openingHours = is_string($source->opening_hours ?? null)
                    ? json_decode($source->opening_hours, true)
                    : ($source->opening_hours ?? []);
                $hours = $openingHours[strtolower($bookingMoment->format('l'))] ?? null;
                abort_if(is_array($hours) && ($hours['closed'] ?? false), 422, 'The business is closed on the selected day.');
            }
            if ($data['reservable_type'] === 'tourism_listing') {
                abort_if($source->capacity !== null && (int) $data['guests'] > (int) $source->capacity, 422, 'Guest count exceeds this listing\'s capacity.');
                $availableDays = is_string($source->available_days ?? null)
                    ? json_decode($source->available_days, true)
                    : ($source->available_days ?? []);
                abort_if($availableDays && ! in_array(strtolower($bookingMoment->format('l')), $availableDays, true), 422, 'This listing is not available on the selected day.');
                abort_if((int) ($source->booking_cutoff_hours ?? 0) > 0 && $bookingMoment->lt(now()->addHours((int) $source->booking_cutoff_hours)), 422, 'This booking is inside the listing cutoff period.');
            }

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
                'partner_id' => match ($data['reservable_type']) {
                    'tourism_listing' => $source->owner_id,
                    'msme' => $source->profile_id,
                    default => null,
                },
                'status_id' => $pendingStatusId,
                'total_amount' => $data['reservable_type'] === 'spot'
                    ? ((float) ($source->entrance_fee ?? 0) * (int) $data['guests'])
                    : ($data['reservable_type'] === 'tourism_listing'
                        ? ((float) ($source->price ?? 0) * (int) $data['guests'])
                        : 0),
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
            $target = match ($data['reviewable_type']) {
                'spot' => DB::table('tourist_spots')
                    ->where('is_active', true)
                    ->when(
                        Schema::hasColumn('tourist_spots', 'is_published'),
                        fn ($query) => $query->where('is_published', true),
                    ),
                'msme' => DB::table('msmes')->where('is_verified', true)->where('verification_status', 'verified'),
                'tourism_listing' => DB::table('tourism_listings')->where('is_active', true)->where('approval_status', 'approved'),
            };
            abort_unless($target->where('id', $data['reviewable_id'])->whereNull('deleted_at')->exists(), 422, 'The selected place is not publicly available for reviews.');
            abort_if(DB::table('reviews')
                ->where('user_id', $userId)
                ->where('reviewable_type', $data['reviewable_type'])
                ->where('reviewable_id', $data['reviewable_id'])
                ->where('id', '<>', $data['id'])
                ->whereNull('deleted_at')
                ->exists(), 422, 'You have already reviewed this place.');

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
            $available = match ($data['favoritable_type']) {
                'spot' => DB::table('tourist_spots')
                    ->where('is_active', true)
                    ->when(
                        Schema::hasColumn('tourist_spots', 'is_published'),
                        fn ($query) => $query->where('is_published', true),
                    ),
                'msme' => DB::table('msmes')->where('is_verified', true)->where('verification_status', 'verified'),
                'tourism_listing' => DB::table('tourism_listings')->where('is_active', true)->where('approval_status', 'approved'),
                'map_location' => DB::table('map_locations')
                    ->where('verified', true)
                    ->where('published', true)
                    ->where('active', true),
            };
            abort_unless(
                $available->where('id', $data['favoritable_id'])
                    ->whereNull('deleted_at')
                    ->exists(),
                422,
                'The selected place is not publicly available.',
            );

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
            'category' => 'required|in:garbage,water_pollution,beach_coastal,environmental_damage,road_infrastructure,public_facility,safety,tourism_site,marine_wildlife,other,Plastic Waste,Coastal Pollution,Illegal Dumping,Overflowing Bin,Hazardous Material,Other',
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
            'status' => 'submitted',
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

        if (! in_array($table, $allowedTables)) {
            return response()->json([
                'status' => 'error',
                'message' => "Table '$table' is not syncable.",
            ], 400);
        }

        $query = DB::table($table);
        $request->user()->loadMissing('role');
        $role = $request->user()->role?->name;
        $isMunicipalManager = in_array($role, ['admin', 'lgu_staff'], true);
        if (in_array($table, ['reservations', 'reviews', 'favorites', 'waste_reports', 'notifications'], true)) {
            $query->where('user_id', $request->user()->id);
        } elseif ($table === 'partner_notifications') {
            $query->where('user_id', $request->user()->id);
        } elseif ($table === 'tourism_listings') {
            if ($role === 'tourism_partner') {
                $query->where('owner_id', $request->user()->id);
            } elseif (! $isMunicipalManager) {
                $query->where('is_active', true)->where('approval_status', 'approved');
            }
        } elseif ($table === 'msmes' && ! $isMunicipalManager) {
            if ($role === 'msme_owner') {
                $query->where(function ($ownerQuery) use ($request): void {
                    $ownerQuery->where('profile_id', $request->user()->id)
                        ->orWhere(function ($publicQuery): void {
                            $publicQuery->where('is_verified', true)->where('verification_status', 'verified');
                        });
                });
            } else {
                $query->where('is_verified', true)->where('verification_status', 'verified');
            }
        } elseif ($table === 'emergency_contacts' && ! $isMunicipalManager) {
            $query->where('is_active', true)->where('is_verified', true);
        } elseif ($table === 'tourist_spots' && ! $isMunicipalManager) {
            $query->where('is_active', true);
        } elseif ($table === 'establishments' && ! $isMunicipalManager) {
            $query->where('is_active', true)->where('is_verified', true);
        } elseif ($table === 'announcements' && ! $isMunicipalManager) {
            $query->where('is_active', true);
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

    private function afterSyncedCreate(string $table, array $record): void
    {
        if ($table === 'reservations') {
            if ($record['reservable_type'] === 'tourism_listing' && $record['partner_id']) {
                PartnerNotification::create([
                    'user_id' => $record['partner_id'],
                    'type' => 'new_reservation',
                    'title' => 'New Reservation',
                    'body' => 'You have a new reservation request.',
                    'data' => ['reservation_id' => $record['id']],
                ]);
            } elseif ($record['reservable_type'] === 'msme' && $record['partner_id']) {
                Notification::create([
                    'user_id' => $record['partner_id'],
                    'type' => 'new_reservation',
                    'title' => 'New Reservation',
                    'body' => 'A new business reservation is awaiting review.',
                    'data' => ['reservation_id' => $record['id'], 'route' => '/msme-portal/reservations'],
                ]);
            }

            return;
        }

        if ($table === 'reviews') {
            $type = $record['reviewable_type'];
            $targetId = $record['reviewable_id'];
            $stats = DB::table('reviews')
                ->where('reviewable_type', $type)
                ->where('reviewable_id', $targetId)
                ->whereNull('deleted_at')
                ->selectRaw('AVG(rating) average, COUNT(*) total')
                ->first();
            $targetTable = match ($type) {
                'spot' => 'tourist_spots',
                'msme' => 'msmes',
                'tourism_listing' => 'tourism_listings',
            };
            DB::table($targetTable)->where('id', $targetId)->update([
                $type === 'msme' ? 'rating' : 'average_rating' => round((float) ($stats->average ?? 0), 2),
                'review_count' => (int) ($stats->total ?? 0),
            ]);
            $target = DB::table($targetTable)->where('id', $targetId)->first();
            if ($type === 'msme' && $target?->profile_id) {
                Notification::create([
                    'user_id' => $target->profile_id,
                    'type' => 'new_review',
                    'title' => 'New Business Review',
                    'body' => 'A tourist reviewed your business.',
                    'data' => ['review_id' => $record['id'], 'route' => '/msme-portal/reviews'],
                ]);
            } elseif ($type === 'tourism_listing' && $target?->owner_id) {
                PartnerNotification::create([
                    'user_id' => $target->owner_id,
                    'type' => 'new_review',
                    'title' => 'New Listing Review',
                    'body' => 'A tourist reviewed your listing.',
                    'data' => ['review_id' => $record['id'], 'listing_id' => $targetId, 'route' => '/tourism-partner/reviews'],
                ]);
            } elseif ($type === 'spot' && Schema::hasTable('tourist_spot_partner_assignments')) {
                DB::table('tourist_spot_partner_assignments')
                    ->where('tourist_spot_id', $targetId)
                    ->pluck('partner_profile_id')
                    ->unique()
                    ->each(fn (string $partnerId) => PartnerNotification::create([
                        'user_id' => $partnerId,
                        'type' => 'new_review',
                        'title' => 'New Destination Review',
                        'body' => 'A tourist reviewed your managed destination.',
                        'data' => [
                            'review_id' => $record['id'],
                            'tourist_spot_id' => $targetId,
                            'route' => '/tourism-partner/reviews',
                        ],
                    ]));
            }

            return;
        }

        if ($table === 'waste_reports') {
            ActivityLog::create([
                'user_id' => $record['user_id'],
                'action' => 'Waste report submitted',
                'details' => json_encode(['entity_type' => 'waste_report', 'entity_id' => $record['id']]),
            ]);
            User::whereHas('role', fn ($query) => $query->whereIn('name', ['admin', 'lgu_staff']))
                ->pluck('id')
                ->each(fn (string $id) => Notification::create([
                    'user_id' => $id,
                    'type' => 'waste_report_submitted',
                    'title' => 'New Waste Report',
                    'body' => 'A new waste report is awaiting review.',
                    'data' => ['waste_report_id' => $record['id'], 'route' => '/lgu/waste-reports/'.$record['id']],
                ]));
        }
    }
}
