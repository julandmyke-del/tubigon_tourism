<?php

return [
    /*
    | Optional messages can be changed per deployment without changing code.
    | Security messages (verification and password reset) are always enabled.
    */
    'reservation_received' => (bool) env('MAIL_RESERVATION_RECEIVED', true),
    'reservation_reminders' => (bool) env('MAIL_RESERVATION_REMINDERS', true),
    'important_announcements' => (bool) env('MAIL_IMPORTANT_ANNOUNCEMENTS', true),
    'urgent_announcements' => (bool) env('MAIL_URGENT_ANNOUNCEMENTS', true),
];
