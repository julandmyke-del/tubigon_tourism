<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Image;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class ImageController extends Controller
{
    public function upload(Request $request): JsonResponse
    {
        $request->validate([
            'image' => 'required|image|max:5120',
            'bucket' => ['required', 'string', Rule::in([
                'msme-gallery',
                'listing-gallery',
                'profile-gallery',
            ])],
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

    public function destroy(Request $request, string $id): JsonResponse
    {
        $image = Image::findOrFail($id);
        $user = $request->user();
        $user->loadMissing('role');
        if ((string) $image->owner_id !== (string) $user->id && $user->role?->name !== 'admin') {
            abort(403, 'You are not authorized to delete this image.');
        }
        $path = parse_url($image->url, PHP_URL_PATH);
        if (is_string($path)) {
            $marker = '/storage/';
            $offset = strpos($path, $marker);
            if ($offset !== false) {
                $relative = ltrim(rawurldecode(substr($path, $offset + strlen($marker))), '/');
                if ($relative !== '' && ! str_contains($relative, '..')) {
                    Storage::disk('public')->delete($relative);
                }
            }
        }
        $image->delete();
        return response()->json(['status' => 'success', 'message' => 'Image deleted']);
    }
}
