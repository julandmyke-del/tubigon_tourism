<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    private const MSME_CATEGORIES = [
        'Food & Dining', 'Accommodation', 'Tour Services', 'Handicrafts',
        'Agriculture', 'Retail', 'Transport', 'Other',
    ];

    public function up(): void
    {
        if (! Schema::hasTable('msme_categories')) {
            Schema::create('msme_categories', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->string('name')->unique();
                $table->string('slug')->unique();
                $table->text('description')->nullable();
                $table->boolean('is_active')->default(true)->index();
                $table->unsignedInteger('display_order')->default(0);
                $table->timestamps();
                $table->softDeletes();
            });
        }

        $names = collect(self::MSME_CATEGORIES);
        if (Schema::hasTable('msmes') && Schema::hasColumn('msmes', 'category')) {
            $names = $names->merge(DB::table('msmes')->whereNotNull('category')->pluck('category'));
        }
        $names->map(fn ($name) => trim((string) $name))->filter()->unique(fn ($name) => Str::lower($name))
            ->values()->each(function (string $name, int $index): void {
                $slug = Str::slug($name);
                $existing = DB::table('msme_categories')->where('slug', $slug)->first();
                if ($existing) {
                    DB::table('msme_categories')->where('id', $existing->id)->update([
                        'name' => $name, 'display_order' => $index + 1, 'updated_at' => now(),
                    ]);

                    return;
                }
                DB::table('msme_categories')->insert([
                    'id' => (string) Str::uuid(), 'slug' => $slug, 'name' => $name,
                    'is_active' => true, 'display_order' => $index + 1,
                    'updated_at' => now(), 'created_at' => now(),
                ]);
            });

        if (Schema::hasTable('msmes') && ! Schema::hasColumn('msmes', 'category_id')) {
            Schema::table('msmes', function (Blueprint $table): void {
                $table->uuid('category_id')->nullable()->after('category')->index();
                $table->foreign('category_id')->references('id')->on('msme_categories')->nullOnDelete();
            });
        }
        if (Schema::hasTable('msmes') && Schema::hasColumn('msmes', 'category_id')) {
            DB::table('msmes')->whereNull('category_id')->orderBy('id')->eachById(function ($msme): void {
                $categoryId = DB::table('msme_categories')
                    ->whereRaw('LOWER(name) = ?', [Str::lower(trim((string) $msme->category))])->value('id');
                if ($categoryId) {
                    DB::table('msmes')->where('id', $msme->id)->update(['category_id' => $categoryId]);
                }
            }, 100, 'id');
        }

        if (Schema::hasTable('role_applications')) {
            Schema::table('role_applications', function (Blueprint $table): void {
                if (! Schema::hasColumn('role_applications', 'requested_msme_category_id')) {
                    $table->uuid('requested_msme_category_id')->nullable()->after('requested_tourist_spot_id')->index();
                }
                if (! Schema::hasColumn('role_applications', 'recommended_msme_category_id')) {
                    $table->uuid('recommended_msme_category_id')->nullable()->after('requested_msme_category_id')->index();
                }
                if (! Schema::hasColumn('role_applications', 'final_msme_category_id')) {
                    $table->uuid('final_msme_category_id')->nullable()->after('recommended_msme_category_id')->index();
                }
            });
            foreach (['requested_msme_category_id', 'recommended_msme_category_id', 'final_msme_category_id'] as $column) {
                if (Schema::hasColumn('role_applications', $column)) {
                    try {
                        Schema::table('role_applications', fn (Blueprint $table) => $table->foreign($column)->references('id')->on('msme_categories')->nullOnDelete());
                    } catch (Throwable) {
                        // Imported databases may already contain an equivalent constraint.
                    }
                }
            }
            DB::table('role_applications')->where('application_type', 'msme_owner')
                ->whereNull('requested_msme_category_id')->orderBy('id')->eachById(function ($application): void {
                    $payload = json_decode((string) $application->payload, true);
                    $name = is_array($payload) ? ($payload['business_category'] ?? null) : null;
                    if (! is_string($name) || trim($name) === '') {
                        return;
                    }
                    $categoryId = DB::table('msme_categories')->whereRaw('LOWER(name) = ?', [Str::lower(trim($name))])->value('id');
                    if ($categoryId) {
                        DB::table('role_applications')->where('id', $application->id)
                            ->update(['requested_msme_category_id' => $categoryId]);
                    }
                }, 100, 'id');
        }

        if (Schema::hasTable('activity_logs')) {
            Schema::table('activity_logs', function (Blueprint $table): void {
                if (! Schema::hasColumn('activity_logs', 'actor_role')) {
                    $table->string('actor_role', 50)->nullable()->index();
                }
                if (! Schema::hasColumn('activity_logs', 'action_type')) {
                    $table->string('action_type', 100)->nullable()->index();
                }
                if (! Schema::hasColumn('activity_logs', 'target_type')) {
                    $table->string('target_type', 100)->nullable()->index();
                }
                if (! Schema::hasColumn('activity_logs', 'target_id')) {
                    $table->string('target_id')->nullable()->index();
                }
                if (! Schema::hasColumn('activity_logs', 'metadata')) {
                    $table->json('metadata')->nullable();
                }
            });
        }

        if (Schema::hasTable('profiles')) {
            Schema::table('profiles', function (Blueprint $table): void {
                if (! Schema::hasColumn('profiles', 'address')) {
                    $table->text('address')->nullable()->after('phone');
                }
                if (! Schema::hasColumn('profiles', 'barangay')) {
                    $table->string('barangay', 120)->nullable()->after('address');
                }
            });
        }

        if (! Schema::hasTable('user_preferences')) {
            Schema::create('user_preferences', function (Blueprint $table): void {
                $table->uuid('user_id')->primary();
                $table->boolean('personalization_enabled')->default(false);
                $table->json('preferred_destination_category_ids')->nullable();
                $table->json('travel_interests')->nullable();
                $table->string('travel_pace', 30)->nullable();
                $table->string('group_type', 30)->nullable();
                $table->string('preferred_transport_mode', 30)->nullable();
                $table->boolean('eco_tourism_interest')->default(false);
                $table->boolean('nearby_suggestions')->default(false);
                $table->boolean('wheelchair_friendly')->default(false);
                $table->boolean('limited_walking')->default(false);
                $table->boolean('senior_friendly')->default(false);
                $table->boolean('child_friendly')->default(false);
                $table->string('accessibility_notes', 500)->nullable();
                $table->boolean('reservation_updates')->default(true);
                $table->boolean('tourism_announcements')->default(true);
                $table->boolean('eco_tips')->default(true);
                $table->boolean('ferry_alerts')->default(true);
                $table->boolean('waste_report_updates')->default(true);
                $table->boolean('application_updates')->default(true);
                $table->boolean('location_recommendations')->default(false);
                $table->boolean('remember_last_map_location')->default(false);
                $table->timestamps();
                $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            });
        }

        if (Schema::hasTable('system_settings') && Schema::hasColumn('system_settings', 'app_name')) {
            DB::table('system_settings')->whereIn('app_name', ['Tubigon Smart Tourism', 'Tubigon Tourism'])
                ->update(['app_name' => 'Tour Tubigon']);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('user_preferences');
        // The remaining changes are deliberately retained because dropping them
        // can discard production taxonomy, audit, and profile data.
    }
};
