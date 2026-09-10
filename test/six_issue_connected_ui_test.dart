import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tubigon_tourism/features/admin/presentation/pages/admin_announcements_page.dart';
import 'package:tubigon_tourism/features/admin/providers/admin_providers.dart';
import 'package:tubigon_tourism/features/authentication/auth_provider.dart';
import 'package:tubigon_tourism/features/connected_operations/data/connected_operations_repository.dart';
import 'package:tubigon_tourism/features/connected_operations/presentation/announcement_placement.dart';
import 'package:tubigon_tourism/features/connected_operations/presentation/concerns_pages.dart';
import 'package:tubigon_tourism/features/connected_operations/presentation/dynamic_booking_page.dart';
import 'package:tubigon_tourism/features/connected_operations/presentation/partner_destination_operations_page.dart';
import 'package:tubigon_tourism/features/connected_operations/presentation/public_spot_gallery.dart';
import 'package:tubigon_tourism/features/connected_operations/presentation/reservation_conversation.dart';
import 'package:tubigon_tourism/features/ferry/models/ferry.dart';
import 'package:tubigon_tourism/features/ferry/repositories/ferry_repository.dart';
import 'package:tubigon_tourism/features/lgupage/presentation/pages/lgu_ferry_management_page.dart';
import 'package:tubigon_tourism/features/lgupage/providers/lgu_providers.dart';
import 'package:tubigon_tourism/features/userpage/presentation/pages/ferry_schedule_page.dart';
import 'package:tubigon_tourism/features/userpage/presentation/pages/tourist_dashboard_page.dart';
import 'package:tubigon_tourism/features/userpage/presentation/pages/tourist_spots_page.dart';
import 'package:tubigon_tourism/features/userpage/presentation/user_shell.dart';
import 'package:tubigon_tourism/core/network/connectivity_provider.dart';
import 'package:tubigon_tourism/features/map/providers/map_provider.dart';
import 'package:tubigon_tourism/features/notifications/repositories/notification_repository.dart';
import 'package:tubigon_tourism/features/reservations/repositories/reservation_repository.dart';
import 'package:tubigon_tourism/features/settings/repositories/settings_repository.dart';
import 'package:tubigon_tourism/features/tourist_spots/repositories/tourist_spot_repository.dart';
import 'package:tubigon_tourism/features/tourism_partner/providers/tourism_partner_providers.dart';

final _announcementItemsProvider =
    StateProvider<List<Map<String, dynamic>>>((ref) => const []);
final _bookingPayloadProvider = StateProvider<Map<String, dynamic>>(
  (ref) => const {
    'data': [],
    'meta': {'booking_enabled': true}
  },
);

class _TouristAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isLoggedIn: true,
        role: UserRole.tourist,
        userId: 'tourist-test',
        name: 'Test Tourist',
      );
}

Widget _app(Widget child, List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: ThemeData.dark(), home: child),
    );

