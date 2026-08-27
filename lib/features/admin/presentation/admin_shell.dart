import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/responsive_layout.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../authentication/auth_provider.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  static const _menuItems = [
    _AdminMenuItem(
        icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/admin'),
    _AdminMenuItem(
        icon: Icons.people_rounded,
        label: 'User Management',
        route: '/admin/users'),
    _AdminMenuItem(
        icon: Icons.store_rounded,
        label: 'MSME Management',
        route: '/admin/msmes'),
    _AdminMenuItem(
        icon: Icons.landscape_rounded,
        label: 'Tourism Management',
        route: '/admin/tourism'),
    _AdminMenuItem(
        icon: Icons.calendar_month_rounded,
        label: 'Reservations',
        route: '/admin/reservations'),
    _AdminMenuItem(
        icon: Icons.rate_review_rounded,
        label: 'Reviews',
        route: '/admin/reviews'),
    _AdminMenuItem(
        icon: Icons.delete_outline_rounded,
        label: 'Waste Reports',
        route: '/admin/waste-reports'),
    _AdminMenuItem(
        icon: Icons.campaign_rounded,
        label: 'Announcements',
        route: '/admin/announcements'),
    _AdminMenuItem(
        icon: Icons.analytics_rounded,
        label: 'Analytics',
        route: '/admin/analytics'),
    _AdminMenuItem(
        icon: Icons.settings_rounded,
        label: 'Settings',
        route: '/admin/settings'),
    _AdminMenuItem(
        icon: Icons.list_alt_rounded,
        label: 'Activity Logs',
        route: '/admin/logs'),
    _AdminMenuItem(
        icon: Icons.add_location_alt_rounded,
        label: 'Map Locations',
        route: '/admin/map-locations'),
    _AdminMenuItem(icon: Icons.map_rounded, label: 'Smart Map', route: '/map'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _menuItems.length; i++) {
      if (location == _menuItems[i].route) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final auth = ref.watch(authProvider);
    final activeIndex = _currentIndex(context);

    // Sidebar View
    final sidebar = Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AdminColors.sidebarBg,
        border:
            Border(right: BorderSide(color: AdminColors.cardBorder, width: 1)),
      ),
      child: Column(
        children: [
          // Branding Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AdminColors.cardBorder, width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AdminColors.orange,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                          color: AdminColors.orangeGlow,
                          blurRadius: 12,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tubigon Admin',
                      style: AppTypography.titleMedium.copyWith(
                        color: AdminColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Management Portal',
                      style: AppTypography.labelSmall.copyWith(
                          color: AdminColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Navigation Menu Items
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              itemCount: _menuItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, idx) {
                final item = _menuItems[idx];
                final isSelected = idx == activeIndex;
                return _SidebarTile(
                  icon: item.icon,
                  label: item.label,
                  isSelected: isSelected,
                  onTap: () {
                    if (!isDesktop) Navigator.of(context).pop();
                    context.go(item.route);
                  },
                );
              },
            ),
          ),
          // Logout Section at Bottom
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(color: AdminColors.cardBorder, width: 1)),
            ),
            child: _SidebarTile(
              icon: Icons.logout_rounded,
              label: 'Logout System',
              isSelected: false,
              isLogout: true,
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AdminColors.navy900,
                    title: const Text('Confirm Logout',
                        style: TextStyle(color: AdminColors.textPrimary)),
                    content: const Text(
                        'Are you sure you want to end your administrator session?',
                        style: TextStyle(color: AdminColors.textSecondary)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel',
                            style: TextStyle(color: AdminColors.textSecondary)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AdminColors.danger),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Logout',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted)
                    context.go('/onboarding?page=5&login=true');
                }
              },
            ),
          ),
        ],
      ),
    );

    // Top Header Bar
    final topBar = Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AdminColors.topbarBg,
        border:
            Border(bottom: BorderSide(color: AdminColors.cardBorder, width: 1)),
      ),
      child: Row(
        children: [
          if (!isDesktop)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded,
                    color: AdminColors.textPrimary),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          // Municipal Environment Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AdminColors.orangeDim,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AdminColors.borderActive),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: AdminColors.orange, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('TUBIGON MUNICIPALITY',
                    style: TextStyle(
                        color: AdminColors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
          const Spacer(),
          // Notification Bell Icon
          IconButton(
            onPressed: () => context.go('/admin/announcements'),
            icon: Stack(
              children: [
                const Icon(Icons.notifications_none_rounded,
                    color: AdminColors.textSecondary, size: 22),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AdminColors.orange, shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // User Badge
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AdminColors.orangeDim,
                child: Text(
                  (auth.name ?? 'A').substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                      color: AdminColors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (isDesktop)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.name ?? 'Administrator',
                      style: AppTypography.titleMedium.copyWith(
                          color: AdminColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                    const Text('Super Admin',
                        style: TextStyle(
                            color: AdminColors.textSecondary, fontSize: 11)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AdminColors.navy950,
      drawer: isDesktop ? null : Drawer(child: sidebar),
      body: Row(
        children: [
          if (isDesktop) sidebar,
          Expanded(
            child: Column(
              children: [
                topBar,
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMenuItem {
  final IconData icon;
  final String label;
  final String route;

  const _AdminMenuItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isLogout;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.isLogout = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isLogout
        ? AdminColors.danger
        : (isSelected ? AdminColors.orange : AdminColors.textSecondary);

    final bg = isSelected ? AdminColors.orangeDim : Colors.transparent;
    final border = isSelected ? AdminColors.borderActive : Colors.transparent;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
