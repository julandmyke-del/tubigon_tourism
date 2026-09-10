# Tour Tubigon connected-product gap audit

Audit date: 2026-09-06

This audit was completed against the active Flutter client under `lib/`, the
Laravel API under `backend/`, the current migrations, route definitions, local
SQLite schema, and the existing automated tests. Existing production-like
records and prior completion work are preserved.

## Verified baseline

- Sanctum bearer-token authentication, secure token storage, cached identity
  metadata, role-aware GoRouter routing, explicit local Guest state, and logout
  cache cleanup already exist.
- Public Tourist Spot, MSME, announcement, ferry, eco-tip, emergency, and map
  endpoints already enforce most publication/verification filters in Laravel.
- Native SQLite and web local-storage caches already cover the major public
  discovery feeds. Map caches are separated between public and privileged
  account scopes.
- Waste reports already have owner scoping, Tubigon coordinate validation,
  offline UUID-based idempotent insertion, lifecycle history, LGU assignment,
  notifications, and private LGU/Admin map visibility.
- Emergency contacts already have audited LGU create/edit/verify/deactivate/
  archive operations and verified-only public/map queries.
- A centralized manual carbon calculator and OSRM routing service already
  exist, but they are not yet connected.

## Gaps confirmed

| Area | Confirmed cause | Required closure |
| --- | --- | --- |
| Persistent session | `_verifySession` resets to anonymous after a network failure even when a secure token and a previously verified identity exist. | Preserve a clearly marked read-only offline session, timestamp the last successful verification, revalidate before reconnect sync, and clear stale role caches on role change. |
| Guest mode | Guest state is real and remembered, but protected screens/actions use inconsistent gates and the current dialog omits Create Account. | Standardize protected-action UX, preserve safe return routes, and keep public routes usable without a token. |
| Waste evidence | The form and API accept photos only and store legacy public URLs in a JSON column. | Add authoritative categories/severity, up to three photos plus one bounded video, an authorized media relation/download endpoint, readable geocoded location metadata, and resolution evidence. |
| Waste operations | Core transitions exist, but severity/category filters, dedicated Waste Map entry, public resolution fields, and reopen support are incomplete. | Extend the model/API/UI without weakening owner/role checks or UUID idempotency. |
| Emergency directory | The initial seeder deliberately marks all candidates unverified, so a fresh verified-only public query is empty. Sources are labels rather than exact references. | Publish only records backed by exact official references, retain uncertain/conflicting records as `needs_reverification`, add explicit public/verification state, and expose cache freshness. |
| Carbon estimator | Factors are compiled into a Dart enum and the UI accepts manual distance only. There is no server history. | Add versioned backend factors, cached Flutter factor delivery, OSRM road-route input, explicit manual/ferry handling, comparisons, methodology, saved Tourist history, and itinerary handoff. |
| Environment | Platform-specific local defaults exist, but production origin configuration is not documented and Laravel CORS is wildcard-only. | Add environment-driven production origin configuration and deployment guidance while preserving local web/emulator defaults. |

## Safety boundary

- Cached roles are presentation hints only. Laravel middleware and ownership
  checks remain authoritative for every privileged operation.
- Only Tourist-created waste reports use the offline write path. Privileged
  LGU/Admin/MSME/Partner mutations remain online-only.
- Public caches are retained on logout; account-private caches and queued
  account mutations are removed.
- Waste media is served only through authenticated, ownership/role-checked API
  routes. Internal storage paths are never returned as public URLs.
- Emergency numbers are not invented. A record is public only after its source
  is explicit and its verification state is `verified`.
- Carbon results are estimates. Factor unit, version, source, route source, and
  calculation assumptions remain visible and auditable.
