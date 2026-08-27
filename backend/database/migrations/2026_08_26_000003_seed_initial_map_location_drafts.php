<?php

use Database\Seeders\MapLocationSeeder;
use Illuminate\Database\Migrations\Migration;

return new class extends Migration
{
    public function up(): void
    {
        // Idempotent and duplicate-aware. Every initial record remains an
        // unpublished, unverified draft until an authorized LGU review.
        (new MapLocationSeeder)->run();
    }

    public function down(): void
    {
        // Intentionally preserve records: staff may have reviewed or edited
        // them after deployment, so a rollback must never erase that work.
    }
};
