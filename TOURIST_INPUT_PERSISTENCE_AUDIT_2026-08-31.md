# Tourist/User Input Persistence Audit

Date: 2026-08-31  
Scope: Flutter Tourist/User surfaces, Riverpod repositories/providers, Laravel v1 API, Sanctum ownership, MySQL persistence, SQLite/web cache, and authorized role-side visibility.

## Result

All existing Tourist domain writes that have an implemented product workflow now use either the Laravel/MySQL authoritative path or the app's intentional offline queue. The audit fixed a non-functional password-recovery path, exposed the existing password-change backend in the Tourist UI, completed MSME and tourism-listing review input, added assigned Tourist Spot reviews to the correct partner scope, completed MSME reservation history, tightened public-target validation in online/offline favorites and reviews, and made review/settings submissions safe against duplicate or misleading UI state.

No database was migrated, reset, seeded, or otherwise mutated during this audit. No parallel persistence system or mock record source was introduced.

Status vocabulary:

- **REAL BACKEND**: Laravel/MySQL is authoritative.
- **LOCAL ONLY**: intentionally device/UI state and not domain data.
- **PARTIAL**: a real backend domain exists, but no complete Tourist UI flow exists.
- **BROKEN**: UI/API claimed a result without completing the intended workflow.
- **MOCK**: fabricated or hard-coded write behavior. No active Tourist domain submission was found in this category.

## Complete input/action inventory

