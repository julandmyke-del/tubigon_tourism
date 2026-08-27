<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Image;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ImageController extends Controller
{
    public function upload(Request $request): JsonResponse
    {
        $request->validate([
            'image' => 'required|image|max:5120',
            'bucket' => 'required|string|max:255',
        ]);

        $userId = $request->user()->id;
        $bucket = $request->bucket;
        $path = $request->file('image')->store("$bucket/$userId", 'public');
        $url = asset("storage/$path");

        $image = Image::create([
            'url' => $url,
            'bucket' => $bucket,
            'owner_id' => $userId,
        ]);

        return response()->json([
            'status' => 'success',
            'data' => $image,
        ], 201);
    }

    public function destroy(string $id): JsonResponse
    {
        $image = Image::findOrFail($id);
        // Optionally delete file from disk too
        $image->delete();
        return response()->json(['status' => 'success', 'message' => 'Image deleted']);
    }
}
