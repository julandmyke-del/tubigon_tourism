# Smart Map runtime setup

The Smart Tubigon Map uses MapLibre GL with OpenStreetMap-derived map data and OSRM routing. It does not require a Google Maps account, billing setup, or API key.

## Geographic scope

The Smart Map is limited to the Municipality of Tubigon, Bohol (PSGC `0701245000`) and centers on the mapped Tubigon town center at `9.9515287, 123.9618897`.

The shared boundary asset is `backend/resources/data/tubigon_boundary.geojson`. It comes from the Philippine GeoRisk/PSA `Municipal_2020_Coast` WGS84 municipal-boundary layer and includes Tubigon's mainland and municipal islands. The geometry is generalized to `0.001` degrees for efficient offline validation. Flutter bundles this same asset, while Laravel remains the authoritative enforcement layer for map feeds and coordinate writes.

Do not replace the boundary with a sample rectangle or populate map-backed tables with unrelated locations. If the government boundary dataset is updated, regenerate this asset for PSGC `0701245000` and rerun both boundary test suites.

## Default map style

The default style is the keyless OpenFreeMap Liberty style:

```text
https://tiles.openfreemap.org/styles/liberty
```

The URL is centralized in `AppConstants.mapStyleUrl`. A deployment can select another MapLibre Style Specification URL without changing source code:

```powershell
flutter run -d chrome --dart-define=MAP_STYLE_URL=https://example.com/style.json
```

Any replacement provider must permit the application's usage and include the required OpenStreetMap attribution. Do not point production builds at `tile.openstreetmap.org` or bulk-download public tiles.

## Flutter Web

`web/index.html` loads the MapLibre GL JS runtime and stylesheet required by `maplibre_gl_web`. No token is required. Keep the JavaScript version aligned with the resolved `maplibre_gl_web` package when upgrading.

## API environments

API hosts are selected at build/run time. `API_BASE_URL` overrides every
platform, while the platform-specific values allow independent development
targets:

```powershell
# Web development (this is also the Web default)
flutter run -d chrome --dart-define=WEB_API_BASE_URL=http://localhost:8000

# Android emulator (10.0.2.2 is the emulator alias for the host computer)
flutter run -d android --dart-define=ANDROID_API_BASE_URL=http://10.0.2.2:8000

# Physical Android device on the same LAN; replace with the computer's LAN IP
flutter run -d android --dart-define=ANDROID_API_BASE_URL=http://192.168.1.10:8000

# Production build for every platform
flutter build web --dart-define=API_BASE_URL=https://api.example.gov.ph
flutter build appbundle --dart-define=API_BASE_URL=https://api.example.gov.ph
```

`localhost` on a physical phone means the phone itself, not the development
computer. Laravel must listen on an accessible interface, the firewall must
allow the chosen port, and both devices must be on a trusted network. Use an
HTTPS API URL for production Web and mobile builds.

The fallback development targets remain `localhost:8000` for Web,
`10.0.2.2:8000` for the Android emulator, and `127.0.0.1:8000` for other local
platforms. Never rely on these fallbacks for a production build.

## Attribution

The map UI visibly credits OpenStreetMap contributors and OpenFreeMap. Preserve this attribution if the visual design changes.

## Routing

Road geometry, distance, ETA, per-leg itinerary estimates, and route lines use
the public OSRM route service. The embedded map and basic in-app navigation have
no Google dependency. This is not a full turn-by-turn, rerouting, voice, or
offline-routing engine.

## Tourist itineraries

The additive Laravel migration
`2026_08_27_000001_create_tourist_itineraries.php` creates only `itineraries`
and `itinerary_items`. Apply that migration through the normal deployment
process; never reset or rebuild an existing database.

Saved itinerary lists/details are cached per authenticated owner for read-only
offline viewing. Creating, editing, reordering, status changes, directions, and
route refreshes require connectivity. The daily
`itineraries:send-reminders` command reuses the existing notification table and
respects disabled notification settings. Production must run Laravel's normal
scheduler worker/cron for the 08:00 reminder schedule to execute.

## Device verification

Before release, verify GPS, live navigation, picker dragging, dialer launching,
and back navigation on a physical Android device. Verify MapLibre rendering,
location permission, picker behavior, and dialer launching on iOS. Desktop/Web
build success does not replace these device checks.
