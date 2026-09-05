import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/features/tourism_partner/presentation/pages/partner_analytics_page.dart';
import 'package:tubigon_tourism/features/tourism_partner/presentation/pages/partner_listings_page.dart';
import 'package:tubigon_tourism/features/tourism_partner/presentation/pages/partner_reservations_page.dart';
import 'package:tubigon_tourism/features/tourism_partner/presentation/pages/partner_reviews_page.dart';
import 'package:tubigon_tourism/features/tourism_partner/providers/tourism_partner_providers.dart';

void main() {
  testWidgets('unassigned Partner receives a controlled destination state',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentPartnerAssignmentProvider.overrideWith((ref) async => null),
      ],
      child: const MaterialApp(home: PartnerListingsPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No destination assigned'), findsOneWidget);
    expect(find.textContaining('Creating duplicate public destinations'),
        findsOneWidget);
    expect(find.text('Create Listing'), findsNothing);
  });

  testWidgets('reservation operations render real summary and valid actions',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        partnerReservationQueueProvider.overrideWith((ref, query) async => {
              'summary': {
                'total': 1,
                'pending': 1,
                'confirmed': 0,
                'completed': 0,
                'cancelled': 0,
                'rejected': 0,
              },
              'items': [
                {
                  'id': 'reservation-id',
                  'public_reference': 'TB-RSV-2026-TEST',
                  'listing_name': 'Mundong Sandbar',
                  'guest_name': 'Sample Tourist',
                  'guests': 2,
                  'date': '2026-09-10',
                  'status': 'pending',
                  'allowed_transitions': ['confirmed', 'rejected'],
                }
              ],
            }),
      ],
      child: const MaterialApp(home: PartnerReservationsPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Reservation Operations'), findsOneWidget);
    expect(find.text('TB-RSV-2026-TEST'), findsOneWidget);
    expect(find.text('Mundong Sandbar'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });

  testWidgets('review dashboard renders authoritative distribution',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        partnerReviewsProvider.overrideWith((ref) async => [
              {
                'id': 'review-id',
                'reviewer': 'Verified Tourist',
                'rating': 2,
                'comment': 'Needs clearer visitor instructions.',
                'date': '2026-09-02',
              }
            ]),
        partnerReviewStatsProvider.overrideWith((ref) async => {
              'averageRating': 2.0,
              'totalReviews': 1,
              'lowRatedReviews': 1,
              'ratingDistribution': {'1': 0, '2': 1, '3': 0, '4': 0, '5': 0},
            }),
      ],
      child: const MaterialApp(home: PartnerReviewsPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Destination Feedback'), findsOneWidget);
    expect(find.text('Verified Tourist'), findsOneWidget);
    expect(find.text('NEEDS ATTENTION'), findsOneWidget);
    expect(find.text('2 star: 1'), findsOneWidget);
  });

  testWidgets('analytics empty state never fabricates unsupported metrics',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        partnerAnalyticsProvider.overrideWith((ref) async => {
              'totalReservations': 0,
              'totalReviews': 0,
              'averageRating': 0,
              'statusDistribution': <String, int>{},
              'ratingDistribution': <String, int>{},
              'comparisonPercent': null,
            }),
      ],
      child: const MaterialApp(home: PartnerAnalyticsPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Destination Performance'), findsOneWidget);
    expect(find.text('Not enough activity yet'), findsOneWidget);
    expect(find.textContaining('Conversion'), findsNothing);
    expect(find.textContaining('Reach'), findsNothing);
  });
}
