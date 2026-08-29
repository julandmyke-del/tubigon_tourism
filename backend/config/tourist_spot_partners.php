<?php

return [
    'development_password' => env('DEV_FEATURED_PARTNER_PASSWORD'),
    'unavailable_reason_codes' => [
        'weather_conditions',
        'maintenance',
        'fully_booked',
        'temporarily_closed',
        'unsafe_sea_conditions',
        'private_event',
        'seasonal_closure',
        'capacity_reached',
        'site_rehabilitation',
        'other',
    ],
];
