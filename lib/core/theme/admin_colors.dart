import 'package:flutter/material.dart';

/// Design tokens and colors for the redesigned Admin interface.
abstract final class AdminColors {
  // Navy Palette
  static const Color navy950 = Color(0xFF060D1A);
  static const Color navy900 = Color(0xFF0A1628);
  static const Color navy800 = Color(0xFF0F2040);
  static const Color navy700 = Color(0xFF162A52);
  static const Color navy600 = Color(0xFF1E3A6E);

  // Backgrounds & Surface Cards
  static const Color sidebarBg = Color(0xFF080F1E);
  static const Color topbarBg = Color(0xDA080F1E);
  static const Color cardBg = Color(0xB20F1932); // rgba(15, 25, 50, 0.7)
  static const Color cardBorder =
      Color(0x12FFFFFF); // rgba(255, 255, 255, 0.07)
  static const Color border = Color(0x12FFFFFF);

  // Accent Orange & Glows
  static const Color orange = Color(0xFFF97316);
  static const Color orangeHover = Color(0xFFEA6C00);
  static const Color orangeDim = Color(0x26F97316); // rgba(249, 115, 22, 0.15)
  static const Color orangeGlow = Color(0x40F97316); // rgba(249, 115, 22, 0.25)
  static const Color borderActive =
      Color(0x80F97316); // rgba(249, 115, 22, 0.5)

  // Typography
  static const Color textPrimary = Color(0xFFF0F4FF);
  static const Color textSecondary = Color(0xFF8899BB);
  static const Color textMuted = Color(0xFF4A5F84);

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
      boxShadow: const [
        BoxShadow(
          color: Color(0x40000000),
          blurRadius: 24,
          offset: Offset(0, 4),
        ),
      ],
    );
  }
}
