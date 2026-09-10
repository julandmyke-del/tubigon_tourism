# Tour Tubigon completion audit

Audit date: 2026-09-06

## Runtime architecture

- Flutter is the active client under `lib/`, using Riverpod providers, GoRouter, Dio, SQLite on supported native targets, and SharedPreferences-compatible storage on web.
- Laravel under `backend/` is the authoritative REST application. Sanctum authenticates protected routes; role middleware separates Tourist, MSME Owner, Tourism Partner, LGU Staff, and Admin operations.
- MySQL is the production data design. Feature tests use isolated SQLite schemas. Migrations are additive and guarded because the project has evolved from an earlier schema.
- Public map data is delivered by Laravel and rendered with MapLibre/OpenFreeMap. OSRM supplies online route estimates; saved route results and downloaded MapLibre regions are limited offline aids, not an offline-routing claim.

## Authoritative domain records

| Domain | Authoritative table(s) | Main API/controller |
| --- | --- | --- |
| Identity and roles | `users`, `profiles`, `roles` | `AuthController`, `UserController` |
| Tourist destinations | `tourist_spots`, `spot_categories` | `TouristSpotController` |
| MSMEs | `msmes` | `MsmeController` |
| Partner content and assignments | `tourism_listings`, `tourist_spot_partner_assignments` | `TourismListingController`, `PartnerTouristSpotController` |
| Reservations | `reservations`, `reservation_status`, `reservation_status_history` | `ReservationController`, `PartnerReservationController` |
| Waste reporting | `waste_reports`, `waste_report_history`, `activity_logs`, `notifications` | `WasteReportController`, `LguController` |
| Ferry information | `ferry_schedules` | `FerryScheduleController` |
| Eco guidance | `eco_tips` | `EcoTipController` |
| Emergency directory | `emergency_contacts`, `emergency_contact_audits` | `EmergencyContactController` |
| Announcements | `announcements` | `AnnouncementController` |
| Itineraries | `itineraries`, `itinerary_items` | `ItineraryController` |
| Maps | `map_locations`, `map_location_categories` and public domain entities | `MapController`, `MapLocationController` |
| Role requests | role-application and review records introduced by guarded workflow migrations | `RoleApplicationController` |
| Analytics | aggregates over the tables above; no separate statistics table | `AnalyticsController`, `LguController`, scoped MSME/Partner controllers |

`establishments` remains a real public/admin domain, while verified `msmes` and approved `tourism_listings` are the active owner-managed business paths. These concepts must not be silently merged because their ownership and publication rules differ.

## Existing end-to-end behavior to preserve

- Registration, email OTP verification, login/logout, password reset, and Google-auth integration structure.
- Role-aware routing and middleware, owner-scoped MSME updates, partner assignment scoping, and public visibility filters.
- Tourist Spot reservations with date/guest/capacity/availability checks, controlled status transitions, history, in-app notifications, and transactional email delivery.
- MSME draft/submission/reverification workflow. Owners cannot choose verification state or edit another owner's business.
- Emergency create/edit/activate/verify/archive workflow with map coordinates, dialer confirmation, public verified-only filtering, and audit records.
- Itinerary save/edit/delete, authoritative-place validation, stop add/remove/reorder, map view, OSRM route estimates, and honest cached-route limitations.
- Offline caches for public spots, MSMEs, ferry schedules, eco tips, emergency contacts, map markers, and saved itineraries. Native offline map regions are separate from offline routing.
- Real LGU, MSME, and Partner aggregates. Existing dashboard numbers come from server queries rather than fabricated client constants.

## Broken or incomplete contracts found

1. The Tourist waste form always passes `localImagePath: null`. The repository would otherwise send a device path as an API URL, so photo evidence is not uploaded.
2. Waste submissions and status updates use general activity logs but have no dedicated, client-readable lifecycle history. The Tourist API exists for owned reports, but no reachable history screen consumes it.
3. Ferry records only contain `operator`, a combined `route`, string times, fare, status, and days. Origin, destination, vessel, date-specific service, advisory, and contact/reference information are absent. Validation accepts arbitrary time strings and incomplete status values.
4. Admin has basic ferry CRUD. LGU has neither ferry API routes nor a management screen despite ferry operations being an LGU responsibility.
5. Eco tips lack publication state, short message, active window, and priority. The public endpoint returns every record. Admin repository mutations exist but the current management view is read-only; LGU is explicitly blocked from managing tips.
6. No carbon-footprint feature, route, centralized calculator, or tests exist.
7. English and Cebuano string maps exist, but `MaterialApp` is fixed to English, widgets do not consume the maps, and Profile explicitly reports Cebuano as unavailable. Current bilingual support is therefore non-functional.
8. Admin's overview controller exposes only lifetime totals and recent activity. LGU/MSME/Partner analytics are substantially richer and real; Admin still needs role/status/time-series operational aggregates to meet the requested dashboard scope.
9. Ferry, eco, and emergency repositories use authoritative-network-first caches, but Tourist views do not consistently disclose that cached information may be stale.
10. Current itinerary is a capable manual planner, not algorithmic personalization. It must not be described as AI-generated.

