<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Laravel CORS — Tour Tubigon API
    |--------------------------------------------------------------------------
    | Allows Flutter Web (running on localhost) to make cross-origin requests
    | to this Laravel API during development. Tighten for production.
    */

    'paths' => ['api/*', 'sanctum/csrf-cookie'],

    'allowed_methods' => ['*'],

    'allowed_origins' => array_values(array_filter(array_map(
        'trim',
        explode(',', (string) env('CORS_ALLOWED_ORIGINS', 'http://localhost:3000,http://localhost:5000,http://localhost:8080')),
    ))),

    // Flutter Web chooses an ephemeral localhost port in development. Hosted
    // production origins must still be supplied explicitly above.
    'allowed_origins_patterns' => env('APP_ENV', 'production') === 'local'
        ? ['#^https?://(localhost|127\.0\.0\.1)(:\d+)?$#']
        : [],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 0,

    'supports_credentials' => false,

];
