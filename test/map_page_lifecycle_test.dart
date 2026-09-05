import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubigon_tourism/core/network/connectivity_provider.dart';
import 'package:tubigon_tourism/core/services/local_storage_service.dart';
import 'package:tubigon_tourism/features/authentication/auth_provider.dart';
import 'package:tubigon_tourism/features/map/providers/map_provider.dart';
import 'package:tubigon_tourism/features/map/services/directions_service.dart';
import 'package:tubigon_tourism/features/userpage/presentation/pages/map_page.dart';

class _GuestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(role: UserRole.guest);
}

class _PendingLocationNotifier extends UserLocationNotifier {
  final locateCompleter = Completer<bool>();
  int stopCount = 0;

  @override
  Future<bool> locate({bool track = false}) => locateCompleter.future;

  @override
  void stopTracking() {
    stopCount++;
    super.stopTracking();
  }
}

class _ReadyLocationNotifier extends UserLocationNotifier {
  _ReadyLocationNotifier() {
    state = const UserLocationState(
      latitude: 9.9515,
      longitude: 123.9619,
    );
  }
}

class _PendingDirectionsService extends DirectionsService {
  final result = Completer<MapRouteResult>();
  CancelToken? capturedToken;

  @override
  Future<MapRouteResult> route({
    required MapCoordinate origin,
    required MapCoordinate destination,
    CancelToken? cancelToken,
  }) {
    capturedToken = cancelToken;
    return result.future;
  }
}

const _destination = MapMarker(
  id: 'msme:1',
  sourceId: '1',
  name: 'BAZAK Food Park',
  description: 'Local food park',
  latitude: 9.953,
  longitude: 123.963,
  category: MapMarkerCategory.msme,
  categoryName: 'MSMEs',
  categorySlug: 'msmes',
  categoryKeys: ['msmes', 'food-parks'],
);

const _touristDestination = MapMarker(
  id: 'tourist_spot:1',
  sourceId: '1',
  name: 'Mundong Sandbar',
  description: 'Nature destination',
  latitude: 9.96,
  longitude: 123.97,
  category: MapMarkerCategory.touristSpot,
  categoryName: 'Tourist Spots',
  categorySlug: 'tourist-spots',
  categoryKeys: ['tourist-spots', 'nature'],
);

const _mapCategories = [
  MapPlaceCategory(
    id: 'tourist-spots',
    name: 'Tourist Spots',
    slug: 'tourist-spots',
    icon: 'landscape',
    markerColor: '#F59E0B',
    sortOrder: 1,
  ),
  MapPlaceCategory(
    id: 'msmes',
    name: 'MSMEs',
    slug: 'msmes',
    icon: 'storefront',
    markerColor: '#0284C7',
    sortOrder: 2,
  ),
];

