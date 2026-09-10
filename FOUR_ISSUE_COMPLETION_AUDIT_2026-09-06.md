# Tour Tubigon Four-Issue Completion Audit

Date: 2026-09-06  
Scope: role-application categories, administrative activity logs, Google/product branding, and user profiles/preferences.

## Executive finding

The repository already has a production-oriented authorization and role-application foundation. The MSME and Tourism Partner application workflows are owner-scoped; LGU and Admin transitions are role-protected; final approval uses database transactions and row locks; Tourism Partner requests point to an existing active Tourist Spot; and public map feeds already gate Tourist Spots and MSMEs by their public/verified state. The requested completion pass therefore extends existing records and APIs instead of creating parallel workflows.

The main gaps are: MSME categories are still a controller constant and a free-form database string; activity logs lack historical actor-role/target metadata and the Admin endpoint is unpaginated; product naming is inconsistent across Flutter/Web/native/email surfaces; and the profile editor has only basic identity fields with no private preference record.

## 1. Application categories and public discovery

### Working

- `role_applications` is the authoritative workflow record and preserves payload, status, timestamps, reviewers, notes, checklist, history, and the linked MSME or requested Tourist Spot.
- Applications are owner-scoped; review endpoints are restricted to LGU/Admin roles.
- MSME submission creates or updates one pending authoritative `msmes` record. Admin role approval is transactional and does not automatically publish it; independent MSME verification remains the public visibility gate.
- Tourism Partner applications reference an existing active `tourist_spots` row and final approval creates an assignment rather than duplicating the destination.
- Final approval uses a transaction, row locking, conflict checks, and closure of competing active applications.
- Smart Map emits both broad and specific category keys and excludes unpublished entities.

### Partial / risk

- MSME categories are defined by `RoleApplicationController::MSME_CATEGORIES`; `msmes.category` is a string. This is not an authoritative reusable backend taxonomy.
- The applicant selects a dropdown in the current Flutter flow, but its values originate from the hardcoded application-options response rather than category records.
- Review screens can read the category label from payload, but there are no separately preserved requested/recommended/final category fields.
- Smart Map derives MSME category slugs from the category string. Renaming or inconsistent labels can fragment filters.
- Tourist Spot categories are already authoritative in `spot_categories`; they should remain a separate taxonomy. A Tourism Partner request must display the selected spot's existing category and must not silently recategorize the destination.

### Completion design

- Add an additive `msme_categories` taxonomy populated from the currently accepted categories and existing distinct MSME values; add nullable `msmes.category_id` and backfill it while retaining the label column for compatibility.
- Add requested/recommended/final MSME category foreign keys to role applications. Preserve the applicant's request, record LGU recommendations in history metadata, and resolve the final category during Admin approval.
- Continue to derive Tourism Partner category from the referenced Tourist Spot and eagerly return its authoritative category.
- Emit stable category IDs/slugs/labels in public map payloads while retaining existing keys.

## 2. Administrative activity logs

### Working

- `activity_logs` is already used throughout authentication, moderation, role applications, reservations, settings, and content administration.
- The endpoint is within the Admin-only route group.
- Dashboard and full-log screens already exist.

### Broken / missing

- The table only stores actor profile ID, action, and a mixed text/JSON details field.
- Actor role at action time is not preserved. Reading the actor's current role later is historically incorrect after role changes.
- Action type, target type/ID, and safe structured metadata are not first-class fields.
- The Admin endpoint returns the full table without pagination or server-side role/action/date/search filters.
- The full-log UI only offers client-side search and omits actor role; the dashboard omits actor, role, and target.

### Completion design

- Add nullable, indexed actor-role, action-type, target-type, and target-ID columns plus JSON metadata.
- Enrich future logs at model creation time, taking a role snapshot and safely normalizing existing JSON details. Existing callers remain compatible.
- Implement bounded pagination and validated role/action/date/search filters, newest first.
- Update Admin repository/providers/pages for server-side filtering, pagination, role badges, target display, loading/empty/error states, and retry.
- Log profile updates without recording private field values. Never place tokens, passwords, verification codes, or raw OAuth assertions in logs.

## 3. Google authentication and product branding

### Working

- Google ID tokens are verified server-side and invalid, expired, unverified-email, and configuration failures are handled without exposing sensitive verifier details.
- Deleted accounts are rejected; existing password accounts are not auto-linked by email; an existing linked Google account is not allowed to rewrite password, role, status, or profile.
- New Google accounts are created as verified Tourists inside a transaction and receive the normal profile/settings dependencies.
- Flutter has web and native Google flows, loading guards, and backend session/token completion.

### Partial / operational dependency

- Product labels vary among `Tubigon Smart Tourism`, `Tubigon Tourism`, and the package-style `tubigon_tourism`.
- Google Cloud OAuth consent-screen branding is external state and cannot be changed safely from this repository.

### Completion design

- Use **Tour Tubigon** consistently where text identifies the application, including Flutter title/localization, auth/onboarding/profile copy, Web metadata, Android label, iOS display name, email views, and default system setting.
- Preserve geographic and government-office wording such as “Tubigon, Bohol” and “Tubigon Tourism Office.”
- Retain the official Google-rendered web button and recognizable native Google action, with disabled/loading behavior preventing duplicate submissions.
- Document exact Google Cloud Console consent-screen changes, authorized origins/redirect configuration checks, and verification requirements as a manual deployment step. No client secret is added to Flutter.

## 4. Professional private profile and preferences

### Working

- Authenticated users can view/update their own profile; Admin access is explicit.
- Avatar upload is type/size validated and user/profile mirrors are kept aligned.
- Authoritative business and destination relationships already exist and can be linked rather than copied into profile fields.

### Broken / missing

- The editor only exposes name, email, phone, and bio and has minimal validation.
- Address/barangay are absent from the profile record and phone/language mirrors can become stale between `users` and `profiles`.
- There is no private model for travel personalization, accessibility choices, granular notifications, or privacy controls.
- The current `settings` row only has global notification/location/offline/language values and is not sufficient for the requested granular controls.

### Completion design

- Add address and barangay to `profiles`, and update mirrored identity fields transactionally.
- Add a one-to-one private `user_preferences` record keyed to the user. Store controlled JSON category IDs/interests and bounded enum-like strings, explicit accessibility choices, granular notification choices, and privacy toggles.
- Preferences are returned and editable only by the account owner. They are never attached to public MSME/Tourist Spot serialization.
- Omit emergency-contact data because no legitimate emergency workflow in this repository consumes it; collecting unused sensitive data would be contrary to data minimization.
- Show role-specific links from existing MSME/destination relations and keep security/account actions linked to existing auth routes.

## Compatibility and migration policy

- All schema changes are additive and guarded for imported production-like databases.
- Existing human-readable category and activity fields are retained so current clients and historical rows continue to render.
- No duplicate user, profile, MSME, Tourist Spot, application, or assignment records are introduced.
- Historical activity rows cannot reliably reconstruct actor role at event time; they remain nullable and the UI labels them as unavailable rather than inventing data.

## Verification targets

- Laravel feature tests: authoritative categories, applicant/LGU/Admin category preservation, idempotent approval, public-map visibility, Admin-only log filtering/pagination, role snapshots, profile ownership/privacy/validation, and Google security regressions.
- Flutter tests: model/repository response compatibility and key profile/filter UI states.
- Full Laravel suite, full Flutter tests, `flutter analyze`, Web release build, and Android debug build.
