# Tubigon Smart Tourism Information and Management System

## Final audit, repair, and readiness report

**Audit date:** 2026-08-28 (Asia/Manila)  
**Workspace:** `C:\Users\Admin\Documents\TUBIGON`  
**Overall verdict:** **Complete but Needs Review — not yet production-ready**

The source now passes backend tests, Flutter tests, static analysis, clean-schema migration, Chrome startup, release web compilation, and Android APK compilation. Production sign-off is still blocked by an unavailable configured MySQL service, unverified real SMTP/Google OAuth credentials, and the absence of a physical Android/iOS device test. Several requested product capabilities are also deliberately presented as unavailable instead of being simulated.

## 1. Executive summary

The working application is a Flutter client backed by a Laravel JSON API. The extracted React/design material is reference material, not a second runtime. The audit preserved the existing architecture, route families, data model intent, and five controlled development accounts.

The most serious repaired issues were:

- incomplete migrations that could not recreate the domain schema on a clean deployment;
- public exposure of unverified/suspended MSMEs, inactive establishments, and unapproved partner listings through adjacent APIs;
- public review enumeration and unnecessary reviewer/owner account data;
- offline records being marked synchronized without server acknowledgement;
- non-idempotent POST requests being retried after ambiguous server failures;
- optimistic local mutations surviving real 4xx/validation failures and appearing successful;
- role bypasses on Tourist-only mutation endpoints;
- stale aggregate ratings after review deletion and duplicate review acceptance;
- missing offline-sync side effects and business-rule checks;
- unrestricted upload bucket names and incomplete owned-image deletion;
- malformed numeric deep links that could throw during routing;
- a vulnerable Composer dependency with six published advisories.

## 2. Audit method and evidence standard

The review traced Flutter route -> page -> provider/repository -> API endpoint -> middleware/controller -> model/table for authentication, role portals, discovery, maps, reservations, reviews, favorites, waste reporting, notifications, settings, analytics, and offline sync. Public, authenticated-owner, manager, and cross-owner paths were checked separately.

No feature is called complete solely because a page renders. A module is considered verified only where its route, data path, authorization boundary, failure behavior, and an appropriate test/build check agree.

The workspace already contained a large uncommitted implementation when the audit began. Those changes were preserved; this report assesses the resulting tree and does not attribute every pre-existing line to this audit.

## 3. Actual architecture and versions

- Client: Flutter 3.44.8 / Dart 3.12.2, Riverpod, GoRouter, Dio, SQLite/sqflite, MapLibre.
- API: Laravel Framework 12.64.0 on PHP 8.2.12, Sanctum token authentication.
- Data: configured MySQL in `.env`; isolated tests and clean-deployment validation use SQLite.
- API surface: 188 registered Laravel routes.
- Authentication source of truth: `users`; `profiles` is reconciled as public/application profile data.
- Local private data: secure token storage plus user-and-role-scoped cache cleanup.

The request described Laravel 11, but the inspected Composer installation is Laravel 12.64.0. No downgrade was attempted.

## 4. Runtime ownership and source-of-truth boundaries

- `lib/` is the active client implementation.
- `backend/` is the active API implementation.
- React/extracted design folders are not executed by the Flutter application.
- Laravel owns validation, authorization, publication state, lifecycle transitions, totals, and durable side effects.
- Flutter owns interaction state, presentation, local queues, and public/private caching, but does not treat local state as server acceptance.

## 5. Route and screen inventory

Guest/Tourist routes cover home, explore and entity details, map/location picker, reservations, profile/settings, favorites, offline maps, itineraries and itinerary map, ferry schedules, notifications, eco tips, emergency information, and waste reporting.

Admin routes cover dashboard, users/detail/edit, MSMEs, tourism/listings, reservations/detail, reviews, waste, announcements, analytics, settings, logs, managed map locations, emergency contacts, and ferry management through tourism management.

Tourism Partner routes cover dashboard, listings/create/edit/submit, reservations, notifications, reviews, analytics, and profile. MSME routes cover dashboard, business profile/listing management, reservations, reviews, analytics, notifications, and availability. LGU routes cover dashboard, tourist spots, tourism and MSME review workflows, waste/detail, emergency contacts, eco tips, announcements, analytics, reports, notifications, and managed map locations.

