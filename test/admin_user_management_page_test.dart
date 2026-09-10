import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/core/theme/app_theme.dart';
import 'package:tubigon_tourism/features/admin/presentation/pages/admin_user_management_page.dart';
import 'package:tubigon_tourism/features/admin/providers/admin_providers.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    required Future<List<Map<String, dynamic>>> Function() loadUsers,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1276, 651);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminUsersProvider.overrideWith((_) => loadUsers()),
          adminRolesProvider.overrideWith((_) async => [
                {'id': 'role-tourist', 'name': 'tourist'},
                {'id': 'role-admin', 'name': 'admin'},
              ]),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: const AdminUserManagementPage(),
        ),
      ),
    );
  }

  testWidgets('desktop registry renders controls, totals, and user actions',
      (tester) async {
    await pumpPage(
      tester,
      loadUsers: () async => [
        {
          'id': 'user-1',
          'name': 'Tourist One',
          'email': 'tourist@example.test',
          'role': 'tourist',
          'is_verified': true,
          'registration_method': 'email',
          'status': 'Active',
          'created_at': '2026-09-09T10:00:00Z',
          'linked_tourist_spots': <Map<String, dynamic>>[],
        },
      ],
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('User Management'), findsOneWidget);
    expect(find.text('Add New User'), findsOneWidget);
    expect(find.text('Total Users'), findsOneWidget);
    expect(find.text('Tourist One'), findsOneWidget);
    expect(find.byTooltip('Edit User Role'), findsOneWidget);
    expect(find.byTooltip('Delete User'), findsOneWidget);

    await tester.tap(find.text('Add New User'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Add New System User'), findsOneWidget);
    expect(find.text('Create User'), findsOneWidget);
  });

  testWidgets('registry failure stays visible and offers retry',
      (tester) async {
    await pumpPage(
      tester,
      loadUsers: () => Future<List<Map<String, dynamic>>>.error(
        StateError('backend unavailable'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Unable to load the user registry.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byTooltip('Refresh users'), findsOneWidget);
  });
}
