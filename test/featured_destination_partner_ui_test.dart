import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/features/tourism_partner/presentation/pages/partner_dashboard_page.dart';
import 'package:tubigon_tourism/features/tourism_partner/presentation/pages/partner_listings_page.dart';
import 'package:tubigon_tourism/features/tourism_partner/providers/tourism_partner_providers.dart';

const _managedSpot = <String, dynamic>{
  'id': '5db393e3-27e9-5bde-bc6e-b3aa619996c3',
  'name': 'Mundong Sandbar',
  'is_published': true,
  'is_featured': true,
  'is_bookable': true,
  'booking_enabled': true,
  'booking_mode': 'date_only',
};

void main() {
  testWidgets('Partner dashboard identifies its managed Tourist Spot',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        partnerDashboardStatsProvider.overrideWith((ref) async => {
              'managedDestinations': [_managedSpot],
              'totalManagedDestinations': 1,
              'todayReservations': 0,
              'pendingReservations': 0,
              'completedReservations': 0,
              'draftListings': 0,
              'pendingListings': 0,
              'publishedListings': 0,
              'recentNotifications': <Map<String, dynamic>>[],
            }),
      ],
      child: const MaterialApp(home: PartnerDashboardPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mundong Sandbar Partner Portal'), findsOneWidget);
    expect(find.text('Accepting Reservations'), findsOneWidget);
    expect(find.text('Manage Availability'), findsOneWidget);
  });

  testWidgets('Partner disabling booking requires a reason confirmation',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        partnerManagedDestinationsProvider
            .overrideWith((ref) async => [_managedSpot]),
        partnerListingsProvider.overrideWith((ref) async => []),
      ],
      child: const MaterialApp(home: PartnerListingsPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Managed Destinations'), findsOneWidget);
    expect(find.text('Mundong Sandbar'), findsOneWidget);
    await tester.tap(find.text('Disable Booking'));
    await tester.pumpAndSettle();

    expect(find.text('Disable Booking?'), findsOneWidget);
    expect(find.text('Reason'), findsOneWidget);
    expect(find.text('Weather Conditions'), findsOneWidget);
  });
}
