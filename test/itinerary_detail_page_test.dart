import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tubigon_tourism/features/itinerary/models/itinerary.dart';
import 'package:tubigon_tourism/features/itinerary/presentation/itinerary_detail_page.dart';
import 'package:tubigon_tourism/features/itinerary/repositories/itinerary_repository.dart';

ItineraryPlace _place({
  required String type,
  required String id,
  required int integerId,
  required String name,
  double? latitude = 9.95,
  double? longitude = 123.96,
  bool bookable = false,
  bool bookingEnabled = false,
}) =>
    ItineraryPlace(
      entityType: type,
      entityId: id,
      sourceIntegerId: integerId,
      markerId: '$type:$id',
      name: name,
      category: type == 'msme' ? 'Food & Dining' : 'Nature',
      address: 'Tubigon, Bohol',
      latitude: latitude,
      longitude: longitude,
      isVerified: true,
      isBookable: bookable,
      bookingEnabled: bookingEnabled,
    );

ItineraryItem _item({
  required String id,
  required int day,
  required int order,
  required ItineraryPlace? place,
  ItineraryReservation? reservation,
}) =>
    ItineraryItem(
      id: id,
      itineraryId: 'trip-1',
      entityType: place?.entityType ?? 'msme',
      entityId: place?.entityId ?? 'missing-id',
      dayNumber: day,
      sortOrder: order,
      plannedStartTime: order == 1 ? '09:00' : '12:30',
      notes: order == 1 ? 'Bring water' : null,
      visitStatus: ItineraryVisitStatus.planned,
      place: place,
      reservation: reservation,
    );

Itinerary _trip({List<ItineraryItem>? items, int dayCount = 1}) {
  final stops = items ??
      [
        _item(
          id: 'stop-2',
          day: 1,
          order: 2,
          place: _place(
            type: 'msme',
            id: 'msme-uuid',
            integerId: 8,
            name: 'BAZAK Food Park',
          ),
        ),
        _item(
          id: 'stop-1',
          day: 1,
          order: 1,
          place: _place(
            type: 'tourist_spot',
            id: 'spot-uuid',
            integerId: 12,
            name: 'Enchanted Ilijan Hill',
            bookable: true,
            bookingEnabled: false,
          ),
          reservation: const ItineraryReservation(
            id: 'reservation-1',
            status: 'confirmed',
          ),
        ),
      ];
  return Itinerary(
    id: 'trip-1',
    name: 'My Tubigon Trip',
    startDate: DateTime(2026, 8, 27),
    endDate: DateTime(2026, 8, 27 + dayCount - 1),
    dayCount: dayCount,
    status: ItineraryStatus.upcoming,
    placeCount: stops.length,
    items: stops,
  );
}

GoRouter _router() => GoRouter(
      initialLocation: '/itineraries/trip-1',
      routes: [
        GoRoute(
          path: '/itineraries/:id',
          builder: (_, state) =>
              ItineraryDetailPage(itineraryId: state.pathParameters['id']!),
        ),
        GoRoute(
            path: '/explore/spot/:id',
            builder: (_, __) => const Scaffold(body: Text('spot-details'))),
        GoRoute(
            path: '/explore/msme/:id',
            builder: (_, __) => const Scaffold(body: Text('msme-details'))),
        GoRoute(
            path: '/map',
            builder: (_, state) => Scaffold(
                  body: Text(
                    'marker=${state.uri.queryParameters['marker']};'
                    'navigate=${state.uri.queryParameters['navigate']}',
                  ),
                )),
        GoRoute(
            path: '/explore',
            builder: (_, __) => const Scaffold(body: Text('explore'))),
      ],
    );

Widget _app(Itinerary trip, {GoRouter? router}) => ProviderScope(
      overrides: [
        itineraryDetailProvider('trip-1').overrideWith((ref) async => trip),
      ],
      child: MaterialApp.router(routerConfig: router ?? _router()),
    );

