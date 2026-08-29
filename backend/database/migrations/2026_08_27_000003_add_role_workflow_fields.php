<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('msmes')) {
            Schema::table('msmes', function (Blueprint $table) {
                if (! Schema::hasColumn('msmes', 'verification_status')) {
                    $table->string('verification_status', 32)->default('pending')->index();
                }
                if (! Schema::hasColumn('msmes', 'verification_notes')) {
                    $table->text('verification_notes')->nullable();
                }
                if (! Schema::hasColumn('msmes', 'submitted_at')) {
                    $table->timestamp('submitted_at')->nullable();
                }
                if (! Schema::hasColumn('msmes', 'reviewed_at')) {
                    $table->timestamp('reviewed_at')->nullable();
                }
                if (! Schema::hasColumn('msmes', 'reviewed_by')) {
                    $table->uuid('reviewed_by')->nullable()->index();
                }
                if (! Schema::hasColumn('msmes', 'operational_status')) {
                    $table->string('operational_status', 32)->default('open')->index();
                }
                if (! Schema::hasColumn('msmes', 'opening_hours')) {
                    $table->json('opening_hours')->nullable();
                }
                if (! Schema::hasColumn('msmes', 'unavailable_dates')) {
                    $table->json('unavailable_dates')->nullable();
                }
                if (! Schema::hasColumn('msmes', 'images')) {
                    $table->json('images')->nullable();
                }
            });

            DB::table('msmes')->where('is_verified', true)->update([
                'verification_status' => 'verified',
                'reviewed_at' => DB::raw('COALESCE(reviewed_at, updated_at)'),
            ]);
        }

        if (Schema::hasTable('tourism_listings')) {
            Schema::table('tourism_listings', function (Blueprint $table) {
                if (! Schema::hasColumn('tourism_listings', 'approval_status')) {
                    $table->string('approval_status', 32)->default('draft')->index();
                }
                if (! Schema::hasColumn('tourism_listings', 'submitted_at')) {
                    $table->timestamp('submitted_at')->nullable();
                }
                if (! Schema::hasColumn('tourism_listings', 'reviewed_at')) {
                    $table->timestamp('reviewed_at')->nullable();
                }
                if (! Schema::hasColumn('tourism_listings', 'reviewed_by')) {
                    $table->uuid('reviewed_by')->nullable()->index();
                }
                if (! Schema::hasColumn('tourism_listings', 'review_notes')) {
                    $table->text('review_notes')->nullable();
                }
                if (! Schema::hasColumn('tourism_listings', 'published_at')) {
                    $table->timestamp('published_at')->nullable();
                }
                if (! Schema::hasColumn('tourism_listings', 'price')) {
                    $table->decimal('price', 12, 2)->nullable();
                }
                if (! Schema::hasColumn('tourism_listings', 'capacity')) {
                    $table->unsignedInteger('capacity')->nullable();
                }
                if (! Schema::hasColumn('tourism_listings', 'duration_minutes')) {
                    $table->unsignedInteger('duration_minutes')->nullable();
                }
                if (! Schema::hasColumn('tourism_listings', 'available_days')) {
                    $table->json('available_days')->nullable();
                }
                if (! Schema::hasColumn('tourism_listings', 'booking_cutoff_hours')) {
                    $table->unsignedInteger('booking_cutoff_hours')->default(0);
                }
            });

            DB::table('tourism_listings')
                ->where('is_active', true)
                ->whereIn('status', ['active', 'approved'])
                ->update([
                    'approval_status' => 'approved',
                    'published_at' => DB::raw('COALESCE(published_at, updated_at)'),
                ]);
        }

        if (Schema::hasTable('waste_reports')) {
            Schema::table('waste_reports', function (Blueprint $table) {
                if (! Schema::hasColumn('waste_reports', 'priority')) {
                    $table->string('priority', 16)->default('normal')->index();
                }
                if (! Schema::hasColumn('waste_reports', 'assigned_to')) {
                    $table->uuid('assigned_to')->nullable()->index();
                }
                if (! Schema::hasColumn('waste_reports', 'assigned_personnel')) {
                    $table->string('assigned_personnel')->nullable();
                }
                if (! Schema::hasColumn('waste_reports', 'assigned_at')) {
                    $table->timestamp('assigned_at')->nullable();
                }
                if (! Schema::hasColumn('waste_reports', 'lgu_notes')) {
                    $table->text('lgu_notes')->nullable();
                }
                if (! Schema::hasColumn('waste_reports', 'resolution_evidence')) {
                    $table->json('resolution_evidence')->nullable();
                }
                if (! Schema::hasColumn('waste_reports', 'reviewed_at')) {
                    $table->timestamp('reviewed_at')->nullable();
                }
                if (! Schema::hasColumn('waste_reports', 'resolved_at')) {
                    $table->timestamp('resolved_at')->nullable();
                }
            });

            DB::table('waste_reports')->where('status', 'pending')->update(['status' => 'submitted']);
        }
    }

    public function down(): void
    {
        $this->dropColumns('msmes', [
            'verification_status', 'verification_notes', 'submitted_at',
            'reviewed_at', 'reviewed_by', 'operational_status', 'opening_hours',
            'unavailable_dates', 'images',
        ]);
        $this->dropColumns('tourism_listings', [
            'approval_status', 'submitted_at', 'reviewed_at', 'reviewed_by',
            'review_notes', 'published_at', 'price', 'capacity',
            'duration_minutes', 'available_days', 'booking_cutoff_hours',
        ]);
        $this->dropColumns('waste_reports', [
            'priority', 'assigned_to', 'assigned_personnel', 'assigned_at',
            'lgu_notes', 'resolution_evidence', 'reviewed_at', 'resolved_at',
        ]);
    }

    /** @param list<string> $columns */
    private function dropColumns(string $tableName, array $columns): void
    {
        if (! Schema::hasTable($tableName)) return;
        Schema::table($tableName, function (Blueprint $table) use ($tableName, $columns) {
            foreach ($columns as $column) {
                if (Schema::hasColumn($tableName, $column)) $table->dropColumn($column);
            }
        });
    }
};
