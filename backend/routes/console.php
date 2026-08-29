<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Uses the existing notifications table and emits at most one reminder per trip/day.
Schedule::command('itineraries:send-reminders')->dailyAt('08:00');
Schedule::command('reservations:send-reminders')->dailyAt('08:05');
