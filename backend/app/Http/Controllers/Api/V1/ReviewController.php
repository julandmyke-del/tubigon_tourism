<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Review;
use App\Models\ActivityLog;
use App\Models\Notification;
use App\Models\PartnerNotification;
use App\Models\SystemSetting;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class ReviewController extends Controller
{
    private const MODERATION_REASONS = [
        'spam',
        'offensive_content',
        'harassment',
        'false_information',
        'irrelevant_content',
        'privacy_information',
        'duplicate',
        'community_guidelines',
        'other',
    ];

    public function index(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'reviewable_type' => 'required|in:spot,msme,tourism_listing',
            'reviewable_id' => 'required|uuid',
        ]);
        abort_unless($this->publicReviewTargetExists(
            $validated['reviewable_type'],
            $validated['reviewable_id'],
        ), 404, 'The selected place is not publicly available.');

        $query = Review::with('user:id,name')
            ->where('reviewable_type', $validated['reviewable_type'])
            ->where('reviewable_id', $validated['reviewable_id']);

        $reviews = $query->orderBy('created_at', 'desc')->get();
        return response()->json(['status' => 'success', 'data' => $reviews]);
    }

    public function managementIndex(): JsonResponse
    {
        $reviews = Review::with('user:id,name')
            ->orderByDesc('created_at')
            ->get();

        return response()->json(['status' => 'success', 'data' => $reviews]);
    }

    public function store(Request $request): JsonResponse
    {
        abort_unless(SystemSetting::enabled('reviews_enabled'), 403, 'Reviews are currently disabled.');
        $request->user()->loadMissing('role');
        abort_unless($request->user()->role?->name === 'tourist', 403, 'Only Tourist accounts may submit reviews.');

        $validated = $request->validate([
            'reviewable_type' => 'required|in:spot,msme,tourism_listing',
            'reviewable_id' => 'required|uuid',
            'rating' => 'required|integer|min:1|max:5',
            'content' => 'required|string|min:3|max:1000',
            'images' => 'nullable|array',
        ]);

        abort_unless($this->publicReviewTargetExists(
            $validated['reviewable_type'],
            $validated['reviewable_id'],
        ), 422, 'The selected place is not publicly available for reviews.');

        if (Review::where('user_id', $request->user()->id)
            ->where('reviewable_type', $validated['reviewable_type'])
            ->where('reviewable_id', $validated['reviewable_id'])
            ->exists()) {
            throw ValidationException::withMessages([
                'reviewable_id' => ['You have already reviewed this place.'],
            ]);
        }

        $validated['user_id'] = $request->user()->id;
        $review = DB::transaction(function () use ($validated): Review {
            $review = Review::create($validated);
            $this->refreshTargetRating(
                $validated['reviewable_type'],
                $validated['reviewable_id'],
            );
            if ($validated['reviewable_type'] === 'msme') {
                $target = DB::table('msmes')->where('id', $validated['reviewable_id'])->first();
                if ($target?->profile_id) Notification::create([
                    'user_id' => $target->profile_id, 'type' => 'new_review', 'title' => 'New Business Review',
                    'body' => 'A tourist reviewed your business.',
                    'data' => ['review_id' => $review->id, 'route' => '/msme-portal/reviews'],
                ]);
            } elseif ($validated['reviewable_type'] === 'tourism_listing') {
                $target = DB::table('tourism_listings')->where('id', $validated['reviewable_id'])->first();
                if ($target?->owner_id) PartnerNotification::create([
                    'user_id' => $target->owner_id, 'type' => 'new_review', 'title' => 'New Listing Review',
                    'body' => 'A tourist reviewed your listing.',
                    'data' => ['review_id' => $review->id, 'listing_id' => $target->id, 'route' => '/tourism-partner/reviews'],
                ]);
            } elseif ($validated['reviewable_type'] === 'spot'
                && Schema::hasTable('tourist_spot_partner_assignments')) {
                DB::table('tourist_spot_partner_assignments')
                    ->where('tourist_spot_id', $validated['reviewable_id'])
                    ->pluck('partner_profile_id')
                    ->unique()
                    ->each(fn (string $partnerId) => PartnerNotification::create([
                        'user_id' => $partnerId,
                        'type' => 'new_review',
                        'title' => 'New Destination Review',
                        'body' => 'A tourist reviewed your managed destination.',
                        'data' => [
                            'review_id' => $review->id,
                            'tourist_spot_id' => $validated['reviewable_id'],
                            'route' => '/tourism-partner/reviews',
                        ],
                    ]));
            }
            return $review;
        });

        return response()->json([
            'status' => 'success',
            'data' => $review->load('user:id,name'),
        ], 201);
    }

    private function publicReviewTargetExists(string $type, string $id): bool
    {
        $query = match ($type) {
            'spot' => DB::table('tourist_spots')
                ->where('is_active', true)
                ->when(
                    Schema::hasColumn('tourist_spots', 'is_published'),
                    fn ($query) => $query->where('is_published', true),
                ),
            'msme' => DB::table('msmes')->where('is_verified', true)->where('verification_status', 'verified'),
            'tourism_listing' => DB::table('tourism_listings')
                ->where('is_active', true)
                ->where('approval_status', 'approved'),
        };

        return $query->where('id', $id)->whereNull('deleted_at')->exists();
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        $review = Review::findOrFail($id);
        $user = $request->user();
        $user->loadMissing('role');
        $isAdmin = $user->role?->name === 'admin';
        if (! $isAdmin && (string) $review->user_id !== (string) $user->id) {
            abort(403, 'You may only delete your own reviews.');
        }
        $moderation = $isAdmin ? $request->validate([
            'reason_code' => ['required', Rule::in(self::MODERATION_REASONS)],
            'reason_detail' => 'nullable|required_if:reason_code,other|string|max:1000',
        ]) : [];

        DB::transaction(function () use ($request, $review, $isAdmin, $moderation): void {
            $type = $review->reviewable_type;
            $targetId = $review->reviewable_id;
            $review->delete();
            $this->refreshTargetRating($type, $targetId);
            $audit = [
                'review_id' => $review->id,
                'owner_id' => $review->user_id,
                'moderator_id' => $isAdmin ? $request->user()->id : null,
                'target_type' => $type,
                'target_id' => $targetId,
                'reason_code' => $moderation['reason_code'] ?? 'owner_deleted',
                'reason_detail' => $moderation['reason_detail'] ?? null,
            ];
            $logData = [
                'user_id' => $request->user()->id,
                'action' => $isAdmin ? 'Review removed by administrator' : 'Review deleted by owner',
                'details' => json_encode($audit, JSON_THROW_ON_ERROR),
            ];
            if (Schema::hasColumn('activity_logs', 'target_type')) {
                $logData['target_type'] = 'review';
            }
            if (Schema::hasColumn('activity_logs', 'target_id')) {
                $logData['target_id'] = $review->id;
            }
            if (Schema::hasColumn('activity_logs', 'metadata')) {
                $logData['metadata'] = $audit;
            }
            ActivityLog::create($logData);
            if ($isAdmin) {
                $label = $this->moderationReasonLabel($moderation['reason_code']);
                Notification::create([
                    'user_id' => $review->user_id,
                    'type' => 'review_removed',
                    'title' => 'Review Removed',
                    'body' => "Your review was removed by an administrator. Reason: {$label}",
                    'data' => [
                        'review_id' => $review->id,
                        'reason_code' => $moderation['reason_code'],
                        'reason' => $label,
                        'reason_detail' => $moderation['reason_detail'] ?? null,
                        'route' => '/notifications',
                    ],
                ]);
            }
        });
        return response()->json([
            'status' => 'success',
            'message' => $isAdmin ? 'Review removed' : 'Review deleted',
        ]);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $request->user()->loadMissing('role');
        abort_unless($request->user()->role?->name === 'tourist', 403, 'Only Tourist accounts may edit reviews.');
        $review = Review::findOrFail($id);
        abort_unless((string) $review->user_id === (string) $request->user()->id, 403, 'You may only edit your own reviews.');
        $validated = $request->validate([
            'rating' => 'required|integer|min:1|max:5',
            'content' => 'required|string|min:3|max:1000',
        ]);
        DB::transaction(function () use ($review, $validated): void {
            $review->update($validated);
            $this->refreshTargetRating($review->reviewable_type, $review->reviewable_id);
        });

        return response()->json([
            'status' => 'success',
            'data' => $review->fresh()->load('user:id,name'),
        ]);
    }

    private function moderationReasonLabel(string $code): string
    {
        return match ($code) {
            'offensive_content' => 'Offensive or inappropriate content',
            'false_information' => 'False or misleading information',
            'irrelevant_content' => 'Irrelevant content',
            'privacy_information' => 'Privacy or personal information',
            'community_guidelines' => 'Community-guideline violation',
            default => str($code)->replace('_', ' ')->title()->toString(),
        };
    }

    private function refreshTargetRating(string $type, string $id): object
    {
        $stats = Review::where('reviewable_type', $type)
            ->where('reviewable_id', $id)
            ->selectRaw('AVG(rating) average, COUNT(*) total')
            ->first();
        $values = [
            $type === 'msme' ? 'rating' : 'average_rating' => round((float) ($stats->average ?? 0), 2),
            'review_count' => (int) ($stats->total ?? 0),
        ];
        $table = match ($type) {
            'spot' => 'tourist_spots',
            'msme' => 'msmes',
            'tourism_listing' => 'tourism_listings',
        };
        DB::table($table)->where('id', $id)->update($values);

        return $stats;
    }
}
