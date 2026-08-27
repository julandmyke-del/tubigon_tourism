<?php

return [
    /*
    | Only this audited seed list may enter the public feed without a staff
    | verifier, and only while the application is running locally or in tests.
    | Normal API creation, verification, and publication remain unchanged.
    */
    'dev_seed_public_tubigon_places' => (bool) env('DEV_SEED_PUBLIC_TUBIGON_PLACES', false),

    'public_seed_environments' => ['local', 'testing'],
];
