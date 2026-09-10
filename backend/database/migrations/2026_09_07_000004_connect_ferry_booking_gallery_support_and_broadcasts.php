<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ferry_ports', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->string('code', 32)->unique();
            $table->string('municipality')->nullable();
            $table->string('province')->nullable();
            $table->double('latitude')->nullable();
            $table->double('longitude')->nullable();
            $table->boolean('is_active')->default(true)->index();
            $table->timestamps();
        });
        Schema::create('ferry_routes', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->uuid('origin_port_id')->index();
            $table->uuid('destination_port_id')->index();
            $table->unsignedInteger('estimated_duration_minutes')->nullable();
            $table->boolean('is_active')->default(true)->index();
            $table->timestamps();
            $table->unique(['origin_port_id', 'destination_port_id']);
            $table->foreign('origin_port_id')->references('id')->on('ferry_ports')->restrictOnDelete();
            $table->foreign('destination_port_id')->references('id')->on('ferry_ports')->restrictOnDelete();
        });
        Schema::table('ferry_schedules', function (Blueprint $table): void {
            $table->uuid('ferry_route_id')->nullable()->index()->after('route');
            $table->uuid('origin_port_id')->nullable()->index()->after('ferry_route_id');
            $table->uuid('destination_port_id')->nullable()->index()->after('origin_port_id');
            $table->date('valid_from')->nullable()->index()->after('departure_date');
            $table->date('valid_until')->nullable()->index()->after('valid_from');
            $table->text('fare_notes')->nullable()->after('fare');
            $table->boolean('is_published')->default(false)->index()->after('is_active');
            $table->timestamp('published_at')->nullable()->after('is_published');
            $table->timestamp('archived_at')->nullable()->index()->after('published_at');
            $table->foreign('ferry_route_id')->references('id')->on('ferry_routes')->nullOnDelete();
            $table->foreign('origin_port_id')->references('id')->on('ferry_ports')->nullOnDelete();
            $table->foreign('destination_port_id')->references('id')->on('ferry_ports')->nullOnDelete();
        });
        // Preserve already-active, previously public schedules when introducing
        // the explicit publication workflow.
        DB::table('ferry_schedules')->where('is_active', true)->update([
            'is_published' => true,
            'published_at' => DB::raw('updated_at'),
        ]);

        Schema::create('booking_offerings', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('tourist_spot_id')->index();
            $table->string('type', 64)->index();
            $table->string('display_name');
            $table->text('description')->nullable();
            $table->decimal('price', 12, 2);
            $table->string('pricing_mode', 64);
            $table->unsignedInteger('capacity_per_unit')->nullable();
            $table->unsignedInteger('quantity_available')->nullable();
            $table->unsignedInteger('min_quantity')->default(1);
            $table->unsignedInteger('max_quantity')->nullable();
            $table->unsignedInteger('lead_time_minutes')->nullable();
            $table->unsignedInteger('max_advance_days')->nullable();
            $table->json('available_days')->nullable();
            $table->json('time_slots')->nullable();
            $table->json('blackout_dates')->nullable();
            $table->text('cancellation_note')->nullable();
            $table->text('operating_note')->nullable();
            $table->boolean('is_add_on')->default(false)->index();
            $table->boolean('is_active')->default(true)->index();
            $table->unsignedInteger('sort_order')->default(0);
            $table->uuid('created_by_user_id')->nullable()->index();
            $table->timestamps();
            $table->softDeletes();
            $table->foreign('tourist_spot_id')->references('id')->on('tourist_spots')->cascadeOnDelete();
            $table->foreign('created_by_user_id')->references('id')->on('users')->nullOnDelete();
        });
        Schema::create('booking_offering_fields', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('offering_id')->index();
            $table->string('field_key', 64);
            $table->string('label');
            $table->string('field_type', 32);
            $table->boolean('is_required')->default(false);
            $table->json('options_json')->nullable();
            $table->decimal('min_value', 12, 2)->nullable();
            $table->decimal('max_value', 12, 2)->nullable();
            $table->unsignedInteger('sort_order')->default(0);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->unique(['offering_id', 'field_key']);
            $table->foreign('offering_id')->references('id')->on('booking_offerings')->cascadeOnDelete();
        });
        Schema::table('reservations', function (Blueprint $table): void {
            $table->string('customer_name_snapshot')->nullable()->after('partner_id');
            $table->string('customer_email_snapshot')->nullable()->after('customer_name_snapshot');
            $table->string('customer_phone_snapshot', 64)->nullable()->after('customer_email_snapshot');
            $table->uuid('tourist_spot_id')->nullable()->index()->after('customer_phone_snapshot');
            $table->uuid('client_submission_id')->nullable()->unique()->after('tourist_spot_id');
        });
        Schema::create('reservation_items', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('reservation_id')->index();
            $table->uuid('offering_id')->nullable()->index();
            $table->string('offering_name_snapshot');
            $table->string('offering_type_snapshot', 64);
            $table->unsignedInteger('quantity');
            $table->decimal('unit_price_snapshot', 12, 2);
            $table->string('pricing_mode_snapshot', 64);
            $table->decimal('subtotal', 12, 2);
            $table->json('booking_details')->nullable();
            $table->timestamps();
            $table->foreign('reservation_id')->references('id')->on('reservations')->cascadeOnDelete();
            $table->foreign('offering_id')->references('id')->on('booking_offerings')->nullOnDelete();
        });
        Schema::create('reservation_messages', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('reservation_id')->index();
            $table->uuid('sender_user_id')->nullable()->index();
            $table->string('sender_role_at_time', 32);
            $table->text('message');
            $table->string('message_type', 32)->default('user_message');
            $table->boolean('is_internal')->default(false)->index();
            $table->timestamps();
            $table->foreign('reservation_id')->references('id')->on('reservations')->cascadeOnDelete();
            $table->foreign('sender_user_id')->references('id')->on('users')->nullOnDelete();
        });
        Schema::create('reservation_message_reads', function (Blueprint $table): void {
            $table->uuid('reservation_message_id');
            $table->uuid('user_id');
            $table->timestamp('read_at');
            $table->primary(['reservation_message_id', 'user_id']);
            $table->foreign('reservation_message_id')->references('id')->on('reservation_messages')->cascadeOnDelete();
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
        });

        Schema::create('tourist_spot_media', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('tourist_spot_id')->index();
            $table->uuid('booking_offering_id')->nullable()->index();
            $table->string('media_type', 16)->default('image');
            $table->string('storage_path');
            $table->string('thumbnail_path')->nullable();
            $table->string('mime_type', 64);
            $table->unsignedBigInteger('size_bytes');
            $table->string('caption')->nullable();
            $table->string('media_category', 32)->default('general');
            $table->unsignedInteger('sort_order')->default(0)->index();
            $table->boolean('is_cover')->default(false)->index();
            $table->boolean('is_active')->default(true)->index();
            $table->uuid('uploaded_by_user_id')->nullable()->index();
            $table->uuid('moderated_by_user_id')->nullable()->index();
            $table->text('moderation_note')->nullable();
            $table->timestamps();
            $table->softDeletes();
            $table->foreign('tourist_spot_id')->references('id')->on('tourist_spots')->cascadeOnDelete();
            $table->foreign('booking_offering_id')->references('id')->on('booking_offerings')->nullOnDelete();
            $table->foreign('uploaded_by_user_id')->references('id')->on('users')->nullOnDelete();
            $table->foreign('moderated_by_user_id')->references('id')->on('users')->nullOnDelete();
        });

        Schema::create('concern_categories', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('slug', 64)->unique();
            $table->string('name');
            $table->string('assigned_role', 32);
            $table->string('redirect_feature', 64)->nullable();
            $table->boolean('is_active')->default(true)->index();
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();
        });
        Schema::create('concerns', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('reference_no', 32)->unique();
            $table->uuid('user_id')->index();
            $table->uuid('category_id')->index();
            $table->string('subject');
            $table->text('description');
            $table->string('related_type', 64)->nullable();
            $table->uuid('related_id')->nullable();
            $table->string('status', 32)->default('submitted')->index();
            $table->string('assigned_role', 32)->index();
            $table->uuid('assigned_user_id')->nullable()->index();
            $table->string('priority', 16)->default('normal')->index();
            $table->timestamp('resolved_at')->nullable();
            $table->timestamp('closed_at')->nullable();
            $table->timestamps();
            $table->softDeletes();
            $table->index(['related_type', 'related_id']);
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('category_id')->references('id')->on('concern_categories')->restrictOnDelete();
            $table->foreign('assigned_user_id')->references('id')->on('users')->nullOnDelete();
        });
        Schema::create('concern_messages', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('concern_id')->index();
            $table->uuid('sender_user_id')->nullable()->index();
            $table->text('message');
            $table->boolean('is_internal')->default(false)->index();
            $table->timestamps();
            $table->foreign('concern_id')->references('id')->on('concerns')->cascadeOnDelete();
            $table->foreign('sender_user_id')->references('id')->on('users')->nullOnDelete();
        });
        Schema::create('concern_attachments', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('concern_id')->index();
            $table->uuid('uploaded_by_user_id')->nullable()->index();
            $table->string('storage_path');
            $table->string('original_name');
            $table->string('mime_type', 64);
            $table->unsignedBigInteger('size_bytes');
            $table->timestamps();
            $table->foreign('concern_id')->references('id')->on('concerns')->cascadeOnDelete();
            $table->foreign('uploaded_by_user_id')->references('id')->on('users')->nullOnDelete();
        });
        Schema::create('concern_histories', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('concern_id')->index();
            $table->uuid('actor_user_id')->nullable()->index();
            $table->string('action', 64);
            $table->string('from_status', 32)->nullable();
            $table->string('to_status', 32)->nullable();
            $table->text('note')->nullable();
            $table->boolean('is_public')->default(true);
            $table->timestamps();
            $table->foreign('concern_id')->references('id')->on('concerns')->cascadeOnDelete();
            $table->foreign('actor_user_id')->references('id')->on('users')->nullOnDelete();
        });

        Schema::table('announcements', function (Blueprint $table): void {
            $table->string('display_type', 32)->default('notification')->index()->after('priority');
            $table->string('cta_label', 80)->nullable()->after('display_type');
            $table->string('related_type', 64)->nullable()->after('cta_label');
            $table->uuid('related_id')->nullable()->after('related_type');
            $table->string('image_path')->nullable()->after('related_id');
        });
        Schema::create('announcement_audiences', function (Blueprint $table): void {
            $table->uuid('announcement_id');
            $table->string('role', 32)->index();
            $table->primary(['announcement_id', 'role']);
            $table->foreign('announcement_id')->references('id')->on('announcements')->cascadeOnDelete();
        });
        Schema::create('announcement_reads', function (Blueprint $table): void {
            $table->uuid('announcement_id');
            $table->uuid('user_id');
            $table->timestamp('read_at');
            $table->timestamp('dismissed_at')->nullable();
            $table->primary(['announcement_id', 'user_id']);
            $table->foreign('announcement_id')->references('id')->on('announcements')->cascadeOnDelete();
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
        });

        DB::table('concern_categories')->insert(array_map(
            fn (array $row): array => ['redirect_feature' => null, ...$row],
            [
                ['id' => 'c1000000-0000-0000-0000-000000000001', 'slug' => 'general-tourism', 'name' => 'General Tourism Concern', 'assigned_role' => 'lgu_staff', 'sort_order' => 10, 'created_at' => now(), 'updated_at' => now()],
                ['id' => 'c1000000-0000-0000-0000-000000000002', 'slug' => 'tourist-spot', 'name' => 'Tourist Spot Information', 'assigned_role' => 'lgu_staff', 'sort_order' => 20, 'created_at' => now(), 'updated_at' => now()],
                ['id' => 'c1000000-0000-0000-0000-000000000003', 'slug' => 'reservation', 'name' => 'Reservation / Booking', 'assigned_role' => 'lgu_staff', 'redirect_feature' => 'reservation_messages', 'sort_order' => 30, 'created_at' => now(), 'updated_at' => now()],
                ['id' => 'c1000000-0000-0000-0000-000000000004', 'slug' => 'ferry', 'name' => 'Ferry Schedule', 'assigned_role' => 'lgu_staff', 'sort_order' => 40, 'created_at' => now(), 'updated_at' => now()],
                ['id' => 'c1000000-0000-0000-0000-000000000005', 'slug' => 'msme', 'name' => 'MSME / Business Information', 'assigned_role' => 'lgu_staff', 'sort_order' => 50, 'created_at' => now(), 'updated_at' => now()],
                ['id' => 'c1000000-0000-0000-0000-000000000006', 'slug' => 'waste', 'name' => 'Waste / Environmental Concern', 'assigned_role' => 'lgu_staff', 'redirect_feature' => 'waste_report', 'sort_order' => 60, 'created_at' => now(), 'updated_at' => now()],
                ['id' => 'c1000000-0000-0000-0000-000000000007', 'slug' => 'emergency-correction', 'name' => 'Emergency Information Correction', 'assigned_role' => 'lgu_staff', 'redirect_feature' => 'emergency_contacts', 'sort_order' => 70, 'created_at' => now(), 'updated_at' => now()],
                ['id' => 'c1000000-0000-0000-0000-000000000008', 'slug' => 'account-login', 'name' => 'Account / Login', 'assigned_role' => 'admin', 'sort_order' => 80, 'created_at' => now(), 'updated_at' => now()],
                ['id' => 'c1000000-0000-0000-0000-000000000009', 'slug' => 'role-application', 'name' => 'Role Application', 'assigned_role' => 'admin', 'sort_order' => 90, 'created_at' => now(), 'updated_at' => now()],
                ['id' => 'c1000000-0000-0000-0000-000000000010', 'slug' => 'technical', 'name' => 'System / Technical Issue', 'assigned_role' => 'admin', 'sort_order' => 100, 'created_at' => now(), 'updated_at' => now()],
                ['id' => 'c1000000-0000-0000-0000-000000000011', 'slug' => 'feedback', 'name' => 'Suggestion / Feedback', 'assigned_role' => 'lgu_staff', 'sort_order' => 110, 'created_at' => now(), 'updated_at' => now()],
                ['id' => 'c1000000-0000-0000-0000-000000000012', 'slug' => 'other', 'name' => 'Other', 'assigned_role' => 'lgu_staff', 'sort_order' => 120, 'created_at' => now(), 'updated_at' => now()],
            ],
        ));
        DB::table('announcements')->whereNotNull('audience')->orderBy('id')->each(function ($item): void {
            DB::table('announcement_audiences')->insertOrIgnore([
                'announcement_id' => $item->id,
                'role' => $item->audience === 'everyone' ? 'public' : $item->audience,
            ]);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('announcement_reads');
        Schema::dropIfExists('announcement_audiences');
        Schema::table('announcements', fn (Blueprint $table) => $table->dropColumn(['display_type', 'cta_label', 'related_type', 'related_id', 'image_path']));
        Schema::dropIfExists('concern_histories');
        Schema::dropIfExists('concern_attachments');
        Schema::dropIfExists('concern_messages');
        Schema::dropIfExists('concerns');
        Schema::dropIfExists('concern_categories');
        Schema::dropIfExists('tourist_spot_media');
        Schema::dropIfExists('reservation_message_reads');
        Schema::dropIfExists('reservation_messages');
        Schema::dropIfExists('reservation_items');
        Schema::table('reservations', fn (Blueprint $table) => $table->dropColumn(['customer_name_snapshot', 'customer_email_snapshot', 'customer_phone_snapshot', 'tourist_spot_id', 'client_submission_id']));
        Schema::dropIfExists('booking_offering_fields');
        Schema::dropIfExists('booking_offerings');
        Schema::table('ferry_schedules', function (Blueprint $table): void {
            $table->dropForeign(['ferry_route_id']);
            $table->dropForeign(['origin_port_id']);
            $table->dropForeign(['destination_port_id']);
            $table->dropColumn(['ferry_route_id', 'origin_port_id', 'destination_port_id', 'valid_from', 'valid_until', 'fare_notes', 'is_published', 'published_at', 'archived_at']);
        });
        Schema::dropIfExists('ferry_routes');
        Schema::dropIfExists('ferry_ports');
    }
};
