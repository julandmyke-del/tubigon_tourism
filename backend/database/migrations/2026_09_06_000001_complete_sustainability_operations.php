<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('waste_reports')) {
            Schema::table('waste_reports', function (Blueprint $table): void {
                if (! Schema::hasColumn('waste_reports', 'barangay')) {
                    $table->string('barangay')->nullable()->after('location_description');
                }
            });
        }

        if (! Schema::hasTable('waste_report_history')) {
            Schema::create('waste_report_history', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->uuid('waste_report_id')->index();
                $table->uuid('changed_by')->nullable()->index();
                $table->string('from_status', 50)->nullable();
                $table->string('to_status', 50);
                $table->text('notes')->nullable();
                $table->json('metadata')->nullable();
                $table->timestamps();
                $table->foreign('waste_report_id')->references('id')->on('waste_reports')->cascadeOnDelete();
                $table->foreign('changed_by')->references('id')->on('users')->nullOnDelete();
            });
        }

        if (Schema::hasTable('ferry_schedules')) {
            Schema::table('ferry_schedules', function (Blueprint $table): void {
                if (! Schema::hasColumn('ferry_schedules', 'origin')) $table->string('origin')->nullable();
                if (! Schema::hasColumn('ferry_schedules', 'destination')) $table->string('destination')->nullable();
                if (! Schema::hasColumn('ferry_schedules', 'vessel_name')) $table->string('vessel_name')->nullable();
                if (! Schema::hasColumn('ferry_schedules', 'departure_date')) $table->date('departure_date')->nullable()->index();
                if (! Schema::hasColumn('ferry_schedules', 'advisory')) $table->text('advisory')->nullable();
                if (! Schema::hasColumn('ferry_schedules', 'contact_information')) $table->string('contact_information')->nullable();
                if (! Schema::hasColumn('ferry_schedules', 'reference_url')) $table->text('reference_url')->nullable();
                if (! Schema::hasColumn('ferry_schedules', 'is_active')) $table->boolean('is_active')->default(true)->index();
                if (! Schema::hasColumn('ferry_schedules', 'updated_by')) $table->uuid('updated_by')->nullable()->index();
            });
        }

        if (Schema::hasTable('eco_tips')) {
            Schema::table('eco_tips', function (Blueprint $table): void {
                if (! Schema::hasColumn('eco_tips', 'short_message')) $table->string('short_message', 500)->nullable();
                if (! Schema::hasColumn('eco_tips', 'is_active')) $table->boolean('is_active')->default(true)->index();
                if (! Schema::hasColumn('eco_tips', 'is_published')) $table->boolean('is_published')->default(false)->index();
                if (! Schema::hasColumn('eco_tips', 'starts_at')) $table->dateTime('starts_at')->nullable()->index();
                if (! Schema::hasColumn('eco_tips', 'ends_at')) $table->dateTime('ends_at')->nullable()->index();
                if (! Schema::hasColumn('eco_tips', 'priority')) $table->unsignedTinyInteger('priority')->default(0)->index();
                if (! Schema::hasColumn('eco_tips', 'created_by')) $table->uuid('created_by')->nullable()->index();
                if (! Schema::hasColumn('eco_tips', 'updated_by')) $table->uuid('updated_by')->nullable()->index();
            });
            // Records created before publication controls existed were already
            // publicly visible; preserve that behavior during the upgrade.
            DB::table('eco_tips')->where('is_published', false)->update([
                'is_active' => true,
                'is_published' => true,
            ]);
        }

        if (Schema::hasTable('emergency_contacts')) {
            Schema::table('emergency_contacts', function (Blueprint $table): void {
                if (! Schema::hasColumn('emergency_contacts', 'barangay')) $table->string('barangay')->nullable();
                if (! Schema::hasColumn('emergency_contacts', 'availability_notes')) $table->string('availability_notes', 1000)->nullable();
                if (! Schema::hasColumn('emergency_contacts', 'emergency_instructions')) $table->text('emergency_instructions')->nullable();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('waste_report_history');

        $this->dropExistingColumns('waste_reports', ['barangay']);
        $this->dropExistingColumns('ferry_schedules', [
            'origin', 'destination', 'vessel_name', 'departure_date', 'advisory',
            'contact_information', 'reference_url', 'is_active', 'updated_by',
        ]);
        $this->dropExistingColumns('eco_tips', [
            'short_message', 'is_active', 'is_published', 'starts_at', 'ends_at',
            'priority', 'created_by', 'updated_by',
        ]);
        $this->dropExistingColumns('emergency_contacts', [
            'barangay', 'availability_notes', 'emergency_instructions',
        ]);
    }

    private function dropExistingColumns(string $tableName, array $columns): void
    {
        if (! Schema::hasTable($tableName)) return;
        $existing = array_values(array_filter(
            $columns,
            fn (string $column): bool => Schema::hasColumn($tableName, $column),
        ));
        if ($existing !== []) {
            Schema::table($tableName, fn (Blueprint $table) => $table->dropColumn($existing));
        }
    }
};
