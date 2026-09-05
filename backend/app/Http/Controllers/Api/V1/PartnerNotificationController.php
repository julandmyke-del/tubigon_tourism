<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\PartnerNotification;
use App\Services\AnnouncementDeliveryService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class PartnerNotificationController extends Controller
{
    public function index(Request $request, AnnouncementDeliveryService $delivery): JsonResponse
    {
        $validated = $request->validate([
            'filter' => ['nullable', Rule::in(['all', 'unread', 'reservations', 'reviews', 'municipal', 'system'])],
        ]);
        $delivery->syncFor($request->user());
        $query = PartnerNotification::where('user_id', $request->user()->id)
            ->whereNull('deleted_at');
        match ($validated['filter'] ?? 'all') {
            'unread' => $query->where('is_read', false),
            'reservations' => $query->where('type', 'like', '%reservation%'),
            'reviews' => $query->where('type', 'like', '%review%'),
            'municipal' => $query->whereIn('type', ['announcement', 'tourist_spot_status_changed', 'lgu_booking_availability_changed']),
            'system' => $query->whereIn('type', ['role_application_approved', 'role_application_rejected', 'admin_assignment_changed']),
            default => null,
        };
        $notifications = $query
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json(['status' => 'success', 'data' => $notifications]);
    }

    public function unreadCount(Request $request, AnnouncementDeliveryService $delivery): JsonResponse
    {
        $delivery->syncFor($request->user());

        return response()->json(['status' => 'success', 'data' => [
            'count' => PartnerNotification::where('user_id', $request->user()->id)
                ->where('is_read', false)->whereNull('deleted_at')->count(),
        ]]);
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