## Security and migration boundary

- Keep all identity, ownership, role, assignment, verification, and publication decisions server-side.
- Add columns/tables through guarded additive migrations; do not rewrite or reseed authoritative records.
- Preserve existing route groups and add LGU operations only inside `role:lgu_staff,admin`.
- Use transactions for multi-record lifecycle changes and retain current status-transition checks.
- Public APIs must filter archived, inactive, unpublished, or out-of-window operational content.

## Implementation sequence selected

1. Add shared schema/model/API contracts for waste history, richer ferry data, and publishable eco tips.
2. Complete Tourist waste image upload and owned-report history.
3. Add professional Admin/LGU ferry management and improve Tourist schedule presentation/cache disclosure.
4. Add Admin/LGU eco-tip management and destination-aware public delivery.
5. Add the centralized, explicitly approximate carbon estimator and tests.
6. Activate persisted English/Cebuano locale selection and localize the newly completed critical flows; retain a documented coverage limitation where legacy screens still contain literals.
7. Extend real Admin aggregates, add backend/Flutter tests, then run full analysis, tests, and supported builds.

## Implementation outcome

- Waste reporting now submits validated multipart JPEG/PNG/WebP evidence, stores a barangay when supplied, retains native offline evidence until upload succeeds, exposes owner-scoped report history, and records each submitted/LGU status transition in `waste_report_history`.
- Ferry schedules now support origin, destination, vessel, service date, normalized time values, recurring days, operational status, advisory, contact/reference details, active state, and updater identity. Public delivery filters inactive and past dated service. LGU and Admin management routes are role protected; the LGU portal has a validated create/edit/archive form.
- Eco guidance now supports short messages, language, linked authoritative destinations, priority, active/published state, and publication windows. Public delivery excludes drafts, archived records, and out-of-window guidance. LGU and Admin management routes are role protected; the LGU portal has create/edit/publish/archive controls.
- Emergency contacts now carry barangay, availability notes, and public emergency instructions without weakening the existing verified-only public directory or audited LGU workflow.
- The new carbon estimator uses one centralized calculator, explicit input limits, passenger/trip multipliers, transparent approximate factors, and no fabricated live environmental measurements. The tricycle value is explicitly identified as a planning proxy.
- English/Cebuano locale selection is active and persisted. Core navigation and the newly completed Tourist sustainability flows consume app translations. Custom Cebuano framework delegates keep standard Material, Widgets, and Cupertino controls valid even though Flutter does not ship Cebuano framework strings.
- Admin analytics now includes real 30-day reservation/waste activity, reservation value, status distributions, partner and MSME-owner counts, verified MSMEs, published spots, active ferry services, access-application states, and most-reserved destinations.
- Public ferry, eco, and emergency screens disclose offline cached-data staleness. Native SQLite schema upgrades are additive; web eco data uses persistent local storage.

## Verification completed

- `flutter analyze`: no issues.
- `flutter test`: 96 passed, 1 intentionally skipped.
- `php artisan test`: 124 passed, 1,260 assertions.
- Focused waste evidence/history and sustainability operations tests pass, including IDOR protection, role authorization, time/status validation, active/public filtering, eco publication windows, and audit rows.
- `flutter build web --release`: passed; output is under `build/web`. The tool reports that the current secure-storage web dependency prevents optional WebAssembly compatibility, but the normal JavaScript web build is valid.
- `flutter build apk --debug`: passed; output is `build/app/outputs/flutter-apk/app-debug.apk`.
- `php artisan migrate --pretend --no-interaction`: passed against the configured MySQL connection and emitted the guarded additive SQL without applying it.
- Verified runtime versions: Flutter 3.44.8 / Dart 3.12.2 and Laravel Framework 12.64.0.

## Deployment and evidence boundaries

- The migration was intentionally previewed, not applied. Deployment must back up the target MySQL database, run the pending migrations (including the pre-existing email-delivery migration), ensure `storage:link` and writable public storage for evidence, and perform role-based smoke tests against deployed API/storage URLs.
- Ferry schedules, emergency numbers, eco guidance, tourist spots, and MSME records remain staff-managed operational data. Code completion does not certify the real-world accuracy of records entered by staff.
- Carbon results are decision-support estimates, not audited inventories or live measurements. Factors should be periodically reviewed; a verified Tubigon tricycle/ferry fleet study can replace the documented proxies later.
- Existing itinerary functionality remains a manually personalized planner with authoritative saved stops and OSRM route estimates; it is not described as AI-generated. True offline turn-by-turn routing is still outside the current architecture.
- The standard web build is supported. WebAssembly deployment would require replacing or upgrading the secure-storage web implementation reported by Flutter's WASM dry run.
