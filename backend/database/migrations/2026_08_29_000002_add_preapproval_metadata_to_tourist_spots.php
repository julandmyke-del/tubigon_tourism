<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('tourist_spots')) {
            return;
        }

        Schema::table('tourist_spots', function (Blueprint $table): void {
            if (! Schema::hasColumn('tourist_spots', 'short_description')) {
                $table->text('short_description')->nullable()->after('description');
            }
            if (! Schema::hasColumn('tourist_spots', 'aliases')) {
                $table->json('aliases')->nullable()->after('short_description');
            }
            if (! Schema::hasColumn('tourist_spots', 'is_preapproved')) {
                $table->boolean('is_preapproved')->default(false)->index()->after('is_featured');
            }
            if (! Schema::hasColumn('tourist_spots', 'preapproved_at')) {
                $table->timestamp('preapproved_at')->nullable()->after('is_preapproved');
            }
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('tourist_spots')) {
            return;
        }

        foreach (['preapproved_at', 'is_preapproved', 'aliases', 'short_description'] as $column) {
            if (Schema::hasColumn('tourist_spots', $column)) {
                Schema::table('tourist_spots', fn (Blueprint $table) => $table->dropColumn($column));
            }
        }
    }
};
