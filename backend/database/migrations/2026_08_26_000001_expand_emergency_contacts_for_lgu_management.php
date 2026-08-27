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

        Schema::table('emergency_contacts', function (Blueprint $table) {
            if (! Schema::hasColumn('emergency_contacts', 'alternative_phone')) {
                $table->string('alternative_phone')->nullable()->after('phone');
            }
            if (! Schema::hasColumn('emergency_contacts', 'description')) {
                $table->text('description')->nullable()->after('address');
            }
            if (! Schema::hasColumn('emergency_contacts', 'operating_hours')) {
                $table->string('operating_hours')->nullable()->after('description');
            }
            if (! Schema::hasColumn('emergency_contacts', 'classification')) {
                $table->string('classification', 32)->default('emergency')->after('operating_hours');
            }
            if (! Schema::hasColumn('emergency_contacts', 'is_active')) {
                $table->boolean('is_active')->default(true)->index()->after('classification');
            }
            if (! Schema::hasColumn('emergency_contacts', 'is_verified')) {
                $table->boolean('is_verified')->default(false)->index()->after('is_active');
            }
            if (! Schema::hasColumn('emergency_contacts', 'source')) {
                $table->string('source')->nullable()->after('is_verified');
            }
            if (! Schema::hasColumn('emergency_contacts', 'source_url')) {
                $table->text('source_url')->nullable()->after('source');
            }
            if (! Schema::hasColumn('emergency_contacts', 'verified_by')) {
                $table->uuid('verified_by')->nullable()->index()->after('source_url');
            }
            if (! Schema::hasColumn('emergency_contacts', 'verified_at')) {
                $table->timestamp('verified_at')->nullable()->after('verified_by');
            }
            if (! Schema::hasColumn('emergency_contacts', 'last_verified_at')) {
                $table->timestamp('last_verified_at')->nullable()->after('verified_at');
            }
            if (! Schema::hasColumn('emergency_contacts', 'updated_by')) {
                $table->uuid('updated_by')->nullable()->index()->after('last_verified_at');
            }
            if (! Schema::hasColumn('emergency_contacts', 'archived_by')) {
                $table->uuid('archived_by')->nullable()->index()->after('updated_by');
            }
        });

        if (! Schema::hasTable('emergency_contact_audits')) {
            Schema::create('emergency_contact_audits', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->uuid('contact_id')->index();
                $table->string('action', 64)->index();
                $table->json('old_value')->nullable();
                $table->json('new_value')->nullable();
                $table->uuid('updated_by')->index();
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('emergency_contact_audits');

        if (! Schema::hasTable('emergency_contacts')) {
            return;
        }

        $columns = [
            'alternative_phone',
            'description',
            'operating_hours',
            'classification',
            'is_active',
            'is_verified',
            'source',
            'source_url',
            'verified_by',
            'verified_at',
            'last_verified_at',
            'updated_by',
            'archived_by',
        ];

        Schema::table('emergency_contacts', function (Blueprint $table) use ($columns) {
            foreach ($columns as $column) {
                if (Schema::hasColumn('emergency_contacts', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
