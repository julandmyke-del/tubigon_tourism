<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('map_location_categories')) {
            Schema::create('map_location_categories', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->uuid('parent_id')->nullable()->index();
                $table->string('name')->unique();
                $table->string('slug')->unique();
                $table->string('icon', 64)->default('place');
                $table->string('marker_color', 7)->default('#F59E0B');
                $table->boolean('active')->default(true)->index();
                $table->unsignedInteger('sort_order')->default(0)->index();
                $table->timestamps();
                $table->softDeletes();
            });
        }

        if (! Schema::hasTable('map_locations')) {
            Schema::create('map_locations', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->string('name');
                $table->string('slug')->unique();
                $table->text('description')->nullable();
                $table->uuid('category_id')->index();
                $table->uuid('subcategory_id')->nullable()->index();
                $table->string('entity_type', 32)->nullable()->index();
                $table->uuid('entity_id')->nullable()->index();
                $table->text('address')->nullable();
                $table->decimal('latitude', 10, 7)->nullable();
                $table->decimal('longitude', 10, 7)->nullable();
                $table->string('marker_icon', 64)->nullable();
                $table->text('image_url')->nullable();
                $table->boolean('is_featured')->default(false)->index();
                $table->unsignedBigInteger('view_count')->default(0);
                $table->boolean('verified')->default(false)->index();
                $table->boolean('published')->default(false)->index();
                $table->boolean('active')->default(true)->index();
                $table->uuid('created_by')->nullable()->index();
                $table->uuid('updated_by')->nullable()->index();
                $table->uuid('verified_by')->nullable()->index();
                $table->timestamp('verified_at')->nullable();
                $table->timestamps();
                $table->softDeletes();

                $table->unique(['entity_type', 'entity_id'], 'map_locations_entity_unique');
                $table->index(['published', 'active', 'category_id'], 'map_locations_public_feed');
                $table->index(['latitude', 'longitude'], 'map_locations_coordinates');
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('map_locations');
        Schema::dropIfExists('map_location_categories');
    }
};
