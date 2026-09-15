import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'route_names.dart';
import '../../features/authentication/auth_provider.dart';
import '../utils/auth_action_guard.dart';
import '../widgets/portal_capability_notice_page.dart';

// ─── Auth, Splash & Onboarding Imports ──────────────────────────────────────
import '../../features/splash/splash_page.dart';
import '../../features/onboarding/pages/redesign_onboarding_page.dart';
import '../../features/authentication/pages/register_page.dart';
import '../../features/authentication/pages/forgot_password_page.dart';
import '../../features/authentication/pages/reset_password_page.dart';
import '../../features/authentication/pages/email_verification_page.dart';

// ─── Tourist / User Module Imports ──────────────────────────────────────────
import '../../features/userpage/userpage.dart';

// ─── Admin Imports ──────────────────────────────────────────────────────────
import '../../features/admin/presentation/admin_shell.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin/presentation/pages/admin_user_management_page.dart';
import '../../features/admin/presentation/pages/admin_user_detail_page.dart';
import '../../features/admin/presentation/pages/admin_msme_management_page.dart';
import '../../features/admin/presentation/pages/admin_tourism_management_page.dart';
import '../../features/admin/presentation/pages/admin_reservation_management_page.dart';
import '../../features/admin/presentation/pages/admin_reservation_detail_page.dart';
import '../../features/admin/presentation/pages/admin_review_management_page.dart';
import '../../features/admin/presentation/pages/admin_waste_reports_page.dart';
import '../../features/admin/presentation/pages/admin_announcements_page.dart';
import '../../features/admin/presentation/pages/admin_analytics_page.dart';
import '../../features/admin/presentation/pages/admin_settings_page.dart';
import '../../features/admin/presentation/pages/admin_activity_logs_page.dart';

// ─── Tourism Partner Imports ───────────────────────────────────────────────
import '../../features/tourism_partner/presentation/partner_shell.dart';
import '../../features/tourism_partner/presentation/pages/partner_dashboard_page.dart';
import '../../features/tourism_partner/presentation/pages/partner_listings_page.dart';
import '../../features/tourism_partner/presentation/pages/partner_reservations_page.dart';
import '../../features/tourism_partner/presentation/pages/partner_notifications_page.dart';
import '../../features/tourism_partner/presentation/pages/partner_reviews_page.dart';
import '../../features/tourism_partner/presentation/pages/partner_analytics_page.dart';
import '../../features/tourism_partner/presentation/pages/partner_profile_page.dart';

// ─── LGU Staff Imports ───────────────────────────────────────────────────
import '../../features/lgupage/lgupage.dart';
import '../../features/map/presentation/map_location_management_page.dart';
import '../../features/itinerary/presentation/itinerary_list_page.dart';
import '../../features/itinerary/presentation/itinerary_form_page.dart';
import '../../features/itinerary/presentation/itinerary_detail_page.dart';
import '../../features/carbon/presentation/carbon_estimator_page.dart';

// ─── MSME Module Imports ───────────────────────────────────────────────────
import '../../features/msmepage/msmepage.dart';
import '../../features/role_applications/presentation/applicant_role_applications_page.dart';
import '../../features/role_applications/presentation/role_application_review_page.dart';
import '../../features/connected_operations/presentation/dynamic_booking_page.dart';
import '../../features/connected_operations/presentation/partner_destination_operations_page.dart';
import '../../features/connected_operations/presentation/concerns_pages.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');
final _adminShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'admin-shell');
final _partnerShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'partner-shell');
final _lguShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'lgu-shell');
final _msmeShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'msme-shell');

