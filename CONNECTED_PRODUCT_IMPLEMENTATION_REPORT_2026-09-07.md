# Tour Tubigon connected-product implementation report

Report date: 2026-09-07  
Scope: persistent sessions, Guest exploration, environmental waste operations,
verified emergency contacts, and route/itinerary-aware carbon estimation.

The pre-change evidence and gap classification are recorded separately in
`CONNECTED_PRODUCT_GAP_AUDIT_2026-09-06.md`. This report describes the
implemented state. Existing production-like records and prior project work
were preserved; no production table was reset or truncated.

## 1. Existing architecture discovered

The client is an established Flutter application using Riverpod, GoRouter,
Dio, MapLibre, Geolocator, OSRM, native SQLite, and web-safe local storage. The
Laravel v12 API uses Sanctum bearer tokens, role middleware, MySQL-compatible
UUID models, additive migrations, notifications, and activity/audit tables.
Public and role portals already shared the same versioned `/api/v1` contract.
The implementation therefore extends the current providers, controllers,
models, map feed, sync protocol, and visual system instead of replacing them.

## 2. Root cause of each issue

- Session: a transient network failure in `_verifySession` discarded an
  otherwise valid secure token and cached identity by resetting to anonymous.
- Guest: Guest state was real and remembered, but account-owned screens and
  actions used inconsistent checks; the prompt omitted Create Account and the
  registration flow lost its return route.
- Waste: the established UUID/offline workflow was sound, but evidence was a
  legacy photo URL list, categories diverged in Flutter, severity/readable
  geolocation were incomplete, and LGU operations lacked a focused map entry.
- Emergency: the public controller correctly required verification, while the
  initial seeder deliberately marked every candidate unverified. The result
  was a truthful but empty public directory.
- Carbon: the calculator was manual-only, kept factors in a Dart enum, did not
  use the existing OSRM/map/itinerary data, and had no server-owned history.

## 3. Exact changes made for Issue 1

- Added controlled offline authenticated state with `isOfflineSession`, last
  server verification time, and cached profile version.
- Startup now distinguishes authenticated, Guest, and unknown modes. A token
  plus a previously verified local identity remains usable for read-only UI
  when connectivity is unavailable.
- A 401/revoked token clears the secure session and private account cache;
  transient network/server failures do not masquerade as revocation.
- Reconnect validates `/auth/me`, refreshes the authoritative role/profile,
  clears stale identity/role cache, and only then flushes safe Tourist work.
- Added one global non-modal offline/back-online banner and a write interceptor
  that blocks unqueued mutations while the device has no network interface.

## 4. Exact changes made for Issue 2

- Retained explicit tokenless Guest state and local Guest-mode remembrance;
  no Guest user is created in MySQL.
- Profile, notifications, role applications, private waste history,
  reservations, and account itinerary screens now require a real account.
- Standardized the protected-action dialog: Sign In, Create Account, and
  Continue Browsing.
- Added safe internal `returnTo` validation and preserved it through login,
  registration, email verification, and Google registration completion.
- Public Home/Explore, verified MSMEs, public map, ferry, emergency, eco tips,
  public announcements, directions, and Carbon Estimator remain accessible.

## 5. Exact changes made for Issue 3

- Added backend-driven waste categories and four controlled severity levels.
- Rebuilt the Tourist form into location, incident, and evidence sections with
  camera/gallery support for up to three photos and one short video.
- Added current GPS, map adjustment, reverse-geocoded address, barangay where
  returned, coordinate fallback, and existing Tubigon server validation.
- Added private evidence records, public-safe history/resolution fields,
  reopen support, resolution photo upload, filtering/pagination, dedicated LGU
  Waste Map navigation, and richer Tourist/LGU detail screens.
- Preserved the native UUID queue and made direct and sync paths idempotent.

## 6. Exact changes made for Issue 4

- Added explicit `is_public`, `verification_status`, `source_name`, and private
  notes semantics to the existing audited directory.
