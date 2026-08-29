<?php

$demoSlugs = array_values(array_filter(array_map(
    'trim',
    explode(',', (string) env('FEATURED_DESTINATION_TEST_BOOKING_SLUGS', 'mundong-sandbar')),
)));

return [
    /*
    | Explicitly local/testing demo configuration. The seeder also checks the
    | running Laravel environment, so this cannot enable bookings in production.
    */
    'demo_enabled' => (bool) env('FEATURED_DESTINATIONS_TEST_BOOKING', false),
    'demo_slugs' => $demoSlugs,
];
