<?php

return [
    // Local/testing-only provisioning fallback. The guarded development
    // seeder cannot run in production, and deployments may override this.
    'development_password' => env('DEV_MSME_OWNER_PASSWORD', 'msme123!'),
];
