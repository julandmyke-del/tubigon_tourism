<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Laravel CORS — Tubigon Smart Tourism API
    |--------------------------------------------------------------------------
    | Allows Flutter Web (running on localhost) to make cross-origin requests
    | to this Laravel API during development. Tighten for production.
    */

    'paths' => ['api/*', 'sanctum/csrf-cookie'],

    'allowed_methods' => ['*'],

    'allowed_origins' => ['*'],

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 0,

    'supports_credentials' => false,

];
