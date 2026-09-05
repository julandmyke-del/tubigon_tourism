import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/core/network/api_client.dart';
import 'package:tubigon_tourism/features/msmepage/data/msme_portal_repository.dart';
import 'package:tubigon_tourism/features/msmepage/models/msme.dart';
import 'package:tubigon_tourism/features/msmepage/presentation/pages/msme_portal_reservations_page.dart';
import 'package:tubigon_tourism/features/msmepage/providers/msme_portal_providers.dart';

class _FakeMsmePortalRepository extends MsmePortalRepository {
  _FakeMsmePortalRepository() : super(apiClient: ApiClient(Dio()));

  @override
  Future<List<Map<String, dynamic>>> getReservations({
    String? statusFilter,
  }) async =>
      const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MSME model preserves authoritative booking capability', () {
    final business = Msme.fromJson({
      'id': '35555555-5555-4555-8555-555555555555',
      'integer_id': 41,
      'name': 'BAZAK Food Park',
      'category': 'Food & Dining',
      'booking_enabled': true,
      'operational_status': 'open',
      'opening_hours': {
        'thursday': {'closed': false, 'open': '08:00', 'close': '18:00'},
      },
      'unavailable_dates': ['2026-09-10'],
      'is_verified': true,
    });

    expect(business.bookingEnabled, isTrue);
    expect(business.isAvailableOn(DateTime(2026, 9, 10)), isFalse);
    expect(business.isAvailableOn(DateTime(2026, 9, 17)), isTrue);
    final cached = Msme.fromJson(business.toJson());
    expect(cached.bookingEnabled, isTrue);
    expect(cached.unavailableDates, ['2026-09-10']);
    expect(cached.openingHours['thursday'], isA<Map>());
  });

  testWidgets('owner without a business sees a guided setup state',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentMsmeProvider.overrideWith(
            (ref) async => const CurrentMsmeState(
              business: null,
              profileRequired: true,
            ),
          ),
        ],
        child: const MaterialApp(home: MsmePortalReservationsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set Up Business'), findsOneWidget);
    expect(find.textContaining('No query results'), findsNothing);
    expect(find.textContaining('App\\Models'), findsNothing);
  });

  testWidgets('late current-business completion does not use ref after dispose',
      (tester) async {
    final current = Completer<CurrentMsmeState>();
    final fakeRepository = _FakeMsmePortalRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          msmePortalRepositoryProvider.overrideWithValue(fakeRepository),
          currentMsmeProvider.overrideWith((ref) => current.future),
        ],
        child: const MaterialApp(home: MsmePortalReservationsPage()),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    current.complete(
      const CurrentMsmeState(
        business: {'id': 'owned-business'},
        profileRequired: false,
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
