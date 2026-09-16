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
        Schema::create('ferry_operators', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('name')->unique();
            $table->text('logo')->nullable();
            $table->text('description')->nullable();
            $table->string('contact_number')->nullable();
            $table->text('website')->nullable();
            $table->boolean('is_active')->default(true)->index();
            $table->timestamps();
        });

        Schema::create('ferry_vessels', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('ferry_operator_id')->index();
            $table->string('vessel_name');
            $table->boolean('is_active')->default(true)->index();
            $table->timestamps();
            $table->unique(['ferry_operator_id', 'vessel_name']);
            $table->foreign('ferry_operator_id')->references('id')->on('ferry_operators')->cascadeOnDelete();
        });

        Schema::table('ferry_schedules', function (Blueprint $table): void {
            $table->uuid('ferry_operator_id')->nullable()->index()->after('operator');
            $table->uuid('ferry_vessel_id')->nullable()->index()->after('vessel_name');
            $table->boolean('arrival_next_day')->default(false)->after('arrival_time');
            $table->text('source_reference')->nullable()->after('reference_url');
            $table->uuid('created_by')->nullable()->index()->after('source_reference');
            $table->foreign('ferry_operator_id')->references('id')->on('ferry_operators')->nullOnDelete();
            $table->foreign('ferry_vessel_id')->references('id')->on('ferry_vessels')->nullOnDelete();
        });

        $operators = [];
        $rows = DB::table('ferry_schedules')
            ->select(['id', 'operator', 'vessel_name'])
            ->whereNull('deleted_at')
            ->orderBy('created_at')
            ->get();

        foreach ($rows as $row) {
            $operatorName = $this->canonicalOperatorName((string) $row->operator);
            if ($operatorName === '') {
                continue;
            }

            $operatorKey = Str::lower($operatorName);
            if (! isset($operators[$operatorKey])) {
                $existing = DB::table('ferry_operators')
                    ->whereRaw('LOWER(name) = ?', [$operatorKey])
                    ->first();
                $operators[$operatorKey] = $existing?->id ?? (string) Str::uuid();
                if (! $existing) {
                    DB::table('ferry_operators')->insert([
                        'id' => $operators[$operatorKey],
                        'name' => $operatorName,
                        'is_active' => true,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }
            }

            $vesselId = null;
            $vesselName = trim((string) ($row->vessel_name ?? ''));
            if ($vesselName !== '') {
                $vessel = DB::table('ferry_vessels')
                    ->where('ferry_operator_id', $operators[$operatorKey])
                    ->whereRaw('LOWER(vessel_name) = ?', [Str::lower($vesselName)])
                    ->first();
                $vesselId = $vessel?->id ?? (string) Str::uuid();
                if (! $vessel) {
                    DB::table('ferry_vessels')->insert([
                        'id' => $vesselId,
                        'ferry_operator_id' => $operators[$operatorKey],
                        'vessel_name' => $vesselName,
                        'is_active' => true,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }
            }

            DB::table('ferry_schedules')->where('id', $row->id)->update([
                'operator' => $operatorName,
                'ferry_operator_id' => $operators[$operatorKey],
                'ferry_vessel_id' => $vesselId,
            ]);
        }
    }

    public function down(): void
    {
        Schema::table('ferry_schedules', function (Blueprint $table): void {
            $table->dropForeign(['ferry_operator_id']);
            $table->dropForeign(['ferry_vessel_id']);
            $table->dropColumn([
                'ferry_operator_id',
                'ferry_vessel_id',
                'arrival_next_day',
                'source_reference',
                'created_by',
            ]);
        });
        Schema::dropIfExists('ferry_vessels');
        Schema::dropIfExists('ferry_operators');
    }

    private function canonicalOperatorName(string $name): string
    {
        $trimmed = preg_replace('/\s+/', ' ', trim($name)) ?? '';

        return match (Str::lower($trimmed)) {
            'fastcat', 'fast cat' => 'FastCat',
            'lite ferry', 'lite ferries' => 'Lite Ferries',
            'mv star craft', 'mv starcraft', 'starcraft' => 'MV Starcraft',
            default => $trimmed,
        };
    }
};