Malformed integer deep links now fail safely instead of throwing. Role shells and route redirects preserve the five portal homes.

## 6. Role-access matrix

| Capability | Guest | Tourist | MSME owner | LGU staff | Admin | Tourism partner |
|---|---:|---:|---:|---:|---:|---:|
| Browse published tourism/map data | Yes | Yes | Yes | Yes | Yes | Yes |
| Tourist reservations/favorites/reviews/waste | No | Yes | No | No | No | No |
| Own MSME profile/reservations/reviews | No | No | Yes | No | Admin management only | No |
| Own partner listings/reservations/reviews | No | No | No | Review workflow | Review workflow | Yes |
| Municipal content/workflow management | No | No | No | Yes | Yes | No |
| User/system administration | No | No | No | No | Yes | No |

Laravel middleware now explicitly protects Tourist mutation routes in addition to controller ownership checks. Partner/MSME record access is scoped to the authenticated owner; administrative and LGU capabilities remain separately prefixed and role-gated.

## 7. Authentication and account flows

Email registration, OTP verification, expiry, attempt limits, resend cooldown, unverified-email change, login, logout, session restore, password update, forgot-password behavior, and Google token handling were traced. Google authentication does not silently link an unrelated existing email account.

The five controlled accounts remain:

- `user@gmail.com` -> Tourist -> `/home`
- `msme@gmail.com` -> MSME owner -> `/msme-portal`
- `lgu@gmail.com` -> LGU staff -> `/lgu`
- `admin@gmail.com` -> Admin -> `/admin`
- `partner@gmail.com` -> Tourism Partner -> `/tourism-partner`

Their unverified-login bypass is disabled by default and requires the independent `DEV_AUTH_ALLOWLIST_BYPASS=true` flag plus exact email membership. `APP_DEBUG` or a local environment alone cannot enable it.

Production verification of actual email delivery and Google OAuth consent/token exchange remains blocked by external credentials and provider configuration.

## 8. Security and privacy results

Repaired controls include:

- public MSMEs require both `is_verified=true` and `verification_status=verified`;
- public tourism listings require approved and active state;
- public establishments require verified and active state;
- favorites, reviews, reservations, and sync validate the target's public state;
- public reviews require a specific valid target and expose reviewer id/name only;
- public MSME endpoints no longer eager-load the owner profile;
- partner/MSME reservations and reviews minimize nested user fields;
- owner-scoped APIs return not-found/forbidden for cross-owner identifiers;
- sync cannot overwrite another user's UUID;
- image uploads use an explicit bucket allowlist and deletion is owner-scoped;
- internal return routes reject external and privileged destinations;
- private local data is keyed and cleared by authenticated user and role.

No remaining confirmed critical IDOR or cross-role mutation path was found in the exercised routes. This is not a substitute for an independent penetration test against the deployed stack.

## 9. Database and migration integrity

The original migration set did not define much of the imported tourism domain and therefore could not reproduce a fresh installation. A guarded additive core-domain migration now creates missing roles, tourism/MSME entities, listings, reservation statuses/reservations, favorites, reviews/ratings, waste, content, notifications, ferry/emergency data, images, activity logs, and settings without dropping existing imported tables.

Result: all 17 migrations run successfully from an empty in-memory SQLite database. Existing migrations remain guarded for imported installations; the core migration has an intentional no-op rollback to avoid deleting tables that may predate Laravel migration tracking.

The configured MySQL database `tubigon_recovered` could not be inspected because `127.0.0.1:3306` actively refused connections. Therefore real migration status, imported row compatibility, indexes, and preservation of the five rows in that database are deployment blockers.

## 10. API and DTO consistency

Flutter endpoint constants and repositories were reconciled with the 188-route Laravel surface. Admin review listing now uses an admin-only endpoint rather than the target-scoped public review endpoint. Verification status queries use encoded query parameters. Public/private publication filters agree across ordinary list/detail, favorites, reviews, reservations, map discovery, and sync pull.

The API still returns mostly ad-hoc JSON model payloads rather than versioned resource/DTO classes. This is functional but remains a maintainability risk. Pagination is not consistently implemented for large management and review lists.

## 11. Data integrity and lifecycle rules

