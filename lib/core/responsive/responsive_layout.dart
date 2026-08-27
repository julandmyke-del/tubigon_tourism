import 'package:flutter/material.dart';

/// Breakpoint-aware layout builder.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  static const double _tabletBreakpoint = 600;
  static const double _desktopBreakpoint = 1024;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < _tabletBreakpoint;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= _tabletBreakpoint && w < _desktopBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= _desktopBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _desktopBreakpoint) {
          return desktop ?? tablet ?? mobile;
        }
        if (constraints.maxWidth >= _tabletBreakpoint) {
          return tablet ?? mobile;
        }
        return mobile;
      },
    );
  }
}
