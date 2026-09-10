import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/responsive/responsive_layout.dart';
import '../../authentication/auth_provider.dart';
import '../../notifications/presentation/notification_bell_button.dart';
import '../providers/msme_portal_providers.dart';
import 'msme_theme.dart';

class MsmeShell extends ConsumerStatefulWidget {
  const MsmeShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MsmeShell> createState() => _MsmeShellState();
}

class _MsmeShellState extends ConsumerState<MsmeShell> {
  static const double _sidebarWidth = 260.0;

  static final List<_MsmeNavItem> _navItems = [
    const _MsmeNavItem(
        id: 'dashboard',
        label: 'Dashboard',
        icon: Icons.dashboard_rounded,
        route: '/msme-portal'),
    const _MsmeNavItem(
        id: 'profile',
        label: 'Business Profile',
        icon: Icons.store_rounded,
        route: '/msme-portal/profile'),
    const _MsmeNavItem(
        id: 'listings',
        label: 'My Business Listing',
        icon: Icons.inventory_2_rounded,
        route: '/msme-portal/listings'),
    const _MsmeNavItem(
        id: 'reservations',
        label: 'Reservations',
        icon: Icons.calendar_month_rounded,
        route: '/msme-portal/reservations'),
    const _MsmeNavItem(
        id: 'reviews',
        label: 'Customer Reviews',
        icon: Icons.star_rate_rounded,
        route: '/msme-portal/reviews'),
    const _MsmeNavItem(
        id: 'analytics',
        label: 'Business Analytics',
        icon: Icons.analytics_rounded,
        route: '/msme-portal/analytics'),
    const _MsmeNavItem(
        id: 'notifications',
        label: 'Notifications',
        icon: Icons.notifications_rounded,
        route: '/msme-portal/notifications'),
    const _MsmeNavItem(
        id: 'availability',
        label: 'Availability Calendar',
        icon: Icons.edit_calendar_rounded,
        route: '/msme-portal/availability'),
    const _MsmeNavItem(
        id: 'map',
        label: 'Smart Tubigon Map',
        icon: Icons.map_rounded,
        route: '/map'),
  ];

