<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('tourist_spots', 'demo_booking_seeded_at')) {
            Schema::table('tourist_spots', function (Blueprint $table): void {
                $table->timestamp('demo_booking_seeded_at')->nullable()
                    ->after('cancellation_notice_hours');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('tourist_spots', 'demo_booking_seeded_at')) {
            Schema::table('tourist_spots', function (Blueprint $table): void {
                $table->dropColumn('demo_booking_seeded_at');
            });
        }
    }
};
