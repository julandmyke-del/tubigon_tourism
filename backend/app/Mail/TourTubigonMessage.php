<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class TourTubigonMessage extends Mailable
{
    use Queueable, SerializesModels;

    /** @param array<string, string> $details */
    public function __construct(
        public readonly string $mailSubject,
        public readonly string $recipientName,
        public readonly string $heading,
        public readonly string $messageText,
        public readonly array $details = [],
        public readonly ?string $actionLabel = null,
        public readonly ?string $actionUrl = null,
        public readonly ?string $closingText = null,
    ) {
    }

    public function envelope(): Envelope
    {
        return new Envelope(subject: $this->mailSubject);
    }

    public function content(): Content
    {
        return new Content(
            view: 'emails.tour-tubigon-message',
            text: 'emails.tour-tubigon-message-text',
        );
    }

    public function attachments(): array
    {
        return [];
    }
}