final appRouterProvider = Provider<GoRouter>((ref) {
  final authListenable = _AuthListenable(ref);
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    refreshListenable: authListenable,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final authState = ref.read(authProvider);
      final isAuthenticated = authState.isAuthenticated;
      final isSplash = location == '/splash';
      final isOnboarding = location == '/onboarding';
      final isAuth = location.startsWith('/auth');
      final returnTo = safeTouristReturnRoute(
        state.uri.queryParameters['returnTo'],
      );

      // Guest discovery is authenticated only for public browsing. Account-
      // owned booking routes require a real Sanctum session and retain a safe
      // internal destination through the login flow.
      if (authState.isGuest &&
          (location.startsWith('/reservations') ||
              location.startsWith('/concerns'))) {
        return Uri(
          path: '/onboarding',
          queryParameters: {
            'page': '5',
            'login': 'true',
            'returnTo': state.uri.toString(),
          },
        ).toString();
      }

      // If user is authenticated
      if (isAuthenticated) {
        final role = authState.role;
        final isAdmin = role == UserRole.admin;
        final isPartner = role == UserRole.tourismPartner;
        final isLgu = role == UserRole.lguStaff;
        final isMsme = role == UserRole.msmeOwner;
        final isTourist = role == UserRole.tourist || role == UserRole.guest;

        final roleHome = authState.homeRoute;
        final isSharedMap = location == '/map' || location.startsWith('/map/');

        // Redirect authenticated users away from splash, onboarding, auth, or root screen to their role dashboard
        if (isSplash || isAuth || isOnboarding || location == '/') {
          if (authState.isLoggedIn && returnTo != null) return returnTo;
          if (authState.isGuest && (isAuth || isOnboarding)) return null;
          return roleHome;
        }

        // Strict Tourist / General User Access Enforcement:
        // Users with Tourist/User role can ONLY access Tourist/User pages
        if (isTourist &&
            (location.startsWith('/admin') ||
                location.startsWith('/tourism-partner') ||
                location.startsWith('/lgu') ||
                location.startsWith('/msme-portal'))) {
          return '/home';
        }

        // Admin section protection: Only Admin
        if (location.startsWith('/admin') && !isAdmin) {
          return roleHome;
        }

        // Tourism Partner section protection: Only Partner and Admin
        if (location.startsWith('/tourism-partner') && !isPartner) {
          return roleHome;
        }

        // LGU section protection: Only LGU Staff and Admin
        if (location.startsWith('/lgu') && !isLgu && !isAdmin) {
          return roleHome;
        }

        // MSME Portal section protection: Only MSME Owner can access /msme-portal
        if (location.startsWith('/msme-portal') && !isMsme) {
          return roleHome;
        }

        // Role Home Consistency: Non-tourist users visiting /home get routed to their portal
        if (location == '/home' && !isTourist) {
          return roleHome;
        }

        // Strict Portal Role Isolation: Portal users visiting non-portal routes get redirected to their portal
        if (isMsme && !location.startsWith('/msme-portal') && !isSharedMap) {
          return '/msme-portal';
        }
        if (isLgu && !location.startsWith('/lgu') && !isSharedMap) {
          return '/lgu';
        }
        if (isPartner &&
            !location.startsWith('/tourism-partner') &&
            !isSharedMap) {
          return '/tourism-partner';
        }
        if (isAdmin &&
            !location.startsWith('/admin') &&
            !location.startsWith('/lgu') &&
            !isSharedMap) {
          return '/admin';
        }

        return null;
      }

      // Allow unauthenticated users on splash, onboarding, or auth screens
      if (isSplash || isOnboarding || isAuth) {
        return null;
      }

      // Preserve only a validated internal Tourist destination. This covers a
      // cold deep link as well as Guest browsing, without creating an open
      // redirect or allowing a Tourist login to enter a privileged portal.
      final protectedReturnTo = safeTouristReturnRoute(state.uri.toString());
      return Uri(
        path: '/onboarding',
        queryParameters: {
          'page': '5',
          'login': 'true',
          if (protectedReturnTo != null) 'returnTo': protectedReturnTo,
        },
      ).toString();
    },
    routes: [
      // ── Splash ──────────────────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        name: RouteNames.splash,
        builder: (context, state) => const SplashPage(),
      ),

      // ── Onboarding ──────────────────────────────────────────────────────
      GoRoute(
        path: '/onboarding',
        name: RouteNames.onboarding,
        builder: (context, state) {
          final pageStr = state.uri.queryParameters['page'];
          final initialPage =
              pageStr != null ? (int.tryParse(pageStr) ?? 0) : 0;
          final showLogin = state.uri.queryParameters['login'] == 'true';
          return RedesignOnboardingPage(
            initialPage: initialPage,
            showLoginForm: showLogin,
            returnTo: state.uri.queryParameters['returnTo'],
          );
        },
      ),

      // ── Auth ────────────────────────────────────────────────────────────
      GoRoute(
        path: '/auth/login',
        name: RouteNames.login,
        builder: (context, state) {
          final pageStr = state.uri.queryParameters['page'];
          final initialPage =
              pageStr != null ? (int.tryParse(pageStr) ?? 5) : 5;
          final showLogin = state.uri.queryParameters['login'] != 'false';
          return RedesignOnboardingPage(
            initialPage: initialPage,
            showLoginForm: showLogin,
            returnTo: state.uri.queryParameters['returnTo'],
          );
        },
        routes: [
          GoRoute(
            path: 'register',
            name: RouteNames.register,
            builder: (context, state) => RegisterPage(
              returnTo: state.uri.queryParameters['returnTo'],
            ),
          ),
          GoRoute(
            path: 'forgot-password',
            name: RouteNames.forgotPassword,
            builder: (context, state) => const ForgotPasswordPage(),
          ),
          GoRoute(
            path: 'reset-password',
            name: RouteNames.resetPassword,
            builder: (context, state) => ResetPasswordPage(
              token: state.uri.queryParameters['token'] ?? '',
              email: state.uri.queryParameters['email'] ?? '',
            ),
          ),
          GoRoute(
            path: 'verify-email',
            name: RouteNames.verifyEmail,
            builder: (context, state) {
              final email = state.uri.queryParameters['email'] ?? '';
              return EmailVerificationPage(
                email: email,
                returnTo: state.uri.queryParameters['returnTo'],
              );
            },
          ),
        ],
      ),

      // ── Main Shell (Bottom Nav) ──────────────────────────────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => UserShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: RouteNames.home,
            builder: (context, state) => const TouristDashboardPage(),
          ),
          GoRoute(
            path: '/explore',
            name: RouteNames.explore,
            builder: (context, state) => const TouristSpotsPage(),
            routes: [
              GoRoute(
                path: 'spot/:id',
                name: RouteNames.touristSpotDetail,
                builder: (context, state) => TouristSpotDetailPage(
                  spotId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                ),
              ),
              GoRoute(
                path: 'place/:id',
                name: RouteNames.explorePlaceDetail,
                builder: (context, state) => ExplorePlaceDetailPage(
                  placeId: state.pathParameters['id'] ?? '',
                ),
              ),
              GoRoute(
                path: 'listing/:id',
                builder: (context, state) => TourismListingDetailPage(
                  listingId: state.pathParameters['id'] ?? '',
                ),
              ),
              GoRoute(
                path: 'msme',
                name: RouteNames.msmeDirectory,
                builder: (context, state) => const MsmeDirectoryPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: RouteNames.msmeDetail,
                    builder: (context, state) => MsmeDetailPage(
                      msmeId:
                          int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/map',
            name: RouteNames.map,
            builder: (context, state) => MapPage(
              initialMarkerId: state.uri.queryParameters['marker'],
              startNavigation: state.uri.queryParameters['navigate'] == 'true',
              offlineMode: state.uri.queryParameters['offline'] == 'true',
            ),
            routes: [
              GoRoute(
                path: 'pick',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => MapLocationPickerPage(
                  allowPortServiceArea:
                      state.uri.queryParameters['port_service_area'] == 'true',
                  initialLatitude:
                      double.tryParse(state.uri.queryParameters['lat'] ?? '') ??
                          9.9515,
                  initialLongitude:
                      double.tryParse(state.uri.queryParameters['lng'] ?? '') ??
                          123.9618,
                  title: switch (state.uri.queryParameters['mode']) {
                    'place' => 'Set Place Location',
                    'itinerary' => 'Choose Trip Starting Point',
                    _ => 'Pin Waste Report Location',
                  },
                  instruction: switch (state.uri.queryParameters['mode']) {
                    'place' =>
                      'Tap anywhere on the map or drag the orange pin to set the exact place location within Tubigon.',
                    'itinerary' =>
                      'Choose a safe starting point within Tubigon for this itinerary route.',
                    _ =>
                      'Tap the map or drag the orange pin to the exact report location within Tubigon.',
                  },
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/reservations',
            name: RouteNames.reservations,
            builder: (context, state) => const ReservationsPage(),
            routes: [
              GoRoute(
                path: 'create',
                name: RouteNames.createReservation,
                builder: (context, state) => CreateReservationPage(
                  initialSpotUuid: state.uri.queryParameters['spot'],
                  initialReservableType:
                      state.uri.queryParameters['type'] ?? 'spot',
                  initialReservableId: state.uri.queryParameters['id'],
                  initialName: state.uri.queryParameters['name'],
                  initialPrice:
                      double.tryParse(state.uri.queryParameters['price'] ?? ''),
                ),
              ),
              GoRoute(
                path: 'offering',
                builder: (context, state) => DynamicBookingPage(
                  spotId: state.uri.queryParameters['spot'] ?? '',
                ),
              ),
              GoRoute(
                path: ':uuid',
                name: RouteNames.reservationDetail,
                builder: (context, state) => ReservationDetailPage(
                  reservationUuid: state.pathParameters['uuid'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            name: RouteNames.profile,
            builder: (context, state) => const ProfilePage(),
            routes: [
              GoRoute(
                path: 'edit',
                name: RouteNames.editProfile,
                builder: (context, state) => const EditProfilePage(),
              ),
              GoRoute(
                path: 'settings',
                name: RouteNames.settings,
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
          GoRoute(
            path: '/concerns',
            builder: (context, state) => const ConcernsPage(),
          ),
        ],
      ),

      // ── Full-Screen Routes (outside shell) ───────────────────────────────
      GoRoute(
        path: '/favorites',
        name: RouteNames.favorites,
        builder: (context, state) => const FavoritesPage(),
      ),
      GoRoute(
        path: '/offline-maps',
        name: RouteNames.offlineMaps,
        builder: (context, state) => const OfflineMapsPage(),
      ),
      GoRoute(
        path: '/itineraries',
        name: RouteNames.itinerary,
        builder: (context, state) => const ItineraryListPage(),
        routes: [
          GoRoute(
            path: 'create',
            name: RouteNames.createItinerary,
            builder: (context, state) => const ItineraryFormPage(),
          ),
          GoRoute(
            path: ':id',
            name: RouteNames.itineraryDetail,
            builder: (context, state) => ItineraryDetailPage(
              itineraryId: state.pathParameters['id'] ?? '',
            ),
            routes: [
              GoRoute(
                path: 'map',
                name: RouteNames.itineraryMap,
                builder: (context, state) => MapPage(
                  itineraryId: state.pathParameters['id'],
                  itineraryDay:
                      int.tryParse(state.uri.queryParameters['day'] ?? '') ?? 1,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/carbon-estimator',
        name: RouteNames.carbonEstimator,
        builder: (context, state) => CarbonEstimatorPage(
          initialDistance:
              double.tryParse(state.uri.queryParameters['distance'] ?? ''),
          initialDistanceSource: state.uri.queryParameters['source'],
          itineraryId: state.uri.queryParameters['itinerary'],
          initialLegDistances: (state.uri.queryParameters['legs'] ?? '')
              .split(',')
              .map(double.tryParse)
              .whereType<double>()
              .where((value) => value > 0)
              .toList(growable: false),
        ),
      ),
      GoRoute(
        path: '/ferry',
        name: RouteNames.ferrySchedule,
        builder: (context, state) => const FerrySchedulePage(),
      ),
      GoRoute(
        path: '/notifications',
        name: RouteNames.notifications,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/applications',
        builder: (context, state) => const ApplicantRoleApplicationsPage(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) => ApplicantRoleApplicationsPage(
              initialApplicationId: state.pathParameters['id'],
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/eco-tips',
        name: RouteNames.ecoTips,
        builder: (context, state) => const EcoTipsPage(),
      ),
      GoRoute(
        path: '/emergency',
        name: RouteNames.emergencyContacts,
        builder: (context, state) => const EmergencyContactsPage(),
      ),
      GoRoute(
        path: '/waste-report',
        name: RouteNames.wasteReport,
        builder: (context, state) => const WasteReportPage(),
      ),
      GoRoute(
        path: '/waste-reports',
        name: RouteNames.wasteReportHistory,
        builder: (context, state) => const WasteReportHistoryPage(),
      ),

      // ── Admin Shell (Dashboard sidebar/drawer) ───────────────────────────
      ShellRoute(
        navigatorKey: _adminShellNavigatorKey,
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            name: RouteNames.adminDashboard,
            builder: (context, state) => const AdminDashboardPage(),
          ),
          GoRoute(
            path: '/admin/users',
            name: 'admin-users',
            builder: (context, state) => const AdminUserManagementPage(),
          ),
          GoRoute(
            path: '/admin/access-requests',
            builder: (context, state) =>
                const RoleApplicationReviewPage(admin: true),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => RoleApplicationReviewPage(
                  admin: true,
                  initialId: state.pathParameters['id'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/admin/users/:id/edit',
            builder: (context, state) => AdminUserEditPage(
              userId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/admin/users/:id',
            builder: (context, state) => AdminUserDetailPage(
              userId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/admin/msmes',
            name: 'admin-msmes',
            builder: (context, state) => const AdminMsmeManagementPage(),
          ),
          GoRoute(
            path: '/admin/tourism',
            name: 'admin-tourism',
            builder: (context, state) => const AdminTourismManagementPage(),
          ),
          GoRoute(
            path: '/admin/reservations',
            name: 'admin-reservations',
            builder: (context, state) => const AdminReservationManagementPage(),
          ),
          GoRoute(
            path: '/admin/reservations/:id',
            builder: (context, state) => AdminReservationDetailPage(
              reservationId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/admin/reviews',
            name: 'admin-reviews',
            builder: (context, state) => const AdminReviewManagementPage(),
          ),
          GoRoute(
            path: '/admin/waste-reports',
            name: 'admin-waste-reports',
            builder: (context, state) => const AdminWasteReportsPage(),
          ),
          GoRoute(
            path: '/admin/announcements',
            name: 'admin-announcements',
            builder: (context, state) => const AdminAnnouncementsPage(),
          ),
          GoRoute(
            path: '/admin/concerns',
            builder: (context, state) => const StaffConcernsPage(role: 'admin'),
          ),
          GoRoute(
            path: '/admin/analytics',
            name: RouteNames.analytics,
            builder: (context, state) => const AdminAnalyticsPage(),
          ),
          GoRoute(
            path: '/admin/settings',
            name: 'admin-settings',
            builder: (context, state) => const AdminSettingsPage(),
          ),
          GoRoute(
            path: '/admin/logs',
            name: 'admin-logs',
            builder: (context, state) => const AdminActivityLogsPage(),
          ),
          GoRoute(
            path: '/admin/map-locations',
            name: RouteNames.adminMapLocations,
            builder: (context, state) => const MapLocationManagementPage(),
          ),
          GoRoute(
            path: '/admin/emergency-contacts',
            builder: (context, state) => const LguEmergencyContactsPage(),
          ),
        ],
      ),

      // ── Tourism Partner Shell ─────────────────────────────────────────
      ShellRoute(
        navigatorKey: _partnerShellNavigatorKey,
        builder: (context, state, child) => PartnerShell(child: child),
        routes: [
          GoRoute(
            path: '/tourism-partner',
            name: RouteNames.partnerDashboard,
            builder: (context, state) => const PartnerDashboardPage(),
          ),
          GoRoute(
            path: '/tourism-partner/listings',
            name: RouteNames.partnerListings,
            builder: (context, state) => const PartnerListingsPage(),
            routes: [
              GoRoute(
                path: 'create',
                name: RouteNames.partnerCreateListing,
                builder: (context, state) => const PartnerListingsPage(),
              ),
              GoRoute(
                path: 'edit/:id',
                name: RouteNames.partnerEditListing,
                builder: (context, state) => const PartnerListingsPage(),
              ),
            ],
          ),
          GoRoute(
            path: '/tourism-partner/preview/:id',
            builder: (context, state) => TouristSpotDetailPage(
              spotId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            ),
          ),
          GoRoute(
            path: '/tourism-partner/reservations',
            name: RouteNames.partnerReservations,
            builder: (context, state) => const PartnerReservationsPage(),
          ),
          GoRoute(
            path: '/tourism-partner/destination-operations',
            builder: (context, state) =>
                const PartnerDestinationOperationsPage(),
          ),
          GoRoute(
            path: '/tourism-partner/notifications',
            name: RouteNames.partnerNotifications,
            builder: (context, state) => const PartnerNotificationsPage(),
          ),
          GoRoute(
            path: '/tourism-partner/reviews',
            name: RouteNames.partnerReviews,
            builder: (context, state) => const PartnerReviewsPage(),
          ),
          GoRoute(
            path: '/tourism-partner/analytics',
            name: RouteNames.partnerAnalytics,
            builder: (context, state) => const PartnerAnalyticsPage(),
          ),
          GoRoute(
            path: '/tourism-partner/profile',
            name: RouteNames.partnerProfile,
            builder: (context, state) => const PartnerProfilePage(),
          ),
          GoRoute(
            path: '/tourism-partner/settings',
            name: RouteNames.partnerSettings,
            builder: (context, state) => const PortalCapabilityNoticePage(
              title: 'Partner settings',
              message:
                  'Account preferences are not yet exposed by the server. Your real contact details can be updated from Profile.',
            ),
          ),
          GoRoute(
            path: '/tourism-partner/business',
            name: RouteNames.partnerBusinessInfo,
            builder: (context, state) => const PartnerProfilePage(),
          ),
        ],
      ),

      // ── LGU Staff Shell ───────────────────────────────────────────────
      ShellRoute(
        navigatorKey: _lguShellNavigatorKey,
        builder: (context, state, child) => LguShell(child: child),
        routes: [
          GoRoute(
            path: '/lgu',
            name: RouteNames.lguDashboard,
            builder: (context, state) => const LguDashboardPage(),
          ),
          GoRoute(
            path: '/lgu/tourist-spots',
            name: RouteNames.lguTouristSpots,
            builder: (context, state) => const LguTouristSpotsPage(),
          ),
          GoRoute(
            path: '/lgu/role-applications',
            builder: (context, state) =>
                const RoleApplicationReviewPage(admin: false),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => RoleApplicationReviewPage(
                  admin: false,
                  initialId: state.pathParameters['id'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/lgu/tourism-monitoring',
            builder: (context, state) => const LguTourismMonitoringPage(),
          ),
          GoRoute(
            path: '/lgu/msme',
            name: RouteNames.lguMsme,
            builder: (context, state) => const LguMsmeMonitoringPage(),
          ),
          GoRoute(
            path: '/lgu/reservations',
            name: RouteNames.lguReservations,
            builder: (context, state) => const LguReservationMonitoringPage(),
          ),
          GoRoute(
            path: '/lgu/reviews',
            builder: (context, state) => const PortalCapabilityNoticePage(
              title: 'Community reviews',
              message:
                  'LGU review moderation is not enabled. Reviews remain public, read-only feedback for the business that received them.',
            ),
          ),
          GoRoute(
            path: '/lgu/waste-reports',
            name: RouteNames.lguWasteReports,
            builder: (context, state) => const LguWasteReportsPage(),
          ),
          GoRoute(
            path: '/lgu/waste-reports/:id',
            builder: (context, state) => LguWasteReportDetailPage(
              reportId: state.pathParameters['id'] ?? '',
            ),
          ),
          GoRoute(
            path: '/lgu/waste-map',
            builder: (context, state) => const MapPage(
              initialCategoryKeys: {'waste-reports'},
            ),
          ),
          GoRoute(
            path: '/lgu/emergency',
            name: RouteNames.lguEmergency,
            builder: (context, state) => const LguEmergencyContactsPage(),
          ),
          GoRoute(
            path: '/lgu/ferry',
            name: RouteNames.lguFerry,
            builder: (context, state) => const LguFerryManagementPage(),
          ),
          GoRoute(
            path: '/lgu/eco-tips',
            name: RouteNames.lguEcoTips,
            builder: (context, state) => const LguEcoTipsPage(),
          ),
          GoRoute(
            path: '/lgu/announcements',
            name: RouteNames.lguAnnouncements,
            builder: (context, state) => const LguAnnouncementsPage(),
          ),
          GoRoute(
            path: '/lgu/concerns',
            builder: (context, state) =>
                const StaffConcernsPage(role: 'lgu_staff'),
          ),
          GoRoute(
            path: '/lgu/analytics',
            name: RouteNames.lguAnalytics,
            builder: (context, state) => const LguAnalyticsPage(),
          ),
          GoRoute(
            path: '/lgu/reports',
            name: RouteNames.lguReports,
            builder: (context, state) => const LguReportsPage(),
          ),
          GoRoute(
            path: '/lgu/notifications',
            name: RouteNames.lguNotifications,
            builder: (context, state) => const LguNotificationsPage(),
          ),
          GoRoute(
            path: '/lgu/profile',
            name: RouteNames.lguProfile,
            builder: (context, state) => const PortalCapabilityNoticePage(
              title: 'Officer profile',
              message:
                  'Officer profile editing is not available through the municipal API yet.',
            ),
          ),
          GoRoute(
            path: '/lgu/settings',
            builder: (context, state) => const PortalCapabilityNoticePage(
              title: 'Municipal settings',
              message:
                  'System-wide settings remain restricted to administrators.',
            ),
          ),
          GoRoute(
            path: '/lgu/map-locations',
            name: RouteNames.lguMapLocations,
            builder: (context, state) => const MapLocationManagementPage(),
          ),
        ],
      ),

      // ── MSME Owner Portal Shell ─────────────────────────────────────────
      ShellRoute(
        navigatorKey: _msmeShellNavigatorKey,
        builder: (context, state, child) => MsmeShell(child: child),
        routes: [
          GoRoute(
            path: '/msme-portal',
            name: RouteNames.msmePortalDashboard,
            builder: (context, state) => const MsmePortalDashboardPage(),
          ),
          GoRoute(
            path: '/msme-portal/profile',
            name: RouteNames.msmePortalProfile,
            builder: (context, state) => const MsmePortalProfilePage(),
          ),
          GoRoute(
            path: '/msme-portal/listings',
            name: RouteNames.msmePortalListings,
            builder: (context, state) => const MsmePortalListingsPage(),
            routes: [
              GoRoute(
                path: 'create',
                name: RouteNames.msmePortalCreateListing,
                builder: (context, state) => const MsmePortalProfilePage(),
              ),
              GoRoute(
                path: 'edit/:id',
                name: RouteNames.msmePortalEditListing,
                builder: (context, state) => const MsmePortalProfilePage(),
              ),
            ],
          ),
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: '/msme-portal/preview',
            builder: (context, state) => const MsmeOwnerPreviewPage(),
          ),
          GoRoute(
            path: '/msme-portal/gallery',
            name: RouteNames.msmePortalGallery,
            builder: (context, state) => const PortalCapabilityNoticePage(
              title: 'Business gallery',
              message:
                  'Standalone gallery management is not enabled. Business images are stored with the single business profile.',
            ),
          ),
          GoRoute(
            path: '/msme-portal/reservations',
            name: RouteNames.msmePortalReservations,
            builder: (context, state) => const MsmePortalReservationsPage(),
          ),
          GoRoute(
            path: '/msme-portal/reviews',
            name: RouteNames.msmePortalReviews,
            builder: (context, state) => const MsmePortalReviewsPage(),
          ),
          GoRoute(
            path: '/msme-portal/analytics',
            name: RouteNames.msmePortalAnalytics,
            builder: (context, state) => const MsmePortalAnalyticsPage(),
          ),
          GoRoute(
            path: '/msme-portal/promotions',
            name: RouteNames.msmePortalPromotions,
            builder: (context, state) => const PortalCapabilityNoticePage(
              title: 'Promotions',
              message:
                  'Promotion publishing is not enabled by the server, so no promotional offers are displayed or saved.',
            ),
          ),
          GoRoute(
            path: '/msme-portal/notifications',
            name: RouteNames.msmePortalNotifications,
            builder: (context, state) => const MsmePortalNotificationsPage(),
          ),
          GoRoute(
            path: '/msme-portal/reports',
            name: RouteNames.msmePortalReports,
            builder: (context, state) => const PortalCapabilityNoticePage(
              title: 'Business reports',
              message:
                  'Downloadable report generation is not enabled. Live booking totals remain available in Analytics.',
            ),
          ),
          GoRoute(
            path: '/msme-portal/availability',
            name: RouteNames.msmePortalAvailability,
            builder: (context, state) => const MsmePortalAvailabilityPage(),
          ),
          GoRoute(
            path: '/msme-portal/settings',
            name: RouteNames.msmePortalSettings,
            builder: (context, state) => const PortalCapabilityNoticePage(
              title: 'Business settings',
              message:
                  'Business operating hours and availability are managed in Business Profile and Availability.',
            ),
          ),
          GoRoute(
            path: '/msme-portal/help',
            name: RouteNames.msmePortalHelp,
            builder: (context, state) => const PortalCapabilityNoticePage(
              title: 'Help center',
              message:
                  'An online support center has not been configured for this deployment.',
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
  ref.onDispose(() {
    router.dispose();
    authListenable.dispose();
  });
  return router;
});

/// Makes the GoRouter refresh whenever auth state changes.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authProvider, (_, __) {
      if (!hasListeners) return;
      notifyListeners();
    });
  }
}
