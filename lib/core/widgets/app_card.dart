import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_shadows.dart';

/// Reusable card with rounded corners, soft shadow, optional gradient header,
/// and a press-down micro-animation.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.gradient,
    this.shadow,
    this.border,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Gradient? gradient;
  final List<BoxShadow>? shadow;
  final Border? border;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(AppSpacing.radiusXl);

    final inner = Container(
      decoration: BoxDecoration(
        color: backgroundColor ??
            (isDark ? AppColors.darkSurface : AppColors.lightSurface),
        gradient: gradient,
        borderRadius: radius,
        border: border ??
            Border.all(
              color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
              width: 1,
            ),
        boxShadow: shadow ?? AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: clipBehavior,
        child:
            padding != null ? Padding(padding: padding!, child: child) : child,
      ),
    );

    if (margin != null) {
      return Padding(padding: margin!, child: _wrapTappable(inner));
    }
    return _wrapTappable(inner);
  }

  Widget _wrapTappable(Widget inner) {
    if (onTap == null) return inner;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            borderRadius ?? BorderRadius.circular(AppSpacing.radiusXl),
        child: inner,
      ),
    );
  }
}
