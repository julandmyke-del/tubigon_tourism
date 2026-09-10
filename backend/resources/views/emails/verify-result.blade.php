<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Email Verified — Tour Tubigon</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { background: #0B132B; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
        .card { background: linear-gradient(135deg, #1C2541 0%, #0B132B 100%); border-radius: 20px; padding: 48px 40px; max-width: 480px; width: 90%; border: 1px solid rgba(249, 115, 22, 0.25); text-align: center; box-shadow: 0 20px 60px rgba(0,0,0,0.4); }
        .icon { font-size: 64px; margin-bottom: 20px; }
        h1 { color: #FFFFFF; font-size: 26px; font-weight: 800; margin-bottom: 12px; letter-spacing: -0.5px; }
        .success-text { color: #22C55E; font-size: 18px; font-weight: 600; margin-bottom: 20px; }
        p { color: #94A3B8; font-size: 15px; line-height: 1.6; margin-bottom: 24px; }
        .brand { color: #F97316; font-weight: 700; }
        .divider { border: none; border-top: 1px solid rgba(255,255,255,0.08); margin: 24px 0; }
        .note { font-size: 13px; color: #64748B; }
        .footer { margin-top: 30px; font-size: 11px; color: #475569; }
        .error-text { color: #EF4444; font-size: 18px; font-weight: 600; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="card">
        @if($status === 'success')
            <div class="icon">✅</div>
            <h1>Email Verified!</h1>
            <p class="success-text">Your account has been successfully verified.</p>
            <p>You can now log in to the <span class="brand">Tour Tubigon</span> application using your registered email and password.</p>
            <hr class="divider">
            <p class="note">You may close this browser tab and return to the application to log in.</p>
        @elseif($status === 'already_verified')
            <div class="icon">ℹ️</div>
            <h1>Already Verified</h1>
            <p class="success-text">Your email address has already been verified.</p>
            <p>Your <span class="brand">Tour Tubigon</span> account is fully active. You can log in to the application.</p>
            <hr class="divider">
            <p class="note">You may close this browser tab.</p>
        @else
            <div class="icon">❌</div>
            <h1>Verification Failed</h1>
            <p class="error-text">This verification link is invalid or has expired.</p>
            <p>Please request a new verification email from the <span class="brand">Tour Tubigon</span> application.</p>
            <hr class="divider">
            <p class="note">Verification links expire after 60 minutes for security purposes.</p>
        @endif

        <div class="footer">
            &copy; {{ date('Y') }} Tour Tubigon — Municipality of Tubigon, Bohol, Philippines
        </div>
    </div>
</body>
</html>
