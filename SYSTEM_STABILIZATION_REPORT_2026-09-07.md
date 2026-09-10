# Tubigon System-Wide Diagnostic and Stabilization Report

Date: 2026-09-07 (Asia/Manila)

## 1. Flutter SDK actually used

`C:\Users\Admin\Documents\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat` was the active executable. Despite the parent folder name, the executable reports Flutter **3.44.8 stable**, framework revision `058e0af2c2`, engine revision `0cd610717b`. The SDK was not changed because the project analyzed, tested, and built successfully with its locked dependency graph.

## 2. Dart version

Dart **3.12.2**; DevTools **2.57.0**. The project constraint remains `>=3.4.0 <4.0.0`.

## 3. Laravel/PHP version

The installed backend is Laravel Framework **12.64.0** on PHP **8.2.12** with Composer **2.9.7**. This differs from the request's Laravel 11 description; no framework downgrade was attempted because the existing Laravel 12 application and its full suite are healthy.

## 4. Baseline analyzer/test/build results

- `flutter doctor -v`: all configured toolchains passed; Android SDK 36.1, Java 21, Chrome 152, and Windows desktop toolchain detected.
- `flutter analyze --no-pub`: 0 issues.
- Flutter tests: 110 passed, 1 skipped, 0 failed.
- Laravel tests: 137 passed, 1,428 assertions, 0 failed.
- `flutter build web --no-pub`: passed in 186.9 seconds; JavaScript web output created. The WASM dry run reported the existing `flutter_secure_storage_web` incompatibility.
- `flutter build apk --release --no-pub`: passed in 101.1 seconds; 100.2 MB APK created.

## 5. Exact Explore assertion stack-trace root cause

The first exception in the clean Guest browser reproduction was:

```text
A RenderViewport expected a child of type RenderSliver but received a child
of type RenderConstrainedBox.

The relevant error-causing widget was:
  AnnouncementPlacement
  .../tourist_dashboard_page.dart:185:11
```

The dashboard inserted `AnnouncementPlacement` directly into `CustomScrollView.slivers`. Its loading/data branches return box widgets (`SizedBox`/`Column`), not slivers. Subsequent route teardown produced the reported `_elements.contains(element)` and `_dependents.isEmpty` assertions, defunct-element notifications, and duplicate-key diagnostics.

Internal root-cause note:

| Field | Finding |
|---|---|
| Error | `RenderViewport` received `RenderConstrainedBox` instead of `RenderSliver` |
| Root trigger | Box-returning `AnnouncementPlacement` inserted directly into a sliver list |
| Affected widget | `TouristDashboardPage` / `AnnouncementPlacement` |
| Affected provider | `publicAnnouncementsProvider(guest)` selected the loading/data box branch; provider lifecycle was not the primary defect |
| Affected route | `/home`, exposed during Guest Home → Explore → Map route churn |
| Lifecycle phase | Render-object mount/layout, followed by damaged element deactivation during route replacement |
| Why assertion happens | The failed render-tree insertion left later inactive-element/dependency cleanup operating on an already inconsistent subtree |

## 6. First project file responsible

`lib/features/userpage/presentation/pages/tourist_dashboard_page.dart`, current line 185. The placement is now wrapped by `SliverToBoxAdapter`.

## 7. Why `_elements.contains(element)` failed

Flutter's inactive-element cleanup attempted to remove an element whose membership bookkeeping had already been disrupted by the earlier invalid sliver/box mount and subsequent route churn. It was a downstream framework assertion, not the first application error.

## 8. Why `_dependents.isEmpty` failed

An inherited element was deactivated while descendants from the damaged subtree still appeared in its dependency set. The malformed render/widget subtree was the earlier actionable failure; Riverpod's stable root `ProviderScope` was not conditionally removed.

## 9. Whether both came from the same root issue

Yes, in the captured reproduction. Before the fix the 20-round probe captured 23 lifecycle assertions. Immediately after only the sliver-boundary correction, the same real-browser route sequence completed with `CAPTURED_FAILURES=0` and `LIFECYCLE_FAILURES=0`. Later hardening retained that result.

## 10. All Flutter lifecycle fixes

- Corrected the dashboard's sliver/box boundary.
- Made router and auth-listenable ownership explicit at provider disposal.
- Prevented redirect callbacks from scheduling UI work with a context being replaced.
- Added mounted/disposed/single-flight controls to reconnect work.
- Reconciled timer/controller state when carousel and dynamic-form inputs change.

## 11. All Riverpod fixes

- Reconnect synchronization is single-flight and stops reading/invalidation after its owning provider is disposed.
- Auth `/me` verification is single-flight, preventing startup and reconnect from issuing overlapping profile restores.
- Explore now watches configured categories at the stable top level of `build`, rather than adding the dependency only inside a successful map-data callback.
- No providers were globally kept alive or converted to another state system.

## 12. All GoRouter fixes

