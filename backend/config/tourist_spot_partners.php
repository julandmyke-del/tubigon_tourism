<?php

return [
    // Local/testing-only provisioning fallback. Production cannot run the
    // development partner seeder, and may override this through the env var.
    'development_password' => env('DEV_FEATURED_PARTNER_PASSWORD', 'Partner123!'),
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
