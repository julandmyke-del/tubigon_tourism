# Six-Issue Connected Product Gap Audit

Date: 2026-09-07

| Issue | State | Working foundation | Root gap / risk | Dependencies |
|---|---|---|---|---|
| LGU ferry management | PARTIAL / RISK | Public API, LGU/Admin CRUD routes, native/web cache, LGU form, activity log | Flat free-text ports/routes, `is_active` doubles as publication, no structural route/port catalog, incomplete status vocabulary and transition checks | Existing `ferry_schedules`, activity log, public cache |
| Destination booking offerings | MISSING on top of WORKING booking core | Published/bookable/enabled spot gates, slot/capacity validation, transaction and row lock, assigned Partner relation, reservation history | One spot fee/form for every booking; no offerings, fields, line items, per-offering inventory, blackout dates, or price snapshots | `tourist_spots`, assignments, reservations, statuses, notifications |
| Customer snapshot and reservation communication | PARTIAL / MISSING | Reservation owner relation, scoped Partner queries, status timeline, in-app/email status notifications | Partner reads live profile data; no booking-time contact snapshot, reservation-only thread, unread state, system messages, or isolated internal notes | Reservation authorization and assigned destination relationship |
| Tourist Spot gallery | MISSING | Existing spot `images` fallback and generic image upload infrastructure | No authoritative ordered media collection, cover invariant, Partner ownership workflow, moderation, captions, or public gallery API | Tourist Spot policy, storage disk, spot public payloads |
| Concerns and support | MISSING | General activity/notification infrastructure and specialized waste/reservation flows | No structured categories, routing, ownership, staff queue, messages, attachments, assignment, escalation, or history | Auth roles, notifications, activity log, private file delivery |
| Targeted announcements | PARTIAL / BROKEN for combinations and Guest | Admin editor, scheduling, priority, one-role visibility, lazy notification synchronization, email command, notification bell banners | Single audience string cannot represent combinations; no Guest endpoint, display placement/CTA/related entity/read relation; server audience model is not relational | Announcements, notifications, Admin UI, role dashboards, cache |

## Existing authoritative architecture to retain

- Laravel Sanctum and role middleware are the API boundary.
- `tourist_spot_partner_assignments` is the sole Partner ownership source.
- `TouristSpotBookingService` and the `tourist_spots` row lock are the booking safety foundation.
- `activity_logs`, `notifications`, `partner_notifications`, and `EmailNotificationService` remain the shared audit/delivery architecture.
- Flutter keeps GoRouter, Riverpod, Dio, SharedPreferences web caching, SQLite native caching, MapLibre, and the current navy/slate/amber design system.

## Implementation direction

Use additive schema only. Add controlled catalogs and relational child records; derive every owner/actor/price/audience from authenticated and authoritative state; preserve historic reservation data; use private media delivery where content is not public; allow cached public/read-only content but require connectivity for operational mutations.
