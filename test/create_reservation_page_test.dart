import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/features/authentication/auth_provider.dart';
import 'package:tubigon_tourism/features/tourist_spots/models/tourist_spot.dart';
import 'package:tubigon_tourism/features/tourist_spots/repositories/tourist_spot_repository.dart';
import 'package:tubigon_tourism/features/userpage/presentation/pages/create_reservation_page.dart';

class _LoggedInTouristNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isLoggedIn: true,
        role: UserRole.tourist,
        userId: 'tourist-test-id',
        name: 'Test Tourist',
      );
}

TouristSpot _spot({
  String id = 'spot-uuid',
  String name = 'Mundong Sandbar',
  bool bookingEnabled = true,
  String? reasonCode,
  String? reason,
}) {
  return TouristSpot(
    id: 1,
    uuid: id,
    name: name,
    slug: 'mundong-sandbar',
    description: 'Controlled test destination.',
    latitude: 9.94,
    longitude: 123.87,
    address: 'Tubigon, Bohol',
    entranceFee: 0,
    openingHours: '',
    ecoTips: const [],
    images: const [],
    averageRating: 0,
    reviewCount: 0,
    isFeatured: true,
    isActive: true,
    isPublished: true,
    isBookable: true,
    bookingEnabled: bookingEnabled,
    bookingUnavailableReasonCode: reasonCode,
    bookingUnavailableReason: reason,
    bookingMode: 'date_only',
    maxGuestsPerReservation: 5,
  );
}

Widget _page({
  required Override spotsOverride,
  String? initialSpotUuid,
}) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(_LoggedInTouristNotifier.new),
      spotsOverride,
      touristSpotAvailabilityProvider.overrideWith(
        (ref, query) async => {
          'date': query.date,
          'booking_mode': 'date_only',
          'available': true,
          'remaining_capacity': 5,
          'slots': <Map<String, dynamic>>[],
        },
      ),
    ],
    child: MaterialApp(
      home: CreateReservationPage(initialSpotUuid: initialSpotUuid),
    ),
  );
}

void main() {
  testWidgets('New Booking shows a real bookable destination dropdown',
      (tester) async {
    await tester.pumpWidget(_page(
      spotsOverride: bookableTouristSpotsProvider.overrideWith(
        (ref) async => [_spot()],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Bookable destination'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Mundong Sandbar'), findsOneWidget);
  });

  testWidgets('deep-linked destination is preselected and can be submitted',
      (tester) async {
    await tester.pumpWidget(_page(
      initialSpotUuid: 'spot-uuid',
      spotsOverride: bookableTouristSpotsProvider.overrideWith(
        (ref) async => [_spot()],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mundong Sandbar'), findsOneWidget);
    expect(find.text('5 guest spaces remain for this date.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Submit Reservation'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final submit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Submit Reservation'),
    );
    expect(submit.onPressed, isNotNull);
  });

  testWidgets('API failure is distinct from a truthful empty result',
      (tester) async {
    await tester.pumpWidget(_page(
      spotsOverride: bookableTouristSpotsProvider.overrideWith(
        (ref) => Future<List<TouristSpot>>.error(Exception('network down')),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('could not be loaded'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('not currently offered'), findsNothing);
  });

  testWidgets('successful empty query shows the no-bookings-offered state',
      (tester) async {
    await tester.pumpWidget(_page(
      spotsOverride: bookableTouristSpotsProvider.overrideWith(
        (ref) async => <TouristSpot>[],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('not currently offered'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('deep-linked unavailable destination shows its public reason',
      (tester) async {
    await tester.pumpWidget(_page(
      initialSpotUuid: 'spot-uuid',
      spotsOverride: bookableTouristSpotsProvider.overrideWith(
        (ref) async => [
          _spot(
            bookingEnabled: false,
            reasonCode: 'weather_conditions',
            reason: 'Boat trips are temporarily suspended.',
          ),
        ],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Booking Temporarily Unavailable'),
        findsOneWidget);
    expect(find.textContaining('Weather Conditions'), findsOneWidget);
    expect(find.textContaining('Boat trips are temporarily suspended.'),
        findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Submit Reservation'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final submit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Submit Reservation'),
    );
    expect(submit.onPressed, isNull);
  });
}
