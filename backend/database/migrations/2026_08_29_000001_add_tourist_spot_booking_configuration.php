<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tourist_spots', function (Blueprint $table): void {
            if (! Schema::hasColumn('tourist_spots', 'is_published')) {
                $table->boolean('is_published')->default(false)->index()->after('is_active');
            }
            if (! Schema::hasColumn('tourist_spots', 'is_bookable')) {
                $table->boolean('is_bookable')->default(false)->index()->after('is_published');
            }
            if (! Schema::hasColumn('tourist_spots', 'booking_mode')) {
                $table->string('booking_mode', 32)->default('no_reservation')->after('is_bookable');
            }
            if (! Schema::hasColumn('tourist_spots', 'booking_available_days')) {
                $table->json('booking_available_days')->nullable()->after('booking_mode');
            }
            if (! Schema::hasColumn('tourist_spots', 'booking_time_slots')) {
                $table->json('booking_time_slots')->nullable()->after('booking_available_days');
            }
            if (! Schema::hasColumn('tourist_spots', 'max_guests_per_reservation')) {
                $table->unsignedInteger('max_guests_per_reservation')->nullable()->after('booking_time_slots');
            }
            if (! Schema::hasColumn('tourist_spots', 'capacity_per_slot')) {
                $table->unsignedInteger('capacity_per_slot')->nullable()->after('max_guests_per_reservation');
            }
            if (! Schema::hasColumn('tourist_spots', 'advance_booking_days')) {
                $table->unsignedInteger('advance_booking_days')->nullable()->after('capacity_per_slot');
            }
            if (! Schema::hasColumn('tourist_spots', 'minimum_notice_hours')) {
                $table->unsignedInteger('minimum_notice_hours')->nullable()->after('advance_booking_days');
            }
            if (! Schema::hasColumn('tourist_spots', 'reservation_fee')) {
                $table->decimal('reservation_fee', 10, 2)->nullable()->after('minimum_notice_hours');
            }
            if (! Schema::hasColumn('tourist_spots', 'booking_instructions')) {
                $table->text('booking_instructions')->nullable()->after('reservation_fee');
            }
            if (! Schema::hasColumn('tourist_spots', 'cancellation_policy')) {
                $table->text('cancellation_policy')->nullable()->after('booking_instructions');
            }
            if (! Schema::hasColumn('tourist_spots', 'cancellation_notice_hours')) {
                $table->unsignedInteger('cancellation_notice_hours')->nullable()->after('cancellation_policy');
            }
        });

        Schema::table('reservations', function (Blueprint $table): void {
            if (! Schema::hasColumn('reservations', 'public_reference')) {
                $table->string('public_reference', 32)->nullable()->unique()->after('id');
            }
        });

        DB::table('reservations')->whereNull('public_reference')->orderBy('id')
            ->chunkById(100, function ($rows): void {
                foreach ($rows as $row) {
                    $year = Carbon::parse($row->created_at ?? now())->format('Y');
                    DB::table('reservations')->where('id', $row->id)->update([
                        'public_reference' => "TB-RSV-{$year}-".strtoupper(Str::random(8)),
                    ]);
                }
            }, 'id');

        if (! Schema::hasTable('reservation_status_history')) {
            Schema::create('reservation_status_history', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->uuid('reservation_id')->index();
                $table->uuid('status_id')->index();
                $table->uuid('changed_by')->nullable()->index();
                $table->text('notes')->nullable();
                $table->timestamps();
                $table->foreign('reservation_id')->references('id')->on('reservations')->cascadeOnDelete();
                $table->foreign('status_id')->references('id')->on('reservation_status')->restrictOnDelete();
                $table->foreign('changed_by')->references('id')->on('users')->nullOnDelete();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('reservation_status_history');

        if (Schema::hasColumn('reservations', 'public_reference')) {
            Schema::table('reservations', function (Blueprint $table): void {
                $table->dropUnique(['public_reference']);
                $table->dropColumn('public_reference');
            });
        }

        $columns = [
            'is_published', 'is_bookable', 'booking_mode',
            'booking_available_days', 'booking_time_slots',
            'max_guests_per_reservation', 'capacity_per_slot',
            'advance_booking_days', 'minimum_notice_hours', 'reservation_fee',
            'booking_instructions', 'cancellation_policy', 'cancellation_notice_hours',
        ];
        foreach ($columns as $column) {
            if (Schema::hasColumn('tourist_spots', $column)) {
                Schema::table('tourist_spots', fn (Blueprint $table) => $table->dropColumn($column));
            }
        }
    }
};
