import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tubigon_tourism/core/theme/admin_colors.dart';
import 'package:tubigon_tourism/core/theme/app_colors.dart';
import 'package:tubigon_tourism/core/theme/app_theme.dart';
import 'package:tubigon_tourism/features/authentication/auth_provider.dart';
import 'package:tubigon_tourism/features/lgupage/presentation/pages/lgu_msme_monitoring_page.dart';
import 'package:tubigon_tourism/features/lgupage/presentation/pages/lgu_tourist_spots_page.dart';
import 'package:tubigon_tourism/features/lgupage/providers/lgu_providers.dart';
import 'package:tubigon_tourism/features/msmepage/models/msme.dart';
import 'package:tubigon_tourism/features/msmepage/data/msme_portal_repository.dart';
import 'package:tubigon_tourism/features/msmepage/presentation/msme_shell.dart';
import 'package:tubigon_tourism/features/msmepage/presentation/msme_theme.dart';
import 'package:tubigon_tourism/features/msmepage/providers/msme_portal_providers.dart';
import 'package:tubigon_tourism/features/tourist_spots/models/tourist_spot.dart';
import 'package:tubigon_tourism/features/tourist_spots/repositories/review_repository.dart';
import 'package:tubigon_tourism/features/tourist_spots/repositories/tourist_spot_repository.dart';
import 'package:tubigon_tourism/features/tourism_partner/presentation/partner_theme.dart';
import 'package:tubigon_tourism/features/userpage/presentation/pages/msme_detail_page.dart';

class _MsmeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isLoggedIn: true,
        role: UserRole.msmeOwner,
        userId: 'owner-id',
        name: 'Owner',
      );
}

void main() {
  test('light and dark themes expose genuinely different semantic surfaces',
      () {
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(AppTheme.light.scaffoldBackgroundColor,
        isNot(AppTheme.dark.scaffoldBackgroundColor));
    expect(AppTheme.light.colorScheme.onSurface.computeLuminance(),
        lessThan(AppTheme.light.colorScheme.surface.computeLuminance()));
  });

  test('legacy role portal tokens follow the resolved app brightness', () {
    addTearDown(() => AppColors.configure(Brightness.dark));

    AppColors.configure(Brightness.light);
    expect(MsmeTheme.bgDark, AppColors.lightBackground);
    expect(MsmeTheme.cardDark, AppColors.lightSurfaceVariant);
    expect(PartnerTheme.surfaceDark, AppColors.lightSurface);
    expect(AdminColors.cardBg, AppColors.lightSurface);
    expect(AdminColors.textPrimary, AppColors.lightOnSurface);

    AppColors.configure(Brightness.dark);
    expect(MsmeTheme.bgDark, AppColors.darkBackground);
    expect(PartnerTheme.cardDark, AppColors.darkSurfaceVariant);
    expect(AdminColors.textPrimary, AppColors.darkOnSurface);
  });

  test('MSME model retains category identity and gallery for shared preview',
      () {
    final business = Msme.fromJson({
      'id': 'business-uuid',
      'integer_id': 12,
      'name': 'Local Kitchen',
      'category': 'Restaurants',
      'category_id': 'category-uuid',
      'description': 'Local food',
      'images': ['https://example.test/one.jpg'],
      'review_count': 2,
    });

    expect(business.categoryId, 'category-uuid');
    expect(business.images, ['https://example.test/one.jpg']);
  });

  test('review edited indicator uses distinct backend timestamps', () {
    final review = Review(
      id: 'review-id',
      userId: 'tourist-id',
      authorName: 'Tourist',
      reviewableType: 'msme',
      reviewableId: 'business-id',
      rating: 4,
      content: 'Updated review',
      createdAt: '2026-09-15T02:35:00Z',
      updatedAt: '2026-09-15T03:10:00Z',
    );
    expect(review.isEdited, isTrue);
  });

  test('LGU verification status normalization is stable', () {
    expect(normalizeVerificationStatus(' Verified '), 'verified');
    expect(normalizeVerificationStatus('needs changes'), 'needs_changes');
    expect(normalizeVerificationStatus('unexpected'), isNull);
  });

  testWidgets('MSME owner preview renders tourist view with mutations disabled',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const business = Msme(
      id: 1,
      uuid: 'business-id',
      name: 'Preview Business',
      category: 'Restaurants',
      description: 'Preview description',
      reviewCount: 0,
      color: Colors.orange,
      icon: Icons.store,
      tagline: '',
      isVerified: false,
      bookingEnabled: true,
      products: [],
      reviews: [],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MsmeBusinessDetailView(
            business: business,
            previewMode: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tourist Preview'), findsOneWidget);
    expect(find.textContaining('Private preview'), findsOneWidget);
    final reserve = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Reservation disabled in preview'),
    );
    expect(reserve.onPressed, isNull);
    expect(find.byKey(const Key('write-review-action')), findsNothing);
  });

  testWidgets('mobile MSME burger opens the shell drawer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/msme-portal/profile',
      routes: [
        ShellRoute(
          builder: (_, __, child) => MsmeShell(child: child),
          routes: [
            GoRoute(
              path: '/msme-portal/profile',
              builder: (_, __) => const SizedBox(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_MsmeAuthNotifier.new),
          currentMsmeProvider.overrideWith((_) async => const CurrentMsmeState(
                business: null,
                profileRequired: true,
              )),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('msme-navigation-menu')));
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('owner preview does not mutate the authenticated MSME session',
      (tester) async {
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_MsmeAuthNotifier.new),
      currentMsmeProvider.overrideWith((_) async => const CurrentMsmeState(
            business: {
              'id': 'owned-business-id',
              'integer_id': 7,
              'name': 'Owned Preview',
              'category': 'Restaurants',
              'description': 'Private owner preview',
              'review_count': 0,
              'is_verified': false,
            },
            profileRequired: false,
          )),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MsmeOwnerPreviewPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tourist Preview'), findsOneWidget);
    expect(container.read(authProvider).role, UserRole.msmeOwner);
    expect(container.read(authProvider).userId, 'owner-id');
  });

  testWidgets('tourist preview has no overflow at required responsive widths',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const business = Msme(
      id: 2,
      uuid: 'responsive-business',
      name: 'Responsive Accommodation and Restaurant',
      category: 'Accommodation',
      description: 'A responsive business preview.',
      reviewCount: 0,
      color: Colors.orange,
      icon: Icons.hotel,
      tagline: '',
      isVerified: false,
      products: [],
      reviews: [],
    );
    for (final width in [360.0, 390.0, 430.0, 768.0, 1024.0, 1366.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: const MsmeBusinessDetailView(
              business: business,
              previewMode: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets('LGU destination card opens its shared edit action',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final spot = <String, dynamic>{
      'id': 'spot-id',
      'name': 'Mangrove Forest Batasan',
      'address': 'Batasan, Tubigon',
      'is_active': true,
      'booking_enabled': false,
      'category_id': 'category-id',
      'partner_assignments': <dynamic>[],
    };
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lguTouristSpotsProvider.overrideWith((_) async => [spot]),
          spotCategoriesProvider.overrideWith((_) async => [
                SpotCategory(
                  id: 1,
                  uuid: 'category-id',
                  name: 'Nature',
                  slug: 'nature',
                ),
              ]),
        ],
        child: MaterialApp(
            theme: AppTheme.light, home: const LguTouristSpotsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lgu-spot-card-spot-id')));
    await tester.pumpAndSettle();

    expect(find.text('Edit Mangrove Forest Batasan'), findsOneWidget);
    expect(find.text('Category *'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View / edit details'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Mangrove Forest Batasan'), findsOneWidget);
  });
}
