<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('tourist_spots') || Schema::hasColumn('tourist_spots', 'operational_status')) {
            return;
        }

        Schema::table('tourist_spots', function (Blueprint $table): void {
            $table->string('operational_status', 24)->default('active')->index()->after('is_active');
        });

        DB::table('tourist_spots')->where('is_active', false)->update([
            'operational_status' => 'inactive',
        ]);
    }

    public function down(): void
    {
        if (Schema::hasTable('tourist_spots') && Schema::hasColumn('tourist_spots', 'operational_status')) {
            Schema::table('tourist_spots', fn (Blueprint $table) => $table->dropColumn('operational_status'));
        }
    }
};
