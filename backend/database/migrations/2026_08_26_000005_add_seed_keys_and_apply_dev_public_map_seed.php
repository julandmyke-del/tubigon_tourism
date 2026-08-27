<?php

use Database\Seeders\MapLocationSeeder;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('map_locations') && ! Schema::hasColumn('map_locations', 'seed_key')) {
            Schema::table('map_locations', function (Blueprint $table) {
                $table->string('seed_key', 96)->nullable()->unique()->after('slug');
            });
        }

        // Reuses existing drafts by normalized name/entity, records a stable
        // internal seed identity, and promotes only when the guarded flag allows.
        (new MapLocationSeeder)->run();
    }

    public function down(): void
    {
        if (Schema::hasTable('map_locations') && Schema::hasColumn('map_locations', 'seed_key')) {
            Schema::table('map_locations', function (Blueprint $table) {
                $table->dropUnique('map_locations_seed_key_unique');
                $table->dropColumn('seed_key');
            });
        }

        // Publication state is deliberately preserved because staff may have
        // reviewed or edited these records after the migration was applied.
    }
};
