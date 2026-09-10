<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\UploadTouristSpotMediaRequest;
use App\Models\ActivityLog;
use App\Models\TouristSpot;
use App\Models\TouristSpotMedia;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Storage;
use Throwable;

class TouristSpotGalleryController extends Controller
{
    public function publicIndex(string $spot): JsonResponse
    {
        $touristSpot = TouristSpot::whereKey($spot)
            ->where('is_active', true)
            ->where('is_published', true)
            ->firstOrFail();

        return response()->json([
            'status' => 'success',
            'data' => $touristSpot->media()
                ->where('is_active', true)
                ->get()
                ->map(fn (TouristSpotMedia $media) => $this->payload($media)),
        ]);
    }

    public function manageIndex(Request $request, string $spot): JsonResponse
    {
        $touristSpot = TouristSpot::findOrFail($spot);
        $this->authorizeSpot($request, $touristSpot, false);

        return response()->json([
            'status' => 'success',
            'data' => $touristSpot->media()
                ->withTrashed()
                ->get()
                ->map(fn (TouristSpotMedia $media) => $this->payload($media)),
        ]);
    }

    public function store(
        UploadTouristSpotMediaRequest $request,
        string $spot,
    ): JsonResponse {
        $touristSpot = TouristSpot::findOrFail($spot);
        abort_unless(
            $request->user()->role?->name === 'tourism_partner',
            403,
            'Gallery ownership belongs to the assigned Tourism Partner.',
        );
        Gate::forUser($request->user())
            ->authorize('updateManagedContent', $touristSpot);
        if ($request->filled('booking_offering_id')) {
            abort_unless(
                $touristSpot->bookingOfferings()
                    ->whereKey($request->validated('booking_offering_id'))
                    ->exists(),
                422,
                'The linked offering must belong to this destination.',
            );
        }
        abort_if(
            $touristSpot->media()->where('is_active', true)->count() >= 30,
            422,
            'This gallery has reached its 30-image limit.',
        );

        $file = $request->file('image');
        $path = $file->store("tourist-spots/{$touristSpot->id}", 'public');
        try {
            $media = DB::transaction(function () use (
                $request,
                $touristSpot,
                $file,
                $path,
            ): TouristSpotMedia {
                $cover = $request->boolean('is_cover')
                    || ! $touristSpot->media()->where('is_active', true)->exists();
                if ($cover) {
                    $touristSpot->media()->update(['is_cover' => false]);
                }
                $media = TouristSpotMedia::create([
                    'tourist_spot_id' => $touristSpot->id,
                    'booking_offering_id' => $request->validated('booking_offering_id'),
                    'storage_path' => $path,
                    'mime_type' => $file->getMimeType(),
                    'size_bytes' => $file->getSize(),
                    'caption' => $request->validated('caption'),
                    'media_category' => $request->validated('media_category', 'general'),
                    'sort_order' => (int) $touristSpot->media()->max('sort_order') + 1,
                    'is_cover' => $cover,
                    'is_active' => true,
                    'uploaded_by_user_id' => $request->user()->id,
                ]);
                $this->log($request, 'Gallery image uploaded', $touristSpot, $media);

                return $media;
            }, 3);
        } catch (Throwable $exception) {
            Storage::disk('public')->delete($path);
            throw $exception;
        }

        return response()->json([
            'status' => 'success',
            'data' => $this->payload($media),
        ], 201);
    }

