<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Verify Your Email — Tubigon Smart Tourism</title>
    <style>
        body { margin: 0; padding: 0; background-color: #0B132B; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; }
        .container { max-width: 600px; margin: 0 auto; padding: 40px 20px; }
        .card { background: linear-gradient(135deg, #1C2541 0%, #0B132B 100%); border-radius: 16px; padding: 40px; border: 1px solid rgba(249, 115, 22, 0.2); }
        .logo { text-align: center; margin-bottom: 30px; }
        .logo-text { font-size: 24px; font-weight: 800; color: #F97316; letter-spacing: -0.5px; }
        .logo-sub { font-size: 12px; color: #94A3B8; margin-top: 4px; }
        h1 { color: #FFFFFF; font-size: 22px; font-weight: 700; margin: 0 0 12px 0; text-align: center; }
        p { color: #94A3B8; font-size: 15px; line-height: 1.6; margin: 0 0 20px 0; text-align: center; }
        .btn { display: block; width: 100%; padding: 16px; background: linear-gradient(135deg, #F97316, #EA580C); color: #FFFFFF; text-align: center; text-decoration: none; font-size: 16px; font-weight: 700; border-radius: 12px; margin: 24px 0; box-sizing: border-box; }
        .btn:hover { opacity: 0.9; }
        .divider { border: none; border-top: 1px solid rgba(255,255,255,0.08); margin: 24px 0; }
        .note { font-size: 12px; color: #64748B; text-align: center; line-height: 1.5; }
        .footer { text-align: center; margin-top: 30px; font-size: 11px; color: #475569; }
    </style>
</head>
<body>
    <div class="container">
        <div class="card">
            <div class="logo">
                <div class="logo-text">🏝️ Tubigon Smart Tourism</div>
                <div class="logo-sub">Information & Management System</div>
            </div>

            <h1>Verify Your Email Address</h1>
            <p>Hello <strong style="color:#FFFFFF;">{{ $userName }}</strong>,</p>
            <p>Thank you for registering with Tubigon Smart Tourism! Please click the button below to verify your email address and activate your account.</p>

            <a href="{{ $verificationUrl }}" class="btn">✅ Verify My Email Address</a>

            <hr class="divider">

            <p class="note">
                This verification link will expire in <strong style="color:#F97316;">{{ $expiresInMinutes }} minutes</strong>.<br>
                If you did not create an account, no further action is required.
            </p>

            <p class="note">
                If the button doesn't work, copy and paste this URL into your browser:<br>
                <span style="color:#F97316; word-break:break-all; font-size:11px;">{{ $verificationUrl }}</span>
            </p>
        </div>

        <div class="footer">
            &copy; {{ date('Y') }} Tubigon Smart Tourism — Municipality of Tubigon, Bohol, Philippines
        </div>
    </div>
</body>
</html>
