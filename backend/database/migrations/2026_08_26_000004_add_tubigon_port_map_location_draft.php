<?php

use Database\Seeders\MapLocationSeeder;
use Illuminate\Database\Migrations\Migration;

return new class extends Migration
{
    public function up(): void
    {
        // The seeder is idempotent and creates Tubigon Port without coordinates,
        // verification, or publication. LGU/Admin must review the exact pin.
        (new MapLocationSeeder)->run();
    }

    public function down(): void
    {
        // Preserve the draft because staff may have reviewed it after migration.
    }
};
