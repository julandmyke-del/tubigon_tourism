Tour Tubigon
Tour Tubigon Information and Management System

{{ $heading }}

Hello {{ $recipientName }},

{{ $messageText }}

@foreach ($details as $label => $value)
{{ $label }}: {{ $value }}
@endforeach

@if ($actionLabel && $actionUrl)
{{ $actionLabel }}: {{ $actionUrl }}
@endif

@if ($closingText)
{{ $closingText }}
@endif

This is an automated message from Tour Tubigon.
Please do not share verification codes or password-reset information.
