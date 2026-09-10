<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('waste_categories')) {
            Schema::create('waste_categories', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->string('slug', 80)->unique();
                $table->string('name');
                $table->string('helper_text', 500)->nullable();
                $table->boolean('is_active')->default(true)->index();
                $table->unsignedSmallInteger('sort_order')->default(0);
                $table->timestamps();
            });
        }

        $now = now();
        foreach ([
            ['illegal-dumping', 'Illegal Dumping'],
            ['overflowing-bin', 'Overflowing Waste Bin'],
            ['uncollected-garbage', 'Uncollected Garbage'],
            ['plastic-waste', 'Plastic Waste'],
            ['coastal-marine-waste', 'Coastal / Marine Waste'],
            ['roadside-waste', 'Roadside Waste'],
            ['burning-waste', 'Burning of Waste'],
            ['hazardous-looking-waste', 'Hazardous-looking Waste'],
            ['other', 'Other'],
        ] as $position => [$slug, $name]) {
            DB::table('waste_categories')->updateOrInsert(
                ['slug' => $slug],
                [
                    'id' => DB::table('waste_categories')->where('slug', $slug)->value('id') ?: (string) Str::uuid(),
                    'name' => $name,
                    'helper_text' => $slug === 'hazardous-looking-waste'
                        ? 'Do not touch suspicious or hazardous material. Use 911 for an immediate threat to life.'
                        : null,
                    'is_active' => true,
                    'sort_order' => ($position + 1) * 10,
                    'created_at' => $now,
                    'updated_at' => $now,
                ],
            );
        }

        if (Schema::hasTable('waste_reports')) {
            Schema::table('waste_reports', function (Blueprint $table): void {
                if (! Schema::hasColumn('waste_reports', 'category_id')) $table->uuid('category_id')->nullable()->index();
                if (! Schema::hasColumn('waste_reports', 'severity')) $table->string('severity', 32)->default('moderate')->index();
                if (! Schema::hasColumn('waste_reports', 'resolved_address')) $table->text('resolved_address')->nullable();
                if (! Schema::hasColumn('waste_reports', 'geocoding_source')) $table->string('geocoding_source')->nullable();
                if (! Schema::hasColumn('waste_reports', 'client_submission_id')) $table->uuid('client_submission_id')->nullable()->unique();
                if (! Schema::hasColumn('waste_reports', 'submitted_at')) $table->timestamp('submitted_at')->nullable()->index();
                if (! Schema::hasColumn('waste_reports', 'resolved_by')) $table->uuid('resolved_by')->nullable()->index();
                if (! Schema::hasColumn('waste_reports', 'resolution_summary')) $table->text('resolution_summary')->nullable();
                if (! Schema::hasColumn('waste_reports', 'reopened_at')) $table->timestamp('reopened_at')->nullable();
            });

            $aliases = [
                'Illegal Dumping' => 'illegal-dumping',
                'Overflowing Bin' => 'overflowing-bin',
                'garbage' => 'uncollected-garbage',
                'Plastic Waste' => 'plastic-waste',
                'Coastal Pollution' => 'coastal-marine-waste',
                'beach_coastal' => 'coastal-marine-waste',
                'water_pollution' => 'coastal-marine-waste',
                'road_infrastructure' => 'roadside-waste',
                'Hazardous Material' => 'hazardous-looking-waste',
                'Other' => 'other',
                'other' => 'other',
            ];
            foreach ($aliases as $legacy => $slug) {
                DB::table('waste_reports')->where('category', $legacy)->whereNull('category_id')->update([
                    'category_id' => DB::table('waste_categories')->where('slug', $slug)->value('id'),
                ]);
            }
            DB::table('waste_reports')->whereNull('submitted_at')->update(['submitted_at' => DB::raw('created_at')]);
        }

        if (! Schema::hasTable('waste_report_media')) {
            Schema::create('waste_report_media', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->uuid('waste_report_id')->index();
                $table->uuid('uploaded_by')->nullable()->index();
                $table->string('media_type', 32)->index();
                $table->string('disk', 32)->default('local');
                $table->text('storage_path');
                $table->string('mime_type', 120);
                $table->unsignedBigInteger('size_bytes');
                $table->string('original_name')->nullable();
                $table->string('visibility', 32)->default('participants');
                $table->timestamps();
                $table->foreign('waste_report_id')->references('id')->on('waste_reports')->cascadeOnDelete();
            });
        }

        if (Schema::hasTable('waste_report_history') && ! Schema::hasColumn('waste_report_history', 'is_public')) {
            Schema::table('waste_report_history', function (Blueprint $table): void {
                $table->boolean('is_public')->default(false)->index();
            });
            DB::table('waste_report_history')
                ->whereIn('to_status', ['submitted', 'under_review', 'assigned', 'in_progress', 'resolved', 'rejected'])
                ->update(['is_public' => true]);
        }

        if (Schema::hasTable('emergency_contacts')) {
            Schema::table('emergency_contacts', function (Blueprint $table): void {
                if (! Schema::hasColumn('emergency_contacts', 'is_public')) $table->boolean('is_public')->default(false)->index();
                if (! Schema::hasColumn('emergency_contacts', 'verification_status')) $table->string('verification_status', 32)->default('draft')->index();
                if (! Schema::hasColumn('emergency_contacts', 'source_name')) $table->string('source_name')->nullable();
                if (! Schema::hasColumn('emergency_contacts', 'notes')) $table->text('notes')->nullable();
            });
            DB::table('emergency_contacts')->update([
                'source_name' => DB::raw('COALESCE(source_name, source)'),
                'is_public' => DB::raw('CASE WHEN is_verified = 1 AND is_active = 1 THEN 1 ELSE is_public END'),
                'verification_status' => DB::raw("CASE WHEN is_verified = 1 THEN 'verified' WHEN is_active = 0 THEN 'inactive' ELSE 'needs_reverification' END"),
            ]);
        }

        if (! Schema::hasTable('emission_factors')) {
            Schema::create('emission_factors', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->string('transport_mode', 80)->index();
                $table->string('display_name');
                $table->decimal('emission_factor', 12, 6);
                $table->string('unit', 64)->default('kg_co2e_per_passenger_km');
                $table->string('occupancy_assumption')->nullable();
                $table->string('source_name');
                $table->unsignedSmallInteger('source_year');
                $table->text('source_url');
                $table->string('version', 40);
                $table->text('notes')->nullable();
                $table->boolean('is_active')->default(true)->index();
                $table->date('effective_from')->nullable();
                $table->date('effective_to')->nullable();
                $table->timestamps();
                $table->unique(['transport_mode', 'version']);
            });
        }

        $factorSource = 'https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2026';
        foreach ([
            ['walking', 'Walking', 0.000000, 'Direct operational emissions only'],
            ['bicycle', 'Bicycle', 0.000000, 'Direct operational emissions only'],
            ['motorcycle', 'Motorcycle', 0.113000, 'Average passenger-km planning factor'],
            ['tricycle', 'Motorized tricycle', 0.120000, 'Transparent local proxy; replace after a verified Tubigon fleet study'],
            ['private_car', 'Private car', 0.170000, 'Average passenger-km planning factor'],
            ['van', 'Van', 0.105000, 'Average passenger-km planning factor'],
            ['bus', 'Bus', 0.102000, 'Average passenger-km planning factor'],
            ['ferry_foot', 'Ferry (foot passenger)', 0.019000, 'Foot-passenger planning factor; route distance must not come from road routing'],
        ] as [$mode, $name, $factor, $notes]) {
            DB::table('emission_factors')->updateOrInsert(
                ['transport_mode' => $mode, 'version' => '2026.1'],
                [
                    'id' => DB::table('emission_factors')->where(['transport_mode' => $mode, 'version' => '2026.1'])->value('id') ?: (string) Str::uuid(),
                    'display_name' => $name,
                    'emission_factor' => $factor,
                    'unit' => 'kg_co2e_per_passenger_km',
                    'occupancy_assumption' => $notes,
                    'source_name' => 'UK Government GHG Conversion Factors 2026 (rounded planning adaptation)',
                    'source_year' => 2026,
                    'source_url' => $factorSource,
                    'notes' => $notes,
                    'is_active' => true,
                    'effective_from' => '2026-01-01',
                    'effective_to' => null,
                    'created_at' => $now,
                    'updated_at' => $now,
                ],
            );
        }

        if (! Schema::hasTable('carbon_estimates')) {
            Schema::create('carbon_estimates', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->uuid('user_id')->index();
                $table->uuid('emission_factor_id')->index();
                $table->string('origin_name')->nullable();
                $table->string('destination_name')->nullable();
                $table->string('origin_entity_type', 80)->nullable();
                $table->uuid('origin_entity_id')->nullable();
                $table->string('destination_entity_type', 80)->nullable();
                $table->uuid('destination_entity_id')->nullable();
                $table->decimal('distance_km', 12, 3);
                $table->string('distance_source', 32);
                $table->timestamp('route_calculated_at')->nullable();
                $table->unsignedSmallInteger('travelers');
                $table->string('trip_type', 24);
                $table->decimal('estimated_kg_co2e', 14, 4);
                $table->decimal('per_traveler_kg_co2e', 14, 4);
                $table->string('factor_version', 40);
                $table->string('factor_unit', 64);
                $table->uuid('itinerary_id')->nullable()->index();
                $table->json('leg_breakdown')->nullable();
                $table->timestamps();
                $table->foreign('emission_factor_id')->references('id')->on('emission_factors')->restrictOnDelete();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('carbon_estimates');
        Schema::dropIfExists('emission_factors');
        Schema::dropIfExists('waste_report_media');
        if (Schema::hasTable('waste_report_history') && Schema::hasColumn('waste_report_history', 'is_public')) {
            Schema::table('waste_report_history', fn (Blueprint $table) => $table->dropColumn('is_public'));
        }
        $this->dropColumns('emergency_contacts', ['is_public', 'verification_status', 'source_name', 'notes']);
        $this->dropColumns('waste_reports', [
            'category_id', 'severity', 'resolved_address', 'geocoding_source',
            'client_submission_id', 'submitted_at', 'resolved_by',
            'resolution_summary', 'reopened_at',
        ]);
        Schema::dropIfExists('waste_categories');
    }

    private function dropColumns(string $tableName, array $columns): void
    {
        if (! Schema::hasTable($tableName)) return;
        $existing = array_values(array_filter($columns, fn (string $column) => Schema::hasColumn($tableName, $column)));
        if ($existing !== []) Schema::table($tableName, fn (Blueprint $table) => $table->dropColumn($existing));
    }
};