- Published only two records currently supported by sufficiently direct
  official references; four conflicting/older local contacts remain visible
  only to authorized staff as `needs_reverification`.
- Added category filters, confirmed-call dialog, alternate call, View on Map,
  Navigate, source/freshness labels, and timestamped offline-copy messaging.
- Enhanced LGU management with controlled categories, public/private state,
  exact source fields, map picker, lifecycle filters, verify/reverify,
  activate/deactivate, and recoverable archive operations.
- Public responses now use an explicit safe-field allowlist.

## 7. Exact changes made for Issue 5

- Added a versioned Laravel emission-factor catalog and server-calculated,
  owner-scoped estimate history.
- Added cached/bundled factor delivery, manual distance, map From/To selection,
  current location, OSRM road distance, exact matching saved-route fallback,
  one-way/round-trip, traveler totals, per-traveler values, comparisons,
  practical lower-impact suggestions, rating, and methodology.
- Ferry never uses OSRM. It accepts a clearly labeled manual/configured sea
  distance only.
- Itinerary route handoff includes total and individual road legs; a transport
  mode can be chosen for each leg and Laravel persists a leg breakdown.
- Authenticated Tourists receive saved history; Guests and offline sessions
  calculate locally without creating server history.

## 8. Database migrations

The additive migration is
`backend/database/migrations/2026_09_06_000003_connect_environmental_safety_and_carbon.php`.
It is guarded with schema checks, backfills compatible legacy data, and has a
targeted rollback. The prior additive sustainability and identity migrations
remain intact. A complete clean SQLite migration rehearsal successfully ran
all migrations through `2026_09_06_000003`; no production-like database was
used for that rehearsal.

## 9. Schema changes

- New `waste_categories` and `waste_report_media` tables.
- Added waste category ID, severity, resolved address, geocoding source,
  unique client submission ID, submitted/resolved/reopened metadata, and
  public-history flag.
- Added emergency public/verification/source/private-note fields.
- New `emission_factors` table with mode/version uniqueness, source, unit,
  assumptions, active/effective dates, and indexes.
- New `carbon_estimates` table with owner, factor, route source/timestamp,
  travelers, result snapshots, itinerary association, and JSON leg breakdown.

## 10. New/changed models

Laravel adds `WasteCategory`, `WasteReportMedia`, `EmissionFactor`, and
`CarbonEstimate`, and extends `WasteReport`, `WasteReportHistory`, and
`EmergencyContact`. Flutter extends `EmergencyContact` and waste records and
adds `CarbonFactor`/catalog representations. Casts cover booleans, timestamps,
numeric factors/results, JSON media/history, and JSON leg breakdowns.

## 11. New/changed relationships

`WasteReport` now belongs to its category and has many authorized media rows;
media belongs to a report/uploader. `CarbonEstimate` belongs to its factor.
Existing report owner/history actors and emergency updater/verifier relations
remain management-only. No duplicate Tourist Spot or MSME relationship was
introduced.

## 12. New/changed policies

No redundant Laravel Policy classes were added. The established Sanctum plus
role-middleware architecture remains authoritative. Controllers add explicit
report-participant checks, owner-only carbon queries, owned-itinerary checks,
LGU/Admin management checks, Tourist-only sync, and public allowlists. Flutter
visibility is UX only and is never treated as authorization.

## 13. New/changed FormRequests

The codebase uses controller validation rather than dedicated FormRequest
classes for these existing endpoints, so no parallel validation layer was
created. Controller rules now enforce category existence/activity, severity,
Tubigon coordinates, MIME/extension/size/count, status transitions, source
requirements, verification lifecycle, factor activity/unit, distance source,
travelers, trip type, itinerary ownership, and leg limits.

## 14. New/changed services/actions

