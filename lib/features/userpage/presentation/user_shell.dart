import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/auth_provider.dart';

class UserShell extends ConsumerWidget {
  const UserShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _TabItem(icon: Icons.home_rounded, label: 'Home', route: '/home'),
    _TabItem(icon: Icons.explore_rounded, label: 'Explore', route: '/explore'),
    _TabItem(icon: Icons.map_rounded, label: 'Map', route: '/map'),
    _TabItem(
        icon: Icons.calendar_month_rounded,
        label: 'Bookings',
        route: '/reservations'),
    _TabItem(icon: Icons.person_rounded, label: 'Profile', route: '/profile'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/explore')) return 1;
    if (location.startsWith('/map')) return 2;
    if (location.startsWith('/reservations')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _currentIndex(context);
    final role = ref.watch(authProvider).role;
    final showTouristNavigation =
        role == UserRole.tourist || role == UserRole.guest;

    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      body: child,
      bottomNavigationBar: showTouristNavigation
          ? _UserBottomNavBar(
              currentIndex: currentIndex,
              tabs: _tabs,
              onTap: (i) {
                if (i != currentIndex) {
                  context.go(_tabs[i].route);
                }
              },
            )
          : null,
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  final String route;

  const _TabItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}

class _UserBottomNavBar extends StatelessWidget {
  const _UserBottomNavBar({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  final int currentIndex;
  final List<_TabItem> tabs;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF1E293B).withValues(alpha: 0.8),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final tab = tabs[i];
              final selected = i == currentIndex;
              return Expanded(
                child: _NavBarItem(
                  icon: tab.icon,
                  label: tab.label,
                  selected: selected,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFFF59E0B);
    const inactiveColor = Color(0xFF64748B);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: selected
                  ? activeColor.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: selected
                  ? Border.all(
                      color: activeColor.withValues(alpha: 0.3), width: 1)
                  : null,
            ),
            child: Icon(
              icon,
              color: selected ? activeColor : inactiveColor,
              size: 22,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'Inter',
              color: selected ? activeColor : inactiveColor,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
