<?php

namespace Tests\Feature;

use App\Models\Announcement;
use App\Models\BookingOffering;
use App\Models\Profile;
use App\Models\Reservation;
use App\Models\ReservationStatus;
use App\Models\Role;
use App\Models\TouristSpot;
use App\Models\TouristSpotPartnerAssignment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SixIssueConnectedFlowTest extends TestCase
{
    use RefreshDatabase;

    private array $roles = [];

    protected function setUp(): void
    {
        parent::setUp();
        foreach (['tourist', 'tourism_partner', 'lgu_staff', 'admin', 'msme_owner'] as $name) {
            $this->roles[$name] = Role::where('name', $name)->firstOrFail();
        }
    }

    public function test_structured_ferry_publication_and_roles_are_authoritative(): void
    {
        $lgu = $this->user('ferry-lgu', 'lgu_staff');
        Sanctum::actingAs($lgu);
        $origin = $this->postJson('/api/v1/lgu/ferry-ports', ['name' => 'Tubigon Port', 'code' => 'TUB'])->assertCreated()->json('data.id');
        $destination = $this->postJson('/api/v1/lgu/ferry-ports', ['name' => 'Cebu Pier 1', 'code' => 'CEB1'])->assertCreated()->json('data.id');
        $route = $this->postJson('/api/v1/lgu/ferry-routes', ['name' => 'Tubigon - Cebu', 'origin_port_id' => $origin, 'destination_port_id' => $destination])->assertCreated()->json('data.id');
        $this->putJson("/api/v1/lgu/ferry-ports/{$origin}", ['name' => 'Tubigon Municipal Port', 'code' => 'TUB', 'is_active' => true])->assertOk();
        $this->putJson("/api/v1/lgu/ferry-routes/{$route}", ['name' => 'Tubigon Municipal Port - Cebu', 'origin_port_id' => $origin, 'destination_port_id' => $destination, 'is_active' => true])->assertOk();
        $id = $this->postJson('/api/v1/lgu/ferry-schedules', ['operator' => 'Verified Operator', 'ferry_route_id' => $route, 'departure_time' => '08:00', 'status' => 'scheduled', 'is_active' => true, 'is_published' => false])->assertCreated()->json('data.id');
        $this->getJson('/api/v1/ferry-schedules')->assertOk()->assertJsonCount(0, 'data');
        $this->putJson("/api/v1/lgu/ferry-schedules/{$id}", ['is_published' => true])->assertOk();
        $this->getJson('/api/v1/ferry-schedules')->assertJsonPath('data.0.origin', 'Tubigon Municipal Port')->assertJsonPath('data.0.destination', 'Cebu Pier 1');
        $this->putJson("/api/v1/lgu/ferry-schedules/{$id}", ['status' => 'not-a-status'])->assertUnprocessable();
        $this->assertDatabaseHas('activity_logs', ['user_id' => $lgu->id, 'action' => 'Ferry schedule published']);
        Sanctum::actingAs($this->user('no-ferry', 'tourism_partner'));
        $this->postJson('/api/v1/lgu/ferry-schedules', ['operator' => 'No', 'route' => 'No', 'departure_time' => '08:00'])->assertForbidden();
        Sanctum::actingAs($this->user('tourist-no-ferry', 'tourist'));
        $this->postJson('/api/v1/lgu/ferry-schedules', ['operator' => 'No', 'route' => 'No', 'departure_time' => '08:00'])->assertForbidden();
    }

    public function test_partner_offerings_create_server_priced_snapshots_and_prevent_last_unit_overbooking(): void
    {
        [$spot, $partner] = $this->assignedSpot();
        Sanctum::actingAs($partner);
        $this->postJson("/api/v1/partner/tourist-spots/{$spot->id}/offerings", ['type' => 'room', 'display_name' => 'Invalid pricing', 'price' => 10, 'pricing_mode' => 'invented'])->assertUnprocessable();
        $offeringId = $this->postJson("/api/v1/partner/tourist-spots/{$spot->id}/offerings", [
            'type' => 'cottage', 'display_name' => 'Family Cottage', 'price' => 500, 'pricing_mode' => 'per_cottage', 'quantity_available' => 1, 'min_quantity' => 1, 'max_quantity' => 1,
            'fields' => [['field_key' => 'guest_count', 'label' => 'Guests', 'field_type' => 'guest_count', 'is_required' => true]],
        ])->assertCreated()->json('data.id');
        $other = $this->spot('Other');
        $this->postJson("/api/v1/partner/tourist-spots/{$other->id}/offerings", ['type' => 'room', 'display_name' => 'No', 'price' => 1, 'pricing_mode' => 'per_day'])->assertForbidden();
        $tourist = $this->user('booking-tourist', 'tourist');
        Sanctum::actingAs($tourist);
        $payload = ['tourist_spot_id' => $spot->id, 'reservation_date' => now()->addDays(3)->toDateString(), 'items' => [['offering_id' => $offeringId, 'quantity' => 1, 'booking_details' => ['guest_count' => 4]]]];
        $missingField = $payload;
        $missingField['items'][0]['booking_details'] = [];
        $this->postJson('/api/v1/offering-reservations', $missingField)->assertUnprocessable();
        $id = $this->postJson('/api/v1/offering-reservations', $payload + ['total_amount' => 1])->assertCreated()->assertJsonPath('data.total_amount', 500)->json('data.id');
        $this->assertDatabaseHas('reservation_items', ['reservation_id' => $id, 'unit_price_snapshot' => 500, 'subtotal' => 500]);
        $this->assertDatabaseHas('reservations', ['id' => $id, 'customer_email_snapshot' => $tourist->email]);
        BookingOffering::whereKey($offeringId)->update(['price' => 999]);
        $this->assertDatabaseHas('reservation_items', ['reservation_id' => $id, 'unit_price_snapshot' => 500]);
        Sanctum::actingAs($this->user('second-tourist', 'tourist'));
        $this->postJson('/api/v1/offering-reservations', $payload)->assertUnprocessable();
    }

    public function test_reservation_messages_are_participant_only_and_internal_notes_remain_private(): void
    {
        [$spot, $partner] = $this->assignedSpot();
        $tourist = $this->user('message-tourist', 'tourist');
        $reservation = $this->reservation($tourist, $partner, $spot);
        Sanctum::actingAs($tourist);
        $this->postJson("/api/v1/reservations/{$reservation->id}/messages", ['message' => 'Is the cottage ready?'])->assertCreated();
        $this->postJson("/api/v1/reservations/{$reservation->id}/messages", ['message' => 'Hidden', 'is_internal' => true])->assertForbidden();
        Sanctum::actingAs($partner);
        $this->postJson("/api/v1/reservations/{$reservation->id}/messages", ['message' => 'Bring the access list.', 'is_internal' => true])->assertCreated();
        Sanctum::actingAs($tourist);
        $this->getJson("/api/v1/reservations/{$reservation->id}/messages")->assertOk()->assertJsonMissing(['message' => 'Bring the access list.']);
        $this->assertDatabaseHas('reservation_message_reads', ['user_id' => $tourist->id]);
        Sanctum::actingAs($partner);
        $this->putJson("/api/v1/partner/reservations/{$reservation->id}/status", ['status_name' => 'approved'])->assertOk();
        $this->assertDatabaseHas('reservation_messages', ['reservation_id' => $reservation->id, 'message_type' => 'system_update', 'message' => 'Reservation Approved']);
        Sanctum::actingAs($this->user('outsider', 'tourist'));
        $this->getJson("/api/v1/reservations/{$reservation->id}/messages")->assertForbidden();
    }

    public function test_partner_gallery_enforces_assignment_cover_and_public_active_media(): void
    {
        Storage::fake('public');
        [$spot, $partner] = $this->assignedSpot();
        Sanctum::actingAs($partner);
        $a = $this->post("/api/v1/partner/tourist-spots/{$spot->id}/gallery", ['image' => UploadedFile::fake()->image('a.jpg', 800, 600), 'caption' => 'Sea view', 'is_cover' => true], ['Accept' => 'application/json'])->assertCreated()->json('data.id');
        $b = $this->post("/api/v1/partner/tourist-spots/{$spot->id}/gallery", ['image' => UploadedFile::fake()->image('b.png', 800, 600), 'caption' => 'Cottage', 'is_cover' => true], ['Accept' => 'application/json'])->assertCreated()->json('data.id');
        $this->assertDatabaseHas('tourist_spot_media', ['id' => $a, 'is_cover' => false]);
        $this->assertDatabaseHas('tourist_spot_media', ['id' => $b, 'is_cover' => true]);
        $this->getJson("/api/v1/tourist-spots/{$spot->id}/gallery")->assertOk()->assertJsonCount(2, 'data');
        $this->putJson("/api/v1/partner/tourist-spots/{$spot->id}/gallery/{$a}", ['is_active' => false])->assertOk();
        $this->getJson("/api/v1/tourist-spots/{$spot->id}/gallery")->assertOk()->assertJsonCount(1, 'data');
        $this->post("/api/v1/partner/tourist-spots/{$spot->id}/gallery", ['image' => UploadedFile::fake()->create('unsafe.txt', 10, 'text/plain')], ['Accept' => 'application/json'])->assertUnprocessable();
        $other = $this->spot('Gallery Other');
        $this->post("/api/v1/partner/tourist-spots/{$other->id}/gallery", ['image' => UploadedFile::fake()->image('x.jpg')], ['Accept' => 'application/json'])->assertForbidden();
        Sanctum::actingAs($this->user('gallery-lgu', 'lgu_staff'));
        $this->putJson("/api/v1/lgu/tourist-spots/{$spot->id}/gallery/{$b}", ['moderation_note' => 'Verified destination image'])->assertOk();
        $this->assertDatabaseHas('tourist_spot_media', ['id' => $b, 'moderation_note' => 'Verified destination image']);
    }

    public function test_concerns_route_to_staff_and_hide_internal_notes(): void
    {
        $tourist = $this->user('concern-tourist', 'tourist');
        Sanctum::actingAs($tourist);
        $category = $this->getJson('/api/v1/concern-categories')->assertOk()->json('data.3.id');
        $this->postJson('/api/v1/concerns', ['category_id' => $category, 'subject' => 'Invalid ferry link', 'description' => 'This related ferry record is not accessible.', 'related_type' => 'ferry_schedule', 'related_id' => '00000000-0000-0000-0000-000000000000'])->assertUnprocessable();
        $id = $this->postJson('/api/v1/concerns', ['category_id' => $category, 'subject' => 'Ferry schedule correction', 'description' => 'The published departure needs confirmation.', 'priority' => 'normal'])->assertCreated()->assertJsonPath('data.assigned_role', 'lgu_staff')->json('data.id');
        $lgu = $this->user('concern-lgu', 'lgu_staff');
        Sanctum::actingAs($lgu);
        $this->putJson("/api/v1/lgu/concerns/{$id}", ['status' => 'under_review', 'note' => 'Private verification detail', 'is_internal' => true])->assertOk();
        $this->putJson("/api/v1/lgu/concerns/{$id}", ['escalate_to_admin' => true, 'note' => 'Needs central review', 'is_internal' => true])->assertOk();
        $this->assertDatabaseHas('concerns', ['id' => $id, 'assigned_role' => 'admin']);
        Sanctum::actingAs($this->user('concern-admin', 'admin'));
        $this->putJson("/api/v1/admin/concerns/{$id}", ['status' => 'resolved', 'note' => 'Schedule verified.', 'is_internal' => false])->assertOk();
        Sanctum::actingAs($tourist);
        $this->getJson("/api/v1/concerns/{$id}")->assertOk()->assertJsonMissing(['message' => 'Private verification detail'])->assertJsonFragment(['message' => 'Schedule verified.']);
        Sanctum::actingAs($this->user('other-concern', 'tourist'));
        $this->getJson("/api/v1/concerns/{$id}")->assertForbidden();
    }

    public function test_multi_audience_announcements_are_server_filtered_for_guest_and_roles(): void
    {
        $admin = $this->user('announcement-admin', 'admin');
        Sanctum::actingAs($admin);
        $id = $this->postJson('/api/v1/admin/announcements', ['title' => 'Ferry advisory', 'body' => 'Check the linked schedule before travel.', 'type' => 'advisory', 'audiences' => ['public', 'tourist'], 'priority' => 'important', 'display_type' => 'banner', 'status' => 'published'])->assertCreated()->assertJsonPath('data.audiences.0', 'public')->json('data.id');
        auth()->forgetGuards();
        $this->getJson('/api/v1/announcements/public')->assertOk()->assertJsonPath('data.0.id', $id);
        Sanctum::actingAs($this->user('announcement-partner', 'tourism_partner'));
        $this->getJson('/api/v1/announcements')->assertOk()->assertJsonCount(1, 'data');
        $this->putJson("/api/v1/announcements/{$id}/read")->assertOk();
        $this->assertDatabaseHas('announcement_reads', ['announcement_id' => $id, 'user_id' => auth()->id()]);
        $this->putJson("/api/v1/announcements/{$id}/dismiss")->assertOk();
        $this->getJson('/api/v1/announcements')->assertJsonPath('data.0.is_dismissed', true);
        $private = Announcement::create(['title' => 'Admin only', 'body' => 'Private', 'type' => 'system', 'audience' => 'admin', 'priority' => 'normal', 'display_type' => 'notification', 'status' => 'published', 'is_active' => true, 'starts_at' => now()]);
        $private->audiences()->create(['role' => 'admin']);
        $this->getJson('/api/v1/announcements')->assertJsonMissing(['id' => $private->id]);
        $scheduled = Announcement::create(['title' => 'Future public', 'body' => 'Not visible yet', 'type' => 'general', 'audience' => 'everyone', 'priority' => 'normal', 'display_type' => 'carousel', 'status' => 'scheduled', 'is_active' => true, 'starts_at' => now()->addDay()]);
        $scheduled->audiences()->create(['role' => 'public']);
        $expired = Announcement::create(['title' => 'Expired public', 'body' => 'No longer visible', 'type' => 'general', 'audience' => 'everyone', 'priority' => 'normal', 'display_type' => 'banner', 'status' => 'published', 'is_active' => true, 'starts_at' => now()->subDays(2), 'expires_at' => now()->subDay()]);
        $expired->audiences()->create(['role' => 'public']);
        auth()->forgetGuards();
        $this->getJson('/api/v1/announcements/public')->assertJsonMissing(['id' => $scheduled->id])->assertJsonMissing(['id' => $expired->id]);
        Sanctum::actingAs($this->user('announcement-nonadmin', 'tourist'));
        $this->postJson('/api/v1/admin/announcements', ['title' => 'No', 'body' => 'Not authorized'])->assertForbidden();
        Sanctum::actingAs($admin);
        $this->deleteJson("/api/v1/admin/announcements/{$id}")->assertOk();
        $this->assertDatabaseHas('announcements', ['id' => $id, 'status' => 'archived', 'is_active' => false]);

        Mail::fake();
        config(['email_notifications.urgent_announcements' => true]);
        $this->user('announcement-msme', 'msme_owner');
        $urgent = $this->postJson('/api/v1/admin/announcements', ['title' => 'Urgent closure', 'body' => 'Operations are temporarily suspended.', 'type' => 'safety', 'audiences' => ['msme_owner'], 'priority' => 'urgent', 'display_type' => 'urgent_alert', 'status' => 'published'])->assertCreated()->json('data.id');
        $this->artisan('announcements:send-email')->assertSuccessful();
        $this->artisan('announcements:send-email')->assertSuccessful();
        Mail::assertSentCount(1);
        $this->assertDatabaseCount('email_deliveries', 1);
        $this->assertDatabaseHas('email_deliveries', ['entity_type' => 'announcement', 'entity_id' => $urgent, 'status' => 'sent']);
    }

    private function assignedSpot(): array
    {
        $spot = $this->spot('Assigned');
        $partner = $this->user('partner-'.substr($spot->id, 0, 5), 'tourism_partner');
        TouristSpotPartnerAssignment::create(['tourist_spot_id' => $spot->id, 'partner_profile_id' => $partner->id, 'is_primary' => true, 'assigned_by' => null, 'assigned_at' => now()]);

        return [$spot, $partner];
    }

    private function spot(string $name): TouristSpot
    {
        return TouristSpot::create(['name' => $name, 'slug' => str($name)->slug().'-'.str()->random(5), 'description' => 'Published destination', 'latitude' => 9.95, 'longitude' => 123.96, 'is_active' => true, 'is_published' => true, 'is_bookable' => true, 'booking_enabled' => true, 'booking_mode' => 'date_only']);
    }

    private function user(string $key, string $role): User
    {
        $u = User::create(['name' => str($key)->title(), 'email' => "{$key}@example.test", 'phone' => '09170000000', 'password' => Hash::make('password'), 'role_id' => $this->roles[$role]->id, 'is_verified' => true, 'email_verified_at' => now()]);
        Profile::create(['id' => $u->id, 'name' => $u->name, 'email' => $u->email, 'phone' => $u->phone, 'role_id' => $u->role_id, 'is_verified' => true]);

        return $u;
    }

    private function reservation(User $tourist, User $partner, TouristSpot $spot): Reservation
    {
        $status = ReservationStatus::where('name', 'pending')->firstOrFail();

        return Reservation::create(['user_id' => $tourist->id, 'partner_id' => $partner->id, 'tourist_spot_id' => $spot->id, 'reservable_type' => 'spot', 'reservable_id' => $spot->id, 'reservation_date' => now()->addDays(3), 'guests' => 2, 'status_id' => $status->id, 'total_amount' => 0, 'customer_name_snapshot' => $tourist->name, 'customer_email_snapshot' => $tourist->email, 'customer_phone_snapshot' => $tourist->phone]);
    }
}
