<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tourist_spots', function (Blueprint $table): void {
            if (! Schema::hasColumn('tourist_spots', 'booking_enabled')) {
                $table->boolean('booking_enabled')->default(false)->index()->after('is_bookable');
            }
            if (! Schema::hasColumn('tourist_spots', 'booking_unavailable_reason_code')) {
                $table->string('booking_unavailable_reason_code', 64)->nullable()->after('booking_enabled');
            }
            if (! Schema::hasColumn('tourist_spots', 'booking_unavailable_reason')) {
                $table->text('booking_unavailable_reason')->nullable()->after('booking_unavailable_reason_code');
            }
            if (! Schema::hasColumn('tourist_spots', 'booking_availability_updated_at')) {
                $table->timestamp('booking_availability_updated_at')->nullable()->after('booking_unavailable_reason');
            }
            if (! Schema::hasColumn('tourist_spots', 'booking_availability_updated_by')) {
                $table->uuid('booking_availability_updated_by')->nullable()->index()->after('booking_availability_updated_at');
                $table->foreign('booking_availability_updated_by')
                    ->references('id')->on('users')->nullOnDelete();
            }
            if (! Schema::hasColumn('tourist_spots', 'contact_information')) {
                $table->text('contact_information')->nullable()->after('opening_hours');
            }
            if (! Schema::hasColumn('tourist_spots', 'visitor_instructions')) {
                $table->text('visitor_instructions')->nullable()->after('contact_information');
            }
            if (! Schema::hasColumn('tourist_spots', 'amenities')) {
                $table->json('amenities')->nullable()->after('visitor_instructions');
            }
        });
        // Existing configured destinations retain their effective availability.
        DB::table('tourist_spots')->update([
            'booking_enabled' => DB::raw('is_bookable'),
        ]);

        if (! Schema::hasTable('tourist_spot_partner_assignments')) {
            Schema::create('tourist_spot_partner_assignments', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->uuid('tourist_spot_id')->index();
                $table->uuid('partner_profile_id')->index();
                $table->boolean('is_primary')->default(true)->index();
                $table->uuid('assigned_by')->nullable()->index();
                $table->timestamp('assigned_at');
                $table->timestamps();
                $table->unique(['tourist_spot_id', 'partner_profile_id'], 'spot_partner_unique');
                $table->foreign('tourist_spot_id')->references('id')->on('tourist_spots')->cascadeOnDelete();
                $table->foreign('partner_profile_id')->references('id')->on('profiles')->cascadeOnDelete();
                $table->foreign('assigned_by')->references('id')->on('users')->nullOnDelete();
            });
        }

        if (! Schema::hasTable('tourist_spot_booking_availability_history')) {
            Schema::create('tourist_spot_booking_availability_history', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->uuid('tourist_spot_id')->index('spot_book_avail_hist_spot_idx');
                $table->boolean('booking_enabled')->index('spot_book_avail_hist_enabled_idx');
                $table->string('reason_code', 64)->nullable();
                $table->text('reason')->nullable();
                $table->uuid('changed_by')->nullable()->index('spot_book_avail_hist_actor_idx');
                $table->timestamp('changed_at');
                $table->timestamps();
                $table->foreign('tourist_spot_id', 'spot_book_avail_hist_spot_fk')
                    ->references('id')->on('tourist_spots')->cascadeOnDelete();
                $table->foreign('changed_by', 'spot_book_avail_hist_actor_fk')
                    ->references('id')->on('users')->nullOnDelete();
            });
        } else {
            $this->completePartiallyCreatedHistoryTable();
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('tourist_spot_booking_availability_history');
        Schema::dropIfExists('tourist_spot_partner_assignments');

        Schema::table('tourist_spots', function (Blueprint $table): void {
            $table->dropForeign(['booking_availability_updated_by']);
            $table->dropColumn([
                'booking_enabled',
                'booking_unavailable_reason_code',
                'booking_unavailable_reason',
                'booking_availability_updated_at',
                'booking_availability_updated_by',
                'contact_information',
                'visitor_instructions',
                'amenities',
            ]);
        });
    }

    /** Complete a table left behind if MySQL rejected an overlong generated key name. */
    private function completePartiallyCreatedHistoryTable(): void
    {
        // SHOW CREATE avoids an information_schema join that is unstable on
        // the project's local MariaDB 10.4 recovery instance.
        $createSql = '';
        if (DB::getDriverName() === 'mysql') {
            $row = DB::selectOne('SHOW CREATE TABLE `tourist_spot_booking_availability_history`');
            $values = $row ? array_values((array) $row) : [];
            $createSql = (string) ($values[1] ?? '');
        }

        Schema::table('tourist_spot_booking_availability_history', function (Blueprint $table) use ($createSql): void {
            if (! str_contains($createSql, 'spot_book_avail_hist_spot_fk')) {
                $table->foreign('tourist_spot_id', 'spot_book_avail_hist_spot_fk')
                    ->references('id')->on('tourist_spots')->cascadeOnDelete();
            }
            if (! str_contains($createSql, 'spot_book_avail_hist_actor_fk')) {
                $table->foreign('changed_by', 'spot_book_avail_hist_actor_fk')
                    ->references('id')->on('users')->nullOnDelete();
            }
            if (! str_contains($createSql, 'spot_book_avail_hist_spot_idx')) {
                $table->index('tourist_spot_id', 'spot_book_avail_hist_spot_idx');
            }
            if (! str_contains($createSql, 'spot_book_avail_hist_enabled_idx')) {
                $table->index('booking_enabled', 'spot_book_avail_hist_enabled_idx');
            }
            if (! str_contains($createSql, 'spot_book_avail_hist_actor_idx')) {
                $table->index('changed_by', 'spot_book_avail_hist_actor_idx');
            }
        });
    }
};
