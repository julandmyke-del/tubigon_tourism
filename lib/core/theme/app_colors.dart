import 'package:flutter/material.dart';

/// Tour Tubigon — Premium Dark Color Token System
/// Never hardcode colors elsewhere; always reference AppColors.
abstract final class AppColors {
  // Resolved by MaterialApp's builder so legacy role portals that still use
  // shared static tokens participate in immediate light/dark switching.
  static Brightness _brightness = Brightness.dark;

  static void configure(Brightness brightness) => _brightness = brightness;

  static bool get isDark => _brightness == Brightness.dark;
  static Color get background =>
      isDark ? darkBackground : lightBackground;
  static Color get surface => isDark ? darkSurface : lightSurface;
  static Color get surfaceVariant =>
      isDark ? darkSurfaceVariant : lightSurfaceVariant;
  static Color get onBackground =>
      isDark ? darkOnBackground : lightOnBackground;
  static Color get onSurface => isDark ? darkOnSurface : lightOnSurface;
  static Color get onSurfaceVariant =>
      isDark ? grey300 : const Color(0xFF5B6778);
  static Color get outline => isDark ? darkOutline : lightOutline;
  // ─── Brand Primary — Dark Navy Blue ──────────────────────────────────────
  static const Color primary = Color(0xFF0B1F3A);
  static const Color primaryLight = Color(0xFF1B365D);
  static const Color primaryDark = Color(0xFF05101E);
  static const Color primaryContainer = Color(0xFF162A45);

  // ─── Brand Secondary — Dark Slate Gray ────────────────────────────────────
  static const Color secondary = Color(0xFF2B2F36);
  static const Color secondaryLight = Color(0xFF3F444E);
  static const Color secondaryDark = Color(0xFF1A1C20);
  static const Color secondaryContainer = Color(0xFF333842);

  // ─── Brand Accent — Warm Orange & Soft Sky Blue ────────────────────────────
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentLight = Color(0xFFFBBF24);
  static const Color accentDark = Color(0xFFD97706);
  static const Color accentContainer = Color(0xFF3D2E14);

  static const Color supportingAccent = Color(0xFF4DA8DA);
  static const Color skyBlue = Color(0xFF4DA8DA);

  // ─── Semantic — Success / Warning / Error / Info ──────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successContainer = Color(0xFF064E3B);
  static const Color warning = Color(0xFFFBBF24);
  static const Color warningContainer = Color(0xFF78350F);
  static const Color error = Color(0xFFDC2626);
  static const Color errorContainer = Color(0xFF7F1D1D);
  static const Color info = Color(0xFF4DA8DA);
  static const Color infoContainer = Color(0xFF0C4A6E);

  // ─── Neutrals ─────────────────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey50 = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF3F4F6);
  static const Color grey200 = Color(0xFFE5E7EB);
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = Color(0xFF6B7280);
  static const Color grey600 = Color(0xFF4B5563);
  static const Color grey700 = Color(0xFF374151);
  static const Color grey800 = Color(0xFF1F2937);
  static const Color grey850 = Color(0xFF182232);
  static const Color grey900 = Color(0xFF111827);

  // ─── Light & Dark Theme Surfaces (Unified Luxury Dark System) ───────────────
  static const Color lightBackground = Color(0xFFF6F7F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFEEF1F5);
  static const Color lightOnBackground = Color(0xFF0B1F3A);
  static const Color lightOnSurface = Color(0xFF27313F);
  static const Color lightOutline = Color(0xFFD6DBE3);

  static const Color darkBackground = Color(0xFF0B1F3A);
  static const Color darkSurface = Color(0xFF1F2937);
  static const Color darkSurfaceVariant = Color(0xFF27313F);
  static const Color darkOnBackground = Color(0xFFFFFFFF);
  static const Color darkOnSurface = Color(0xFFFFFFFF);
  static const Color darkOutline = Color(0x1AFFFFFF);

  // ─── Cards & Containers ───────────────────────────────────────────────────
  static Color get cardBg => surface;
  static Color get surfaceDark => surfaceVariant;

  // ─── Category Colors ──────────────────────────────────────────────────────
  static const Color categoryBeach = Color(0xFF4DA8DA);
  static const Color categoryNature = Color(0xFF10B981);
  static const Color categoryHistorical = Color(0xFFF59E0B);
  static const Color categoryCultural = Color(0xFF8B5CF6);
  static const Color categoryAdventure = Color(0xFFDC2626);
  static const Color categoryFood = Color(0xFFF59E0B);
  static const Color categoryEco = Color(0xFF10B981);
  static const Color categoryAccommodation = Color(0xFF38BDF8);

  // ─── Overlay & Scrim ──────────────────────────────────────────────────────
  static const Color scrim = Color(0x80000000);
  static const Color scrimLight = Color(0x40000000);
  static const Color shimmerBase = Color(0xFF1F2937);
  static const Color shimmerHighlight = Color(0xFF27313F);
}
