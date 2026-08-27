# Authentication setup

The application uses Laravel Sanctum for its own sessions. Google is used only
to obtain an OpenID Connect ID token; Laravel verifies that token and then
issues the same Sanctum token used by password login.

## Development-only test account login

When the backend has `APP_ENV=local`, the existing password credentials for
`user@gmail.com`, `msme@gmail.com`, `lgu@gmail.com`, `partner@gmail.com`, and
`admin@gmail.com` may log in without completing email verification. The stored
password is still required, and the stored account status and role are still
enforced. No database fields are changed by this bypass.

The bypass is disabled for every other `APP_ENV` value, including `production`.

## Google Cloud configuration

1. Create a Web OAuth 2.0 client in Google Cloud Console. Add the Flutter web
   origins used in development and production (for example,
   `http://localhost:PORT` and the production HTTPS origin).
2. Create an Android OAuth client for package
   `com.tubigon.tubigon_tourism` and register the signing certificate SHA-1.
3. If iOS is shipped, create an iOS OAuth client for the Runner bundle ID and
   complete the URL-scheme setup from the official `google_sign_in_ios`
   instructions.
4. Put the Web OAuth client ID in `backend/.env`:

   ```dotenv
   GOOGLE_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
   ```

5. Start Flutter with the same Web/server client ID. Client IDs are public
   identifiers; never pass a Google client secret to Flutter.

   ```powershell
   flutter run --dart-define=GOOGLE_CLIENT_ID=your-web-client-id.apps.googleusercontent.com --dart-define=GOOGLE_SERVER_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
   ```

   For iOS without `GoogleService-Info.plist`, also provide the iOS client ID
   with `--dart-define=GOOGLE_IOS_CLIENT_ID=...` after completing its URL
   scheme setup.

## Email verification mail

Configure `MAIL_MAILER`, `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`,
`MAIL_PASSWORD`, `MAIL_FROM_ADDRESS`, and `MAIL_FROM_NAME` in `backend/.env`.
The signed link lifetime defaults to 60 minutes and can be changed with:

```dotenv
AUTH_VERIFICATION_EXPIRE_MINUTES=60
```

Never commit production credentials. After changing Laravel environment
values, run `php artisan config:clear` before testing.
