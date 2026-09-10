<?php

namespace App\Services;

use App\Mail\TourTubigonMessage;
use App\Models\Announcement;
use App\Models\EmailDelivery;
use App\Models\Msme;
use App\Models\Reservation;
use App\Models\RoleApplication;
use App\Models\TourismListing;
use App\Models\TouristSpot;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Schema;
use Throwable;

class EmailNotificationService
{
    public function reservation(Reservation $reservation, string $event, ?string $reason = null): bool
    {
        if ($event === 'submitted' && ! config('email_notifications.reservation_received', true)) {
            return false;
        }
        if ($event === 'reminder' && ! config('email_notifications.reservation_reminders', true)) {
            return false;
        }

        $recipient = User::find($reservation->user_id);
        if (! $recipient) {
            return false;
        }

        $targetName = $this->reservationTargetName($reservation);
        $reference = $reservation->public_reference ?: 'Pending reference';
        $visitDate = $reservation->reservation_date?->timezone(config('app.timezone'))->format('F j, Y') ?? 'Not specified';
        $visitTime = $reservation->start_time ? substr((string) $reservation->start_time, 0, 5) : null;
        $details = array_filter([
            'Destination / Business' => $targetName,
            'Visit Date' => $visitDate,
            'Visit Time' => $visitTime,
            'Guests' => (string) $reservation->guests,
            'Booking Reference' => $reference,
            'Reason' => $reason ? trim($reason) : null,
        ], static fn (?string $value): bool => $value !== null && $value !== '');

        [$subject, $heading, $message] = match ($event) {
            'submitted' => [
                "Reservation Request Received - {$targetName}",
                'Reservation request received',
                'We received your reservation request. It is awaiting review by the responsible destination or business operator.',
            ],
            'approved', 'confirmed' => [
                'Your Reservation Has Been Confirmed',
                'Reservation confirmed',
                "Your reservation for {$targetName} has been confirmed.",
            ],
            'rejected' => [
                "Reservation Update - {$targetName}",
                'Reservation not approved',
                'Your reservation request was not approved. Review the safe operational details below or open Tour Tubigon for the latest status.',
            ],
            'cancelled' => [
                "Reservation Cancelled - {$targetName}",
                'Reservation cancelled',
                "Your reservation for {$targetName} has been cancelled.",
            ],
            'reminder' => [
                "Reminder: Your Visit to {$targetName} Is Tomorrow",
                'Your reservation is tomorrow',
                "This is a reminder for your upcoming visit to {$targetName}.",
            ],
            default => [
                "Reservation Update - {$targetName}",
                'Reservation updated',
                "The status of your reservation for {$targetName} was updated.",
            ],
        };

        $dedupeEvent = $event === 'approved' ? 'confirmed' : $event;

        return $this->deliver(
            recipient: $recipient,
            messageType: "reservation_{$dedupeEvent}",
            entityType: 'reservation',
            entityId: (string) $reservation->id,
            dedupeIdentity: "reservation:{$reservation->id}:{$dedupeEvent}",
            mail: new TourTubigonMessage(
                mailSubject: $subject,
                recipientName: $recipient->name,
                heading: $heading,
                messageText: $message,
                details: $details,
                actionLabel: 'View Reservation',
                actionUrl: $this->frontendUrl("/reservations/{$reservation->id}"),
                closingText: 'Please keep your booking reference for any follow-up with the Tourism Office or operator.',
            ),
        );
    }