void _largeTestViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1100, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('two-place trip renders two separately bordered ordered cards',
      (tester) async {
    _largeTestViewport(tester);
    await tester.pumpWidget(_app(_trip()));
    await tester.pumpAndSettle();

    expect(find.byType(ItineraryPlaceCard), findsNWidgets(2));
    expect(find.text('Enchanted Ilijan Hill'), findsOneWidget);
    expect(find.text('BAZAK Food Park'), findsOneWidget);
    expect(find.text('Reservation Confirmed'), findsOneWidget);
    expect(find.text('Book'), findsNothing,
        reason: 'Disabled booking must not remove the destination card.');

    for (final id in ['stop-1', 'stop-2']) {
      final card = tester
          .widget<Container>(find.byKey(ValueKey('itinerary-place-card-$id')));
      final decoration = card.decoration! as BoxDecoration;
      expect(decoration.border, isNotNull);
    }
    final firstBadge = tester.widget<CircleAvatar>(
        find.byKey(const ValueKey('itinerary-stop-number-stop-1')));
    final secondBadge = tester.widget<CircleAvatar>(
        find.byKey(const ValueKey('itinerary-stop-number-stop-2')));
    expect((firstBadge.child! as Text).data, '1');
    expect((secondBadge.child! as Text).data, '2');
  });

  testWidgets('day grouping renders authoritative dates and ordered sections',
      (tester) async {
    _largeTestViewport(tester);
    final dayTwo = _item(
      id: 'day-two',
      day: 2,
      order: 1,
      place: _place(
        type: 'msme',
        id: 'day-two-msme',
        integerId: 9,
        name: 'Day Two MSME',
      ),
    );
    await tester.pumpWidget(_app(_trip(
      dayCount: 2,
      items: [_trip().items.first, dayTwo],
    )));
    await tester.pumpAndSettle();

    expect(find.text('DAY 1'), findsOneWidget);
    expect(find.text('DAY 2'), findsOneWidget);
    expect(find.text('August 27, 2026'), findsOneWidget);
    expect(find.text('August 28, 2026'), findsOneWidget);
  });

  testWidgets('missing optional data and coordinates still render a stop card',
      (tester) async {
    _largeTestViewport(tester);
    final noCoordinates = _item(
      id: 'offline-stop',
      day: 1,
      order: 1,
      place: _place(
        type: 'msme',
        id: 'offline-msme',
        integerId: 10,
        name: 'Cached Offline MSME',
        latitude: null,
        longitude: null,
      ),
    );
    final cached = Itinerary.fromJson(_trip(items: [noCoordinates]).toJson());
    await tester.pumpWidget(_app(cached));
    await tester.pumpAndSettle();

    expect(find.byType(ItineraryPlaceCard), findsOneWidget);
    expect(find.text('Cached Offline MSME'), findsOneWidget);
    expect(find.text('Location unavailable'), findsOneWidget);
    expect(find.text('Map'), findsNothing);
    expect(find.text('Directions'), findsNothing);
  });

  testWidgets('details, map and directions use authoritative IDs and marker',
      (tester) async {
    _largeTestViewport(tester);
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(_trip(), router: router));
    await tester.pumpAndSettle();

    tester
        .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'View Details').first)
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('spot-details'), findsOneWidget);

    router.go('/itineraries/trip-1');
    await tester.pumpAndSettle();
    tester
        .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Map').first)
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('marker=tourist_spot:spot-uuid;navigate=null'),
        findsOneWidget);

    router.go('/itineraries/trip-1');
    await tester.pumpAndSettle();
    tester
        .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Directions').first)
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('marker=tourist_spot:spot-uuid;navigate=true'),
        findsOneWidget);
  });

  testWidgets('place cards remain usable at a narrow mobile viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_trip()));
    await tester.pumpAndSettle();

    expect(find.text('Enchanted Ilijan Hill'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('BAZAK Food Park'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('BAZAK Food Park'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty, loading and error states never leave a blank body',
      (tester) async {
    _largeTestViewport(tester);
    await tester.pumpWidget(_app(_trip(items: const [])));
    await tester.pumpAndSettle();
    expect(find.text('No places yet'), findsOneWidget);
    expect(find.text('Explore Places'), findsOneWidget);

    final pending = Completer<Itinerary>();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        itineraryDetailProvider('trip-1').overrideWith((ref) => pending.future),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    ));
    await tester.pump();
    expect(find.text('Loading itinerary places…'), findsOneWidget);

    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        itineraryDetailProvider('trip-1')
            .overrideWith((ref) => Future.error(Exception('offline'))),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load this itinerary.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('refresh invalidates and reloads itinerary details',
      (tester) async {
    _largeTestViewport(tester);
    var loads = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        itineraryDetailProvider('trip-1').overrideWith((ref) async {
          loads++;
          return _trip();
        }),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    ));
    await tester.pumpAndSettle();
    expect(loads, 1);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(loads, greaterThan(1));
  });

  testWidgets('leaving during itinerary refresh is lifecycle safe',
      (tester) async {
    _largeTestViewport(tester);
    final refresh = Completer<Itinerary>();
    var loads = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        itineraryDetailProvider('trip-1').overrideWith((ref) {
          loads++;
          return loads == 1 ? Future.value(_trip()) : refresh.future;
        }),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    refresh.complete(_trip());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
