<?php

namespace App\Console\Commands;

use App\Models\Announcement;
use App\Services\EmailNotificationService;
use Illuminate\Console\Command;

class SendAnnouncementEmails extends Command
{
    protected $signature = 'announcements:send-email';

    protected $description = 'Send idempotent email for active important and urgent announcements';

    public function handle(EmailNotificationService $delivery): int
    {
        $sent = 0;
        Announcement::query()
            ->where('is_active', true)
            ->whereIn('status', ['published', 'scheduled'])
            ->whereIn('priority', ['important', 'urgent'])
            ->where(fn ($query) => $query->whereNull('starts_at')->orWhere('starts_at', '<=', now()))
            ->where(fn ($query) => $query->whereNull('expires_at')->orWhere('expires_at', '>', now()))
            ->chunkById(50, function ($announcements) use ($delivery, &$sent): void {
                foreach ($announcements as $announcement) {
                    $sent += $delivery->announcement($announcement);
                }
            });

        $this->info("Sent {$sent} announcement email(s).");

        return self::SUCCESS;
    }
}
