<?php

namespace App\Console\Commands;

use App\Models\Notification;
use App\Models\Reservation;
use Illuminate\Console\Command;

class SendReservationReminders extends Command
{
    protected $signature = 'reservations:send-reminders';

    protected $description = 'Send idempotent reminders for tomorrow\'s active reservations';

    public function handle(): int
    {
        $reminderDate = today()->addDay()->toDateString();
        $created = 0;

        Reservation::whereDate('reservation_date', $reminderDate)
            ->whereHas('status', fn ($query) => $query->whereIn('name', [
                'pending', 'approved', 'confirmed',
            ]))
            ->chunkById(100, function ($reservations) use ($reminderDate, &$created): void {
                foreach ($reservations as $reservation) {
                    $exists = Notification::where('user_id', $reservation->user_id)
                        ->where('type', 'reservation_reminder')
                        ->where('data->reservation_id', (string) $reservation->id)
                        ->where('data->reminder_for', $reminderDate)
                        ->exists();
                    if ($exists) {
                        continue;
                    }
                    Notification::create([
                        'user_id' => $reservation->user_id,
                        'type' => 'reservation_reminder',
                        'title' => 'Upcoming Reservation',
                        'body' => 'You have a reservation scheduled for tomorrow.',
                        'data' => [
                            'reservation_id' => (string) $reservation->id,
                            'reminder_for' => $reminderDate,
                            'route' => "/reservations/{$reservation->id}",
                        ],
                    ]);
                    $created++;
                }
            });

        $this->info("Created {$created} reservation reminder(s).");
        return self::SUCCESS;
    }
}
