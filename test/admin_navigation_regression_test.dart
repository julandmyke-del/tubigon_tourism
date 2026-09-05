import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tubigon_tourism/features/admin/presentation/admin_shell.dart';
import 'package:tubigon_tourism/features/authentication/auth_provider.dart';
import 'package:tubigon_tourism/features/notifications/repositories/notification_repository.dart';
import 'package:tubigon_tourism/features/settings/repositories/settings_repository.dart';

class _AdminAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isLoggedIn: true,
        role: UserRole.admin,
        name: 'Test Admin',
        email: 'admin@example.test',
        userId: 'admin-id',
      );
}

void main() {
  testWidgets('Admin peer routes always render Dashboard again',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    Widget page(String label) => Scaffold(body: Text(label));
    final router = GoRouter(
      initialLocation: '/admin',
      routes: [
        ShellRoute(
          builder: (_, __, child) => AdminShell(child: child),
          routes: [
            GoRoute(
                path: '/admin', builder: (_, __) => page('dashboard-content')),
            GoRoute(
                path: '/admin/users',
                builder: (_, __) => page('users-content')),
            GoRoute(
                path: '/admin/msmes',
                builder: (_, __) => page('msmes-content')),
            GoRoute(
                path: '/admin/tourism',
                builder: (_, __) => page('tourism-content')),
            GoRoute(
                path: '/admin/announcements',
                builder: (_, __) => page('announcements-content')),
            GoRoute(
                path: '/admin/settings',
                builder: (_, __) => page('settings-content')),
            GoRoute(
                path: '/admin/logs', builder: (_, __) => page('logs-content')),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_AdminAuthNotifier.new),
          touristNotificationsProvider.overrideWith((_) async => const []),
          touristUnreadCountProvider.overrideWith((_) async => 0),
          systemSettingsProvider.overrideWith((_) async => const {}),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('dashboard-content'), findsOneWidget);

    for (final entry in {
      '/admin/users': 'users-content',
      '/admin/msmes': 'msmes-content',
      '/admin/tourism': 'tourism-content',
      '/admin/announcements': 'announcements-content',
      '/admin/settings': 'settings-content',
      '/admin/logs': 'logs-content',
    }.entries) {
      router.go(entry.key);
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);

      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/admin');
      expect(find.text('dashboard-content'), findsOneWidget);
    }
  });
}
