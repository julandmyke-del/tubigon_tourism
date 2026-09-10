# Tour Tubigon Four-Feature Implementation Report

Date: 2026-09-08  
Scope: native offline maps, English/Filipino/Cebuano localization, Tourist Concerns & Support, and verified Tubigon plaza/church records.

## Acceptance status

The application code, schema, APIs, caches, localization, automated tests, web build, and Android build are complete and passing. A native Android smoke run created and validated a 17.6 MB MapLibre offline region for the Tubigon boundary and cached 25 published places. With all test servers and network access disabled, the app restored that package, entered explicit offline mode, and loaded the 25-place cache without a network/API request or crash.

One manual acceptance gate remains: this machine's headless Pixel_4 AVD cannot create the EGL configuration required by `MapLibreSurfaceView` under any available software/host GPU mode, so it displays a blank native platform-view surface even online. The downloaded basemap therefore still requires visual confirmation on a physical Android device (and iOS separately) before claiming that the final rendered-basemap criterion is satisfied. The app does not label the package usable until MapLibre reports it complete with nonzero resources.

## 1. Files changed

### Flutter

- `lib/main.dart` — enables the three supported locales and localization delegates.
- `lib/core/localization/app_localization.dart` — persisted locale controller, device-locale fallback, and Cebuano framework delegates.
- `lib/core/localization/en.dart`
- `lib/core/localization/fil.dart`
- `lib/core/localization/ceb.dart`
- `lib/features/offline_maps/offline_map_provider.dart` — native package lifecycle, validation, resume/restore, candidate promotion, measured storage, deletion, and cache refresh.
- `lib/features/offline_maps/offline_maps_page.dart` — truthful native/web states, progress, pause/resume, storage, deletion, and localized errors.
- `lib/features/userpage/presentation/pages/map_page.dart` — localized plaza/church filters, explicit offline behavior, cached routing fallback, and a direct-route package guard.
- `lib/features/userpage/presentation/pages/profile_page.dart` — persisted English/Filipino/Cebuano selector and localized feature entries.
- `lib/features/connected_operations/data/connected_operations_repository.dart` — concern result handling, typed failures, and device-local concern drafts.
- `lib/features/connected_operations/presentation/concerns_pages.dart` — localized Tourist/LGU/Admin concern screens, draft recovery, secure conversations, workflow updates, and friendly failures.

### Laravel

- `backend/app/Models/MapLocation.php` — provenance/address fields, casts, fillable fields, and public `coordinate_source` payload.
- `backend/app/Http/Controllers/Api/V1/MapLocationController.php` — provenance validation and trust reset when a coordinate source changes.

- `backend/app/Http/Controllers/Api/V1/ConcernController.php` — retains the existing secure ticket architecture and now also notifies the assigned/routed staff when a user replies and notifies verified Admin users when LGU escalates a ticket.

The existing concern requests, policy, models, notification model, and routes were retained because they already provided the required server-side architecture.

### Migrations

- `backend/database/migrations/2026_09_08_000001_add_map_location_provenance_and_verified_civic_places.php`

### Tests

- `backend/tests/Feature/VerifiedCivicPlacesTest.php`
- `backend/tests/Feature/ConcernSupportFlowTest.php`
- `test/localization_test.dart`
- `test/offline_favorites_auth_test.dart`

## 2. Database changes

Migration `2026_09_08_000001_add_map_location_provenance_and_verified_civic_places` ran in batch 19.

Additive nullable fields on `map_locations`:

- `barangay` varchar(120)
- `municipality` varchar(120)
- `province` varchar(120)
- `coordinate_source_name` varchar(255)
- `coordinate_source_url` text
- `coordinate_source_id` varchar(120)
- `coordinate_source_license` varchar(120)
- `coordinate_verified_at` timestamp

No existing columns, rows, or indexes were removed. No new index was required for these display/provenance fields. The migration adds or reuses `plaza-park` and `church-place-of-worship` categories, then idempotently inserts or updates an exact seed-key, slug, or case-insensitive name match. Its rollback is intentionally non-destructive and retains managed civic content.

