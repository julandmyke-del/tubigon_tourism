import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/core/theme/app_theme.dart';
import 'package:tubigon_tourism/features/admin/presentation/pages/admin_tourism_management_page.dart';
import 'package:tubigon_tourism/features/admin/providers/admin_providers.dart';
import 'package:tubigon_tourism/features/lgupage/providers/lgu_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminSpotsProvider.overrideWith((ref) async => [
                {
                  'id': 'spot-1',
                  'name': 'Tubigon Heritage Walk',
                  'average_rating': 4.8,
                  'is_active': true,
                  'category': {
                    'id': 'category-1',
                    'name': 'Cultural Attraction',
                  },
                },
              ]),
          adminCategoriesProvider.overrideWith((ref) async => [
                {
                  'id': 'category-1',
                  'name': 'Cultural Attraction',
                  'slug': 'cultural-attraction',
                },
              ]),
          adminEmergencyProvider.overrideWith((ref) async => [
                {
                  'id': 'contact-1',
                  'agency_name': 'Tubigon Emergency Operations Center',
                  'contact_number': '911',
                },
              ]),
          lguFerrySchedulesProvider.overrideWith((ref) async => const []),
          lguEcoTipsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const AdminTourismManagementPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tourist spots render and add dialog opens without layout errors',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('Tubigon Heritage Walk'), findsOneWidget);
    expect(find.text('Add Tourist Spot'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Add Tourist Spot'));
    await tester.pumpAndSettle();

    expect(find.text('Spot Name'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all management tabs expose their operational controls',
      (tester) async {
    await pumpPage(tester);

    await tester.tap(find.widgetWithText(Tab, 'Spot Categories'));
    await tester.pumpAndSettle();
    expect(find.text('Cultural Attraction'), findsOneWidget);
    expect(find.text('Add Category'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('add-spot-category')));
    await tester.pumpAndSettle();
    expect(find.text('Add Spot Category'), findsOneWidget);
    expect(find.text('Save Category'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Ferry Schedules'));
    await tester.pumpAndSettle();
    expect(find.text('Ferry Schedule Management'), findsOneWidget);
    expect(find.text('Routes / Ports'), findsOneWidget);
    expect(find.text('Add Ferry Schedule'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(Tab, 'Emergency Contacts'));
    await tester.pumpAndSettle();
    expect(find.text('Manage Emergency Contacts'), findsOneWidget);
    expect(find.text('Tubigon Emergency Operations Center'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(Tab, 'Eco Guidelines'));
    await tester.pumpAndSettle();
    expect(find.text('Eco-Tourism Guidance'), findsOneWidget);
    expect(find.text('Create Eco Tip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
