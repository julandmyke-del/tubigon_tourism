import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/features/tourism_partner/presentation/pages/partner_dashboard_page.dart';
import 'package:tubigon_tourism/features/tourism_partner/presentation/pages/partner_listings_page.dart';
import 'package:tubigon_tourism/features/tourism_partner/providers/tourism_partner_providers.dart';

const _managedSpot = <String, dynamic>{
  'id': '5db393e3-27e9-5bde-bc6e-b3aa619996c3',
  'integer_id': 101,
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
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1400);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentPartnerAssignmentProvider.overrideWith((ref) async => {
              'id': 'assignment-id',
              'status': 'active',
              'assigned_at': '2026-09-02T10:00:00Z',
              'destination': _managedSpot,
            }),
      ],
      child: const MaterialApp(home: PartnerListingsPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Assigned Destination'), findsOneWidget);
    expect(find.text('Mundong Sandbar'), findsOneWidget);
    await tester.tap(find.text('Pause Reservations'));
    await tester.pumpAndSettle();

    expect(find.text('Pause reservations?'), findsOneWidget);
    expect(find.text('Reason'), findsOneWidget);
    expect(find.text('Weather Conditions'), findsOneWidget);
  });
}