| Input/action and Tourist surface | Before -> final status | Endpoint and persistent store | Ownership, target, and authorized visibility | Refresh and offline behavior |
|---|---|---|---|---|
| Register: name, email, password, confirmation | REAL BACKEND -> REAL BACKEND | `POST /api/v1/auth/register`; `users`, profile, settings, verification-code records | Server creates a `tourist`; role/verification cannot be supplied by the client. Admin user management can see the account under existing permissions. | Auth/verification Riverpod state updates. Online only; failures remain failures. |
| Password login and Google login | REAL BACKEND -> REAL BACKEND | `POST /auth/login`, `POST /auth/google`; `users`, Sanctum tokens | Authenticated identity and existing role are returned by the server; protected password accounts cannot be silently Google-linked. | Token/auth state is persisted through the existing secure/web-safe store; logout revokes the current token. |
| Email OTP entry, resend, verification-link handling, and correction of an unverified email | REAL BACKEND -> REAL BACKEND | `/auth/verify-email-code`, `/auth/resend-verification-code`, `/auth/email/verify/{id}/{hash}`, `/auth/change-unverified-email`, `/auth/verification-status`; `users` plus verification records | The pending user is identified by the signed/pending verification workflow. Server cooldown, expiry, attempt limits, and single-use behavior remain authoritative. | Auth/verification state refreshes; online only. |
| Forgot password email | BROKEN -> REAL BACKEND | `POST /auth/forgot-password`; Laravel password broker and `password_reset_tokens` | Generic response prevents account enumeration. Broker token is delivered to the configured frontend reset route. | Online only; throttled. No fake success for delivery logic. |
| Reset password from email link: new password and confirmation | MISSING/PARTIAL -> REAL BACKEND | `POST /auth/reset-password`; `users.password`, `password_reset_tokens`, Sanctum tokens | Broker validates token/email, hashes through the model, randomizes remember token, and revokes existing tokens. | New routed Flutter form locks while submitting and reports server validation accurately. |
| Change password: current password, new password, confirmation | PARTIAL (backend only) -> REAL BACKEND | `PUT /auth/password`; `users.password` | Sanctum user is derived server-side; current password is required; password is hashed. | Profile dialog prevents double submit and reports success only after API completion. Online only. |
| Profile edit: name, phone, bio | REAL BACKEND -> REAL BACKEND | `PUT /users/{authenticated-id}`; `users` and user profile | Controller authorizes the requested user and validates only editable fields. Payload attempts to change role or verification are ignored/rejected by the safe field set. Other users cannot read/update the private profile. | Auth state reload and profile provider invalidation propagate the new display name/details. Online only. |
| Profile avatar | PARTIAL -> PARTIAL | Existing `POST /users/{id}/avatar`; image/profile records | Owner authorization exists, but the current Tourist edit-profile UI has no image picker/upload workflow. | No Tourist-side write is advertised. |
| Change an already verified account's email | NOT IMPLEMENTED -> NOT IMPLEMENTED | No safe verified-email-change route/UI | The existing unverified-email correction remains intact; verification is not bypassed. | Explicit unresolved item; no local-only fake update exists. |
| Tourist Spot rating/comment | REAL BACKEND with duplicate-submit UI gap -> REAL BACKEND | `POST /reviews`, public `GET /reviews`; `reviews` (`reviewable_type`, `reviewable_id`, authenticated `user_id`) | Only public active/published spots are accepted. Public detail shows reviews; assigned destination partner and Admin review management see authorized target records. Unrelated partners do not. | Review provider and target detail are invalidated. Existing SQLite sync queue is preserved; feedback distinguishes synced from queued. Submit locks in flight. |
| MSME rating/comment | PARTIAL (API supported, no detail input) -> REAL BACKEND | Same review endpoints/table, target type `msme` | Only authoritative verified/active MSMEs are accepted. Public MSME detail shows reviews; only the owning MSME portal sees protected records. | Shared review provider plus MSME-list invalidation; queued offline writes retain the target ID. |
| Tourism-listing rating/comment | PARTIAL (API supported, no detail input) -> REAL BACKEND | Same review endpoints/table, target type `tourism_listing` | Only approved/published listings are accepted. Public listing detail shows reviews; only the owning partner sees protected records. | Shared review provider plus listing refresh; online/queued outcomes are distinct. |
| Delete own review | REAL BACKEND API, no current Tourist control -> PARTIAL | `DELETE /reviews/{id}`; `reviews` | Controller ownership prevents deleting another Tourist's review. Admin management stays under existing route permissions. | No delete button was invented because the current product UI does not expose one. |
| Create booking: destination, date, time slot, guests, existing notes/special-request field where present | REAL BACKEND -> REAL BACKEND | `POST /reservations`; `reservations`, initial `reservation_status_history`, notifications | Tourist, spot/listing/MSME target, and assigned partner/owner are resolved server-side. Booking-disabled, inactive/unpublished, capacity, date/day, and slot rules are server-authoritative. Assigned partner/MSME, LGU, and Admin see only their existing authorized views; unrelated partners cannot access it. | Tourist booking/detail and relevant providers invalidate. Deliberately online-only; an unavailable network never produces queued/success feedback. |
| Cancel own booking | REAL BACKEND -> REAL BACKEND | `PUT /reservations/{id}/cancel`; reservations/history/notifications | Only the booking Tourist can cancel and only from supported states. Existing reservations remain readable if future booking is disabled. | Booking providers refresh; online only. |
| Partner/LGU/Admin/MSME booking status change as observed by Tourist | PARTIAL for MSME history -> REAL BACKEND | Partner/MSME/LGU/Admin status endpoints; `reservations`, `reservation_status_history`, notifications | Allowed state transitions and target ownership are server-scoped and locked. MSME updates now create the same auditable history used by other reservation paths. | Tourist sees the authoritative status/history on provider refresh; role notifications remain intact. |
| Add/remove favorite for Tourist Spot, MSME, tourism listing, or public map location | REAL BACKEND with offline target-validation gaps -> REAL BACKEND | `GET /favorites`, `POST /favorites/toggle`, `/sync/push`; `favorites`; SQLite/web queue/cache | `user_id` is always the Sanctum user. Target type/ID must exist and be public; map locations must be verified, published, and active; spots must be published/active. Favorite sets are private and owner-scoped. | Favorite notifier updates detail/Favorites/Explore state and reconciles sync. Offline toggles are intentionally queued, never represented as server-synced until push succeeds. |
| Create/update/archive/delete trip: title, dates, notes/status | REAL BACKEND -> REAL BACKEND | `/itineraries`; `itineraries` | `user_id` is server-derived. Every show/update/delete lookup is owner-scoped; no partner/LGU/Admin private itinerary view was added. | Itinerary providers and local cache reconcile with API. Existing offline/cached-read architecture is preserved. |
| Add/remove/reorder itinerary stop; date/time, notes, visited/skipped state, reservation link | REAL BACKEND -> REAL BACKEND | `/itineraries/{id}/items`, reorder and item endpoints; `itinerary_items` and reservation relationship | Parent and item ownership are checked together. Targets resolve to authoritative Tourist Spot/MSME/listing/map IDs; cross-itinerary IDs and IDOR are rejected. | Provider invalidation/reload preserves authoritative order and Smart Map/OSRM IDs. |
| Waste report: category, description, selected latitude/longitude | REAL BACKEND -> REAL BACKEND | `POST /waste-reports`, `/sync/push`; `waste_reports`, notifications | Reporting user, initial status, and priority are server-derived even if spoofed fields are sent. Category/text/ranges and Tubigon coordinates are validated. Tourist reads are owner-scoped; LGU/Admin management sees operational reports. Another Tourist cannot open a report by ID. | Form locks during submit; online success and accepted offline queue messages are distinct. Map picker only returns temporary report coordinates and cannot edit destination/MSME coordinates. |
| Waste report photo/image | PARTIAL -> PARTIAL | Existing `/waste-reports/{id}/images`; waste image storage/model | Backend and a dormant repository parameter exist, but the current report page never selects or passes an image. | Explicit unresolved item; no claim or mock upload was added. |
| Tourist waste-report history | PARTIAL -> PARTIAL | `GET /waste-reports`; `waste_reports` owner scope | Backend supports the Tourist's own list/show, while LGU/Admin have management views. The current Tourist router/page does not expose a working history screen. | Explicit unresolved UI item. |
| Push/location/offline preference switches | REAL BACKEND with optimistic-error gap -> REAL BACKEND | `GET/PUT /settings`; settings record | Settings are keyed to the authenticated user; no client owner field is accepted. Private to that user. | Each toggle now locks independently, applies server response, and rolls back on error; provider is invalidated. Online write only. |
| Theme/dark-mode selection | LOCAL ONLY -> LOCAL ONLY (intentional) | Existing device/web preference store | Device presentation preference, not shared domain data and not exposed to other roles. | Persists locally and updates theme provider immediately. |
| Language dialog | UI-ONLY availability notice -> unchanged | No Tourist write endpoint is invoked | English is the only selectable/current language; Cebuano/Filipino are visibly unavailable. | No fake persistence. Backend language setting remains unused by this UI. |
| Notification read/read-all | REAL BACKEND -> REAL BACKEND | `/notifications/{id}/read`, `/notifications/read-all`; notifications | Notification queries and mutations are authenticated/recipient-scoped. | Notification and unread-count providers refresh. Requires backend. |
| Waste-report map picker, Smart Map search/category filters, list searches, rating filters, date-picker staging | LOCAL ONLY -> LOCAL ONLY (intentional) | Temporary widget/provider state; no domain table | These controls select or filter data and do not themselves create a record. Only a subsequent authorized submit persists selected values. | Map/search state is temporary or cached as designed. |
| Offline map download/removal | LOCAL ONLY -> LOCAL ONLY (intentional) | Existing native/browser cache | Device-owned map asset cache, not a shared domain record. | Remains available through the existing platform-safe cache implementation. |
| Call, directions, share, external-link actions | NON-PERSISTENT -> unchanged | Platform navigation/intent only | No owned domain record is expected. | No fake backend write. |

