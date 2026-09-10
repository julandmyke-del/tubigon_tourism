<?php

namespace Tests\Feature;

use App\Models\Profile;
use App\Models\Role;
use App\Models\User;
use App\Models\WasteCategory;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class WasteReportFlowTest extends TestCase
{
    private Role $touristRole;
    private Role $lguRole;

    protected function setUp(): void
    {
        parent::setUp();
        $this->createSchema();
        $this->touristRole = Role::create(['name' => 'tourist']);
        $this->lguRole = Role::create(['name' => 'lgu_staff']);
        Role::create(['name' => 'admin']);
    }

    public function test_report_is_backend_persisted_for_authenticated_tourist_and_visible_to_lgu(): void
    {
        $owner = $this->user('owner', $this->touristRole);
        $other = $this->user('other', $this->touristRole);
        $lgu = $this->user('lgu', $this->lguRole);

        Sanctum::actingAs($owner);
        $response = $this->postJson('/api/v1/waste-reports', [
            'user_id' => $other->id,
            'category' => 'garbage',
            'description' => 'Plastic waste has accumulated beside the public walkway.',
            'location_description' => 'Near Tubigon port',
            'latitude' => 9.9515,
            'longitude' => 123.9618,
            'status' => 'resolved',
            'priority' => 'urgent',
        ])->assertCreated()
            ->assertJsonPath('data.user_id', $owner->id)
            ->assertJsonPath('data.status', 'submitted')
            ->assertJsonPath('data.priority', 'normal');
        $reportId = $response->json('data.id');

        $this->assertDatabaseHas('waste_reports', [
            'id' => $reportId,
            'user_id' => $owner->id,
            'category' => 'garbage',
            'status' => 'submitted',
        ]);
        $this->assertDatabaseHas('waste_report_history', [
            'waste_report_id' => $reportId,
            'changed_by' => $owner->id,
            'to_status' => 'submitted',
        ]);
        $this->assertDatabaseHas('notifications', [
            'user_id' => $lgu->id,
            'type' => 'waste_report_submitted',
        ]);

        Sanctum::actingAs($other);
        $this->getJson('/api/v1/waste-reports')->assertOk()->assertJsonCount(0, 'data');
        $this->getJson("/api/v1/waste-reports/{$reportId}")->assertNotFound();

        Sanctum::actingAs($lgu);
        $this->getJson('/api/v1/waste-reports')
            ->assertOk()->assertJsonFragment(['id' => $reportId]);
        $this->putJson("/api/v1/lgu/waste-reports/{$reportId}/status", [
            'status' => 'under_review',
            'notes' => 'Inspection assigned.',
        ])->assertOk();
        $this->assertDatabaseHas('waste_reports', [
            'id' => $reportId,
            'status' => 'under_review',
        ]);
        $this->assertDatabaseHas('waste_report_history', [
            'waste_report_id' => $reportId,
            'changed_by' => $lgu->id,
            'from_status' => 'submitted',
            'to_status' => 'under_review',
            'notes' => 'Inspection assigned.',
        ]);
    }

    public function test_owner_can_attach_real_image_evidence_but_other_tourist_cannot(): void
    {
        Storage::fake('public');
        $owner = $this->user('photo-owner', $this->touristRole);
        $other = $this->user('photo-other', $this->touristRole);

        Sanctum::actingAs($owner);
        $reportId = $this->postJson('/api/v1/waste-reports', [
            'category' => 'Plastic Waste',
            'description' => 'Discarded plastic containers are blocking the drainage channel.',
            'barangay' => 'Centro',
            'latitude' => 9.9515,
            'longitude' => 123.9618,
        ])->assertCreated()->json('data.id');

        $upload = fn () => UploadedFile::fake()->create('evidence.jpg', 128, 'image/jpeg');
        $this->post("/api/v1/waste-reports/{$reportId}/images", [
            'images' => [$upload()],
        ])->assertOk()->assertJsonCount(1, 'data.images');

        $imageUrl = $this->getJson("/api/v1/waste-reports/{$reportId}")
            ->assertOk()->json('data.images.0');
        $storedPath = preg_replace('#^/storage/#', '', (string) parse_url($imageUrl, PHP_URL_PATH));
        Storage::disk('public')->assertExists($storedPath);

        Sanctum::actingAs($other);
        $this->post("/api/v1/waste-reports/{$reportId}/images", [
            'images' => [$upload()],
        ])->assertForbidden();
    }

    public function test_waste_report_writes_require_auth_tourist_role_and_tubigon_coordinates(): void
    {
        $payload = [
            'category' => 'garbage',
            'description' => 'A sufficiently detailed waste report description.',
            'latitude' => 9.9515,
            'longitude' => 123.9618,
        ];
        $this->postJson('/api/v1/waste-reports', $payload)->assertUnauthorized();

        Sanctum::actingAs($this->user('lgu-writer', $this->lguRole));
        $this->postJson('/api/v1/waste-reports', $payload)->assertForbidden();

        Sanctum::actingAs($this->user('tourist-writer', $this->touristRole));
        $this->postJson('/api/v1/waste-reports', [
            ...$payload,
            'latitude' => 10.3157,
            'longitude' => 123.8854,
        ])->assertUnprocessable();
        $this->assertDatabaseCount('waste_reports', 0);
    }

    public function test_connected_report_supports_authoritative_metadata_private_media_idempotency_and_public_history(): void
    {
        Storage::fake('local');
        Schema::create('waste_categories', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->string('slug')->unique(); $table->string('name'); $table->text('helper_text')->nullable(); $table->boolean('is_active')->default(true); $table->unsignedInteger('sort_order')->default(0); $table->timestamps();
        });
        Schema::table('waste_reports', function (Blueprint $table): void {
            $table->uuid('category_id')->nullable(); $table->string('severity')->default('moderate'); $table->text('resolved_address')->nullable(); $table->string('geocoding_source')->nullable(); $table->uuid('client_submission_id')->nullable()->unique(); $table->timestamp('submitted_at')->nullable(); $table->uuid('resolved_by')->nullable(); $table->text('resolution_summary')->nullable(); $table->timestamp('reopened_at')->nullable();
        });
        Schema::table('waste_report_history', fn (Blueprint $table) => $table->boolean('is_public')->default(false));
        Schema::create('waste_report_media', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->uuid('waste_report_id'); $table->uuid('uploaded_by'); $table->string('media_type'); $table->string('disk'); $table->text('storage_path'); $table->string('mime_type'); $table->unsignedBigInteger('size_bytes'); $table->string('original_name'); $table->string('visibility')->default('participants'); $table->timestamps();
        });
        $category = WasteCategory::create(['slug' => 'illegal-dumping', 'name' => 'Illegal Dumping', 'helper_text' => 'Dumped waste', 'sort_order' => 1]);
        $owner = $this->user('connected-owner', $this->touristRole);
        $other = $this->user('connected-other', $this->touristRole);
        $lgu = $this->user('connected-lgu', $this->lguRole);
        $clientId = (string) \Illuminate\Support\Str::uuid();

        Sanctum::actingAs($owner);
        $response = $this->post('/api/v1/waste-reports', [
            'category_id' => $category->id,
            'severity' => 'urgent',
            'description' => 'Several sacks were dumped beside the drainage channel.',
            'resolved_address' => 'Centro, Tubigon, Bohol',
            'geocoding_source' => 'device_reverse_geocoder',
            'latitude' => 9.9515,
            'longitude' => 123.9618,
            'client_submission_id' => $clientId,
            'photos' => [UploadedFile::fake()->create('one.jpg', 120, 'image/jpeg')],
            'video' => UploadedFile::fake()->create('short.mp4', 500, 'video/mp4'),
        ], ['Accept' => 'application/json'])->assertCreated()
            ->assertJsonPath('data.category_definition.slug', 'illegal-dumping')
            ->assertJsonPath('data.severity', 'urgent')
            ->assertJsonCount(2, 'data.media');
        $reportId = $response->json('data.id');
        $mediaId = $response->json('data.media.0.id');

        $this->postJson('/api/v1/waste-reports', [
            'category_id' => $category->id,
            'description' => 'Several sacks were dumped beside the drainage channel.',
            'latitude' => 9.9515,
            'longitude' => 123.9618,
            'client_submission_id' => $clientId,
        ])->assertOk()->assertJsonPath('meta.idempotent_replay', true);
        $this->assertDatabaseCount('waste_reports', 1);

        $offlineId = (string) \Illuminate\Support\Str::uuid();
        $offlineRecord = [
            'id' => $offlineId,
            'category' => 'illegal-dumping',
            'severity' => 'high',
            'description' => 'Offline report with authoritative category resolution.',
            'resolved_address' => 'Centro, Tubigon, Bohol',
            'geocoding_source' => 'device_geocoding',
            'latitude' => 9.9515,
            'longitude' => 123.9618,
            'images' => [],
        ];
        $this->postJson('/api/v1/sync/push', [
            'table' => 'waste_reports', 'records' => [$offlineRecord],
        ])->assertOk()->assertJsonPath('data.synced_count', 1);
        $this->postJson('/api/v1/sync/push', [
            'table' => 'waste_reports', 'records' => [$offlineRecord],
        ])->assertOk()->assertJsonPath('data.synced_count', 0);
        $this->assertDatabaseHas('waste_reports', [
            'id' => $offlineId,
            'category' => 'illegal-dumping',
            'category_id' => $category->id,
            'client_submission_id' => $offlineId,
        ]);
        $this->assertDatabaseCount('waste_reports', 2);

        Sanctum::actingAs($other);
        $this->get("/api/v1/waste-report-media/$mediaId")->assertForbidden();

        Sanctum::actingAs($lgu);
        $this->putJson("/api/v1/lgu/waste-reports/$reportId/status", [
            'status' => 'under_review', 'public_note' => 'LGU review started.',
            'internal_note' => 'PRIVATE-OPERATIONS-NOTE',
        ])->assertOk();
        $this->putJson("/api/v1/lgu/waste-reports/$reportId/status", [
            'status' => 'in_progress', 'public_note' => 'Cleanup team dispatched.',
            'internal_note' => 'PRIVATE-OPERATIONS-NOTE',
        ])->assertOk();
        $this->putJson("/api/v1/lgu/waste-reports/$reportId/status", [
            'status' => 'resolved', 'resolution_summary' => 'Waste removed and area inspected.',
            'internal_note' => 'PRIVATE-OPERATIONS-NOTE',
        ])->assertOk();

        Sanctum::actingAs($owner);
        $this->getJson("/api/v1/waste-reports/$reportId")
            ->assertOk()
            ->assertJsonPath('data.resolution_summary', 'Waste removed and area inspected.')
            ->assertJsonMissing(['internal_note' => 'PRIVATE-OPERATIONS-NOTE'])
            ->assertJsonMissing(['lgu_notes' => 'PRIVATE-OPERATIONS-NOTE']);
    }

    private function user(string $key, Role $role): User
    {
        $user = User::create([
            'name' => ucfirst($key),
            'email' => "{$key}@example.test",
            'password' => Hash::make('safe-password'),
            'role_id' => $role->id,
            'is_verified' => true,
        ]);
        Profile::create([
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'role_id' => $role->id,
            'is_verified' => true,
        ]);
        return $user;
    }

    private function createSchema(): void
    {
        foreach (['personal_access_tokens', 'activity_logs', 'notifications', 'waste_report_history', 'waste_reports', 'profiles', 'users', 'roles'] as $table) {
            Schema::dropIfExists($table);
        }
        Schema::create('roles', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->string('name')->unique(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('users', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->string('name'); $table->string('email')->unique(); $table->string('password'); $table->uuid('role_id'); $table->boolean('is_verified')->default(false); $table->rememberToken(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('profiles', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->string('name'); $table->string('email'); $table->uuid('role_id'); $table->boolean('is_verified')->default(false); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('waste_reports', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->uuid('user_id'); $table->string('category'); $table->text('description'); $table->text('location_description')->nullable(); $table->string('barangay')->nullable(); $table->decimal('latitude', 10, 7); $table->decimal('longitude', 10, 7); $table->json('images')->nullable(); $table->string('status')->default('submitted'); $table->string('priority')->default('normal'); $table->uuid('assigned_to')->nullable(); $table->string('assigned_personnel')->nullable(); $table->timestamp('assigned_at')->nullable(); $table->text('lgu_notes')->nullable(); $table->json('resolution_evidence')->nullable(); $table->timestamp('reviewed_at')->nullable(); $table->timestamp('resolved_at')->nullable(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('waste_report_history', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->uuid('waste_report_id'); $table->uuid('changed_by')->nullable(); $table->string('from_status')->nullable(); $table->string('to_status'); $table->text('notes')->nullable(); $table->json('metadata')->nullable(); $table->timestamps();
        });
        Schema::create('notifications', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->uuid('user_id'); $table->string('type'); $table->string('title'); $table->text('body'); $table->json('data')->nullable(); $table->boolean('is_read')->default(false); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('activity_logs', function (Blueprint $table): void {
            $table->uuid('id')->primary(); $table->uuid('user_id')->nullable(); $table->string('action'); $table->text('details')->nullable(); $table->timestamps(); $table->softDeletes();
        });
        Schema::create('personal_access_tokens', function (Blueprint $table): void {
            $table->id(); $table->string('tokenable_type'); $table->uuid('tokenable_id'); $table->string('name'); $table->string('token', 64)->unique(); $table->text('abilities')->nullable(); $table->timestamp('last_used_at')->nullable(); $table->timestamp('expires_at')->nullable(); $table->timestamps();
        });
    }
}
