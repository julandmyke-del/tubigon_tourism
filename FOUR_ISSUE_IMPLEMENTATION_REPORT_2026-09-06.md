# Tour Tubigon Four-Issue Implementation Report

Date: 2026-09-06  
Status: implemented and verified

The audit-first findings are recorded in `FOUR_ISSUE_COMPLETION_AUDIT_2026-09-06.md`. This report describes the completed implementation and production handoff.

## 1. Authoritative categories and role applications

- Added the `msme_categories` backend taxonomy. The migration preserves every currently accepted application category and imports distinct existing `msmes.category` values instead of discarding production labels.
- Added nullable `msmes.category_id`, backfilled by label, while retaining `msmes.category` for backward compatibility with current directory and reservation clients.
- Added requested, LGU-recommended, and Admin-final MSME category references to `role_applications`.
- Application options now return backend category records (`id`, `name`, `slug`). Flutter submits both the stable ID and compatibility label.
- MSME submission continues to create/update one pending authoritative MSME. LGU can record a different recommendation without overwriting the applicant's original choice. Admin selects/resolves the final category in the same locked approval transaction.
- A repeated approval is rejected and cannot duplicate the MSME, user/profile role update, or destination assignment.
- Tourism Partner applications still select an existing active Tourist Spot. Its authoritative `spot_categories` relationship is now visible in applicant and review UI; no duplicate public destination is created.
- Smart Map keeps its verified/public gates and now emits `source_category_id` and `source_category_slug` in addition to `category`, `category_label`, and `category_keys`.

## 2. Role-aware administrative activity logs

- Extended `activity_logs` with `actor_role`, `action_type`, `target_type`, `target_id`, and safe JSON `metadata`.
- New log entries snapshot the actor role when the action occurs. Role changes therefore do not rewrite historical responsibility.
- Existing text/JSON callers remain compatible. Target fields are normalized from existing `target_*`, `entity_*`, or `reservable_*` structures.
- Sensitive metadata keys containing password, secret, token, verification code, authorization, cookie, or ID-token data are excluded from structured metadata.
- `GET /api/v1/admin/activity-logs` remains Admin-only and now supports bounded pagination plus role, action type, start/end date, and free-text search. Results are newest first.
- Admin UI now includes server-driven filters, pagination, actor/role, action, target, details, timestamp, loading, retry, and empty states.
- Dashboard recent activity now shows actor, role snapshot, action, target, and time.
- Historical rows retain nullable snapshot/target fields because the system cannot truthfully reconstruct role-at-action-time from present-day roles.

## 3. Google authentication and Tour Tubigon branding

- Existing secure Google flow is preserved: server-side ID-token verification, verified-email requirement, disabled-account checks, no email-only auto-linking, no role/password/status rewrite for existing linked users, and normal Sanctum session creation.
- Existing official Google-rendered Web button and guarded native Google action remain in use; loading state prevents duplicate completion.
- Application-facing labels now use **Tour Tubigon** in Flutter title/localization/auth/onboarding/profile, Web title/metadata, Android app label, iOS display/bundle name, system-setting default, verification emails, and general email templates.
- Geographic and municipal-office wording remains unchanged where it identifies Tubigon, Bohol or the Tubigon Tourism Office.
- `AUTHENTICATION_SETUP.md` now documents the manual Google Cloud Console branding, verification, authorized-origin, Android signing, and iOS URL-scheme checks. No Google client secret is embedded in Flutter.

## 4. Professional private profile and preferences

- Added address and barangay to the stable profile record. Name, phone, bio, and language mirrors now update transactionally between `users` and `profiles` where applicable.
- Added one private `user_preferences` row per account with:
  - optional personalization enablement;
  - authoritative destination-category IDs and controlled travel interests;
  - pace, group type, transport, eco-tourism, and nearby choices;
  - explicit wheelchair, limited-walking, senior, child, and optional notes choices;
  - reservation, announcement, eco-tip, ferry, waste-report, and application notification controls;
  - location-recommendation and remembered-map-location privacy controls.
- Private preferences are returned and editable only by their owner. Admin may manage basic account data but cannot retrieve or change another user's preference payload.
- Relevant notification preferences suppress future in-app notifications in their selected category. Unclassified security/account-protection notices remain allowed.
- Flutter profile UI now has sectioned validation, controlled dropdown/chip choices, explicit privacy language, saving/error states, role-specific links to existing business/destination records, and validated avatar upload.
- No business/destination data is copied into preferences. No emergency-contact profile data was collected because the repository has no legitimate consumer for that sensitive data.

## Schema and new code

- Migration: `backend/database/migrations/2026_09_06_000002_complete_applications_activity_profiles.php`
- Models: `MsmeCategory`, `UserPreference`; extended `ActivityLog`, `Msme`, `Notification`, `PartnerNotification`, `Profile`, `RoleApplication`, and `User`.
- Regression tests: `backend/tests/Feature/FourIssueCompletionTest.php` and `test/four_issue_completion_test.dart`.

## Verification results

- Laravel Pint on touched PHP: passed.
- Laravel full suite: **127 passed, 1,306 assertions**.
- Flutter full suite: **99 passed, 1 intentionally skipped**.
- `flutter analyze`: **no issues found**.
- `flutter build web --release`: passed; artifact at `build/web`.
- `flutter build apk --debug`: passed; artifact at `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check`: passed.

Flutter reported dependency-upgrade notices and a WebAssembly dry-run advisory for the existing `flutter_secure_storage_web` implementation. These do not affect the completed standard JavaScript Web build. WASM was not claimed as a supported target.

## Production rollout

1. Back up the production database and uploaded storage.
2. Deploy backend and Flutter code from the same revision.
3. Run `php artisan migrate --force` from `backend`.
4. Run `php artisan optimize:clear`, then rebuild the production configuration cache as required by the deployment environment.
5. Confirm `php artisan storage:link` exists for avatar delivery.
6. Build Flutter with the production API URL and the public Google Web/server client IDs. Never pass a client secret to Flutter.
7. In Google Cloud Console, change the consent-screen app name/logo to **Tour Tubigon**, verify support/developer contacts and legal URLs, then complete any Google re-verification requirement.
8. Verify exact production Web origin, Android release package/SHA-1 or SHA-256 requirements, and iOS bundle ID/URL scheme.
9. Smoke-test: email login, Google login, application submission/review/approval, MSME verification/public map display, Admin log filtering, profile update/avatar, and each role portal.

## Rollback note

The migration's `down()` intentionally drops only `user_preferences`. Taxonomy, audit, category-link, and profile columns are retained to avoid destructive rollback of production data. Application-code rollback remains compatible because legacy category labels and activity details are preserved.
