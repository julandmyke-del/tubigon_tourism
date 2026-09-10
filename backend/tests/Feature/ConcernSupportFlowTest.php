<?php

namespace Tests\Feature;

use App\Models\Concern;
use App\Models\ConcernAttachment;
use App\Models\ConcernCategory;
use App\Models\ConcernMessage;
use App\Models\Notification;
use App\Models\Profile;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ConcernSupportFlowTest extends TestCase
{
    use RefreshDatabase;

    private array $roles = [];

    protected function setUp(): void
    {
        parent::setUp();

        foreach (['tourist', 'lgu_staff', 'admin'] as $name) {
            $this->roles[$name] = Role::where('name', $name)->firstOrFail();
        }
    }

    public function test_attachment_validation_private_download_and_submission_notification(): void
    {
        Storage::fake('local');
        $lgu = $this->user('attachment-lgu', 'lgu_staff');
        $tourist = $this->user('attachment-tourist', 'tourist');
        $category = ConcernCategory::where('assigned_role', 'lgu_staff')->firstOrFail();
        Sanctum::actingAs($tourist);

        $payload = [
            'category_id' => $category->id,
            'subject' => 'Incorrect public information',
            'description' => 'The published information needs an LGU review.',
        ];

        $this->post('/api/v1/concerns', [
            ...$payload,
            'attachment' => UploadedFile::fake()->create(
                'unsafe.txt',
                10,
                'text/plain',
            ),
        ], ['Accept' => 'application/json'])->assertUnprocessable();

        $response = $this->post('/api/v1/concerns', [
            ...$payload,
            'attachment' => UploadedFile::fake()->image('evidence.jpg'),
        ], ['Accept' => 'application/json'])
            ->assertCreated()
            ->assertJsonPath('data.assigned_role', 'lgu_staff');

        $concernId = $response->json('data.id');
        $reference = $response->json('data.reference_no');
        $this->assertMatchesRegularExpression(
            '/^TB-CON-\d{4}-[A-Z0-9]{8}$/',
            $reference,
        );
        $this->assertDatabaseHas('notifications', [
            'user_id' => $lgu->id,
            'type' => 'concern_assigned',
        ]);

        $attachment = ConcernAttachment::where('concern_id', $concernId)
            ->firstOrFail();
        Storage::disk('local')->assertExists($attachment->storage_path);

        $this->getJson("/api/v1/concerns/{$concernId}")
            ->assertOk()
            ->assertJsonMissing(['storage_path' => $attachment->storage_path])
            ->assertJsonPath('data.attachments.0.name', 'evidence.jpg');
        $this->get("/api/v1/concern-attachments/{$attachment->id}")
            ->assertOk()
            ->assertHeader('X-Content-Type-Options', 'nosniff');

        Sanctum::actingAs($this->user('attachment-outsider', 'tourist'));
        $this->getJson("/api/v1/concerns/{$concernId}")->assertForbidden();
        $this->get("/api/v1/concern-attachments/{$attachment->id}", [
            'Accept' => 'application/json',
        ])->assertForbidden();
    }

    public function test_replies_transitions_and_escalation_notify_the_correct_people(): void
    {
        $lgu = $this->user('workflow-lgu', 'lgu_staff');
        $admin = $this->user('workflow-admin', 'admin');
        $tourist = $this->user('workflow-tourist', 'tourist');
        $category = ConcernCategory::where('assigned_role', 'lgu_staff')->firstOrFail();

        Sanctum::actingAs($tourist);
        $response = $this->postJson('/api/v1/concerns', [
            'category_id' => $category->id,
            'subject' => 'Ferry information concern',
            'description' => 'Please confirm the published departure information.',
        ])->assertCreated();
        $concernId = $response->json('data.id');
        $reference = $response->json('data.reference_no');

        Sanctum::actingAs($lgu);
        $this->putJson("/api/v1/lgu/concerns/{$concernId}", [
            'status' => 'under_review',
            'assign_to_self' => true,
        ])->assertOk();
        $this->putJson("/api/v1/lgu/concerns/{$concernId}", [
            'status' => 'reopened',
        ])->assertUnprocessable();
        $this->assertDatabaseHas('concerns', [
            'id' => $concernId,
            'status' => 'under_review',
            'assigned_user_id' => $lgu->id,
        ]);

        $this->postJson("/api/v1/lgu/concerns/{$concernId}/messages", [
            'message' => 'Please provide the exact travel date.',
        ])->assertCreated();
        $this->assertDatabaseHas('notifications', [
            'user_id' => $tourist->id,
            'type' => 'concern_reply',
        ]);
        $touristReplyNotifications = Notification::where('user_id', $tourist->id)
            ->where('type', 'concern_reply')
            ->count();
        $this->postJson("/api/v1/lgu/concerns/{$concernId}/messages", [
            'message' => 'Internal staff-only verification note.',
            'is_internal' => true,
        ])->assertCreated();
        $this->assertSame(
            $touristReplyNotifications,
            Notification::where('user_id', $tourist->id)
                ->where('type', 'concern_reply')
                ->count(),
        );

        Sanctum::actingAs($tourist);
        $this->postJson("/api/v1/concerns/{$concernId}/messages", [
            'message' => 'My travel date is next Monday.',
            'is_internal' => true,
        ])->assertCreated();
        $this->assertDatabaseHas('concern_messages', [
            'concern_id' => $concernId,
            'sender_user_id' => $tourist->id,
            'message' => 'My travel date is next Monday.',
            'is_internal' => false,
        ]);
        $this->assertDatabaseHas('notifications', [
            'user_id' => $lgu->id,
            'type' => 'concern_reply',
        ]);
        $this->getJson("/api/v1/concerns/{$concernId}")
            ->assertOk()
            ->assertJsonMissing([
                'message' => 'Internal staff-only verification note.',
            ]);

        Sanctum::actingAs($lgu);
        $this->putJson("/api/v1/lgu/concerns/{$concernId}", [
            'escalate_to_admin' => true,
            'note' => 'Admin review is required.',
            'is_internal' => true,
        ])->assertOk();

        $concern = Concern::findOrFail($concernId);
        $this->assertSame($reference, $concern->reference_no);
        $this->assertSame('admin', $concern->assigned_role);
        $this->assertDatabaseHas('notifications', [
            'user_id' => $admin->id,
            'type' => 'concern_escalated',
        ]);
        $this->getJson("/api/v1/lgu/concerns/{$concernId}")
            ->assertForbidden();

        Sanctum::actingAs($admin);
        $this->getJson("/api/v1/admin/concerns/{$concernId}")
            ->assertOk()
            ->assertJsonFragment(['message' => 'Admin review is required.']);
        $this->putJson("/api/v1/admin/concerns/{$concernId}", [
            'status' => 'resolved',
            'note' => 'The information was corrected.',
        ])->assertOk();
        $this->assertDatabaseHas('notifications', [
            'user_id' => $tourist->id,
            'type' => 'concern_update',
        ]);
        $this->assertTrue(
            ConcernMessage::where('concern_id', $concernId)
                ->where('is_internal', true)
                ->exists(),
        );
    }

    private function user(string $key, string $role): User
    {
        $user = User::create([
            'name' => str($key)->title(),
            'email' => "{$key}@example.test",
            'phone' => '09170000000',
            'password' => Hash::make('password'),
            'role_id' => $this->roles[$role]->id,
            'is_verified' => true,
            'email_verified_at' => now(),
        ]);
        Profile::create([
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'phone' => $user->phone,
            'role_id' => $user->role_id,
            'is_verified' => true,
        ]);

        return $user;
    }
}