void main() {
  testWidgets('Home, Explore, and Map shell routes survive 20 navigation loops',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (context, state, child) => UserShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const TouristDashboardPage(),
            ),
            GoRoute(
              path: '/explore',
              builder: (context, state) => const TouristSpotsPage(),
            ),
            GoRoute(
              path: '/map',
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Map lifecycle boundary')),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(_TouristAuth.new),
        touristSpotsListProvider.overrideWith((ref) async => const []),
        reservationsListProvider.overrideWith((ref) async => const []),
        touristNotificationsProvider.overrideWith((ref) async => const []),
        systemSettingsProvider.overrideWith((ref) async => const {}),
        publicAnnouncementsProvider(false)
            .overrideWith((ref) async => const []),
        mapMarkersProvider.overrideWith((ref) async => const []),
        mapPlaceCategoriesProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp.router(
        theme: ThemeData.dark(),
        routerConfig: router,
      ),
    ));
    await tester.pump();
    await tester.pump();

    for (var iteration = 0; iteration < 20; iteration++) {
      for (final route in ['/explore', '/map', '/explore', '/home']) {
        router.go(route);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 25));
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('dashboard announcement placement remains a valid sliver child',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(
      const TouristDashboardPage(),
      [
        authProvider.overrideWith(_TouristAuth.new),
        touristSpotsListProvider.overrideWith((ref) async => const []),
        reservationsListProvider.overrideWith((ref) async => const []),
        touristNotificationsProvider.overrideWith((ref) async => const []),
        systemSettingsProvider.overrideWith((ref) async => const {}),
        publicAnnouncementsProvider(false).overrideWith((ref) async => [
              {
                'id': 'announcement-sliver',
                'title': 'Port Advisory',
                'body': 'Board at the designated gate.',
                'priority': 'important',
                'category': 'ferry',
                'display_type': 'carousel',
              }
            ]),
      ],
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byType(AnnouncementPlacement), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(AnnouncementPlacement),
        matching: find.byType(SliverToBoxAdapter),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('dynamic booking renders offering controls and price preview',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(
      const DynamicBookingPage(spotId: 'spot-1'),
      [
        authProvider.overrideWith(_TouristAuth.new),
        publicOfferingsProvider('spot-1').overrideWith((ref) async => {
              'data': [
                {
                  'id': 'offering-1',
                  'type': 'cottage',
                  'display_name': 'Family Cottage',
                  'price': 500,
                  'pricing_mode': 'per_cottage',
                  'min_quantity': 1,
                  'max_quantity': 2,
                  'fields': [
                    {
                      'field_key': 'guest_count',
                      'label': 'Guests',
                      'field_type': 'guest_count',
                      'is_required': true,
                    }
                  ],
                }
              ],
              'meta': {'booking_enabled': true},
              'offline': false,
            }),
      ],
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('Family Cottage'), findsOneWidget);
    expect(find.textContaining('Estimated total'), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(find.text('Guests *'), findsOneWidget);
    expect(find.text('Review and Submit'), findsOneWidget);
  });

  testWidgets('dynamic booking safely reconciles changed offering fields',
      (tester) async {
    final Map<String, dynamic> first = {
      'data': [
        {
          'id': 'offering-a',
          'type': 'cottage',
          'display_name': 'Cottage A',
          'price': 500,
          'pricing_mode': 'per_cottage',
          'fields': [
            {
              'field_key': 'guest_count',
              'label': 'Guests',
              'field_type': 'guest_count',
            }
          ],
        }
      ],
      'meta': {'booking_enabled': true},
    };
    final Map<String, dynamic> second = {
      'data': [
        {
          'id': 'offering-b',
          'type': 'tour',
          'display_name': 'Tour B',
          'price': 250,
          'pricing_mode': 'per_person',
          'fields': [
            {
              'field_key': 'adult_count',
              'label': 'Adults',
              'field_type': 'adult_count',
            }
          ],
        }
      ],
      'meta': {'booking_enabled': true},
    };
    final container = ProviderContainer(
      overrides: [
        _bookingPayloadProvider.overrideWith((ref) => first),
        authProvider.overrideWith(_TouristAuth.new),
        publicOfferingsProvider('spot-changing').overrideWith(
          (ref) async => ref.watch(_bookingPayloadProvider),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: const DynamicBookingPage(spotId: 'spot-changing'),
      ),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('Cottage A'), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(find.text('Guests'), findsOneWidget);

    container.read(_bookingPayloadProvider.notifier).state = second;
    await tester.pump();
    await tester.pump();
    expect(find.text('Cottage A'), findsNothing);
    expect(find.text('Tour B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('partner destination exposes offerings and gallery management',
      (tester) async {
    await tester.pumpWidget(_app(
      const PartnerDestinationOperationsPage(),
      [
        currentPartnerAssignmentProvider.overrideWith((ref) async => {
              'destination': {'id': 'spot-1', 'name': 'Assigned Beach'}
            }),
        partnerOfferingsProvider('spot-1')
            .overrideWith((ref) async => const []),
        partnerGalleryProvider('spot-1').overrideWith((ref) async => const []),
      ],
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('Booking Offerings'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Add Offering'), findsOneWidget);
    DefaultTabController.of(tester.element(find.byType(TabBar))).animateTo(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Add Photo'), findsOneWidget);
  });

  testWidgets('public gallery opens a swipe and zoom viewer', (tester) async {
    await tester.pumpWidget(_app(
      const Scaffold(body: PublicSpotGallery(spotId: 'spot-1')),
      [
        publicGalleryProvider('spot-1').overrideWith((ref) async => [
              {
                'id': 'photo-1',
                'url': 'https://example.invalid/photo.jpg',
                'caption': 'Sunset view'
              }
            ]),
      ],
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('View All (1)'), findsOneWidget);
    for (var iteration = 0; iteration < 3; iteration++) {
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'View All (1)'))
          .onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('Sunset view'), findsOneWidget);
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'reservation conversation distinguishes system and internal notes',
      (tester) async {
    await tester.pumpWidget(_app(
      const Scaffold(
          body: ReservationConversation(
              reservationId: 'reservation-1', partner: true)),
      [
        reservationMessagesProvider('reservation-1')
            .overrideWith((ref) async => [
                  {
                    'message': 'Reservation Confirmed',
                    'message_type': 'system_update',
                    'is_internal': false,
                  },
                  {
                    'message': 'Prepare cottage keys',
                    'message_type': 'partner_message',
                    'is_internal': true,
                  },
                ]),
      ],
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('Reservation Confirmed'), findsOneWidget);
    expect(find.text('Prepare cottage keys'), findsOneWidget);
    expect(find.textContaining('Internal'), findsWidgets);
  });

  testWidgets('public ferry page displays status and stale offline copy',
      (tester) async {
    await tester.pumpWidget(_app(
      const FerrySchedulePage(),
      [
        isOnlineProvider.overrideWithValue(false),
        ferrySchedulesListProvider.overrideWith((ref) async => const [
              Ferry(
                id: 1,
                uuid: 'ferry-1',
                operator: 'Verified Ferries',
                route: 'Tubigon to Cebu',
                departure: '08:00',
                arrival: '10:00',
                duration: '2h 00m',
                fare: 500,
                status: 'delayed',
                days: ['monday'],
                advisory: 'Weather delay',
              )
            ]),
      ],
    ));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Showing saved information'), findsOneWidget);
    expect(find.text('DELAYED'), findsOneWidget);
    expect(find.textContaining('Weather delay'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('concerns screen shows queue and structured submit form',
      (tester) async {
    await tester.pumpWidget(_app(
      const ConcernsPage(),
      [
        myConcernsProvider.overrideWith((ref) async => const []),
        concernCategoriesProvider.overrideWith((ref) async => [
              {
                'id': 'category-1',
                'name': 'Ferry Schedule',
                'redirect_feature': null,
              }
            ]),
      ],
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('No concerns submitted.'), findsOneWidget);
    await tester.tap(find.text('Submit Concern'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Related to (optional)'), findsOneWidget);
    expect(find.textContaining('Attach an image'), findsOneWidget);
  });

  testWidgets('announcement placement prioritizes urgent targeted alert',
      (tester) async {
    await tester.pumpWidget(_app(
      const Scaffold(body: AnnouncementPlacement()),
      [
        authProvider.overrideWith(_TouristAuth.new),
        publicAnnouncementsProvider(false).overrideWith((ref) async => [
              {
                'id': 'announcement-1',
                'title': 'Weather Advisory',
                'body': 'Travel only when cleared.',
                'priority': 'urgent',
                'category': 'safety',
                'display_type': 'urgent_alert',
              }
            ]),
      ],
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('Weather Advisory'), findsOneWidget);
    expect(find.text('URGENT'), findsOneWidget);
  });

  testWidgets('announcement carousel clamps its page when the feed shrinks',
      (tester) async {
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TouristAuth.new),
      publicAnnouncementsProvider(false).overrideWith(
        (ref) async => ref.watch(_announcementItemsProvider),
      ),
    ]);
    addTearDown(container.dispose);
    container.read(_announcementItemsProvider.notifier).state = List.generate(
      3,
      (index) => {
        'id': 'slide-$index',
        'title': 'Slide $index',
        'body': 'Announcement body',
        'priority': 'important',
        'category': 'general',
        'display_type': 'carousel',
      },
    );
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(body: AnnouncementPlacement()),
      ),
    ));
    await tester.pump();
    await tester.pump();
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pump(const Duration(milliseconds: 400));

    container.read(_announcementItemsProvider.notifier).state = const [
      {
        'id': 'slide-0',
        'title': 'Only slide',
        'body': 'Announcement body',
        'priority': 'important',
        'category': 'general',
        'display_type': 'carousel',
      }
    ];
    await tester.pump();
    await tester.pump();
    expect(find.text('Only slide'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('LGU ferry form uses controlled structured inputs',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(
      const LguFerryManagementPage(),
      [
        lguFerrySchedulesProvider.overrideWith((ref) async => const []),
        lguFerryCatalogsProvider.overrideWith((ref) async => {
              'ports': const [],
              'routes': [
                {'id': 'route-1', 'name': 'Tubigon – Cebu'}
              ],
              'statuses': const [],
            }),
      ],
    ));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Add Ferry Schedule'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Ferry Route *'), findsOneWidget);
    expect(find.text('Operator *'), findsOneWidget);
    expect(find.text('Status *'), findsOneWidget);
    expect(find.textContaining('Departure:'), findsOneWidget);
  });

  testWidgets('Admin announcement composer supports audience and scheduling',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(
      const AdminAnnouncementsPage(),
      [adminAnnouncementsProvider.overrideWith((ref) async => const [])],
    ));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Create Announcement'));
    await tester.pump();
    expect(find.text('Guests/Public'), findsNothing);
    expect(find.text('Public'), findsOneWidget);
    expect(find.text('Priority'), findsOneWidget);
    expect(find.text('Display'), findsOneWidget);
    expect(find.text('Start date/time'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
  });
}
