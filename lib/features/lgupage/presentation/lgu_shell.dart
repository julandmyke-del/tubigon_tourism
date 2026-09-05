import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../authentication/auth_provider.dart';
import '../../notifications/presentation/notification_bell_button.dart';

class LguShell extends ConsumerStatefulWidget {
  const LguShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LguShell> createState() => _LguShellState();
}

class _LguShellState extends ConsumerState<LguShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _navyBg = Color(0xFF0B132B);
  static const _cardBg = Color(0xFF1C2541);
  static const _sidebarBg = Color(0xFF0D1B2A);
  static const _accentOrange = Color(0xFFF97316);

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/lgu') return 0;
    if (location.startsWith('/lgu/tourist-spots')) return 1;
    if (location.startsWith('/lgu/tourism-monitoring')) return 2;
    if (location.startsWith('/lgu/reservations')) return 3;
    if (location.startsWith('/lgu/reviews')) return 4;
    if (location.startsWith('/lgu/msme')) return 5;
    if (location.startsWith('/lgu/waste-reports')) return 6;
    if (location.startsWith('/lgu/announcements')) return 7;
    if (location.startsWith('/lgu/eco-tips')) return 8;
    if (location.startsWith('/lgu/emergency')) return 9;
    if (location.startsWith('/lgu/analytics')) return 10;
    if (location.startsWith('/lgu/reports')) return 11;
    if (location.startsWith('/lgu/notifications')) return 12;
    if (location.startsWith('/lgu/profile')) return 13;
    if (location.startsWith('/lgu/settings')) return 14;
    if (location.startsWith('/lgu/map-locations')) return 16;
    if (location.startsWith('/lgu/role-applications')) return 17;
    return 0;
  }

  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        context.goNamed(RouteNames.lguDashboard);
        break;
      case 1:
        context.goNamed(RouteNames.lguTouristSpots);
        break;
      case 2:
        context.go('/lgu/tourism-monitoring');
        break;
      case 3:
        context.goNamed(RouteNames.lguReservations);
        break;
      case 4:
        context.go('/lgu/reviews');
        break;
      case 5:
        context.goNamed(RouteNames.lguMsme);
        break;
      case 6:
        context.goNamed(RouteNames.lguWasteReports);
        break;
      case 7:
        context.goNamed(RouteNames.lguAnnouncements);
        break;
      case 8:
        context.goNamed(RouteNames.lguEcoTips);
        break;
      case 9:
        context.goNamed(RouteNames.lguEmergency);
        break;
      case 10:
        context.goNamed(RouteNames.lguAnalytics);
        break;
      case 11:
        context.goNamed(RouteNames.lguReports);
        break;
      case 12:
        context.goNamed(RouteNames.lguNotifications);
        break;
      case 13:
        context.goNamed(RouteNames.lguProfile);
        break;
      case 14:
        context.go('/lgu/settings');
        break;
      case 15:
        context.go('/map');
        break;
      case 16:
        context.goNamed(RouteNames.lguMapLocations);
        break;
      case 17:
        context.go('/lgu/role-applications');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final location = GoRouterState.of(context).matchedLocation;
    final auth = ref.watch(authProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;

        final shell = Scaffold(
          key: _scaffoldKey,
          backgroundColor: _navyBg,
          drawer: isDesktop
              ? null
              : Drawer(child: _buildSidebar(selectedIndex, isDrawer: true)),
          appBar: AppBar(
            backgroundColor: _cardBg,
            elevation: 0,
            leading: isDesktop
                ? null
                : IconButton(
                    icon:
                        const Icon(Icons.menu_rounded, color: AppColors.white),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs + 2),
                  decoration: BoxDecoration(
                    color: _accentOrange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: _accentOrange.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.account_balance_rounded,
                      color: _accentOrange, size: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Tubigon LGU Portal',
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              NotificationBellButton(
                onViewAll: () => context.goNamed(RouteNames.lguNotifications),
                iconColor: AppColors.grey300,
                badgeColor: _accentOrange,
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.grey850,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.grey700),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 12,
                      backgroundColor: _accentOrange,
                      child: Icon(Icons.person_rounded,
                          size: 14, color: AppColors.white),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      auth.name ?? 'LGU Staff',
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.grey400),
                color: _cardBg,
                onSelected: (value) {
                  if (value == 'logout') {
                    ref.read(authProvider.notifier).logout();
                    if (context.mounted) {
                      context.go('/onboarding?page=5&login=true');
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded,
                            color: Color(0xFFEF4444), size: 18),
                        SizedBox(width: 8),
                        Text('Sign Out',
                            style: TextStyle(color: Color(0xFFEF4444))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
          body: Row(
            children: [
              if (isDesktop)
                SizedBox(
                  width: 260,
                  child: _buildSidebar(selectedIndex, isDrawer: false),
                ),
              Expanded(
                child: Column(
                  children: [
                    if (location == '/lgu') const AnnouncementHighlights(),
                    Expanded(child: widget.child),
                  ],
                ),
              ),
            ],
          ),
        );
        return shell;
      },
    );
  }

  Widget _buildSidebar(int selectedIndex, {required bool isDrawer}) {
    return Container(
      color: _sidebarBg,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: AppColors.white.withValues(alpha: 0.08))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_accentOrange, Color(0xFFFF8C00)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_outlined,
                        color: AppColors.white, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MUNICIPAL LGU',
                          style: AppTypography.labelMedium.copyWith(
                            color: _accentOrange,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          'Tubigon Tourism',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
                children: [
                  _buildNavHeader('OVERVIEW'),
                  _buildNavItem(0, Icons.dashboard_rounded, 'Dashboard',
                      selectedIndex, isDrawer),
                  _buildNavItem(15, Icons.map_rounded, 'Smart Municipal Map',
                      selectedIndex, isDrawer),
                  _buildNavItem(16, Icons.add_location_alt_rounded,
                      'Map Locations', selectedIndex, isDrawer),
                  _buildNavHeader('TOURISM MANAGEMENT'),
                  _buildNavItem(1, Icons.map_rounded, 'Tourist Spots',
                      selectedIndex, isDrawer),
                  _buildNavItem(2, Icons.sensors_rounded, 'Tourism Activity',
                      selectedIndex, isDrawer),
                  _buildNavItem(3, Icons.event_note_rounded, 'Reservations',
                      selectedIndex, isDrawer),
                  _buildNavHeader('OPERATIONS'),
                  _buildNavItem(17, Icons.verified_user_outlined,
                      'Role Applications', selectedIndex, isDrawer),
                  _buildNavItem(5, Icons.storefront_rounded,
                      'MSME Verification', selectedIndex, isDrawer),
                  _buildNavItem(6, Icons.delete_outline_rounded,
                      'Waste Reports', selectedIndex, isDrawer),
                  _buildNavItem(7, Icons.campaign_rounded, 'Announcements',
                      selectedIndex, isDrawer),
                  _buildNavItem(8, Icons.eco_rounded, 'Eco-Tips', selectedIndex,
                      isDrawer),
                  _buildNavItem(9, Icons.phone_in_talk_rounded,
                      'Emergency Contacts', selectedIndex, isDrawer),
                  _buildNavHeader('INSIGHTS'),
                  _buildNavItem(10, Icons.bar_chart_rounded,
                      'Tourism Analytics', selectedIndex, isDrawer),
                  _buildNavItem(11, Icons.assessment_rounded, 'Reports & Stats',
                      selectedIndex, isDrawer),
                  _buildNavHeader('ACCOUNT'),
                  _buildNavItem(12, Icons.notifications_rounded,
                      'Notifications', selectedIndex, isDrawer),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
          left: AppSpacing.sm, top: AppSpacing.sm, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.grey500,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label,
      int selectedIndex, bool isDrawer) {
    final isSelected = index == selectedIndex;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? _accentOrange.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(color: _accentOrange.withValues(alpha: 0.4))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          dense: true,
          leading: Icon(
            icon,
            color: isSelected ? _accentOrange : AppColors.grey400,
            size: 20,
          ),
          title: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.white : AppColors.grey300,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onTap: () {
            if (isDrawer) Navigator.pop(context);
            _onItemTapped(index);
          },
        ),
      ),
    );
  }
}
