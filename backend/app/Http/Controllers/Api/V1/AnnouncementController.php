<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Announcement;
use App\Models\ActivityLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AnnouncementController extends Controller
{
    public function index(): JsonResponse
    {
        $announcements = Announcement::where('is_active', true)
            ->orderBy('created_at', 'desc')->get();
        return response()->json(['status' => 'success', 'data' => $announcements]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'body' => 'required|string',
            'category' => 'nullable|string|max:255',
            'is_active' => 'nullable|boolean',
        ]);
        $announcement = Announcement::create($validated);

        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => 'Announcement created',
            'details' => "Created announcement: {$announcement->title}",
        ]);

        return response()->json(['status' => 'success', 'data' => $announcement], 201);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $announcement = Announcement::findOrFail($id);
        $validated = $request->validate([
            'title' => 'sometimes|string|max:255',
            'body' => 'sometimes|string',
            'category' => 'nullable|string|max:255',
            'is_active' => 'nullable|boolean',
        ]);
        $announcement->update($validated);

        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => 'Announcement updated',
            'details' => "Updated announcement: {$announcement->title}",
        ]);

        return response()->json(['status' => 'success', 'data' => $announcement]);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        $announcement = Announcement::findOrFail($id);
        $announcement->delete();

        ActivityLog::create([
            'user_id' => $request->user()->id,
            'action' => 'Announcement deleted',
            'details' => "Deleted announcement ID $id",
        ]);

        return response()->json(['status' => 'success', 'message' => 'Announcement deleted']);
    }
}
