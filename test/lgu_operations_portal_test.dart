import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tubigon_tourism/core/routes/route_names.dart';
import 'package:tubigon_tourism/features/authentication/auth_provider.dart';
import 'package:tubigon_tourism/features/lgupage/presentation/lgu_shell.dart';
import 'package:tubigon_tourism/features/lgupage/presentation/pages/lgu_dashboard_page.dart';
import 'package:tubigon_tourism/features/lgupage/providers/lgu_providers.dart';
import 'package:tubigon_tourism/features/notifications/repositories/notification_repository.dart';
import 'package:tubigon_tourism/features/settings/repositories/settings_repository.dart';

class _LguAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isLoggedIn: true,
        role: UserRole.lguStaff,
        name: 'Test LGU Staff',
        email: 'lgu@example.test',
        userId: 'lgu-id',
      );
}

const _dashboardData = <String, dynamic>{
  'totalSpots': 8,
  'activeSpots': 7,
  'verifiedMsmes': 12,
  'totalMsmes': 15,
  'activeReservations': 4,
  'pendingWasteReports': 2,
  'resolvedWasteReports': 9,
  'activeAnnouncements': 3,
  'actionCenter': <String, dynamic>{
    'msmesAwaitingReview': 3,
    'emergencyContactsNeedingVerification': 1,
    'wasteReportsAwaitingReview': 2,
    'mapLocationsNeedingReview': 2,
  },
  'operationalAlerts': <Map<String, dynamic>>[
    <String, dynamic>{
      'message': '3 MSME applications await review.',
      'route': '/lgu/msme',
    },
  ],
  'recentActivity': <Map<String, dynamic>>[
    <String, dynamic>{
      'action': 'MSME review verified',
      'target': 'BAZAK Food Park',
      'actor': 'LGU Reviewer',
      'created_at': '2026-09-01T09:00:00+08:00',
    },
  ],
  'lastSyncedAt': '2026-09-01T10:00:00+08:00',
};

void main() {
  testWidgets('LGU dashboard renders authoritative KPI and activity data',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        lguDashboardStatsProvider.overrideWith((_) async => _dashboardData),
      ],
      child: const MaterialApp(home: LguDashboardPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Municipal Operations Command Center'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.textContaining('BAZAK Food Park'), findsWidgets);
    expect(find.text('3 MSME applications await review.'), findsOneWidget);
  });

  testWidgets('LGU dashboard has visible loading and error states',
      (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        lguDashboardStatsProvider.overrideWith((_) => pending.future),
      ],
      child: const MaterialApp(home: LguDashboardPage()),
    ));
    await tester.pump();
    expect(find.byKey(const Key('lgu-dashboard-skeleton')), findsOneWidget);

    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        lguDashboardStatsProvider
            .overrideWith((_) => Future<Map<String, dynamic>>.error('offline')),
      ],
      child: const MaterialApp(home: LguDashboardPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lgu-dashboard-error-state')), findsOneWidget);
    expect(find.textContaining('could not be loaded'), findsOneWidget);
  });

  testWidgets('LGU peer routes always render Dashboard again', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    Widget page(String label) => Scaffold(body: Text(label));
    final router = GoRouter(
      initialLocation: '/lgu',
      routes: [
        ShellRoute(
          builder: (_, __, child) => LguShell(child: child),
          routes: [
            GoRoute(
              path: '/lgu',
              name: RouteNames.lguDashboard,
              builder: (_, __) => page('lgu-dashboard-content'),
            ),
            GoRoute(
                path: '/lgu/tourist-spots',
                builder: (_, __) => page('spots-content')),
            GoRoute(
                path: '/lgu/tourism-monitoring',
                builder: (_, __) => page('activity-content')),
            GoRoute(
                path: '/lgu/msme', builder: (_, __) => page('msme-content')),
            GoRoute(
                path: '/lgu/waste-reports',
                builder: (_, __) => page('waste-content')),
            GoRoute(
                path: '/lgu/announcements',
                builder: (_, __) => page('announcements-content')),
            GoRoute(
                path: '/lgu/analytics',
                builder: (_, __) => page('analytics-content')),
            GoRoute(
                path: '/lgu/reports',
                builder: (_, __) => page('reports-content')),
          ],
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(_LguAuthNotifier.new),
        touristNotificationsProvider.overrideWith((_) async => const []),
        touristUnreadCountProvider.overrideWith((_) async => 0),
        systemSettingsProvider.overrideWith((_) async => const {}),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('lgu-dashboard-content'), findsOneWidget);

    for (final entry in {
      '/lgu/tourist-spots': 'spots-content',
      '/lgu/tourism-monitoring': 'activity-content',
      '/lgu/msme': 'msme-content',
      '/lgu/waste-reports': 'waste-content',
      '/lgu/announcements': 'announcements-content',
      '/lgu/analytics': 'analytics-content',
      '/lgu/reports': 'reports-content',
    }.entries) {
      router.go(entry.key);
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/lgu');
      expect(find.text('lgu-dashboard-content'), findsOneWidget);
    }
  });
}
