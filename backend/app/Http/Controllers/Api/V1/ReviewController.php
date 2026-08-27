<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Review;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReviewController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Review::with('user');

        if ($request->has('reviewable_type') && $request->has('reviewable_id')) {
            $query->where('reviewable_type', $request->reviewable_type)
                  ->where('reviewable_id', $request->reviewable_id);
        }

        $reviews = $query->orderBy('created_at', 'desc')->get();
        return response()->json(['status' => 'success', 'data' => $reviews]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'reviewable_type' => 'required|in:spot,msme,tourism_listing',
            'reviewable_id' => 'required|uuid',
            'rating' => 'required|integer|min:1|max:5',
            'content' => 'required|string|min:3|max:1000',
            'images' => 'nullable|array',
        ]);

        $validated['user_id'] = $request->user()->id;
        $review = Review::create($validated);

        return response()->json([
            'status' => 'success',
            'data' => $review->load('user'),
        ], 201);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        $review = Review::findOrFail($id);
        $user = $request->user();
        $user->loadMissing('role');
        if ($user->role?->name !== 'admin' && (string) $review->user_id !== (string) $user->id) {
            abort(403, 'You may only delete your own reviews.');
        }
        $review->delete();
        return response()->json(['status' => 'success', 'message' => 'Review deleted']);
    }
}
