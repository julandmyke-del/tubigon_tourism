<?php

namespace App\Console\Commands;

use App\Models\Itinerary;
use App\Models\Notification;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class SendItineraryReminders extends Command
{
    protected $signature = 'itineraries:send-reminders';

    protected $description = 'Create one existing-system notification for each itinerary starting tomorrow';

    public function handle(): int
    {
        if (! Schema::hasTable('notifications') || ! Schema::hasTable('itineraries')) {
            $this->warn('Itinerary or notification storage is unavailable.');

            return self::SUCCESS;
        }

        $reminderDate = today()->addDay()->toDateString();
        $created = 0;

        Itinerary::query()
            ->whereDate('start_date', $reminderDate)
            ->whereNotIn('status', ['archived', 'completed'])
            ->orderBy('id')
            ->chunkById(100, function ($itineraries) use ($reminderDate, &$created): void {
                foreach ($itineraries as $itinerary) {
                    if ($this->notificationsDisabledFor((string) $itinerary->user_id)) {
                        continue;
                    }

                    $exists = Notification::query()
                        ->where('user_id', $itinerary->user_id)
                        ->where('type', 'itinerary_reminder')
                        ->where('data->itinerary_id', (string) $itinerary->id)
                        ->where('data->reminder_for', $reminderDate)
                        ->exists();
                    if ($exists) {
                        continue;
                    }

                    Notification::create([
                        'user_id' => $itinerary->user_id,
                        'type' => 'itinerary_reminder',
                        'title' => 'Your Tubigon trip starts tomorrow',
                        'body' => "{$itinerary->name} has {$itinerary->items()->count()} planned stop(s).",
                        'data' => [
                            'itinerary_id' => (string) $itinerary->id,
                            'reminder_for' => $reminderDate,
                            'route' => "/itineraries/{$itinerary->id}",
                        ],
                        'is_read' => false,
                    ]);
                    $created++;
                }
            });

        $this->info("Created {$created} itinerary reminder(s).");

        return self::SUCCESS;
    }

    private function notificationsDisabledFor(string $userId): bool
    {
        return Schema::hasTable('settings')
            && DB::table('settings')->where('user_id', $userId)
                ->where('notifications_enabled', false)->exists();
    }
}