The existing coordinate validator, sync service, route cache, directions
service, secure/local storage, and private-session cleanup were extended and
reused. Transactional controller actions coordinate report creation/history/
notification, status/history/notification, and emergency mutation/audit.
Carbon calculation is authoritative in `CarbonController`; Flutter retains a
local estimator for Guest/offline presentation using the same versioned unit.

## 15. API routes

Added public `GET /api/v1/waste-categories` and
`GET /api/v1/carbon/factors`; authenticated participant media upload/download;
Tourist `GET|POST /api/v1/carbon/estimates`; LGU/Admin resolution media; and
LGU/Admin emergency verification-status endpoints. Existing waste CRUD/status,
emergency management, map feed, auth, and sync routes were extended instead of
duplicated. `php artisan route:list` resolves the complete 241-route API.

## 16. API response changes

Waste responses now include a stable display reference, category definition,
severity, readable address, media metadata/authorized URLs, public history,
resolution summary, and sync replay metadata. Manager responses retain the
operational view; owner responses remove internal notes and legacy private
evidence, including internal notes nested in history metadata. Emergency
public responses expose only the safe allowlist. Carbon responses include
factor source/version/unit, totals, per-traveler result, distance source, and
leg snapshots.

## 17. Flutter repositories

`WasteReportRepository` now caches category definitions, creates one client
UUID, uploads multipart media, preserves native local paths until successful
sync, and parses history/media/resolution data. `EmergencyRepository` replaces
the public cache on refresh and records cache time. New `CarbonRepository`
loads authoritative factors, falls back to last-known/bundled configuration,
caches owner history, and saves only through the authenticated API.
`LguRepository` adds filtered report paging, authenticated media bytes,
resolution upload, richer status payloads, and emergency lifecycle actions.

## 18. Flutter Riverpod providers/notifiers

`AuthNotifier` carries controlled offline metadata and revalidation.
`reconnectSyncCoordinatorProvider` gates sync behind identity validation.
Waste category/list providers, existing LGU providers, public emergency
provider, map/filter providers, and new carbon catalog provider are invalidated
at their owning feature boundaries. No global data-refresh storm was added.

## 19. Flutter screens/widgets

Changed screens include onboarding/auth return handling, protected Profile/
applications/itinerary/waste history, the multi-section Waste Report form,
Tourist waste cards/timeline, LGU waste list/detail, LGU Waste Map entry,
public/LGU Emergency Contacts, itinerary detail, and Carbon Estimator. The
existing navy/slate/amber theme, rounded cards, responsive wrapping, loading,
empty, error, and disabled states are retained. Raw Dio errors and raw UUIDs
are not used as primary user labels.

## 20. GoRouter changes

Router redirects continue to derive role homes from authenticated state.
Protected return routes reject external URLs and privileged prefixes. Register
and email verification now retain the safe Tourist destination. Added
`/lgu/waste-map`, carbon distance/source/itinerary/leg query handoff, and kept
emergency/waste deep links within the existing Map page.

## 21. Offline cache changes

Native SQLite is upgraded to version 11 with waste category/severity/address/
video/media/resolution fields and emergency public/verification/source fields.
Web uses SharedPreferences-compatible JSON caches for public emergency and
carbon factors/history. Private map cache scoping remains identity/role aware.
Time-sensitive emergency and factor copies display their cache timestamp;
waste cards retain last sync/update time.

## 22. Session persistence implementation

Native auth tokens remain in secure storage; passwords are never stored.
Minimal local metadata records the last user, role, successful verification,
mode, and profile version. Cached role controls offline presentation only.
Online `/auth/me` is authoritative. Logout revokes when reachable, removes the
token/session metadata, clears prior-user private data/queued work, and retains
only safe public discovery caches.

## 23. Guest mode implementation

Guest is a local state with no token, user ID, or database record. It is
remembered across launch unless a real stored authenticated session takes
priority. Public reads and cached public content work; protected taps receive
the professional auth prompt and safe return flow. Guest server favorites,
reservations, waste reports, notifications, role applications, private
itineraries, and carbon history remain prohibited. Guest favorites/itinerary
migration was not added because safe cross-device merge semantics were not
already present.