  int _getSelectedIndex(String location) {
    for (int i = _navItems.length - 1; i >= 0; i--) {
      final route = _navItems[i].route;
      if (location == route || (i > 0 && location.startsWith(route))) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final location = GoRouterState.of(context).matchedLocation;
    final activeIndex = _getSelectedIndex(location);
    final activeItem = _navItems[activeIndex];
    final auth = ref.watch(authProvider);
    final current = ref.watch(currentMsmeProvider).valueOrNull;
    final business = current?.business;
    final businessName = business?['name']?.toString();
    final verification = business?['verification_status']?.toString();

    return Scaffold(
      backgroundColor: MsmeTheme.bgDark,
      drawer: isDesktop
          ? null
          : _buildDrawer(
              context, activeIndex, auth, businessName, verification),
      body: Row(
        children: [
          if (isDesktop)
            _buildSidebar(
                context, activeIndex, auth, businessName, verification),
          Expanded(
            child: Column(
              children: [
                _buildTopAppBar(context, activeItem, isDesktop),
                if (location == '/msme-portal') const AnnouncementHighlights(),
                Expanded(
                    child: Container(
                        color: MsmeTheme.bgDark, child: widget.child)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAppBar(
      BuildContext context, _MsmeNavItem activeItem, bool isDesktop) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
          color: Color(0xE6060D1F),
          border:
              Border(bottom: BorderSide(color: Color(0x1AFFFFFF), width: 1))),
      child: Row(
        children: [
          if (!isDesktop)
            IconButton(
                icon:
                    const Icon(Icons.menu_rounded, color: MsmeTheme.textWhite),
                onPressed: () => Scaffold.of(context).openDrawer()),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('MSME Owner Portal',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: MsmeTheme.textDisabled)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 14, color: MsmeTheme.textDisabled),
                const SizedBox(width: 4),
                Text(activeItem.label,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: MsmeTheme.primaryOrange,
                        fontWeight: FontWeight.w600))
              ]),
              const SizedBox(height: 2),
              Text(activeItem.label,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: MsmeTheme.textWhite)),
            ],
          ),
          const Spacer(),
          if (isDesktop)
            Container(
              width: 240,
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08))),
              child: Row(children: [
                const Icon(Icons.search_rounded,
                    size: 18, color: MsmeTheme.textDisabled),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        style: GoogleFonts.inter(
                            fontSize: 13, color: MsmeTheme.textWhite),
                        decoration: InputDecoration(
                            hintText: 'Search portal...',
                            hintStyle: GoogleFonts.inter(
                                fontSize: 13, color: MsmeTheme.textDisabled),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero),
                        onSubmitted: (value) => _searchPortal(context, value)))
              ]),
            ),
          const SizedBox(width: 16),
          NotificationBellButton(
            onViewAll: () => context.go('/msme-portal/notifications'),
            iconColor: MsmeTheme.textMuted,
            badgeColor: MsmeTheme.primaryOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, int activeIndex, AuthState auth,
      String? businessName, String? verification) {
    return Container(
      width: _sidebarWidth,
      decoration: const BoxDecoration(
          gradient: MsmeTheme.sidebarGradient,
          border:
              Border(right: BorderSide(color: Color(0x1AFFFFFF), width: 1))),
      child: Column(
        children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(children: [
                Row(children: [
                  Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          gradient: MsmeTheme.orangeGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x59F97316),
                                blurRadius: 15,
                                offset: Offset(0, 4))
                          ]),
                      child: const Icon(Icons.storefront_rounded,
                          color: Colors.white, size: 22)),
                  const SizedBox(width: 12),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tour Tubigon',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: MsmeTheme.textWhite)),
                        Text('MSME Owner Portal',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: MsmeTheme.primaryOrange))
                      ])
                ]),
                const SizedBox(height: 16),
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: MsmeTheme.primaryOrange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: MsmeTheme.primaryOrange
                                .withValues(alpha: 0.15))),
                    child: Row(children: [
                      CircleAvatar(
                          radius: 16,
                          backgroundColor: MsmeTheme.primaryOrange,
                          child: Text((auth.name ?? 'M')[0].toUpperCase(),
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontSize: 13))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(businessName ?? auth.name ?? 'MSME Owner',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: MsmeTheme.textWhite),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(
                                businessName == null
                                    ? 'Business setup required'
                                    : 'MSME Owner · ${verification?.replaceAll('_', ' ') ?? 'draft'}',
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: MsmeTheme.textMuted))
                          ]))
                    ]))
              ])),
          const Divider(height: 1, color: Color(0x1AFFFFFF)),
          Expanded(
              child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  children: [
                Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text('MANAGEMENT MENU',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: MsmeTheme.textDisabled,
                            letterSpacing: 1.0))),
                ...List.generate(_navItems.length, (idx) {
                  final item = _navItems[idx];
                  final isSelected = idx == activeIndex;
                  return _SidebarTile(
                      item: item,
                      isSelected: isSelected,
                      onTap: () => context.go(item.route));
                })
              ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                InkWell(
                    onTap: () => _showLogoutDialog(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: const BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            color: Colors.transparent),
                        child: Row(children: [
                          const Icon(Icons.logout_rounded,
                              color: MsmeTheme.red, size: 20),
                          const SizedBox(width: 12),
                          Text('Logout',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: MsmeTheme.red))
                        ]))),
                const SizedBox(height: 12),
                Text('Tubigon STIMS v2.0 • MSME',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: MsmeTheme.textDisabled))
              ])),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, int activeIndex, AuthState auth,
      String? businessName, String? verification) {
    return Drawer(
      backgroundColor: MsmeTheme.surfaceDark,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
              decoration:
                  const BoxDecoration(gradient: MsmeTheme.sidebarGradient),
              currentAccountPicture: CircleAvatar(
                  backgroundColor: MsmeTheme.primaryOrange,
                  child: Text((auth.name ?? 'M')[0].toUpperCase(),
                      style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white))),
              accountName: Text(businessName ?? auth.name ?? 'MSME Owner',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              accountEmail: Text(
                  businessName == null
                      ? 'Business setup required'
                      : 'MSME Owner · ${verification?.replaceAll('_', ' ') ?? 'draft'}',
                  style: GoogleFonts.inter(color: MsmeTheme.textMuted))),
          Expanded(
              child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _navItems.length,
                  itemBuilder: (context, idx) {
                    final item = _navItems[idx];
                    final isSelected = idx == activeIndex;
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: Icon(item.icon,
                            color: isSelected
                                ? MsmeTheme.primaryOrange
                                : MsmeTheme.textMuted),
                        title: Text(item.label,
                            style: GoogleFonts.inter(
                                color: isSelected
                                    ? MsmeTheme.primaryOrange
                                    : MsmeTheme.textWhite,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                        selected: isSelected,
                        selectedTileColor:
                            MsmeTheme.primaryOrange.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        onTap: () {
                          context.pop();
                          context.go(item.route);
                        },
                      ),
                    );
                  })),
          const Divider(color: Color(0x1AFFFFFF)),
          ListTile(
              leading: const Icon(Icons.logout_rounded, color: MsmeTheme.red),
              title: Text('Logout',
                  style: GoogleFonts.inter(
                      color: MsmeTheme.red, fontWeight: FontWeight.bold)),
              onTap: () {
                context.pop();
                _showLogoutDialog(context);
              }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _searchPortal(BuildContext context, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return;
    final destination = switch (query) {
      final value
          when value.contains('profile') || value.contains('business') =>
        '/msme-portal/profile',
      final value when value.contains('listing') || value.contains('public') =>
        '/msme-portal/listings',
      final value
          when value.contains('reservation') || value.contains('booking') =>
        '/msme-portal/reservations',
      final value when value.contains('review') || value.contains('rating') =>
        '/msme-portal/reviews',
      final value
          when value.contains('analytic') || value.contains('performance') =>
        '/msme-portal/analytics',
      final value
          when value.contains('notification') ||
              value.contains('announcement') =>
        '/msme-portal/notifications',
      final value
          when value.contains('availability') ||
              value.contains('calendar') ||
              value.contains('hours') =>
        '/msme-portal/availability',
      final value when value.contains('map') || value.contains('location') =>
        '/map',
      _ => null,
    };
    if (destination != null) {
      context.go(destination);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'No portal section matched. Try profile, reservations, reviews, analytics, availability, or map.')));
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: MsmeTheme.cardDark,
              title: Text('Confirm Logout',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              content: Text(
                  'Are you sure you want to log out of the MSME Owner Portal?',
                  style: GoogleFonts.inter(color: MsmeTheme.textMuted)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(color: MsmeTheme.textMuted))),
                ElevatedButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await ref.read(authProvider.notifier).signOut();
                      if (context.mounted) {
                        context.go('/onboarding?page=5&login=true');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: MsmeTheme.red),
                    child: Text('Logout',
                        style: GoogleFonts.inter(
                            color: Colors.white, fontWeight: FontWeight.bold)))
              ],
            ));
  }
}

class _MsmeNavItem {
  final String id;
  final String label;
  final IconData icon;
  final String route;
  const _MsmeNavItem(
      {required this.id,
      required this.label,
      required this.icon,
      required this.route});
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile(
      {required this.item, required this.isSelected, required this.onTap});
  final _MsmeNavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: isSelected
                    ? MsmeTheme.primaryOrange.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isSelected
                        ? MsmeTheme.primaryOrange.withValues(alpha: 0.25)
                        : Colors.transparent)),
            child: Row(children: [
              Icon(item.icon,
                  color: isSelected
                      ? MsmeTheme.primaryOrange
                      : MsmeTheme.textMuted,
                  size: 20),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(item.label,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isSelected
                              ? MsmeTheme.primaryOrange
                              : MsmeTheme.textMuted,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500))),
            ]),
          )),
    );
  }
}
