<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('emergency_contacts')) {
            return;
        }

        Schema::table('emergency_contacts', function (Blueprint $table): void {
            if (! Schema::hasColumn('emergency_contacts', 'contact_label')) {
                $table->string('contact_label', 80)->nullable()->after('name');
            }
            if (! Schema::hasColumn('emergency_contacts', 'display_order')) {
                $table->unsignedInteger('display_order')->default(100)->index()->after('contact_label');
            }
            if (! Schema::hasColumn('emergency_contacts', 'created_by')) {
                $table->uuid('created_by')->nullable()->index()->after('last_verified_at');
            }
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('emergency_contacts')) {
            return;
        }

        Schema::table('emergency_contacts', function (Blueprint $table): void {
            foreach (['contact_label', 'display_order', 'created_by'] as $column) {
                if (Schema::hasColumn('emergency_contacts', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