## 24. Waste media storage implementation

The API accepts at most three JPEG/PNG/WebP photos (5 MB each), one MP4/MOV/
WebM video (25 MB), and up to three resolution photos. Laravel validates both
MIME and extension, generates stored names, writes to the private `local` disk,
and returns an authenticated API URL rather than a filesystem path. Download
checks owner or LGU/Admin participation and replies with the recorded content
type plus `private, no-store`. Local media paths are cleared only after upload.

## 25. Reverse-geocoding implementation

The Tourist form uses Geolocator for coordinates, the existing map picker for
pin adjustment, and the Flutter `geocoding` package for readable place data.
It persists coordinates, resolved address, optional barangay/sub-locality, and
`device_geocoding` source. If name lookup fails, the valid coordinates remain
usable and the UI says that the name is unavailable. Laravel independently
enforces the established Tubigon jurisdiction rule.

## 26. Waste workflow/status transitions

Allowed flow is `submitted -> under_review -> assigned|in_progress ->
in_progress -> resolved -> closed|reopened -> under_review`, with controlled
rejection from pre-resolution review states. Assignment requires a staff/team.
Resolve/reject requires a public note. Resolve stores summary, actor, and time;
reopen clears resolution actor/time and records reopen time. Every accepted
transition appends history; arbitrary statuses are rejected.

## 27. Dedicated Waste Map implementation

LGU Waste Management now links to `/lgu/waste-map`, which opens the existing
MapLibre implementation with `waste-reports` selected by default and restores
the prior map filter on exit. Markers use exact report coordinates and link to
LGU detail. The report list adds status, category, severity, barangay/search,
date, and assignment filters and consumes every server page. Tourism markers
are not mixed into this operational view by default.

## 28. Emergency real-data records and sources

The idempotent seeder is part of `DatabaseSeeder`. Public records are:

- Tubigon Rural Health Unit: `0946-713-8362` / `0917-894-5676`, Potohan,
  sourced from the PhilHealth accredited TB-DOTS provider list dated
  2025-12-31.
- Philippine National Emergency Hotline: `911`, sourced from the official
  e-government emergency hotline directory.

Police, Fire, Coast Guard, and Tubigon Community Hospital candidates are kept
as `needs_reverification` because their available official references are
older, indirect, or conflicting. No coordinates were invented. Exact source
URLs are stored in the seeder and management records.

## 29. Emergency verification system

Lifecycle values are `draft`, `verified`, `needs_reverification`, and
`inactive`. Only verified + active + public rows reach Guest/Tourist. Verify
requires an exact source name/reference and URL, records verifier/freshness,
and writes audit history. Sensitive edits automatically revoke verification.
Deactivation revokes verification; reactivation requires reverification.
Archive is soft-delete and audited.

## 30. Emergency Map integration

Verified/public contacts with valid coordinates join the existing Emergency
map category. A directory card targets `/map?marker=emergency:{uuid}` and can
request navigation; the Map page selects the marker and retains call/navigation
actions. Contacts without verified coordinates keep Call but disable View on
Map/Navigate. The two currently published seed records intentionally have no
invented coordinates, so LGU must verify a pin before their map marker appears.

## 31. Carbon factor sources

Eight factor records (walking, bicycle, motorcycle, tricycle, private car,
van, bus, and foot-passenger ferry) use version `2026.1`, unit
`kg_co2e_per_passenger_km`, source year 2026, and the UK Government 2026 GHG
conversion-factor publication URL. Values are explicitly rounded planning
adaptations. Tricycle is explicitly labeled a transparent local proxy pending
a verified Tubigon fleet study. The app never calls the result exact.

## 32. Carbon calculation formula