## Authorization and propagation findings

- All audited Tourist writes derive `user_id` from `$request->user()`; client-supplied `user_id`, owner/partner IDs, role, verification, approval, status, and priority do not control protected ownership/state.
- Favorites, itineraries, and profile/account data remain private. No new LGU/Admin/partner access was added.
- Reviews are publicly readable for public targets, while protected management queries are scoped to the MSME owner's MSME, a partner's owned listing, or the partner's assigned Tourist Spot. Assigned Tourist Spot partners now receive review notifications. Unrelated owners/partners are excluded by server queries, not Flutter filtering.
- Reservations retain their operational visibility. Tourist ownership, target, and partner/MSME assignment are derived by the backend. Status transitions write history and notify the Tourist; terminal transitions cannot be reopened.
- Waste reports remain operational data visible to LGU/Admin, while Tourist list/show access is owner-scoped. Report coordinates are independently validated and cannot mutate authoritative map-place coordinates.
- Online and `/sync/push` target validation now agree for published spots and verified map locations, preventing an offline queue from admitting a target rejected by the direct API.

## Client refresh and submission behavior

- Review dialogs invalidate the shared target review provider and relevant MSME/listing detail source after accepted API/queue writes. They use a lifecycle-owned controller and disable input/actions in flight.
- Reservation creation/cancellation and itinerary/favorite mutations retain their existing notifier invalidation and cache reconciliation.
- Profile updates reload authenticated user state and invalidate profile data.
- Setting toggles now serialize each setting write, accept the authoritative server value, and restore the previous value on failure.
- Password reset/change and reviews prevent duplicate submissions and never show success for a rejected operation.