The existing concern schema in `2026_09_07_000004_connect_ferry_booking_gallery_support_and_broadcasts` was reused:

- `concern_categories`: unique slug, server-controlled assigned role, redirect guidance, active/sort fields.
- `concerns`: unique reference number, indexed owner/category/status/role/assignee/priority, related-record composite index, timestamps, soft delete, and foreign keys.
- `concern_messages`: indexed concern/sender/internal flag and foreign keys.
- `concern_attachments`: indexed concern/uploader, private storage metadata, size/MIME, and foreign keys.
- `concern_histories`: indexed concern/actor, transitions, notes, and public/internal visibility.

All migrations report `Ran`; the local MySQL database was not reset or reseeded.

## 3. New or updated API surface

No duplicate routes were introduced. Existing routes were connected to the updated UI/repository and retained their Sanctum/role middleware.

Public map data:

- `GET /api/v1/map/locations` — now includes locality fields and nullable coordinate provenance for published records.
- `GET /api/v1/map/locations/authenticated` — authenticated role-aware map feed.
- `GET /api/v1/place-categories` — includes the plaza and church categories.

LGU/Admin map management:

- `GET|POST /api/v1/{lgu|admin}/map-locations`
- `POST /api/v1/{lgu|admin}/map-locations/duplicates`
- `PUT|DELETE /api/v1/{lgu|admin}/map-locations/{id}`
- `PATCH /api/v1/{lgu|admin}/map-locations/{id}/{verify|publish|status}`

Concerns:

- `GET /api/v1/concern-categories`
- `GET|POST /api/v1/concerns`
- `GET /api/v1/concerns/{id}`
- `POST /api/v1/concerns/{id}/messages`
- `GET /api/v1/concern-attachments/{attachment}`
- `GET /api/v1/{lgu|admin}/concerns`
- `GET|PUT /api/v1/{lgu|admin}/concerns/{id}`
- `POST /api/v1/{lgu|admin}/concerns/{id}/messages`

## 4. Offline map implementation

### What is downloaded

On Android/iOS, the app requests a persistent MapLibre offline region using the configured OpenFreeMap Liberty style for the Tubigon bounding box:

- southwest: `9.884021, 123.881415`
- northeast: `10.072237, 124.029692`
- zoom range: 10 through 16
- style default: `https://tiles.openfreemap.org/styles/liberty`

MapLibre owns the downloaded style, vector/raster tiles, sprites, and glyph resources. The app also refreshes and persists public place/category data and best-effort emergency/ferry snapshots. An authenticated Tourist additionally refreshes cached itinerary details, reservation summaries, and favorites through their existing user-scoped caches.

OpenFreeMap documents MapLibre Native mobile usage and attribution requirements: <https://openfreemap.org/quick_start/> and <https://openfreemap.org/>. MapLibre's offline-region API is the package-supported native mechanism: <https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/>.

### Storage and integrity strategy

- Map resources live in MapLibre Native's platform-managed offline database/cache.
- Package metadata lives under `tubigon_offline_package_metadata_v1` in the existing local storage service.
- Public map records/categories use the existing role-aware app cache; private snapshots remain user scoped.
- A new download is a candidate region. The previous verified region remains usable until the candidate reports complete, has a positive resource count, and has positive byte size.
- Only then is the candidate promoted and the old region deleted.
- Interrupted or invalid candidates are removed; their bytes no longer replace the retained package's measured size.
- Restore rechecks MapLibre's real region status. A manually entered `/map?offline=true` route is also blocked unless both data and a verified basemap are ready.
- Deletion removes current/pending regions, clears ambient/public map caches, and does not delete server-side Favorites, Itineraries, or Reservations.

### Native versus web

- Android/iOS: genuine persistent MapLibre regions, validation, pause/resume, restart recovery, update, and delete.
- Web: data snapshot only. The UI explicitly says that a full browser basemap package is unavailable and never offers “Open Offline Map.” MapLibre's cross-platform documentation also identifies web/offline differences: <https://maplibre.org/flutter-maplibre-gl/advanced/>.