For one mode: `distance_km × kg_CO2e_per_passenger_km × travelers × trip
multiplier`. The multiplier is 1 for one-way and 2 for round-trip. Per traveler
is group total divided by travelers. Multileg estimates calculate every leg
with its own factor and sum the results. Laravel recalculates submitted values;
it never trusts a Flutter-computed result. Low/Moderate/High is a simple UI
planning band based on per-traveler output, not certification.

## 33. Route calculation behavior

From supports current position or eligible public map places; To uses eligible
public Tourist Spot, MSME, listing, or managed place coordinates. Road routes
use the existing OSRM service and store/display distance source and calculation
time. Successful routes are cached under the exact origin/destination key.
Offline reuse additionally checks the cached origin coordinate; otherwise the
app requires a manual distance rather than silently using an unrelated route.

## 34. Ferry/sea route handling

Ferry selection disables road-route mode. Its distance must be manually
entered from a published/configured sea-route source and is labeled
`configured_ferry`; the server rejects a ferry factor paired with `osrm`.
OSRM-derived itinerary legs exclude ferry choices. No haversine line was
presented as sailing distance and no sea route was fabricated.

## 35. Itinerary integration

After an itinerary route is calculated, `Estimate carbon` passes its owned
itinerary ID, route total, source, and individual leg distances. Carbon UI
shows a mode picker per road leg and a leg result breakdown. The server checks
itinerary ownership and persists factor snapshots for each leg. A true mixed
road/ferry itinerary still requires a separately verified/manual ferry segment
because the current itinerary router is OSRM-road based.

## 36. Activity-log connections

Tourist waste submission logs one meaningful activity, including the offline
sync path. Every LGU review/assignment/progress/resolution/reopen action uses
the existing activity mechanism, and emergency create/update/verify/status/
archive writes the dedicated audit table. Routine carbon calculations, map
movement, and connectivity changes are deliberately not logged. Carbon saved
history itself is the audit record for that optional user action.

## 37. Notifications

Waste submission creates LGU/Admin in-app notifications. Significant status
changes create an owner-scoped in-app notification with report ID, status, and
route. Resolution/rejection text is available through the public-safe report
history/summary. No directory CRUD broadcast, carbon email, or connectivity
notification was added; this avoids duplicate or noisy messaging.

## 38. Security protections

Sanctum actor identity overrides client identity. Role middleware protects
portals and mutation routes. Waste owner/media IDOR, carbon history ownership,
itinerary ownership, and emergency management authorization are tested.
Uploaded files are bounded and private. Public emergency and map queries use
server filtering; public emergency fields are allowlisted. Internal waste
notes are stripped at the report and nested-history levels. Tokens, passwords,
secrets, private storage paths, and reporter contact data are not exposed.

## 39. Offline behavior per role

- Guest: cached public discovery/emergency/ferry/eco/map plus manual/cached
  carbon; no private mutations.
- Tourist: the same plus cached own content/profile/itinerary and the only
  queued mutation in this scope—UUID waste submission with media.
- MSME Owner and Partner: safe cached reads only; authoritative edits,
  publishing, booking changes, and reservation decisions are online-only.
- LGU and Admin: optional cached/reference reads; approvals, verification,
  status, publication, settings, identity, and security writes are blocked
  offline and are never queued.

## 40. API/environment fixes for local/mobile/production

Flutter preserves platform defaults: local web `http://localhost:8000`, Android
emulator `http://10.0.2.2:8000`, and loopback for other local native use. Any
target can be overridden with `API_BASE_URL`; platform-specific web/Android/iOS
defines remain supported. Hosted production therefore does not compile in a
localhost requirement when the deployment define is supplied. Laravel CORS is
now `CORS_ALLOWED_ORIGINS` driven; ephemeral localhost patterns exist only in
local environment. Production must use matching HTTPS origins to avoid mixed
content.

## 41. Tests actually run

- `php artisan test`
- Focused `CarbonEstimateFlowTest`, `EmergencyContactManagementTest`,
  `WasteReportFlowTest`, and sustainability suites during iteration
