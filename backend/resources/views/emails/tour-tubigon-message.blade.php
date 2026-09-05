<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ $mailSubject }}</title>
</head>
<body style="margin:0;padding:0;background:#f1f5f9;font-family:Arial,Helvetica,sans-serif;color:#172033;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f1f5f9;padding:28px 12px;">
    <tr><td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:600px;background:#ffffff;border:1px solid #dbe3ee;border-radius:14px;overflow:hidden;">
            <tr><td style="background:#0b1930;padding:24px 30px;border-bottom:4px solid #f59e0b;">
                <div style="font-size:23px;font-weight:700;color:#ffffff;">Tour Tubigon</div>
                <div style="font-size:12px;color:#cbd5e1;margin-top:5px;">Tubigon Smart Tourism Information and Management System</div>
            </td></tr>
            <tr><td style="padding:30px;">
                <h1 style="font-size:22px;line-height:1.3;color:#10213f;margin:0 0 18px;">{{ $heading }}</h1>
                <p style="font-size:15px;line-height:1.65;margin:0 0 14px;">Hello {{ $recipientName }},</p>
                <p style="font-size:15px;line-height:1.65;margin:0 0 20px;">{{ $messageText }}</p>

                @if ($details !== [])
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;margin:20px 0;">
                        @foreach ($details as $label => $value)
                            <tr>
                                <td style="padding:10px 14px;color:#64748b;font-size:13px;border-bottom:1px solid #e2e8f0;">{{ $label }}</td>
                                <td style="padding:10px 14px;color:#172033;font-size:13px;font-weight:600;text-align:right;border-bottom:1px solid #e2e8f0;">{{ $value }}</td>
                            </tr>
                        @endforeach
                    </table>
                @endif

                @if ($actionLabel && $actionUrl)
                    <p style="margin:24px 0;text-align:center;">
                        <a href="{{ $actionUrl }}" style="display:inline-block;background:#ea7a16;color:#ffffff;text-decoration:none;font-size:14px;font-weight:700;padding:12px 22px;border-radius:8px;">{{ $actionLabel }}</a>
                    </p>
                @endif

                @if ($closingText)
                    <p style="font-size:14px;line-height:1.6;color:#475569;margin:20px 0 0;">{{ $closingText }}</p>
                @endif
            </td></tr>
            <tr><td style="background:#f8fafc;padding:20px 30px;border-top:1px solid #e2e8f0;color:#64748b;font-size:12px;line-height:1.6;">
                This is an automated message from Tour Tubigon.<br>
                Please do not share verification codes or password-reset information.<br><br>
                Tubigon Smart Tourism Information and Management System
            </td></tr>
        </table>
    </td></tr>
</table>
</body>
</html>
