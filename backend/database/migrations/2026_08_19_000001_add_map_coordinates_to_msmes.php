<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('msmes')) {
            return;
        }

        Schema::table('msmes', function (Blueprint $table) {
            if (!Schema::hasColumn('msmes', 'latitude')) {
                $table->decimal('latitude', 10, 7)->nullable()->after('address');
            }
            if (!Schema::hasColumn('msmes', 'longitude')) {
                $table->decimal('longitude', 10, 7)->nullable()->after('latitude');
            }
        });
    }

    public function down(): void
    {
        if (Schema::hasTable('msmes')) {
            Schema::table('msmes', function (Blueprint $table) {
                $columns = array_values(array_filter(
                    ['latitude', 'longitude'],
                    fn (string $column) => Schema::hasColumn('msmes', $column)
                ));
                if ($columns !== []) {
                    $table->dropColumn($columns);
                }
            });
        }
    }
};
