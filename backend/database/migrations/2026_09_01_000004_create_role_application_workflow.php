<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('tourist_spot_partner_assignments')) {
            $duplicateSpot = DB::table('tourist_spot_partner_assignments')
                ->select('tourist_spot_id')->groupBy('tourist_spot_id')
                ->havingRaw('COUNT(*) > 1')->value('tourist_spot_id');
            $duplicatePartner = DB::table('tourist_spot_partner_assignments')
                ->select('partner_profile_id')->groupBy('partner_profile_id')
                ->havingRaw('COUNT(*) > 1')->value('partner_profile_id');
            if ($duplicateSpot !== null || $duplicatePartner !== null) {
                throw new RuntimeException(
                    'Partner assignments must be reconciled to one destination per partner and one partner per destination before enabling access applications.',
                );
            }
            Schema::table('tourist_spot_partner_assignments', function (Blueprint $table): void {
                $table->unique('tourist_spot_id', 'partner_assignment_spot_unique');
                $table->unique('partner_profile_id', 'partner_assignment_profile_unique');
            });
        }

        if (! Schema::hasTable('role_applications')) {
            Schema::create('role_applications', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->uuid('applicant_user_id')->index('role_app_applicant_idx');
                $table->string('application_type', 32)->index('role_app_type_idx');
                $table->string('status', 40)->default('draft')->index('role_app_status_idx');
                // Terminal applications set this to null. A nullable value lets the
                // database enforce one active request per user and application type.
                $table->boolean('active_slot')->nullable()->default(true);
                $table->json('payload')->nullable();
                $table->uuid('requested_tourist_spot_id')->nullable()->index('role_app_spot_idx');
                $table->uuid('linked_msme_id')->nullable()->index('role_app_msme_idx');
                $table->json('lgu_checklist')->nullable();
                $table->uuid('reviewed_by_lgu_id')->nullable()->index('role_app_lgu_idx');
                $table->timestamp('lgu_reviewed_at')->nullable();
                $table->text('lgu_notes')->nullable();
                $table->uuid('admin_reviewed_by_id')->nullable()->index('role_app_admin_idx');
                $table->timestamp('admin_reviewed_at')->nullable();
                $table->text('admin_notes')->nullable();
                $table->timestamp('submitted_at')->nullable();
                $table->timestamp('approved_at')->nullable();
                $table->timestamp('rejected_at')->nullable();
                $table->timestamp('withdrawn_at')->nullable();
                $table->timestamps();

                $table->unique(
                    ['applicant_user_id', 'application_type', 'active_slot'],
                    'role_app_one_active_unique',
                );
                $table->foreign('applicant_user_id', 'role_app_applicant_fk')
                    ->references('id')->on('users')->cascadeOnDelete();
                $table->foreign('requested_tourist_spot_id', 'role_app_spot_fk')
                    ->references('id')->on('tourist_spots')->nullOnDelete();
                $table->foreign('linked_msme_id', 'role_app_msme_fk')
                    ->references('id')->on('msmes')->nullOnDelete();
                $table->foreign('reviewed_by_lgu_id', 'role_app_lgu_fk')
                    ->references('id')->on('users')->nullOnDelete();
                $table->foreign('admin_reviewed_by_id', 'role_app_admin_fk')
                    ->references('id')->on('users')->nullOnDelete();
            });
        }

        if (! Schema::hasTable('role_application_history')) {
            Schema::create('role_application_history', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->uuid('application_id')->index('role_app_hist_app_idx');
                $table->uuid('actor_user_id')->nullable()->index('role_app_hist_actor_idx');
                $table->string('action', 64);
                $table->string('from_status', 40)->nullable();
                $table->string('to_status', 40)->nullable();
                $table->text('notes')->nullable();
                $table->json('metadata')->nullable();
                $table->timestamp('created_at')->useCurrent();

                $table->foreign('application_id', 'role_app_hist_app_fk')
                    ->references('id')->on('role_applications')->cascadeOnDelete();
                $table->foreign('actor_user_id', 'role_app_hist_actor_fk')
                    ->references('id')->on('users')->nullOnDelete();
            });
        }

        if (Schema::hasTable('system_settings')) {
            Schema::table('system_settings', function (Blueprint $table): void {
                if (! Schema::hasColumn('system_settings', 'msme_applications_enabled')) {
                    $table->boolean('msme_applications_enabled')->default(true);
                }
                if (! Schema::hasColumn('system_settings', 'partner_applications_enabled')) {
                    $table->boolean('partner_applications_enabled')->default(true);
                }
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('role_application_history');
        Schema::dropIfExists('role_applications');

        if (Schema::hasTable('tourist_spot_partner_assignments')) {
            Schema::table('tourist_spot_partner_assignments', function (Blueprint $table): void {
                $table->dropUnique('partner_assignment_spot_unique');
                $table->dropUnique('partner_assignment_profile_unique');
            });
        }

        if (Schema::hasTable('system_settings')) {
            Schema::table('system_settings', function (Blueprint $table): void {
                if (Schema::hasColumn('system_settings', 'msme_applications_enabled')) {
                    $table->dropColumn('msme_applications_enabled');
                }
                if (Schema::hasColumn('system_settings', 'partner_applications_enabled')) {
                    $table->dropColumn('partner_applications_enabled');
                }
            });
        }
    }
};
