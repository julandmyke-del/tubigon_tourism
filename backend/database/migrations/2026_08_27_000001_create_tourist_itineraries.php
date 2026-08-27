<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('itineraries')) {
            Schema::create('itineraries', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->uuid('user_id')->index();
                $table->string('name');
                $table->text('description')->nullable();
                $table->date('start_date');
                $table->date('end_date');
                $table->unsignedSmallInteger('travelers')->nullable();
                $table->string('status', 24)->default('draft')->index();
                $table->string('start_location_type', 32)->default('first_stop');
                $table->string('start_location_name')->nullable();
                $table->uuid('start_location_id')->nullable();
                $table->decimal('start_latitude', 10, 7)->nullable();
                $table->decimal('start_longitude', 10, 7)->nullable();
                $table->timestamps();
                $table->softDeletes();

                $table->index(['user_id', 'start_date', 'end_date'], 'itineraries_owner_dates');
            });
        }

        if (! Schema::hasTable('itinerary_items')) {
            Schema::create('itinerary_items', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->uuid('itinerary_id')->index();
                $table->string('entity_type', 32)->index();
                $table->uuid('entity_id')->index();
                $table->unsignedSmallInteger('day_number')->default(1)->index();
                $table->unsignedSmallInteger('sort_order')->default(0);
                $table->time('planned_start_time')->nullable();
                $table->time('planned_end_time')->nullable();
                $table->text('notes')->nullable();
                $table->uuid('reservation_id')->nullable()->index();
                $table->string('visit_status', 16)->default('planned')->index();
                $table->timestamps();
                $table->softDeletes();

                $table->index(['itinerary_id', 'day_number', 'sort_order'], 'itinerary_items_day_order');
                $table->foreign('itinerary_id')->references('id')->on('itineraries')->cascadeOnDelete();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('itinerary_items');
        Schema::dropIfExists('itineraries');
    }
};