## Files changed by this audit

Backend implementation:

- `backend/routes/api.php`
- `backend/app/Http/Controllers/Api/V1/AuthController.php`
- `backend/app/Http/Controllers/Api/V1/FavoriteController.php`
- `backend/app/Http/Controllers/Api/V1/MsmeController.php`
- `backend/app/Http/Controllers/Api/V1/ReviewController.php`
- `backend/app/Http/Controllers/Api/V1/SyncController.php`
- `backend/app/Http/Controllers/Api/V1/TourismListingController.php`
- `backend/app/Models/User.php`
- `backend/app/Notifications/ResetPasswordNotification.php`
- `backend/config/app.php`
- `backend/.env.example`

Flutter implementation:

- `lib/core/constants/api_endpoints.dart`
- `lib/core/routes/app_router.dart`
- `lib/features/authentication/auth_provider.dart`
- `lib/features/authentication/pages/reset_password_page.dart`
- `lib/features/userpage/presentation/pages/profile_page.dart`
- `lib/features/userpage/presentation/pages/settings_page.dart`
- `lib/features/userpage/presentation/pages/msme_detail_page.dart`
- `lib/features/userpage/presentation/pages/tourism_listing_detail_page.dart`
- `lib/features/userpage/presentation/pages/tourist_spot_detail_page.dart`
- `lib/features/userpage/presentation/widgets/place_reviews_panel.dart`
- `lib/features/tourism_partner/presentation/pages/partner_reviews_page.dart`

Tests:

- `backend/tests/Feature/AuthFlowTest.php`
- `backend/tests/Feature/FeaturedDestinationPartnerOwnershipTest.php`
- `backend/tests/Feature/PortalSecurityTest.php`
- `backend/tests/Feature/WasteReportFlowTest.php`
- `test/place_reviews_panel_test.dart`
- `test/reset_password_page_test.dart`
- `test/settings_page_test.dart`

The working tree also contains pre-existing edits from other Tubigon tasks. They were preserved and are not attributed to this audit in the list above.

## Tests and builds

- Focused Laravel persistence/security matrix: **71 passed, 750 assertions**.
- Full Laravel suite (`php artisan test --compact`): **98 passed, 984 assertions**.
- New focused Flutter review/reset/settings tests: **4 passed**.
- Full Flutter suite (`flutter test --reporter compact`): **49 passed, 1 pre-existing skipped**.
- `flutter analyze`: **passed, no issues**.
- `dart analyze`: **passed, no issues**.
- `flutter build web --release`: **passed**, output `build/web`. The compiler reported only the existing `flutter_secure_storage_web` WebAssembly dry-run incompatibility; the normal release web build succeeded.
- `flutter build apk --release`: **passed**, output `build/app/outputs/flutter-apk/app-release.apk` (95.5 MB).

Backend feature tests exercise the cross-role flows against an isolated test database: Tourist review -> correct assigned partner, Tourist booking -> assigned partner/MSME -> status/history -> Tourist, Tourist waste report -> LGU visibility, and Tourist A private favorites/itinerary/profile isolation from Tourist B. No authoritative local MySQL data was altered for manual verification.

## Remaining partial/non-persistent features

1. Verified-account email change has no safe UI/API workflow. The existing unverified-email correction is real and remains protected; no bypass was created.
2. Profile avatar upload has a backend endpoint but no Tourist image-selection UI.
3. Waste-report image upload has backend support but is not wired to the current Tourist report page.
4. Tourist waste-report history is supported by owner-scoped API endpoints but has no reachable Tourist page.
5. Tourist review deletion is owner-authorized in the API but has no current Tourist UI control.
6. Additional languages are unavailable UI choices, not persisted selections.

These are reported as partial or intentionally local—not as completed capabilities—and none currently shows fabricated success.
