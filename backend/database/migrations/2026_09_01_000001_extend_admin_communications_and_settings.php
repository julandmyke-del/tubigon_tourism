<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('announcements', function (Blueprint $table): void {
            $table->string('type', 50)->default('general')->after('category');
            $table->string('audience', 50)->default('everyone')->index()->after('type');
            $table->string('priority', 20)->default('normal')->index()->after('audience');
            $table->string('status', 20)->default('published')->index()->after('priority');
            $table->timestamp('starts_at')->nullable()->index()->after('status');
            $table->timestamp('expires_at')->nullable()->index()->after('starts_at');
            $table->timestamp('published_at')->nullable()->after('expires_at');
            $table->uuid('created_by')->nullable()->index()->after('published_at');
        });

        Schema::table('notifications', function (Blueprint $table): void {
            $table->uuid('announcement_id')->nullable()->index()->after('user_id');
            $table->unique(['user_id', 'announcement_id'], 'notifications_user_announcement_unique');
        });

        Schema::table('partner_notifications', function (Blueprint $table): void {
            $table->uuid('announcement_id')->nullable()->index()->after('user_id');
            $table->unique(['user_id', 'announcement_id'], 'partner_notifications_user_announcement_unique');
        });

        Schema::table('system_settings', function (Blueprint $table): void {
            $table->string('municipality_name')->default('Municipality of Tubigon')->after('app_name');
            $table->string('tourism_office_address')->nullable()->after('contact_phone');
            $table->string('support_contact')->nullable()->after('tourism_office_address');
            $table->boolean('tourist_registration_enabled')->default(true);
            $table->boolean('msme_registration_enabled')->default(true);
            $table->boolean('require_msme_verification')->default(true);
            $table->boolean('reviews_enabled')->default(true);
            $table->boolean('waste_reporting_enabled')->default(true);
            $table->boolean('global_booking_enabled')->default(true);
            $table->text('maintenance_notice')->nullable();
            $table->uuid('updated_by')->nullable()->index();
        });
    }

    public function down(): void
    {
        Schema::table('notifications', function (Blueprint $table): void {
            $table->dropUnique('notifications_user_announcement_unique');
            $table->dropColumn('announcement_id');
        });
        Schema::table('partner_notifications', function (Blueprint $table): void {
            $table->dropUnique('partner_notifications_user_announcement_unique');
            $table->dropColumn('announcement_id');
        });
        Schema::table('announcements', function (Blueprint $table): void {
            $table->dropColumn([
                'type', 'audience', 'priority', 'status', 'starts_at',
                'expires_at', 'published_at', 'created_by',
            ]);
        });
        Schema::table('system_settings', function (Blueprint $table): void {
            $table->dropColumn([
                'municipality_name', 'tourism_office_address', 'support_contact',
                'tourist_registration_enabled', 'msme_registration_enabled',
                'require_msme_verification', 'reviews_enabled',
                'waste_reporting_enabled', 'global_booking_enabled',
                'maintenance_notice', 'updated_by',
            ]);
        });
    }
};