- Authorization redirects remain authoritative and preserve role isolation.
- Removed `ScaffoldMessenger.of(context)` post-frame callbacks from `redirect`; the callback now makes redirect decisions without side effects on a context that may be deactivated.
- `GoRouter` and its `_AuthListenable` are disposed with `appRouterProvider`.

## 13. All GlobalKey fixes

No application-owned duplicate `GlobalKey` was found. Root, tourist shell, admin, partner, LGU, and MSME navigator keys are distinct. The duplicate-key warnings were downstream of the malformed tree and disappeared after the root fix, so no unnecessary key churn was introduced.

## 14. All controller/timer cleanup fixes

- Announcement auto-slide cancels for disposal, background/inactive lifecycle, zero/one slide, and disabled animations.
- Carousel pointer interaction pauses and safely restarts auto-slide.
- Feed shrink clamps the page index before restarting.
- Dynamic booking removes and disposes controllers for fields that no longer exist after an offering refresh.
- Existing Map, gallery, message, search, and form controller disposal was retained where already correct.

## 15. Explore-specific fixes

- Dashboard announcement content is now a valid sliver child.
- Explore category provider dependency is stable.
- Category chips, discovery tiles, and grid cards use stable entity/category keys based on type and ID rather than list index.

## 16. Map lifecycle fixes

No new Map production change was required. The Map defunct-element trace appeared only after the dashboard tree had already failed and disappeared with the sliver fix. The existing Map suite covers late GPS completion, pending OSRM cancellation, filtering, selection, and deep-link focus; all passed.

## 17. Carousel fixes

`AnnouncementPlacement` now observes app lifecycle, tracks current slide count, clamps stale indexes after refresh, restarts only when safe, and never animates without mounted clients.

## 18. Gallery fixes

Hero tags now include `spotId + mediaId`, and thumbnail/viewer children have stable compound keys. The viewer's page controller remains state-owned and disposed once.

## 19. Dynamic booking form fixes

Offerings and fields now have stable ID-based keys. When the backend replaces/removes offerings, invalid selections and quantities are removed and obsolete `TextEditingController` instances are disposed after the frame in which their widgets disappear.

## 20. Messaging screen fixes

No production fix was necessary. The reservation conversation has no polling timer or scroll controller leak in the audited implementation. Its text controller is state-owned and disposed; its rendering/visibility test passed.

## 21. Auth/bootstrap fixes

Session verification is single-flight, so startup restore and immediate reconnect coordination share one `/me` operation instead of racing state writes/router refreshes. Guest, authenticated, and role redirect behavior remains unchanged.

## 22. Offline/reconnect fixes

The app-wide reconnect coordinator now allows one active sync, records disposal, and checks ownership after awaited operations before reading or invalidating Riverpod providers. Existing sync order is preserved: validate session, flush authenticated work, refresh public/map data, then authenticated lists.

## 23. Dio/network fixes

No Dio production change was necessary. The browser probe saw expected Guest 401s only in the corrupted baseline run; the central API layer already maps failures and does not navigate from an interceptor. API base URLs remain configurable rather than hard-coded for every deployment target.

## 24. JSON/model fixes

No model change was necessary. Existing tests covered nullable/typed current response shapes. The MapLibre browser console's null-style warnings did not become Dart/Flutter errors in the clean final run.

## 25. Backend API fixes

No backend source fix was required in this pass. The full feature suite covering auth, Explore data, map, ferry, emergency, waste, carbon, offerings, reservations, messages, gallery, concerns, announcements, roles, and authorization passed.

## 26. Laravel log issues fixed

The latest recorded errors were historical `testing.ERROR` entries from 03:17–03:19 UTC involving incomplete SQLite test migrations/class duplication during prior development. No new error was written by the final 137-test run. Logs were retained as audit history rather than deleted.

## 27. Migration/schema fixes

Five pending migrations were inspected to confirm their `up()` paths were additive, then applied with `php artisan migrate --force` as batch 18. Final `migrate:status` reports every migration as `Ran`, including email deliveries, sustainability, profiles/activity, environmental/carbon, and ferry/booking/gallery/support/broadcast tables.

## 28. Queue/email issues fixed

`php artisan queue:failed` reports **No failed jobs found**. Backend tests verify queued notification/email behavior remains isolated from primary transactions. No queue or mail source change was needed.

## 29. Security impact review

No secrets, credentials, tokens, passwords, OTPs, database credentials, or customer message content were added to source or the report. Backend authorization, Sanctum enforcement, role redirects, Guest protected-action behavior, IDOR protections, and server-side pricing remain intact. Removing redirect snackbars did not remove the redirect/authorization decision.

## 30. Files changed

Files changed by this stabilization pass:

- `lib/features/userpage/presentation/pages/tourist_dashboard_page.dart`
- `lib/features/userpage/presentation/pages/tourist_spots_page.dart`
- `lib/features/connected_operations/presentation/announcement_placement.dart`
- `lib/features/connected_operations/presentation/public_spot_gallery.dart`
- `lib/features/connected_operations/presentation/dynamic_booking_page.dart`
- `lib/features/authentication/auth_provider.dart`
- `lib/core/routes/app_router.dart`
- `lib/core/services/reconnect_sync_coordinator.dart`
- `test/six_issue_connected_ui_test.dart`
- `diagnostics/explore_lifecycle_probe.js`
- `diagnostics/explore_lifecycle_probe.png`
- this report