- Partner listings use draft -> submitted -> approved/needs-changes/rejected/suspended/archive rules.
- MSMEs use pending/reviewed verification states; notes are required for adverse review decisions.
- Reservation transitions reject illegal reopening of terminal states.
- Tourism listing totals are calculated server-side.
- Duplicate active reservations and duplicate reviews are rejected.
- Review create/delete refreshes aggregate score and count.
- Public data requires coherent boolean and workflow state, not one flag alone.
- Waste reports use canonical categories while accepting legacy values for compatibility.

## 12. Networking, errors, and false-success prevention

Dio retries only idempotent GET/HEAD requests. POST/PUT mutations are not replayed automatically after an ambiguous 5xx response.

Offline-capable repositories retain queued work only for actual network failures. A 4xx/validation response rolls back the optimistic local record and surfaces the server message. Cancelling a never-synced draft removes it locally; cancelling a server reservation requires online acknowledgement because the sync API does not support arbitrary reservation updates.

Admin settings no longer convert a network/server error into a fake empty settings object.

## 13. Offline sync and cache isolation

The server returns `synced_ids`, and Flutter marks only those acknowledged IDs clean. Existing owned/semantically duplicate favorites may be acknowledged idempotently; a foreign UUID produces 403. Offline reservation, review, favorite, and waste creation now runs server validation against current publication and business rules.

Offline accepted creates now generate the same important aggregate, notification, and activity-log side effects as online creates. Private caches are scoped by user and role and cleared on logout/account switch. Public map/reference cache is deliberately retained.

Conflict resolution remains create-oriented rather than a general revision protocol; true multi-device edits, tombstones, and conflict UI are not implemented.

## 14. Maps and offline maps

The active map stack is MapLibre, not Google Maps. Managed/public location APIs enforce publication, verification, active state, Tubigon coordinates, and duplicate workflows. Android/iOS offline packages use native MapLibre region downloading, which includes the style's dependent tiles, glyphs, sprites, and vector resources. Package metadata uses measured values.

Web offline-map UI is truthful: it does not claim persistent basemap downloads where the platform implementation only caches application data. Full offline search/routing and turn-by-turn navigation are not present.

## 15. Guest and Tourist portal

Published discovery, detail pages, map, ferry/emergency/eco information, authentication handoff, favorites, itineraries, reservations, reviews, notifications, profile/settings, offline maps, and waste submission are connected. Guest browsing stays public; protected mutations redirect/authenticate through a validated internal return route.

Tourist workflows are **Complete but Needs Review** pending real API/database/device validation.

## 16. Admin portal

Dashboard, user management, MSME and partner workflow management, tourist content, map locations, reservations/detail, reviews, waste, announcements, analytics, settings, logs, ferry, and emergency management have real API paths. User/role/profile mutations are transactional and protect the last admin. Destructive actions use confirmations and archives/soft deletion where modeled.

Admin is **Complete but Needs Review**; large lists need pagination and production-scale performance testing.

## 17. Tourism Partner portal

Owned draft/listing submission, reservation decisions, reviews/statistics, notifications, analytics, password/profile, and image upload are connected and owner-scoped. Approved listings edited in sensitive fields return to draft/review.

The Settings destination is an explicit capability notice rather than a fake screen. Partner is **Complete but Needs Review** for supported capabilities and **Partial** overall because dedicated business settings and owner review replies are not implemented.

## 18. LGU staff portal

LGU staff can manage/review tourism and MSME workflows, tourist spots, waste, emergency contacts, eco tips, announcements, analytics/reports, notifications, and map locations. LGU-specific reservation/review/profile/settings screens that lacked an honest backend contract were removed/replaced with capability notices.

LGU is **Complete but Needs Review** for supported municipal workflows and **Partial** relative to the full requested wishlist.

## 19. MSME owner portal

Business profile/listing submission, availability, reservations, reviews, notifications, dashboard, and analytics are connected to owner-scoped endpoints. Image upload now supplies the required `msme-gallery` bucket.

Gallery, promotions, reports, settings, and help do not have complete domain/backend support and are presented as unavailable instead of simulated. MSME is **Partial**.

## 20. Reservations

Online and offline creation validate target state, date/time, unavailable dates, opening day, listing capacity/available days/cutoff, duplicates, server-side partner linkage, status, and amount. MSME/partner owners can only see and transition their own reservations. Tourist cancellation and terminal-state rules are enforced.