    public function application(RoleApplication $application, string $event): bool
    {
        $application->loadMissing(['applicant', 'requestedTouristSpot']);
        $recipient = $application->applicant;
        if (! $recipient) {
            return false;
        }

        $label = $application->application_type === RoleApplication::TYPE_MSME
            ? 'MSME Owner application'
            : 'Tourism Partner application';
        $details = ['Application' => $label];
        if ($application->application_type === RoleApplication::TYPE_PARTNER
            && $application->requestedTouristSpot) {
            $details['Assigned Destination'] = $application->requestedTouristSpot->name;
        }

        [$subject, $heading, $message, $actionLabel] = match ($event) {
            'needs_changes' => [
                $application->application_type === RoleApplication::TYPE_MSME
                    ? 'Action Required: Update Your MSME Application'
                    : 'Action Required: Update Your Tourism Partner Application',
                'Application changes required',
                'The Municipal Tourism Office reviewed your application and requested changes. Open Tour Tubigon to review the request and resubmit. Private internal review notes are not included in this email.',
                'Review Application',
            ],
            'approved' => [
                $application->application_type === RoleApplication::TYPE_MSME
                    ? 'Your MSME Owner Application Has Been Approved'
                    : 'Tourism Partner Access Approved',
                'Application approved',
                $application->application_type === RoleApplication::TYPE_MSME
                    ? 'Your account has been approved for MSME Owner access. Business publication and verification remain separate municipal decisions.'
                    : 'Your Tourism Partner access was approved and linked to the authoritative destination shown below.',
                'Open Your Portal',
            ],
            'rejected' => [
                "Update on Your {$label}",
                'Application decision available',
                'Your application was not approved. Open Tour Tubigon to review the official decision and available next steps. Private internal review notes are not included in this email.',
                'View Application',
            ],
            default => [
                "Update on Your {$label}",
                'Application updated',
                'The status of your application was updated. Open Tour Tubigon for the authoritative details.',
                'View Application',
            ],
        };

        $route = $event === 'approved'
            ? ($application->application_type === RoleApplication::TYPE_MSME ? '/msme-portal' : '/tourism-partner')
            : "/applications/{$application->id}";

        return $this->deliver(
            recipient: $recipient,
            messageType: "role_application_{$event}",
            entityType: 'role_application',
            entityId: (string) $application->id,
            dedupeIdentity: "role-application:{$application->id}:{$event}",
            mail: new TourTubigonMessage(
                mailSubject: $subject,
                recipientName: $recipient->name,
                heading: $heading,
                messageText: $message,
                details: $details,
                actionLabel: $actionLabel,
                actionUrl: $this->frontendUrl($route),
            ),
        );
    }

    public function partnerAssignment(User $partner, ?TouristSpot $spot, string $changeId): bool
    {
        $assigned = $spot !== null;

        return $this->deliver(
            recipient: $partner,
            messageType: $assigned ? 'partner_destination_assigned' : 'partner_destination_unassigned',
            entityType: 'user',
            entityId: (string) $partner->id,
            dedupeIdentity: "partner-assignment:{$changeId}",
            mail: new TourTubigonMessage(
                mailSubject: $assigned ? 'Tourism Partner Destination Assignment Updated' : 'Tourism Partner Destination Assignment Removed',
                recipientName: $partner->name,
                heading: $assigned ? 'Your assigned destination was updated' : 'Your destination assignment was removed',
                messageText: $assigned
                    ? 'Your Tourism Partner portal now reflects the final destination assignment saved by the administrator.'
                    : 'Your Tourism Partner destination assignment was removed. Contact the Tourism Office if you need assistance.',
                details: $assigned ? ['Assigned Destination' => $spot->name] : [],
                actionLabel: 'Open Partner Portal',
                actionUrl: $this->frontendUrl('/tourism-partner'),
            ),
        );
    }

    public function passwordChanged(User $user): bool
    {
        return $this->deliver(
            recipient: $user,
            messageType: 'security_password_changed',
            entityType: 'user',
            entityId: (string) $user->id,
            dedupeIdentity: "password-changed:{$user->id}:".now()->format('YmdHis.u'),
            mail: new TourTubigonMessage(
                mailSubject: 'Your Tour Tubigon Password Was Changed',
                recipientName: $user->name,
                heading: 'Password changed',
                messageText: 'The password for your Tour Tubigon account was changed. If you did not make this change, contact support immediately.',
                actionLabel: 'Sign In to Tour Tubigon',
                actionUrl: $this->frontendUrl('/auth/login'),
            ),
        );
    }

