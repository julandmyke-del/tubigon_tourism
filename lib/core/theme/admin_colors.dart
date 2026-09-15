import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Design tokens and colors for the redesigned Admin interface.
abstract final class AdminColors {
  // Navy Palette
  static Color get navy950 => AppColors.background;
  static Color get navy900 => AppColors.surface;
  static Color get navy800 => AppColors.surfaceVariant;
  static Color get navy700 => AppColors.isDark
      ? const Color(0xFF162A52)
      : const Color(0xFFE5EAF1);
  static Color get navy600 => AppColors.isDark
      ? const Color(0xFF1E3A6E)
      : const Color(0xFFD9E2EF);

  // Backgrounds & Surface Cards
  static Color get sidebarBg => AppColors.surface;
  static Color get topbarBg => AppColors.surface.withValues(alpha: 0.94);
  static Color get cardBg => AppColors.surface;
  static Color get cardBorder => AppColors.outline;
  static Color get border => AppColors.outline;

  // Accent Orange & Glows
  static const Color orange = Color(0xFFF97316);
  static const Color orangeHover = Color(0xFFEA6C00);
  static const Color orangeDim = Color(0x26F97316); // rgba(249, 115, 22, 0.15)
  static const Color orangeGlow = Color(0x40F97316); // rgba(249, 115, 22, 0.25)
  static const Color borderActive =
      Color(0x80F97316); // rgba(249, 115, 22, 0.5)

  // Typography
  static Color get textPrimary => AppColors.onSurface;
  static Color get textSecondary => AppColors.onSurfaceVariant;
  static Color get textMuted => AppColors.isDark
      ? const Color(0xFF4A5F84)
      : const Color(0xFF64748B);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color successBg = Color(0x1A10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0x1AF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerBg = Color(0x1AEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoBg = Color(0x1A3B82F6);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color purpleBg = Color(0x1A8B5CF6);

  // Card Decoration Helper
  static BoxDecoration glassDecoration({
    BorderRadiusGeometry borderRadius =
        const BorderRadius.all(Radius.circular(12)),
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: cardBg,
      borderRadius: borderRadius,
      border: Border.all(color: borderColor ?? cardBorder, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: AppColors.isDark ? .25 : .08),
          blurRadius: 24,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
