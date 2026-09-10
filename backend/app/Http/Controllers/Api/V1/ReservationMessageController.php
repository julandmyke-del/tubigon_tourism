<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreMessageRequest;
use App\Models\Notification;
use App\Models\PartnerNotification;
use App\Models\Reservation;
use App\Models\ReservationMessage;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

class ReservationMessageController extends Controller
{
    public function index(Request $r, string $reservation): JsonResponse
    {
        $res = $this->participant($r, $reservation);
        $partner = (string) $res->partner_id === (string) $r->user()->id;
        $items = $res->messages()->with('sender:id,name')->when(! $partner, fn ($q) => $q->where('is_internal', false))->get();
        $this->mark($r, $items);

        return response()->json(['status' => 'success', 'data' => $items]);
    }

    public function store(StoreMessageRequest $r, string $reservation): JsonResponse
    {
        $res = $this->participant($r, $reservation);
        $partner = (string) $res->partner_id === (string) $r->user()->id;
        $internal = (bool) $r->boolean('is_internal');
        abort_if($internal && ! $partner, 403, 'Only the assigned Partner can create internal notes.');
        $message = DB::transaction(function () use ($r, $res, $partner, $internal) {
            $m = ReservationMessage::create(['reservation_id' => $res->id, 'sender_user_id' => $r->user()->id, 'sender_role_at_time' => $partner ? 'tourism_partner' : 'tourist', 'message' => $r->validated('message'), 'message_type' => $partner ? 'partner_message' : 'user_message', 'is_internal' => $internal]);
            DB::table('reservation_message_reads')->insert(['reservation_message_id' => $m->id, 'user_id' => $r->user()->id, 'read_at' => now()]);
            if (! $internal) {
                if ($partner) {
                    Notification::create(['user_id' => $res->user_id, 'type' => 'reservation_message', 'title' => 'New reservation message', 'body' => 'Your Tourism Partner replied to your reservation.', 'data' => ['reservation_id' => $res->id, 'route' => "/reservations/{$res->id}"]]);
                } else {
                    PartnerNotification::create(['user_id' => $res->partner_id, 'type' => 'reservation_message', 'title' => 'New reservation message', 'body' => 'A Tourist sent a reservation message.', 'data' => ['reservation_id' => $res->id, 'route' => '/tourism-partner/reservations']]);
                }
            }

return $m;
        });

        return response()->json(['status' => 'success', 'data' => $message], 201);
    }

    public function read(Request $r, string $reservation): JsonResponse
    {
        $res = $this->participant($r, $reservation);
        $this->mark($r, $res->messages()->get());

        return response()->json(['status' => 'success']);
    }

    private function participant(Request $r, string $id): Reservation
    {
        $res = Reservation::findOrFail($id);
        Gate::forUser($r->user())->authorize('communicate', $res);

        return $res;
    }

    private function mark(Request $r, $items): void
    {
        foreach ($items as $m) {
            DB::table('reservation_message_reads')->updateOrInsert(['reservation_message_id' => $m->id, 'user_id' => $r->user()->id], ['read_at' => now()]);
        }
    }
}