    public function announcement(Announcement $announcement): int
    {
        if (! $this->announcementShouldEmail($announcement)) {
            return 0;
        }

        $audiences = $announcement->audienceRoles();
        $roleAudiences = array_values(array_diff($audiences, ['public']));
        $query = User::query()
            ->where('is_verified', true)
            ->whereNotNull('email')
            ->whereHas('role', function (Builder $role) use ($roleAudiences, $audiences): void {
                if (! in_array('public', $audiences, true) && $roleAudiences !== []) {
                    $role->whereIn('name', $roleAudiences);
                }
            })
            ->with('role');

        $sent = 0;
        $query->chunkById(100, function ($users) use ($announcement, &$sent): void {
            foreach ($users as $user) {
                $sent += $this->deliver(
                    recipient: $user,
                    messageType: 'announcement_'.$announcement->priority,
                    entityType: 'announcement',
                    entityId: (string) $announcement->id,
                    dedupeIdentity: "announcement:{$announcement->id}:user:{$user->id}",
                    mail: new TourTubigonMessage(
                        mailSubject: ($announcement->priority === 'urgent' ? 'Urgent Tour Tubigon Advisory - ' : 'Tour Tubigon Advisory - ').$announcement->title,
                        recipientName: $user->name,
                        heading: $announcement->title,
                        messageText: $announcement->body,
                        details: [
                            'Priority' => ucfirst($announcement->priority),
                            'Audience' => collect($announcement->audienceRoles())->map(fn ($role) => str($role)->replace('_', ' ')->title())->join(', '),
                        ],
                        actionLabel: 'View Announcement',
                        actionUrl: $this->frontendUrl('/notifications'),
                    ),
                ) ? 1 : 0;
            }
        });

        return $sent;
    }

    private function announcementShouldEmail(Announcement $announcement): bool
    {
        if (! $announcement->is_active
            || ! in_array($announcement->status, ['published', 'scheduled'], true)
            || ($announcement->starts_at && $announcement->starts_at->isFuture())
            || ($announcement->expires_at && $announcement->expires_at->isPast())) {
            return false;
        }

        return match ($announcement->priority) {
            'urgent' => (bool) config('email_notifications.urgent_announcements', true),
            'important' => (bool) config('email_notifications.important_announcements', true),
            default => false,
        };
    }

    private function deliver(
        User $recipient,
        string $messageType,
        string $entityType,
        string $entityId,
        string $dedupeIdentity,
        TourTubigonMessage $mail,
    ): bool {
        if ($recipient->trashed() || ! $recipient->is_verified || ! filter_var($recipient->email, FILTER_VALIDATE_EMAIL)) {
            return false;
        }

        $delivery = null;
        if (Schema::hasTable('email_deliveries')) {
            $delivery = EmailDelivery::firstOrCreate(
                ['dedupe_key' => hash('sha256', $dedupeIdentity)],
                [
                    'user_id' => $recipient->id,
                    'message_type' => $messageType,
                    'entity_type' => $entityType,
                    'entity_id' => $entityId,
                    'recipient_masked' => $this->maskEmail($recipient->email),
                    'status' => 'pending',
                    'attempts' => 0,
                ],
            );
            if (! $delivery->wasRecentlyCreated && $delivery->status === 'sent') {
                return false;
            }
            $delivery->forceFill([
                'status' => 'pending',
                'attempts' => $delivery->attempts + 1,
                'last_attempt_at' => now(),
                'error_class' => null,
            ])->save();
        }

        try {
            Mail::to($recipient->email, $recipient->name)->send($mail);
            $delivery?->forceFill(['status' => 'sent', 'sent_at' => now()])->save();

            return true;
        } catch (Throwable $exception) {
            $delivery?->forceFill([
                'status' => 'failed',
                'error_class' => $exception::class,
            ])->save();
            Log::warning('Tour Tubigon email delivery failed.', [
                'message_type' => $messageType,
                'user_id' => $recipient->id,
                'recipient' => $this->maskEmail($recipient->email),
                'attempt' => $delivery?->attempts ?? 1,
                'exception' => $exception::class,
            ]);

            return false;
        }
    }

    private function reservationTargetName(Reservation $reservation): string
    {
        return match ($reservation->reservable_type) {
            'spot' => TouristSpot::withTrashed()->whereKey($reservation->reservable_id)->value('name') ?? 'Tourist Destination',
            'msme' => Msme::withTrashed()->whereKey($reservation->reservable_id)->value('name') ?? 'MSME Business',
            'tourism_listing' => TourismListing::withTrashed()->whereKey($reservation->reservable_id)->value('listing_name') ?? 'Tourism Listing',
            default => 'Tour Tubigon Destination',
        };
    }

    private function frontendUrl(string $path): string
    {
        $base = rtrim((string) config('app.frontend_url'), '/');

        return $base.'/'.ltrim($path, '/');
    }

    private function maskEmail(string $email): string
    {
        [$local, $domain] = array_pad(explode('@', $email, 2), 2, '');
        $visible = substr($local, 0, min(2, strlen($local)));

        return $visible.'***@'.$domain;
    }
}
