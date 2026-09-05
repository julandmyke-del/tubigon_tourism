<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Favorite;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\ValidationException;

class FavoriteController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $favorites = Favorite::where('user_id', $request->user()->id)
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json(['status' => 'success', 'data' => $favorites]);
    }

    public function toggle(Request $request): JsonResponse
    {
        $request->validate([
            'favoritable_type' => 'required|in:spot,msme,tourism_listing,map_location',
            'favoritable_id' => 'required|uuid',
        ]);

        $userId = $request->user()->id;
        if (! $this->isPubliclyAvailable(
            $request->string('favoritable_type')->toString(),
            $request->string('favoritable_id')->toString(),
        )) {
            throw ValidationException::withMessages([
                'favoritable_id' => ['The selected place is not publicly available.'],
            ]);
        }
        return DB::transaction(function () use ($request, $userId) {
            $existing = Favorite::where('user_id', $userId)
                ->where('favoritable_type', $request->favoritable_type)
                ->where('favoritable_id', $request->favoritable_id)
                ->lockForUpdate()
                ->first();

            if ($existing) {
                $existing->forceDelete();
                return response()->json([
                    'status' => 'success',
                    'message' => 'Removed from favorites',
                    'data' => ['is_favorite' => false],
                ]);
            }

            $favorite = Favorite::create([
                'user_id' => $userId,
                'favoritable_type' => $request->favoritable_type,
                'favoritable_id' => $request->favoritable_id,
            ]);

            return response()->json([
                'status' => 'success',
                'message' => 'Added to favorites',
                'data' => ['is_favorite' => true, 'favorite' => $favorite],
            ]);
        });
    }

    private function isPubliclyAvailable(string $type, string $id): bool
    {
        $query = match ($type) {
            'spot' => DB::table('tourist_spots')
                ->where('is_active', true)
                ->when(
                    Schema::hasColumn('tourist_spots', 'is_published'),
                    fn ($query) => $query->where('is_published', true),
                ),
            'msme' => DB::table('msmes')
                ->where('is_verified', true)
                ->where('verification_status', 'verified'),
            'tourism_listing' => DB::table('tourism_listings')
                ->where('is_active', true)
                ->where('approval_status', 'approved'),
            'map_location' => DB::table('map_locations')
                ->where('verified', true)
                ->where('published', true)
                ->where('active', true),
        };

        return $query->where('id', $id)->whereNull('deleted_at')->exists();
    }
}