Result: **Complete but Needs Review** pending live MySQL and real concurrency testing.

## 21. Listings, MSMEs, establishments, and tourist content

Public visibility is now aligned across list, detail, favorite, review, reservation, map, and sync paths. Admin/LGU review decisions maintain boolean/workflow coherence. Owner edits and submission are real, not local-only.

Result: **Complete but Needs Review**.

## 22. Reviews and favorites

Reviews require a published target, Tourist role, one review per user/target, and refresh aggregates on create/delete. Public review reads are target-scoped and do not reveal email. Favorites require a published target, are unique per user/entity, and roll back optimistic changes on server rejection.

Owner replies, moderation reasons, review pagination, and richer abuse tooling are not implemented. Result: **Complete but Needs Review** for the current scope; **Partial** against the extended wishlist.

## 23. Waste reporting

Tourists can create reports with canonical category, description, Tubigon coordinates, and up to five images; manager visibility is role-scoped, status updates are controlled, and online/offline submission emits audit/notification side effects.

Video attachments, reference-number UX, heatmaps, duplicate-report detection, and a richer assignment/escalation workflow are absent. Result: **Partial**.

## 24. Ferry, emergency, eco tips, and announcements

These modules use real public reads and admin/LGU management routes with active/verified filtering where relevant. Ferry display includes explicit freshness/fallback messaging rather than silently presenting local data as live.

Announcement scheduling, expiry, and audience segmentation are incomplete. Result: ferry/emergency/eco **Complete but Needs Review**; announcements **Partial**.

## 25. Notifications, analytics, reports, and settings

User and partner notifications are owner-scoped. Important online/offline business events generate notifications. Admin/LGU/owner dashboards and analytics use backend data rather than hard-coded success responses. Settings errors surface instead of returning empty success.

Realtime push delivery, background sync guarantees, exhaustive audit-event coverage, export scheduling, and several role-specific settings contracts remain incomplete. Result: **Partial**.

## 26. UI, accessibility, and responsiveness

The app uses responsive shells/cards, explicit loading/error/empty states, confirmations, inline validation, themed OTP feedback, and capability notices for unsupported routes. Flutter analysis is clean after applying const, control-flow, and deprecation fixes.

No formal WCAG audit, screen-reader session, contrast measurement suite, keyboard-only matrix, or low-end-device performance profile was performed. Result: **Complete but Needs Review**.

## 27. Dependencies and performance

- `league/commonmark` was updated from 2.8.3 to 2.10.0; six reported advisories are no longer present in the locked audit.
- Constraint-compatible Flutter dependencies were upgraded and verified.
- `google_sign_in_android` is pinned to 7.2.16 because 7.2.17 fails this toolchain's Android build unless generated output is reconciled; the pin is documented in `pubspec.yaml`.
- Major Flutter dependency upgrades were not forced because Riverpod, GoRouter, storage, geolocation, and plugin majors require planned migrations.
- The standard JavaScript web build succeeds; optional WebAssembly output remains blocked by `flutter_secure_storage_web` using `dart:html`/`dart:js_util`.

The last Composer audit used locally cached advisory data because Packagist timed out during the final refresh. A connected CI audit should be part of release gating.

## 28. Automated verification

- PHP syntax: every changed/new PHP file passed `php -l`.
- Laravel: **68 tests passed, 546 assertions**.
- Flutter analyze: **No issues found**.
- Flutter tests: **18 passed, 1 Chrome-only test skipped** in the VM run.
- Clean schema: **17 migrations passed** on empty in-memory SQLite.
- Composer locked audit: no advisory found after the security update, subject to the cache caveat above.

Coverage includes role routing, five account destinations, auth/OTP/dev bypass, owner isolation, status transitions, publication visibility, favorites, review target/duplicate/privacy behavior, map management, Tubigon boundary validation, cache isolation, and storage boundaries.

## 29. Builds and runtime checks

- Release web build: passed; artifact `build/web`.
- Android debug build: passed after a clean rebuild; artifact `build/app/outputs/flutter-apk/app-debug.apk`.
- Chrome 151 debug startup: connected to Flutter debug service and exited normally with `--no-resident`.
- Detected devices: Windows desktop, Chrome, Edge; no physical mobile device.
- Standard web is supported; Flutter's optional WASM dry run reports secure-storage incompatibility.

