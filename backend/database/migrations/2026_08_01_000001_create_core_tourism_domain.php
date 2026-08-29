<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Recreates the domain schema that originally existed only in tubigon.sql.
     * Every table is guarded so applying this to an imported database is additive.
     */
    public function up(): void
    {
        if (! Schema::hasTable('spot_categories')) {
            Schema::create('spot_categories', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->unsignedInteger('integer_id')->nullable()->unique();
                $table->string('name')->unique();
                $table->string('slug')->unique();
                $table->timestamps();
                $table->softDeletes();
            });
            $this->enableMysqlSequence('spot_categories');
        }

        if (! Schema::hasTable('tourist_spots')) {
            Schema::create('tourist_spots', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->unsignedInteger('integer_id')->nullable()->unique();
                $table->string('name');
                $table->string('slug')->unique();
                $table->text('description')->nullable();
                $table->uuid('category_id')->nullable();
                $table->double('latitude')->nullable();
                $table->double('longitude')->nullable();
                $table->text('address')->nullable();
                $table->decimal('entrance_fee', 10, 2)->default(0);
                $table->string('opening_hours')->nullable();
                $table->json('eco_tips')->nullable();
                $table->json('images')->nullable();
                $table->decimal('average_rating', 3, 2)->default(0);
                $table->unsignedInteger('review_count')->default(0);
                $table->boolean('is_featured')->default(false)->index();
                $table->boolean('is_active')->default(true)->index();
                $table->timestamps();
                $table->softDeletes();
                $table->foreign('category_id')->references('id')->on('spot_categories')->nullOnDelete();
            });
            $this->enableMysqlSequence('tourist_spots');
        }

        if (! Schema::hasTable('establishments')) {
            Schema::create('establishments', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->unsignedInteger('integer_id')->nullable()->unique();
                $table->string('name');
                $table->string('category')->nullable();
                $table->text('description')->nullable();
                $table->double('latitude')->nullable();
                $table->double('longitude')->nullable();
                $table->text('address')->nullable();
                $table->string('phone')->nullable();
                $table->string('email')->nullable();
                $table->string('website')->nullable();
                $table->string('business_hours')->nullable();
                $table->json('images')->nullable();
                $table->decimal('average_rating', 3, 2)->default(0);
                $table->unsignedInteger('review_count')->default(0);
                $table->boolean('is_verified')->default(false)->index();
                $table->boolean('is_active')->default(true)->index();
                $table->timestamps();
                $table->softDeletes();
            });
            $this->enableMysqlSequence('establishments');
        }

        if (! Schema::hasTable('msmes')) {
            Schema::create('msmes', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->unsignedInteger('integer_id')->nullable()->unique();
                $table->uuid('profile_id')->nullable()->index();
                $table->string('name');
                $table->string('category');
                $table->string('tagline')->nullable();
                $table->text('description')->nullable();
                $table->string('phone')->nullable();
                $table->text('address')->nullable();
                $table->double('latitude')->nullable();
                $table->double('longitude')->nullable();
                $table->string('business_hours')->nullable();
                $table->decimal('rating', 3, 2)->default(0);
                $table->unsignedInteger('review_count')->default(0);
                $table->string('color', 50)->nullable();
                $table->string('icon', 100)->nullable();
                $table->boolean('is_verified')->default(false)->index();
                $table->json('products')->nullable();
                $table->timestamps();
                $table->softDeletes();
                $table->foreign('profile_id')->references('id')->on('profiles')->nullOnDelete();
            });
            $this->enableMysqlSequence('msmes');
        }

        if (! Schema::hasTable('reservation_status')) {
            Schema::create('reservation_status', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->string('name')->unique();
                $table->timestamps();
                $table->softDeletes();
            });
        }

        if (! Schema::hasTable('reservations')) {
            Schema::create('reservations', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->uuid('user_id')->index();
                $table->uuid('partner_id')->nullable()->index();
                $table->string('reservable_type');
                $table->uuid('reservable_id')->index();
                $table->dateTime('reservation_date');
                $table->string('start_time', 50)->nullable();
                $table->string('end_time', 50)->nullable();
                $table->unsignedInteger('guests')->default(1);
                $table->uuid('status_id')->nullable()->index();
                $table->text('notes')->nullable();
                $table->decimal('total_amount', 10, 2)->default(0);
                $table->timestamps();
                $table->softDeletes();
                $table->foreign('user_id')->references('id')->on('profiles')->cascadeOnDelete();
                $table->foreign('status_id')->references('id')->on('reservation_status')->restrictOnDelete();
            });
        }

        if (! Schema::hasTable('favorites')) {
            Schema::create('favorites', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->uuid('user_id')->index();
                $table->string('favoritable_type');
                $table->uuid('favoritable_id');
                $table->timestamps();
                $table->softDeletes();
                $table->unique(['user_id', 'favoritable_type', 'favoritable_id'], 'user_favoritable_unique');
                $table->foreign('user_id')->references('id')->on('profiles')->cascadeOnDelete();
            });
        }

        if (! Schema::hasTable('reviews')) {
            Schema::create('reviews', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->uuid('user_id')->index();
                $table->string('reviewable_type');
                $table->uuid('reviewable_id');
                $table->unsignedTinyInteger('rating');
                $table->text('content')->nullable();
                $table->json('images')->nullable();
                $table->timestamps();
                $table->softDeletes();
                $table->index(['reviewable_type', 'reviewable_id']);
                $table->foreign('user_id')->references('id')->on('profiles')->cascadeOnDelete();
            });
        }

        if (! Schema::hasTable('ratings')) {
            Schema::create('ratings', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->uuid('user_id')->index();
                $table->string('rateable_type');
                $table->uuid('rateable_id');
                $table->unsignedTinyInteger('value');
                $table->timestamps();
                $table->softDeletes();
                $table->unique(['user_id', 'rateable_type', 'rateable_id']);
                $table->foreign('user_id')->references('id')->on('profiles')->cascadeOnDelete();
            });
        }

        if (! Schema::hasTable('waste_reports')) {
            Schema::create('waste_reports', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->uuid('user_id')->nullable()->index();
                $table->string('category');
                $table->text('description');
                $table->text('location_description')->nullable();
                $table->double('latitude')->nullable();
                $table->double('longitude')->nullable();
                $table->json('images')->nullable();
                $table->string('status', 50)->default('submitted')->index();
                $table->timestamps();
                $table->softDeletes();
                $table->foreign('user_id')->references('id')->on('profiles')->nullOnDelete();
            });
        }

        if (! Schema::hasTable('eco_tips')) {
            Schema::create('eco_tips', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->unsignedInteger('integer_id')->nullable()->unique();
                $table->string('title');
                $table->text('content');
                $table->string('category')->nullable();
                $table->uuid('spot_id')->nullable();
                $table->string('language', 50)->default('en');
                $table->timestamps();
                $table->softDeletes();
                $table->foreign('spot_id')->references('id')->on('tourist_spots')->nullOnDelete();
            });
            $this->enableMysqlSequence('eco_tips');
        }

        if (! Schema::hasTable('announcements')) {
            Schema::create('announcements', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->string('title');
                $table->text('body');
                $table->string('category')->nullable();
                $table->boolean('is_active')->default(true)->index();
                $table->timestamps();
                $table->softDeletes();
            });
        }

        if (! Schema::hasTable('notifications')) {
            Schema::create('notifications', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->uuid('user_id')->nullable()->index();
                $table->string('type');
                $table->string('title');
                $table->text('body')->nullable();
                $table->json('data')->nullable();
                $table->boolean('is_read')->default(false)->index();
                $table->timestamps();
                $table->softDeletes();
                $table->foreign('user_id')->references('id')->on('profiles')->cascadeOnDelete();
            });
        }

        if (! Schema::hasTable('emergency_contacts')) {
            Schema::create('emergency_contacts', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->unsignedInteger('integer_id')->nullable()->unique();
                $table->string('name');
                $table->string('category');
                $table->string('phone', 50);
                $table->text('address')->nullable();
                $table->double('latitude')->nullable();
                $table->double('longitude')->nullable();
                $table->timestamps();
                $table->softDeletes();
            });
            $this->enableMysqlSequence('emergency_contacts');
        }

        if (! Schema::hasTable('ferry_schedules')) {
            Schema::create('ferry_schedules', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->unsignedInteger('integer_id')->nullable()->unique();
                $table->string('operator');
                $table->string('route');
                $table->string('departure_time', 50);
                $table->string('arrival_time', 50)->nullable();
                $table->decimal('fare', 10, 2)->nullable();
                $table->string('status', 50)->default('scheduled')->index();
                $table->json('days_of_week')->nullable();
                $table->timestamps();
                $table->softDeletes();
            });
            $this->enableMysqlSequence('ferry_schedules');
        }

        if (! Schema::hasTable('images')) {
            Schema::create('images', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->text('url');
                $table->string('bucket');
                $table->uuid('owner_id')->nullable()->index();
                $table->timestamps();
                $table->softDeletes();
                $table->foreign('owner_id')->references('id')->on('profiles')->nullOnDelete();
            });
        }

        if (! Schema::hasTable('activity_logs')) {
            Schema::create('activity_logs', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->uuid('user_id')->nullable()->index();
                $table->string('action');
                $table->text('details')->nullable();
                $table->timestamps();
                $table->softDeletes();
                $table->foreign('user_id')->references('id')->on('profiles')->nullOnDelete();
            });
        }

        if (! Schema::hasTable('settings')) {
            Schema::create('settings', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->uuid('user_id')->unique();
                $table->boolean('notifications_enabled')->default(true);
                $table->boolean('location_enabled')->default(true);
                $table->boolean('offline_mode')->default(false);
                $table->string('language', 50)->default('en');
                $table->timestamps();
                $table->softDeletes();
                $table->foreign('user_id')->references('id')->on('profiles')->cascadeOnDelete();
            });
        }

        if (! Schema::hasTable('system_settings')) {
            Schema::create('system_settings', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->string('app_name')->default('Tubigon Smart Tourism');
                $table->string('contact_email')->default('support@tubigontourism.gov.ph');
                $table->string('contact_phone')->default('+63 38 508 8000');
                $table->text('privacy_policy')->nullable();
                $table->text('terms_of_service')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('admin_notifications')) {
            Schema::create('admin_notifications', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->string('title');
                $table->text('body');
                $table->string('type');
                $table->json('data')->nullable();
                $table->boolean('is_read')->default(false);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('tourism_listings')) {
            Schema::create('tourism_listings', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->uuid('owner_id')->index();
                $table->string('listing_name');
                $table->string('listing_type')->default('attraction');
                $table->text('description')->nullable();
                $table->text('address')->nullable();
                $table->double('latitude')->nullable();
                $table->double('longitude')->nullable();
                $table->string('contact_number')->nullable();
                $table->string('email')->nullable();
                $table->string('operating_hours')->nullable();
                $table->json('images')->nullable();
                $table->string('status', 50)->default('draft');
                $table->boolean('is_active')->default(false)->index();
                $table->decimal('average_rating', 3, 2)->default(0);
                $table->unsignedInteger('review_count')->default(0);
                $table->timestamps();
                $table->softDeletes();
                $table->foreign('owner_id')->references('id')->on('profiles')->cascadeOnDelete();
            });
        }

        if (! Schema::hasTable('partner_notifications')) {
            Schema::create('partner_notifications', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->uuid('user_id')->index();
                $table->string('type');
                $table->string('title');
                $table->text('body')->nullable();
                $table->json('data')->nullable();
                $table->boolean('is_read')->default(false)->index();
                $table->timestamps();
                $table->softDeletes();
                $table->foreign('user_id')->references('id')->on('profiles')->cascadeOnDelete();
            });
        }

        DB::table('roles')->insertOrIgnore([
            ['id' => 'r0000000-0000-0000-0000-000000000001', 'name' => 'tourist', 'created_at' => now(), 'updated_at' => now()],
            ['id' => 'r0000000-0000-0000-0000-000000000002', 'name' => 'msme_owner', 'created_at' => now(), 'updated_at' => now()],
            ['id' => 'r0000000-0000-0000-0000-000000000003', 'name' => 'lgu_staff', 'created_at' => now(), 'updated_at' => now()],
            ['id' => 'r0000000-0000-0000-0000-000000000004', 'name' => 'admin', 'created_at' => now(), 'updated_at' => now()],
            ['id' => 'r0000000-0000-0000-0000-000000000005', 'name' => 'tourism_partner', 'created_at' => now(), 'updated_at' => now()],
        ]);
        DB::table('reservation_status')->insertOrIgnore([
            ['id' => 's0000000-0000-0000-0000-000000000001', 'name' => 'pending', 'created_at' => now(), 'updated_at' => now()],
            ['id' => 's0000000-0000-0000-0000-000000000002', 'name' => 'confirmed', 'created_at' => now(), 'updated_at' => now()],
            ['id' => 's0000000-0000-0000-0000-000000000003', 'name' => 'approved', 'created_at' => now(), 'updated_at' => now()],
            ['id' => 's0000000-0000-0000-0000-000000000004', 'name' => 'rejected', 'created_at' => now(), 'updated_at' => now()],
            ['id' => 's0000000-0000-0000-0000-000000000005', 'name' => 'completed', 'created_at' => now(), 'updated_at' => now()],
            ['id' => 's0000000-0000-0000-0000-000000000006', 'name' => 'cancelled', 'created_at' => now(), 'updated_at' => now()],
        ]);
    }

    /** Rollback is intentionally a no-op: these tables may predate Laravel migrations. */
    public function down(): void {}

    private function enableMysqlSequence(string $table): void
    {
        if (DB::getDriverName() !== 'mysql') {
            return;
        }
        DB::statement("ALTER TABLE `{$table}` MODIFY `integer_id` INT UNSIGNED NOT NULL AUTO_INCREMENT");
    }
};
