import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

/// A premium AppBar with an optional gradient background, hero title, and
/// consistent styling matching the Tubigon design system.
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GradientAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.gradient,
    this.backgroundColor,
    this.foregroundColor = AppColors.white,
    this.actions,
    this.leading,
    this.showBack = true,
    this.centerTitle = false,
    this.elevation = 0,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color foregroundColor;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  final bool centerTitle;
  final double elevation;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (subtitle != null ? 20 : 0) + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final hasGradient = gradient != null || backgroundColor == null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: hasGradient ? (gradient ?? AppGradients.primary) : null,
          color: backgroundColor,
          boxShadow: elevation > 0
              ? [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.1),
                    blurRadius: elevation * 2,
                    offset: Offset(0, elevation),
                  )
                ]
              : null,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: kToolbarHeight + (subtitle != null ? 20 : 0),
                child: Row(
                  children: [
                    if (showBack && Navigator.canPop(context))
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: foregroundColor,
                          size: 20,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      )
                    else if (leading != null)
                      leading!
                    else
                      const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: centerTitle
                          ? Center(child: _buildTitle())
                          : _buildTitle(),
                    ),
                    if (actions != null) ...actions!,
                    if (actions == null) const SizedBox(width: AppSpacing.md),
                  ],
                ),
              ),
              if (bottom != null) bottom!,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.titleLarge.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: AppTypography.bodySmall.copyWith(
              color: foregroundColor.withValues(alpha: 0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}