- `DB_CONNECTION=sqlite DB_DATABASE=:memory: php artisan migrate:fresh --force`
- `flutter test --no-pub`
- `flutter analyze --no-pub` repeatedly after integration
- PHP syntax scan across app/config/database/routes/tests
- `git diff --check`
- `flutter build web --release --no-pub`
- `flutter build apk --debug --no-pub`

## 42. Exact passing/failing test results

The final complete Laravel run was 131/131 tests passing with 1,347
assertions. The final connected-feature focused run was 13/13 passing with 119
assertions. The final complete Flutter run was 101 tests passing with one
intentional existing skip and zero failures. Two stale widget tests initially
failed because they opened newly protected pages as Guest; their fixtures were
corrected to represent a signed-in Tourist, then passed. No unresolved test
failure remains. A fresh in-memory migration plus full DatabaseSeeder run also
completed successfully.

## 43. Flutter analyze result

`flutter analyze --no-pub` completed after the final itinerary and emergency
changes with `No issues found`. Earlier style-only findings (missing braces,
one non-const widget, and an unused saving flag) were corrected.

## 44. Web build result

`flutter build web --release --no-pub` succeeded and generated `build/web`.
The compiler reported only its informational WebAssembly dry-run warning for
the current `flutter_secure_storage_web` dependency; the standard JavaScript
web release is successful.

## 45. Android build result if run

`flutter build apk --debug --no-pub` succeeded and generated
`build/app/outputs/flutter-apk/app-debug.apk` for ARM, ARM64, and x64 target
architectures.

## 46. Manual tests completed

No physical-device, real phone-dialer, camera/gallery, GPS, hosted-web, SMTP,
or live production API acceptance test was claimed. Automated widget/feature
tests, route inspection, complete migration rehearsal, static analysis, and
both platform builds were completed. The supplied manual acceptance scripts
still need execution on the intended local web, Android device/emulator, and
hosted HTTPS environment with real LGU accounts.

## 47. Known remaining limitations

- Four local emergency candidates require direct LGU confirmation before they
  may be public; the two published contacts need LGU-verified coordinates for
  Map actions.
- Carbon factors are planning adaptations, and tricycle is a proxy. They must
  be replaced when a verified Philippine/Tubigon passenger-km study exists.
- The itinerary router is road-only. Mixed ferry itineraries require an
  independently verified/manual sea leg; the UI will not infer one.
- Native waste media queueing relies on local files remaining available until
  upload. Web has no durable file-handle queue, so offline web submission is
  blocked rather than pretending the browser can safely retain uploads.
- A first-ever offline launch has no cache; cached routes work only after a
  matching successful online route. API-interface availability does not prove
  internet/server reachability, so online-only writes can still fail cleanly.
- Real device/browser call, permission, responsive, and deployment behavior
  remains an external acceptance responsibility.

## 48. Required external/manual configuration

1. Back up the production database, then run `php artisan migrate --force`.
2. Run the normal idempotent `DatabaseSeeder` or
   `php artisan db:seed --class=EmergencyContactSeeder --force`; review the
   four `needs_reverification` records in LGU Emergency Management.
3. Configure Laravel `APP_URL`, database, Sanctum/auth, mail/queue worker,
   filesystem permissions, and `CORS_ALLOWED_ORIGINS` with the exact hosted
   Flutter origin(s). Keep all secrets server-side.
4. Build hosted web with an HTTPS API, for example
   `--dart-define=API_BASE_URL=https://api.example.gov.ph`; configure a
   reachable LAN HTTPS/HTTP URL for a physical Android device. Do not use the
   emulator-only `10.0.2.2` address on a physical phone.
5. Confirm Android/iOS location, camera, gallery, network, and phone-link
   permissions and server upload/body limits are at least the application
   limits.
6. Have authorized LGU staff directly verify emergency phone numbers,
   availability, exact pins, and factor governance dates, then execute every
   supplied manual acceptance checklist on local web, Android, and hosted web.