    public function update(
        Request $request,
        string $spot,
        string $media,
    ): JsonResponse {
        $touristSpot = TouristSpot::findOrFail($spot);
        $this->authorizeSpot($request, $touristSpot, true);
        $galleryMedia = $touristSpot->media()->withTrashed()->findOrFail($media);
        $validated = $request->validate([
            'caption' => 'nullable|string|max:255',
            'media_category' => 'nullable|in:general,scenery,facilities,activities,accommodation,food,entrance_access,other',
            'is_active' => 'sometimes|boolean',
            'is_cover' => 'sometimes|boolean',
            'moderation_note' => 'nullable|string|max:1000',
        ]);

        DB::transaction(function () use (
            $request,
            $touristSpot,
            $galleryMedia,
            $validated,
        ): void {
            if (($validated['is_cover'] ?? false) === true) {
                $touristSpot->media()
                    ->whereKeyNot($galleryMedia->id)
                    ->update(['is_cover' => false]);
                $validated['is_active'] = true;
            }
            if (in_array($request->user()->role?->name, ['lgu_staff', 'admin'], true)) {
                $validated['moderated_by_user_id'] = $request->user()->id;
            }
            $galleryMedia->update($validated);
            $this->log(
                $request,
                ($validated['is_cover'] ?? false)
                    ? 'Gallery cover changed'
                    : 'Gallery image updated',
                $touristSpot,
                $galleryMedia,
            );
        }, 3);

        return response()->json([
            'status' => 'success',
            'data' => $this->payload($galleryMedia->fresh()),
        ]);
    }

    public function reorder(Request $request, string $spot): JsonResponse
    {
        $touristSpot = TouristSpot::findOrFail($spot);
        $this->authorizeSpot($request, $touristSpot, true);
        $validated = $request->validate([
            'media_ids' => 'required|array|max:30',
            'media_ids.*' => 'uuid|distinct',
        ]);

        DB::transaction(function () use ($touristSpot, $validated, $request): void {
            foreach ($validated['media_ids'] as $index => $id) {
                abort_unless(
                    $touristSpot->media()->whereKey($id)->exists(),
                    422,
                    'Every media item must belong to this destination.',
                );
                $touristSpot->media()
                    ->whereKey($id)
                    ->update(['sort_order' => $index]);
            }
            $this->log($request, 'Gallery reordered', $touristSpot, null);
        }, 3);

        return response()->json(['status' => 'success']);
    }

    public function content(Request $request, string $media)
    {
        $galleryMedia = TouristSpotMedia::withTrashed()->findOrFail($media);
        $touristSpot = TouristSpot::findOrFail($galleryMedia->tourist_spot_id);
        $public = $galleryMedia->is_active
            && ! $galleryMedia->trashed()
            && $touristSpot->is_active
            && $touristSpot->is_published;
        if (! $public) {
            abort_unless($request->user(), 404);
            $this->authorizeSpot($request, $touristSpot, false);
        }
        abort_unless(
            Storage::disk('public')->exists($galleryMedia->storage_path),
            404,
        );

        return Storage::disk('public')->response(
            $galleryMedia->storage_path,
            null,
            [
                'Content-Type' => $galleryMedia->mime_type,
                'Cache-Control' => 'public, max-age=86400',
                'X-Content-Type-Options' => 'nosniff',
            ],
        );
    }

    private function authorizeSpot(
        Request $request,
        TouristSpot $touristSpot,
        bool $write,
    ): void {
        $role = $request->user()?->role?->name;
        if (in_array($role, ['admin', 'lgu_staff'], true)) {
            return;
        }
        abort_unless($request->user(), 404);
        Gate::forUser($request->user())->authorize(
            $write ? 'updateManagedContent' : 'viewManaged',
            $touristSpot,
        );
    }

    private function payload(TouristSpotMedia $media): array
    {
        return [
            'id' => $media->id,
            'tourist_spot_id' => $media->tourist_spot_id,
            'booking_offering_id' => $media->booking_offering_id,
            'caption' => $media->caption,
            'media_category' => $media->media_category,
            'sort_order' => $media->sort_order,
            'is_cover' => $media->is_cover,
            'is_active' => $media->is_active,
            'mime_type' => $media->mime_type,
            'url' => url("/api/v1/tourist-spot-media/{$media->id}"),
            'updated_at' => $media->updated_at,
        ];
    }

    private function log(
        Request $request,
        string $action,
        TouristSpot $touristSpot,
        ?TouristSpotMedia $media,
    ): void {
        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => $action,
            'details' => json_encode([
                'tourist_spot_id' => $touristSpot->id,
                'media_id' => $media?->id,
            ]),
        ]);
    }
}
