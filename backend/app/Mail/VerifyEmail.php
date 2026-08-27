<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class VerifyEmail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public readonly string $userName,
        public readonly string $verificationUrl,
        public readonly int $expiresInMinutes,
    ) {
    }

    public function envelope(): Envelope
    {
        return new Envelope(
            subject: 'Verify Your Email Address — Tubigon Smart Tourism',
        );
    }

    public function content(): Content
    {
        return new Content(view: 'emails.verify-email');
    }

    public function attachments(): array
    {
        return [];
    }
}
