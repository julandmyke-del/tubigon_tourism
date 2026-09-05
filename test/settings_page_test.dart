import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubigon_tourism/core/network/connectivity_provider.dart';
import 'package:tubigon_tourism/features/authentication/auth_provider.dart';
import 'package:tubigon_tourism/features/settings/repositories/settings_repository.dart';
import 'package:tubigon_tourism/features/userpage/presentation/pages/settings_page.dart';

class _LoggedInTouristNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isLoggedIn: true,
        role: UserRole.tourist,
        userId: 'tourist-id',
        name: 'Test Tourist',
      );
}

class _FakeSettingsRepository implements SettingsRepository {
  Completer<Map<String, dynamic>>? pending;
  int updates = 0;

  @override
  Future<Map<String, dynamic>> getSettings() async => {
        'notifications_enabled': true,
        'offline_mode': true,
        'location_enabled': true,
      };

  @override
  Future<Map<String, dynamic>> getSystemSettings() async => const {
        'reviews_enabled': true,
        'waste_reporting_enabled': true,
        'global_booking_enabled': true,
        'tourist_registration_enabled': true,
      };

  @override
  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> values) {
    updates++;
    return pending!.future;
  }
}

Widget _app(_FakeSettingsRepository repository) => ProviderScope(
      overrides: [
        authProvider.overrideWith(_LoggedInTouristNotifier.new),
        settingsRepositoryProvider.overrideWithValue(repository),
        connectivityProvider.overrideWith(
          (ref) => Stream.value(ConnectivityStatus.online),
        ),
      ],
      child: const MaterialApp(home: SettingsPage()),
    );

void main() {
  testWidgets('failed setting save is locked in flight and rolls back',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _FakeSettingsRepository()
      ..pending = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    final pushTile = find.ancestor(
      of: find.text('Push Notifications'),
      matching: find.byType(SwitchListTile),
    );
    expect(tester.widget<SwitchListTile>(pushTile).value, isTrue);

    tester.widget<SwitchListTile>(pushTile).onChanged!(false);
    await tester.pump();
    expect(repository.updates, 1);
    expect(tester.widget<SwitchListTile>(pushTile).value, isFalse);
    expect(tester.widget<SwitchListTile>(pushTile).onChanged, isNull);

    repository.pending!.completeError(Exception('Network unavailable'));
    await tester.pumpAndSettle();

    expect(repository.updates, 1);
    expect(tester.widget<SwitchListTile>(pushTile).value, isTrue);
    expect(tester.widget<SwitchListTile>(pushTile).onChanged, isNotNull);
    expect(find.textContaining('Network unavailable'), findsOneWidget);
  });
}