## 30. Unresolved blockers and known limitations

### Release blockers

1. Start/restore the configured MySQL service and run a backup-first `migrate:status`, additive migration, schema/index inspection, and real-data smoke test.
2. Configure and verify production SMTP sender/domain, delivery, OTP expiry/resend, and email-change flows.
3. Configure and verify Google OAuth client IDs, redirect origins, Android SHA fingerprints, and real sign-in on every target platform.
4. Run physical Android and iOS tests for location permission, image picking/upload, secure storage, background/resume, native offline regions, deep links, and poor connectivity.
5. Run an independent security review against the deployed reverse proxy, TLS/CORS/session configuration, storage permissions, rate limits, logs, and backups.

### Product limitations

- no consistent server pagination for large lists;
- no full conflict-resolution protocol for edited/deleted offline records;
- no full offline routing/search;
- no owner replies to reviews;
- no waste video/reference/heatmap/duplicate workflow;
- no announcement scheduling/audience segmentation;
- several role-specific settings/report/promotions/help/gallery capabilities are notices, not implemented modules;
- no production-scale load, accessibility, or disaster-recovery test.

## 31. Module readiness classification

| Module | Classification | Reason |
|---|---|---|
| Architecture/routing/role guards | Production Ready | Static and automated boundary checks pass |
| Email authentication/OTP | Complete but Needs Review | Logic/tests pass; SMTP delivery unverified |
| Google authentication | Blocked | Requires real provider credentials/platform setup |
| Public discovery and details | Complete but Needs Review | Publication/privacy filters repaired and tested |
| Tourist reservations | Complete but Needs Review | Business rules pass; live DB/concurrency unverified |
| Favorites | Production Ready | Owner-scoped, publication-safe, rollback-safe |
| Reviews | Complete but Needs Review | Core flow safe; moderation/replies/pagination incomplete |
| Itineraries | Complete but Needs Review | Owner-scoped; live-device/offline review remains |
| Maps/managed locations | Complete but Needs Review | Real MapLibre flow; native device verification pending |
| Offline maps | Complete but Needs Review | Native packages implemented; web limitations truthful |
| Offline mutation sync | Partial | Safe create queue; general conflicts/updates absent |
| Admin portal | Complete but Needs Review | Supported workflows connected; scale/live DB pending |
| Tourism Partner portal | Partial | Core workflow complete; settings/replies absent |
| LGU portal | Partial | Core municipal workflow complete; unsupported wishlist items absent |
| MSME portal | Partial | Core business workflow complete; gallery/promotions/reports/settings/help absent |
| Waste reporting | Partial | Core report lifecycle works; advanced requested features absent |
| Ferry schedules | Complete but Needs Review | Real CRUD/read path; operational feed freshness needs deployment review |
| Emergency contacts / eco tips | Complete but Needs Review | Real managed/public flow; live data review pending |
| Announcements | Partial | CRUD present; scheduling/audiences incomplete |
| Notifications | Partial | In-app records present; no verified push/background delivery |
| Analytics/reports/settings | Partial | Real data paths exist; exports/scheduling/role coverage incomplete |
| Clean deployment schema | Complete but Needs Review | Empty SQLite passes; configured MySQL unavailable |
| Web JavaScript build | Production Ready | Release compilation and Chrome startup pass |
| WebAssembly build | Blocked | Secure-storage web dependency is incompatible |
| Android debug build | Complete but Needs Review | APK builds; physical-device validation pending |
| iOS build/device behavior | Blocked | No macOS/Xcode/iOS device in this environment |

## 32. Production-readiness roadmap

1. Back up and restore the real MySQL service; validate migrations and imported data without destructive commands.
2. Run the complete backend/Flutter/build pipeline in CI with live Packagist/pub advisory access.
3. Complete SMTP and Google OAuth integration tests using production-like domains and signed Android builds.
4. Execute the physical-device and accessibility matrix.
5. Add pagination and query/index profiling before production-scale data import.
6. Decide which explicitly unavailable role modules are genuinely in release scope; implement only those with backend contracts, tests, and audit events.
7. Add offline update/delete conflict semantics, telemetry, backup/restore drills, rate-limit verification, and an external penetration test.

**Final determination:** the repository is substantially safer and buildable, but claiming full production readiness would be inaccurate until the release blockers above are closed.