The working tree already contained extensive user/previous-task changes; they were preserved.

## 31. Tests added

- 20-loop Home → Explore → Map → Explore → Home shell regression.
- Dashboard announcement placement is a valid sliver child.
- Dynamic booking safely reconciles replaced offering fields/controllers.
- Announcement carousel clamps its page when a three-item feed shrinks to one.
- Existing gallery test strengthened to open/close the full-screen viewer three times.
- Reusable real-Chrome Guest lifecycle probe retained under `diagnostics/`.

## 32. Tests actually run

- Baseline and final `flutter analyze --no-pub`.
- Baseline and final full `flutter test --no-pub`.
- Targeted `flutter test test/six_issue_connected_ui_test.dart --no-pub`.
- Baseline and final `php artisan test`.
- Real Chrome debug probe before and after the root fix.
- Baseline and final web/release-APK builds.
- `php artisan migrate:status`, migration execution, and `php artisan queue:failed`.

## 33. Exact pass/fail counts

- Final Flutter: **114 passed, 1 skipped, 0 failed**.
- Targeted Flutter: **13 passed, 0 failed**.
- Final Laravel: **137 passed, 1,428 assertions, 0 failed**.
- Browser lifecycle probe: **0 captured failures, 0 lifecycle failures** after 20 route rounds.

## 34. `flutter analyze` result

Final result: **No issues found** in 59.9 seconds.

## 35. `flutter build web` result

Final result: **passed** in 138.2 seconds; output at `build/web`. The non-blocking WASM dry-run warning for `flutter_secure_storage_web` remains; the standard JavaScript web build is valid.

## 36. Android build result

Final `flutter build apk --release --no-pub`: **passed** in 136.1 seconds. Output: `build/app/outputs/flutter-apk/app-release.apk` (100.2 MB). No physical-device/background-foreground acceptance run was performed.

## 37. Manual role acceptance results

This matrix separates genuinely manual/browser-tested behavior from automated coverage:

| Role | Manual status | Scope |
|---|---|---|
| Guest | PASS (partial) | Local Chrome: Home, Explore, real MapLibre route, announcements, browser route churn; 20 rounds with zero errors |
| Guest | NOT TESTED | Phone browser, hosted web, protected-action → login round trip, Ferry/Emergency/Carbon manual interaction |
| Tourist | NOT TESTED | No live Tourist credentials used; automated auth, booking, messages, gallery, waste, emergency, ferry, concerns, carbon, and announcement tests passed |
| MSME Owner | NOT TESTED | No live role session; automated portal/business/profile/authorization coverage passed |
| Tourism Partner | NOT TESTED | No live role session; automated assigned spot, offerings, reservations, customers, messages, gallery, actions, announcements coverage passed |
| LGU Staff | NOT TESTED | No live role session; automated ferry, waste, emergency, concerns, applications, announcements, analytics coverage passed |
| Admin | NOT TESTED | No live role session; automated users, activity, announcements, concerns, approvals, settings, and oversight coverage passed |

No role was marked `BLOCKED`; live-account/manual-device acceptance simply was not executed.

## 38. Remaining known issues

- WASM output is not currently supported by `flutter_secure_storage_web`; normal JavaScript web output passes.
- The SDK folder name says `3.41.7`, while the executable inside is Flutter 3.44.8. This is confusing but not a functional mismatch.
- Phone-browser, hosted-web, and physical-Android lifecycle acceptance remain outstanding.
- Laravel logs retain old testing failures for historical audit; current tests are green.

## 39. Items not fixed and exact reason

- Flutter SDK was not switched: no dependency or framework-version incompatibility was proven.
- Map provider cleanup was not rewritten: the suspect trace disappeared after the first malformed-tree fix, the real MapLibre stress pass is clean, and dedicated Map lifecycle tests pass.
- Dio, backend controllers, JSON models, reservation messaging, and queue code were not changed: no active failure remained after schema synchronization and their automated coverage passed.
- Existing unrelated dirty-worktree changes were not reverted or reformatted wholesale because they belong to prior user work.

## 40. Manual/environment configuration needed

- For a phone browser or physical Android device, provide a reachable backend URL using the project's API-base dart define/LAN configuration; `localhost` on a phone refers to the phone, while Android emulator uses `10.0.2.2`.
- Run a queue worker in deployments configured for database queues and keep Gmail SMTP values in deployment environment variables.
- Perform a final credentialed acceptance pass for Tourist, MSME Owner, Tourism Partner, LGU Staff, and Admin on the intended hosted/LAN environment.
- No database reset, reseed, secret rotation, SDK change, or architecture replacement is required for this fix.
