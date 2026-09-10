<?php

namespace App\Services;

use App\Models\Announcement;
use App\Models\Notification;
use App\Models\PartnerNotification;
use App\Models\User;
use Illuminate\Support\Facades\Schema;

class AnnouncementDeliveryService
{
    public function syncFor(User $user): void
    {
        if (! Schema::hasTable('announcements')
            || ! Schema::hasColumn('announcements', 'audience')
            || ! Schema::hasColumn('notifications', 'announcement_id')) {
            return;
        }
        $user->loadMissing('role');
        $role = $user->role?->name ?? 'tourist';

        $columns = ['id', 'title', 'body', 'priority', 'audience', 'starts_at', 'created_at'];
        foreach (['display_type', 'cta_label', 'related_type', 'related_id'] as $column) {
            if (Schema::hasColumn('announcements', $column)) {
                $columns[] = $column;
            }
        }
        $active = Announcement::visibleTo($role)->select($columns)->get();
        $model = $role === 'tourism_partner'
            ? PartnerNotification::class
            : Notification::class;
        $model::where('user_id', $user->id)
            ->whereNotNull('announcement_id')
            ->whereNotIn('announcement_id', $active->pluck('id'))
            ->forceDelete();

        $active->each(function (Announcement $announcement) use ($user, $role, $model): void {
            $model::withTrashed()->firstOrCreate(
                [
                    'user_id' => $user->id,
                    'announcement_id' => $announcement->id,
                ],
                [
                    'type' => 'announcement',
                    'title' => $announcement->title,
                    'body' => $announcement->body,
                    'data' => [
                        'announcement_id' => $announcement->id,
                        'priority' => $announcement->priority,
                        'audience' => $announcement->audience,
                        'audiences' => $announcement->audienceRoles(),
                        'display_type' => $announcement->display_type,
                        'related_type' => $announcement->related_type,
                        'related_id' => $announcement->related_id,
                        'route' => $this->announcementRoute($role),
                    ],
                    'is_read' => false,
                ],
            );
        });
    }

    public function refresh(Announcement $announcement): void
    {
        foreach ([Notification::class, PartnerNotification::class] as $model) {
            $model::where('announcement_id', $announcement->id)->update([
                'title' => $announcement->title,
                'body' => $announcement->body,
                'data' => json_encode([
                    'announcement_id' => $announcement->id,
                    'priority' => $announcement->priority,
                    'audience' => $announcement->audience,
                ]),
            ]);
        }
    }

    public function remove(Announcement $announcement): void
    {
        Notification::where('announcement_id', $announcement->id)->forceDelete();
        PartnerNotification::where('announcement_id', $announcement->id)->forceDelete();
    }

    private function announcementRoute(string $role): string
    {
        return match ($role) {
            'msme_owner' => '/msme-portal/notifications',
            'tourism_partner' => '/tourism-partner/notifications',
            'lgu_staff' => '/lgu/announcements',
            'admin' => '/admin/announcements',
            default => '/notifications',
        };
    }
}
