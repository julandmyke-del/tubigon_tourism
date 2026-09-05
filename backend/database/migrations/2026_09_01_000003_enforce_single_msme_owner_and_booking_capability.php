<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const OWNER_UNIQUE = 'msmes_profile_id_unique';

    public function up(): void
    {
        if (! Schema::hasTable('msmes')) {
            return;
        }

        if (Schema::hasColumn('msmes', 'profile_id')) {
            $duplicateOwner = DB::table('msmes')
                ->select('profile_id')
                ->whereNotNull('profile_id')
                ->groupBy('profile_id')
                ->havingRaw('COUNT(*) > 1')
                ->value('profile_id');

            if ($duplicateOwner !== null) {
                throw new RuntimeException(
                    'Cannot enforce one MSME per owner until duplicate profile_id records are reconciled safely.',
                );
            }

            Schema::table('msmes', function (Blueprint $table): void {
                $table->unique('profile_id', self::OWNER_UNIQUE);
            });
        }

        if (! Schema::hasColumn('msmes', 'booking_enabled')) {
            Schema::table('msmes', function (Blueprint $table): void {
                $table->boolean('booking_enabled')->default(false)->index();
            });
        }
    }

    public function down(): void
    {
        if (! Schema::hasTable('msmes')) {
            return;
        }

        $hasBooking = Schema::hasColumn('msmes', 'booking_enabled');
        Schema::table('msmes', function (Blueprint $table) use ($hasBooking): void {
            $table->dropUnique(self::OWNER_UNIQUE);
            if ($hasBooking) {
                $table->dropColumn('booking_enabled');
            }
        });
    }
};
