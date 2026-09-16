import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/core/network/connectivity_provider.dart';
import 'package:tubigon_tourism/features/emergency/models/emergency_contact.dart';
import 'package:tubigon_tourism/features/emergency/repositories/emergency_repository.dart';
import 'package:tubigon_tourism/features/map/providers/map_provider.dart';
import 'package:tubigon_tourism/features/userpage/presentation/pages/emergency_contacts_page.dart';

void main() {
  final contacts = [
    _contact('police', 'Tubigon Police', '0998-598-6445', 10),
    _contact('fire', 'Bureau of Fire', '0963-774-5972', 20),
    _contact('terssu-smart', 'TERSSU', '0930-785-0655', 50, label: 'Smart'),
    _contact('terssu-globe', 'TERSSU', '0927-454-5496', 60, label: 'Globe'),
  ];

  Widget app({
    required Future<List<EmergencyContact>> Function(Ref ref) override,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return ProviderScope(
      key: UniqueKey(),
      overrides: [
        isOnlineProvider.overrideWithValue(true),
        emergencyContactsListProvider.overrideWith(override),
        mapMarkersProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: themeMode,
        home: const EmergencyContactsPage(),
      ),
    );
  }

  testWidgets(
      'official numbers and both TERSSU labels are visible and callable',
      (tester) async {
    await tester.pumpWidget(app(override: (ref) async => contacts));
    await tester.pumpAndSettle();

    expect(find.text('Municipality of Tubigon'), findsOneWidget);
    expect(find.text('Tubigon Police'), findsOneWidget);
    expect(find.text('0998-598-6445'), findsOneWidget);
    expect(find.text('Smart'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'CALL NOW'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Globe'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Globe'), findsOneWidget);
    expect(find.text('0927-454-5496'), findsOneWidget);
  });

  testWidgets('empty and failed loads remain distinct and retryable',
      (tester) async {
    final inactive = _contact(
      'inactive',
      'Inactive Hotline',
      '0999-000-0000',
      1,
      active: false,
    );
    await tester.pumpWidget(app(override: (ref) async => [inactive]));
    await tester.pumpAndSettle();
    expect(find.text('No active emergency contacts are configured.'),
        findsOneWidget);
    expect(find.text('Inactive Hotline'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);

    var attempts = 0;
    await tester.pumpWidget(app(override: (ref) async {
      attempts++;
      if (attempts == 1) throw Exception('network failed');
      return contacts;
    }));
    await tester.pumpAndSettle();
    expect(find.textContaining('Check your connection'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Tubigon Police'), findsOneWidget);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('directory is responsive in ${mode.name} mode', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester
          .pumpWidget(app(override: (ref) async => contacts, themeMode: mode));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('Tubigon Police'), findsOneWidget);
    });
  }
}

EmergencyContact _contact(
  String uuid,
  String name,
  String phone,
  int order, {
  String? label,
  bool active = true,
}) =>
    EmergencyContact(
      id: order,
      uuid: uuid,
      name: name,
      contactLabel: label,
      displayOrder: order,
      category: name.contains('Fire') ? 'Fire' : 'Police',
      phone: phone,
      isActive: active,
      isPublic: true,
      isVerified: true,
      verificationStatus: 'verified',
      color: Colors.red,
      icon: Icons.emergency,
    );
