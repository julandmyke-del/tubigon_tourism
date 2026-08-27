import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/responsive/responsive_layout.dart';
import '../../authentication/auth_provider.dart';
import 'partner_theme.dart';

class PartnerShell extends ConsumerStatefulWidget {
  const PartnerShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PartnerShell> createState() => _PartnerShellState();
}

class _PartnerShellState extends ConsumerState<PartnerShell> {
  static const double _sidebarWidth = 260.0;

  static final List<_PartnerNavItem> _navItems = [
    _PartnerNavItem(
      id: 'dashboard',
      label: 'Dashboard',
      icon: Icons.dashboard_rounded,
      route: '/tourism-partner',
    ),
    _PartnerNavItem(
      id: 'listings',
      label: 'My Listings',
      icon: Icons.store_rounded,
      route: '/tourism-partner/listings',
    ),
    _PartnerNavItem(
      id: 'reservations',
      label: 'Reservations',
      icon: Icons.calendar_month_rounded,
      route: '/tourism-partner/reservations',
      badgeCount: 5,
    ),
    _PartnerNavItem(
      id: 'reviews',
      label: 'Reviews',
      icon: Icons.star_rate_rounded,
      route: '/tourism-partner/reviews',
    ),
    _PartnerNavItem(
      id: 'notifications',
      label: 'Notifications',
      icon: Icons.notifications_rounded,
      route: '/tourism-partner/notifications',
      badgeCount: 3,
    ),
    _PartnerNavItem(
      id: 'analytics',
      label: 'Analytics',
      icon: Icons.analytics_rounded,
      route: '/tourism-partner/analytics',
    ),
    _PartnerNavItem(
      id: 'profile',
      label: 'Profile',
      icon: Icons.person_rounded,
      route: '/tourism-partner/profile',
    ),
    _PartnerNavItem(
      id: 'settings',
      label: 'Settings',
      icon: Icons.settings_rounded,
      route: '/tourism-partner/settings',
    ),
    _PartnerNavItem(
      id: 'business',
      label: 'Business Info',
      icon: Icons.business_rounded,
      route: '/tourism-partner/business',
    ),
    _PartnerNavItem(
      id: 'map',
      label: 'Smart Tubigon Map',
      icon: Icons.map_rounded,
      route: '/map',
    ),
  ];

