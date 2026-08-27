<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\PartnerNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PartnerNotificationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $notifications = PartnerNotification::where('user_id', $request->user()->id)
            ->whereNull('deleted_at')
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json(['status' => 'success', 'data' => $notifications]);
    }

    public function markRead(Request $request, string $id): JsonResponse
    {
        PartnerNotification::where('id', $id)
            ->where('user_id', $request->user()->id)
            ->update(['is_read' => true]);

        return response()->json(['status' => 'success', 'message' => 'Notification marked as read']);
    }

    public function markAllRead(Request $request): JsonResponse
    {
        PartnerNotification::where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->update(['is_read' => true]);

        return response()->json(['status' => 'success', 'message' => 'All notifications marked as read']);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        PartnerNotification::where('id', $id)
            ->where('user_id', $request->user()->id)
            ->update(['deleted_at' => now()]);

        return response()->json(['status' => 'success', 'message' => 'Notification deleted']);
    }
}