Future<void> _replaceMapRoute(WidgetTester tester) async {
  final context = tester.element(find.byType(MapPage));
  unawaited(Navigator.of(context).pushReplacement<void, void>(
    MaterialPageRoute<void>(builder: (_) => const Scaffold()),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('leaving Smart Map while markers load is lifecycle safe',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
    final pendingMarkers = Completer<List<MapMarker>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_GuestAuthNotifier.new),
          mapMarkersProvider.overrideWith((ref) => pendingMarkers.future),
        ],
        child: const MaterialApp(home: MapPage()),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('late GPS completion cannot access a disposed MapPage',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
    final pendingMarkers = Completer<List<MapMarker>>();
    final location = _PendingLocationNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_GuestAuthNotifier.new),
          mapMarkersProvider.overrideWith((ref) => pendingMarkers.future),
          userLocationProvider.overrideWith((ref) => location),
          connectivityProvider.overrideWith(
            (ref) => Stream.value(ConnectivityStatus.online),
          ),
        ],
        child: const MaterialApp(home: MapPage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Current location'));
    await tester.pump();
    await _replaceMapRoute(tester);
    location.locateCompleter.complete(true);
    await tester.pump();

    expect(location.stopCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending OSRM route is cancelled when Smart Map is left',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
    final pendingMarkers = Completer<List<MapMarker>>();
    final directions = _PendingDirectionsService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_GuestAuthNotifier.new),
          mapMarkersProvider.overrideWith((ref) => pendingMarkers.future),
          selectedMarkerProvider.overrideWith((ref) => _destination),
          userLocationProvider.overrideWith(
            (ref) => _ReadyLocationNotifier(),
          ),
          directionsServiceProvider.overrideWithValue(directions),
          connectivityProvider.overrideWith(
            (ref) => Stream.value(ConnectivityStatus.online),
          ),
        ],
        child: const MaterialApp(home: MapPage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Directions'));
    for (var i = 0; i < 20 && directions.capturedToken == null; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(directions.capturedToken, isNotNull);

    await _replaceMapRoute(tester);
    expect(directions.capturedToken!.isCancelled, isTrue);
    directions.result.complete(const MapRouteResult(
      points: [
        MapCoordinate(9.9515, 123.9619),
        MapCoordinate(9.953, 123.963),
      ],
      distanceKm: .3,
      durationMinutes: 1,
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('map search ListTiles paint above the glass Material surface',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_GuestAuthNotifier.new),
          mapMarkersProvider.overrideWith((ref) async => [_destination]),
          connectivityProvider.overrideWith(
            (ref) => Stream.value(ConnectivityStatus.online),
          ),
        ],
        child: const MaterialApp(home: MapPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'BAZAK');
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.widgetWithText(ListTile, 'BAZAK Food Park'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category chips update visibility, count, and All restoration',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_GuestAuthNotifier.new),
          mapMarkersProvider.overrideWith(
            (ref) async => [_touristDestination, _destination],
          ),
          mapPlaceCategoriesProvider.overrideWith(
            (ref) async => _mapCategories,
          ),
          connectivityProvider.overrideWith(
            (ref) => Stream.value(ConnectivityStatus.online),
          ),
        ],
        child: const MaterialApp(home: MapPage()),
      ),
    );
    await tester.pump();
    await tester.pump();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(MapPage)));

    await tester.tap(find.widgetWithText(FilterChip, 'MSMEs'));
    await tester.pump();
    expect(find.text('1 place found'), findsOneWidget);
    expect(
      container.read(filteredMapMarkersProvider).requireValue,
      [_destination],
    );

    await tester.tap(find.widgetWithText(FilterChip, 'All'));
    await tester.pump();
    expect(
      container.read(filteredMapMarkersProvider).requireValue,
      [_touristDestination, _destination],
    );
    expect(find.textContaining('places found'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('combined filter/search shows a useful zero-results state',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_GuestAuthNotifier.new),
          mapMarkersProvider.overrideWith(
            (ref) async => [_touristDestination, _destination],
          ),
          mapPlaceCategoriesProvider.overrideWith(
            (ref) async => _mapCategories,
          ),
          connectivityProvider.overrideWith(
            (ref) => Stream.value(ConnectivityStatus.online),
          ),
        ],
        child: const MaterialApp(home: MapPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithText(FilterChip, 'MSMEs'));
    await tester.enterText(find.byType(TextField), 'sandbar');
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('No places found'), findsOneWidget);
    expect(find.text('No places match this filter.'), findsOneWidget);
    expect(find.text('Clear Filters'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtering clears a hidden selection but preserves navigation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_GuestAuthNotifier.new),
          mapMarkersProvider.overrideWith(
            (ref) async => [_touristDestination, _destination],
          ),
          mapPlaceCategoriesProvider.overrideWith(
            (ref) async => _mapCategories,
          ),
          selectedMarkerProvider.overrideWith(
            (ref) => _touristDestination,
          ),
          navigationProvider.overrideWith(
            (ref) => const NavigationState(
              destination: _touristDestination,
              isNavigating: true,
              distanceKm: 1,
              etaMinutes: 3,
            ),
          ),
          connectivityProvider.overrideWith(
            (ref) => Stream.value(ConnectivityStatus.online),
          ),
        ],
        child: const MaterialApp(home: MapPage()),
      ),
    );
    await tester.pump();
    await tester.pump();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(MapPage)));

    await tester.tap(find.widgetWithText(FilterChip, 'MSMEs'));
    await tester.pump();

    expect(container.read(selectedMarkerProvider), isNull);
    expect(container.read(navigationProvider).isNavigating, isTrue);
    expect(container.read(navigationProvider).destination?.id,
        _touristDestination.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtering preserves a selected marker that remains visible',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_GuestAuthNotifier.new),
          mapMarkersProvider.overrideWith(
            (ref) async => [_touristDestination, _destination],
          ),
          mapPlaceCategoriesProvider.overrideWith(
            (ref) async => _mapCategories,
          ),
          selectedMarkerProvider.overrideWith((ref) => _destination),
          connectivityProvider.overrideWith(
            (ref) => Stream.value(ConnectivityStatus.online),
          ),
        ],
        child: const MaterialApp(home: MapPage()),
      ),
    );
    await tester.pump();
    await tester.pump();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(MapPage)));

    await tester.tap(find.widgetWithText(FilterChip, 'MSMEs'));
    await tester.pump();

    expect(container.read(selectedMarkerProvider)?.id, _destination.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deep-link focus preserves the remembered map filter',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_GuestAuthNotifier.new),
          mapMarkersProvider.overrideWith(
            (ref) async => [_touristDestination, _destination],
          ),
          mapFilterProvider.overrideWith(
            (ref) => const MapFilterState(activeCategoryKeys: {'nature'}),
          ),
          connectivityProvider.overrideWith(
            (ref) => Stream.value(ConnectivityStatus.online),
          ),
        ],
        child: const MaterialApp(
          home: MapPage(initialMarkerId: 'msme:1'),
        ),
      ),
    );
    await tester.pump();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(MapPage)));

    expect(
      container.read(mapFilterProvider).activeCategoryKeys,
      {'nature'},
    );
    expect(tester.takeException(), isNull);
  });
}