  int _getSelectedIndex(String location) {
    for (int i = _navItems.length - 1; i >= 0; i--) {
      final route = _navItems[i].route;
      if (location == route || (i > 0 && location.startsWith(route))) {
        return i;
      }
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

    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      drawer: isDesktop ? null : _buildDrawer(context, activeIndex, auth),
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(context, activeIndex, auth),
          Expanded(
            child: Column(
              children: [
                _buildTopAppBar(context, activeItem, isDesktop),
                Expanded(
                  child: Container(
                    color: PartnerTheme.bgDark,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context, _PartnerNavItem activeItem, bool isDesktop) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xE6060D1F),
        border: Border(
          bottom: BorderSide(color: Color(0x1AFFFFFF), width: 1),
        ),
      ),
      child: Row(
        children: [
          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: PartnerTheme.textWhite),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Partner Portal',
                    style: GoogleFonts.inter(fontSize: 11, color: PartnerTheme.textDisabled),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 14, color: PartnerTheme.textDisabled),
                  const SizedBox(width: 4),
                  Text(
                    activeItem.label,
                    style: GoogleFonts.inter(fontSize: 11, color: PartnerTheme.primaryOrange, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                activeItem.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: PartnerTheme.textWhite,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Search Field (Desktop)
          if (isDesktop)
            Container(
              width: 240,
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 18, color: PartnerTheme.textDisabled),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      style: GoogleFonts.inter(fontSize: 13, color: PartnerTheme.textWhite),
                      decoration: InputDecoration(
                        hintText: 'Search…',
                        hintStyle: GoogleFonts.inter(fontSize: 13, color: PartnerTheme.textDisabled),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 16),

          // Notification Bell
          IconButton(
            onPressed: () => context.go('/tourism-partner/notifications'),
            icon: Badge(
              label: const Text('3'),
              backgroundColor: PartnerTheme.primaryOrange,
              child: const Icon(Icons.notifications_outlined, color: PartnerTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, int activeIndex, AuthState auth) {
    return Container(
      width: _sidebarWidth,
      decoration: const BoxDecoration(
        gradient: PartnerTheme.sidebarGradient,
        border: Border(
          right: BorderSide(color: Color(0x1AFFFFFF), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Logo & Partner Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: PartnerTheme.orangeGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x59F97316),
                            blurRadius: 15,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tubigon Tourism',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: PartnerTheme.textWhite,
                          ),
                        ),
                        Text(
                          'Partner Portal',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: PartnerTheme.primaryOrange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // User Info Box
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PartnerTheme.primaryOrange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: PartnerTheme.primaryOrange.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: PartnerTheme.primaryOrange,
                        child: Text(
                          (auth.name ?? 'E')[0].toUpperCase(),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.name ?? 'Explorer',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: PartnerTheme.textWhite),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Business Partner',
                              style: GoogleFonts.inter(fontSize: 11, color: PartnerTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const PartnerBadge(label: 'Active', type: PartnerBadgeType.green),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x1AFFFFFF)),

          // Navigation Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'MAIN MENU',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: PartnerTheme.textDisabled,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                ...List.generate(_navItems.length, (idx) {
                  final item = _navItems[idx];
                  final isSelected = idx == activeIndex;
                  return _SidebarTile(
                    item: item,
                    isSelected: isSelected,
                    onTap: () => context.go(item.route),
                  );
                }),
              ],
            ),
          ),

          // Logout Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                InkWell(
                  onTap: () => _showLogoutDialog(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.logout_rounded, color: PartnerTheme.red, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'Logout',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: PartnerTheme.red),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tubigon STIMS v2.0 • Partner',
                  style: GoogleFonts.inter(fontSize: 10, color: PartnerTheme.textDisabled),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, int activeIndex, AuthState auth) {
    return Drawer(
      backgroundColor: PartnerTheme.surfaceDark,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: PartnerTheme.sidebarGradient,
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: PartnerTheme.primaryOrange,
              child: Text(
                (auth.name ?? 'E')[0].toUpperCase(),
                style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            accountName: Text(
              auth.name ?? 'Explorer',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            accountEmail: Text(
              auth.email ?? 'partner@tubigontourism.com',
              style: GoogleFonts.inter(color: PartnerTheme.textMuted),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _navItems.length,
              itemBuilder: (context, idx) {
                final item = _navItems[idx];
                final isSelected = idx == activeIndex;
                return ListTile(
                  leading: Icon(
                    item.icon,
                    color: isSelected ? PartnerTheme.primaryOrange : PartnerTheme.textMuted,
                  ),
                  title: Text(
                    item.label,
                    style: GoogleFonts.inter(
                      color: isSelected ? PartnerTheme.primaryOrange : PartnerTheme.textWhite,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: PartnerTheme.primaryOrange.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onTap: () {
                    context.pop();
                    context.go(item.route);
                  },
                );
              },
            ),
          ),
          const Divider(color: Color(0x1AFFFFFF)),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: PartnerTheme.red),
            title: Text('Logout', style: GoogleFonts.inter(color: PartnerTheme.red, fontWeight: FontWeight.bold)),
            onTap: () {
              context.pop();
              _showLogoutDialog(context);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PartnerTheme.cardDark,
        title: Text('Confirm Logout', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to log out of the Tourism Partner portal?',
          style: GoogleFonts.inter(color: PartnerTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.inter(color: PartnerTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) context.go('/onboarding?page=5&login=true');
            },
            style: ElevatedButton.styleFrom(backgroundColor: PartnerTheme.red),
            child: Text('Logout', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _PartnerNavItem {
  final String id;
  final String label;
  final IconData icon;
  final String route;
  final int? badgeCount;

  const _PartnerNavItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
    this.badgeCount,
  });
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _PartnerNavItem item;
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
            color: isSelected ? PartnerTheme.primaryOrange.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? PartnerTheme.primaryOrange.withValues(alpha: 0.25) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                color: isSelected ? PartnerTheme.primaryOrange : PartnerTheme.textMuted,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isSelected ? PartnerTheme.primaryOrange : PartnerTheme.textMuted,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (item.badgeCount != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: PartnerTheme.primaryOrange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${item.badgeCount}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