### Available offline

- Cached public markers, localized categories/filters, local search, details already in the map snapshot, GPS/current-position controls, and straight-line distance.
- Cached exact route results can be reused where the existing route cache has a match.
- Cached emergency/ferry/trip summaries when previously synchronized.

Still online-only:

- Creating a new OSRM road route when no exact cached route exists.
- Fresh API synchronization, new reservations/server mutations, and uncached remote images.
- Concern submission/replies; an offline concern is saved as a local draft instead.

### Native smoke result

- MapLibre region validation: `Ready`, 17.6 MB, nonzero completed resources.
- Public data snapshot: 25 places, 27.9 KB.
- Interrupted downloads: remained `Data only`, displayed a localized retry error, and did not expose the Open button.
- Network-disabled reopen: restored explicit offline mode and the 25-place cache without crash or API access.
- Visual basemap/marker proof: blocked by the headless AVD's `MapLibreSurfaceView` EGL configuration failure; physical-device verification is mandatory.

## 5. Localization

The existing map-based localization architecture was extended rather than replaced with ARB files.

- Runtime key coverage: 286 keys available in English, Filipino, and Cebuano.
- English: 286 authored entries.
- Filipino: 237 authored translations; 49 legacy keys safely inherit English.
- Cebuano: 259 authored translations; 27 legacy keys safely inherit English.
- Every key in the English catalog exists at runtime in all three locales; missing keys never surface as raw identifiers.
- The new/high-priority journeys—Offline Maps, language selection, Tourist/LGU/Admin concerns, concern errors/statuses/categories, and plaza/church map categories—have authored wording in all three languages.
- Language selection persists as `preferred_locale`; `fil`/`tl` devices default to Filipino, `ceb` defaults to Cebuano, and other devices default to English.
- Proper names and dynamic database content remain in their stored language (currently primarily English), as intended. Some unrelated legacy UI strings also continue to use the English fallback and should be translated in a later full-app localization pass.

## 6. Concerns and support

### Tourist flow

An authenticated Tourist opens Concerns & Support, views active/resolved tickets, creates a concern with category, subject, description, priority, optional owned/public related record, and optional JPEG/PNG/WebP image up to 5 MB, then receives the server-created ticket/reference and can continue the conversation. Offline submission and explicit Save Draft persist the form locally. Attachment bytes are not silently persisted; the filename is retained with a reattach prompt.

### Routing, LGU, and Admin

Routing is decided by `concern_categories.assigned_role`, never by a client-provided role. LGU lists only LGU-routed tickets; Admin can see Admin-routed/escalated tickets. Staff can assign, reply, add internal notes, update workflow status, and LGU can escalate to Admin. Technical/Admin categories therefore reach Admin while tourism/ferry/local-service categories follow their configured LGU routing.

Statuses enforce server-side transitions across `submitted`, `under_review`, `assigned`, `in_progress`, `needs_more_information`, `resolved`, `closed`, and `reopened`.

### Security and auditability

- Sanctum protects all ticket, message, management, and attachment operations.
- `ConcernPolicy` prevents Tourist IDOR; a Tourist can view/reply only to their own ticket.
- LGU visibility is restricted to records whose `assigned_role` is `lgu_staff`; Admin has supervisory access.
- Related reservations, waste reports, and role applications are ownership checked.
- Internal messages and non-public history are filtered from Tourist payloads.
- Attachments use private local-disk storage and an authorized download controller with `X-Content-Type-Options: nosniff`.
- Creation and management use database transactions, row locking where needed, histories, and activity logs.
- New concerns notify verified users in the routed role; public staff replies and status changes notify the ticket owner. Internal notes do not notify or leak to the Tourist.
- Tourist replies notify the assigned staff member, falling back to verified users in the server-routed role when the ticket is unassigned. LGU escalation notifies verified Admin users without cloning or changing the reference number.

## 7. Verified plaza/church data

All coordinates are feature centroids from OpenStreetMap and carry `OpenStreetMap contributors`, source object ID/URL, `ODbL 1.0`, and verification timestamp in the database. They are strong map-marker positions, not cadastral surveys or certified entrance GPS points.

| Place | Category | Latitude | Longitude | Sources | Confidence |
|---|---|---:|---:|---|---|
| Tubigon Town Plaza | Plazas & Parks | 9.9512209 | 123.9620116 | [OSM way 143346516](https://www.openstreetmap.org/way/143346516), [Pacer/OSM listing](https://www.mypacer.com/parks/290122/tubigon-town-plaza-tubigon), [Waze listing](https://www.waze.com/live-map/directions/ph/central-visayas/tubigon/tubigon-public-plaza?to=place.ChIJ6Xm6RHAvqjMRbw6qVTOWuzU) | High for the plaza feature centroid |
| Saint Isidore the Farmer Parish Church | Churches & Places of Worship | 9.9502983 | 123.9629650 | [OSM way 943081282](https://www.openstreetmap.org/way/943081282), [Bohol parish assignment list](https://tubagbohol.mikeligalig.com/pages/mga-bag-ong-assignment-sa-mga-pari-sa-bohol/) | High for the mapped church building centroid |
| Saint John of the Cross Parish Church | Churches & Places of Worship | 9.9208119 | 123.9308790 | [OSM way 661954412](https://www.openstreetmap.org/way/661954412), [Mapcarta/OSM reference](https://mapcarta.com/W661954412), [Bohol parish assignment list](https://tubagbohol.mikeligalig.com/pages/mga-bag-ong-assignment-sa-mga-pari-sa-bohol/) | High for the mapped church building centroid |

Holy Cross Parish in Cawayanan is a real parish ([ParishPH reference](https://www.parishph.com/2022/07/holy-cross-parish-cawayanan-tubigon.html)), but no defensible exact coordinate source was found. It was deliberately not inserted rather than inventing a pin.

The three added records are verified, published, active, exposed by the public map API, styled by the localized filters, usable by details/navigation UI, and included in the public offline marker snapshot.

## 8. Tests and builds run

- `vendor/bin/pint ...`: passed.
- `php artisan migrate --force`: migration completed successfully.
- `php artisan migrate:status`: all migrations `Ran`; new migration is batch 19.
- `php artisan test`: **141 passed**, **1,480 assertions**, 18.01 s on the final full rerun.
- `backend/tests/Feature/ConcernSupportFlowTest.php`: **2 passed**, **37 assertions**; explicitly covers attachment MIME validation/private download authorization, submission notifications, staff/user replies, internal-note notification suppression, invalid transitions, escalation notification, stable reference, and post-escalation role access.
- `flutter analyze`: **No issues found**, final rerun 52.8 s.
- `flutter test`: exit 0; **118 passed, 1 skipped** in the full suite. The skip is the existing environment-dependent test.
- Focused offline/localization test run: **12 passed**.
- Earlier focused cross-feature run: **25 passed**.
- `flutter build web`: passed; final rerun compiled in 110.1 s. The existing Wasm compatibility warning from `flutter_secure_storage_web` remains non-fatal; the standard JavaScript build succeeded.
- `flutter build apk --debug`: passed; final rerun assembled in 12.5 s. `build/app/outputs/flutter-apk/app-debug.apk` is 229,908,949 bytes with SHA-256 `D89C157F6D3041F2C7880DA481E1C6E10F7CD1FB9D41EB7C5A5C1C6DD8921F06`.
- Native Android smoke: validated 17.6 MB MapLibre package and 25 cached places; offline route/cache restore passed; AVD visual render blocked by EGL as described above.

## 9. Known limitations

- A physical Android device must visually confirm the downloaded production OpenFreeMap basemap and marker rendering in airplane mode. This Windows AVD cannot create MapLibre's EGL surface, independent of online/offline state.
- iOS native download/render was not built or tested on this Windows host.
- Web intentionally supports data caching only, not a persistent full basemap package.
- New OSRM road routes require internet unless an exact route was cached previously; the UI says so instead of pretending routing works offline.
- Remote images are best-effort cache content and are excluded from measured package size.
- Dynamic CMS/database content and 49 Filipino/27 Cebuano legacy fallback keys remain English.
- The successful AVD download used a temporary localhost pass-through because the headless emulator NAT had no outbound internet. It served the same OpenFreeMap Liberty style, tiles, sprites, and glyphs; the proxy and smoke entry point were removed afterward. Production continues to use the official HTTPS style URL.
- The web build emits Flutter's Wasm dry-run warning because `flutter_secure_storage_web 9.2.4` still uses `dart:html`/`dart:js_util`. The normal JavaScript web build succeeds.
- OSM positions are community-maintained feature centroids, not LGU survey coordinates. Staff can correct them through the existing managed-map workflow; provenance changes reset trust for reverification.
- Concern drafts do not persist attachment bytes. Users must reattach the indicated image before submission.
- Pre-existing managed map records were preserved; they should receive the same provenance audit over time.

## 10. Manual acceptance test

### Setup

1. Back up the production database using the deployment's normal backup process.
2. In `backend`, run `php artisan migrate --force`.
3. Serve Laravel over a device-reachable HTTPS URL, or for a trusted development LAN run `php artisan serve --host=0.0.0.0 --port=8000` and build with `--dart-define=API_BASE_URL=http://<computer-lan-ip>:8000`.
4. Install the Android build on a physical device with at least 100 MB free. Grant location permission when testing GPS.

### Native offline package

1. Sign in as a Tourist, open **Profile → Offline Maps**.
2. Tap **Download Offline Map**, confirm, and keep the app foregrounded until status becomes **Ready**. Verify nonzero Places and Map resources.
3. Force-close the app, enable airplane mode, and make sure Wi-Fi/mobile data are both off.
4. Reopen the app, return to **Offline Maps**, and tap **Open Offline Map**.
5. Pan/zoom throughout Tubigon. Confirm roads/land/water labels render, the current-location control remains permission-aware, and cached markers appear.
6. Search for “Tubigon Town Plaza,” “Saint Isidore,” and “Saint John of the Cross.” Open each detail and exercise the plaza/church filters.
7. Tap Navigate for a destination with no saved route. Confirm the localized internet-required message; the app must not call OSRM successfully while offline.
8. Reconnect, choose Update, interrupt once, and verify the old valid package stays open. Resume/retry to Ready. Delete the package and confirm `/map?offline=true` is blocked afterward.

### Web behavior

1. Open Profile → Offline Maps in the built web app.
2. Save offline data and confirm the UI says **Data only** / full basemap unavailable.
3. Confirm there is no **Open Offline Map** button claiming browser basemap support.

### Languages

1. In Profile → Language, select English, Filipino, and Cebuano in turn.
2. Check Offline Maps, Concerns & Support, status/category wording, and plaza/church filter names after each selection.
3. Force-close/reopen the app after each language choice and confirm persistence with no raw localization keys.

### Concerns

1. As Tourist A, create a Ferry concern with subject, details, priority, related ferry record, and image. Confirm the real ticket/reference opens.
2. Turn network off, draft a Technical concern, close/reopen the form, and confirm fields restore plus the attachment reattach notice.
3. Reconnect and submit. Verify Ferry routes to LGU and Technical routes to Admin.
4. Sign in as LGU Staff. Open the Ferry ticket, assign it, move it through review/in-progress, send a public reply, then add an internal note.
5. Return as Tourist A: public reply/status must appear; internal note/history must not.
6. As LGU, escalate an appropriate ticket to Admin; confirm it leaves the LGU queue and appears for Admin.
7. As Tourist B, request Tourist A's ticket/attachment IDs directly. Confirm 403/404 and no data leak.
8. As Admin, reply/manage the Technical/escalated ticket and verify Tourist notification and valid status transitions.

### Civic places

1. Online, open Map and enable **Plazas & Parks** and **Churches & Places of Worship**.
2. Confirm the three tabled records appear at their documented coordinates, open details, and use online navigation.
3. Download/refresh the offline package, disable network, and repeat search/filter/detail checks from the cached map snapshot.
