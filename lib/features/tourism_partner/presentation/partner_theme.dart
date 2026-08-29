import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Partner Module Specific Theme & Design Tokens
abstract final class PartnerTheme {
  // Colors (matching CSS design tokens)
  static const Color bgDark = Color(0xFF060D1F);
  static const Color surfaceDark = Color(0xFF0A1628);
  static const Color cardDark = Color(0xFF0F1F3D);
  static const Color cardBorder = Color(0x1AFFFFFF);

  static const Color primaryOrange = Color(0xFFF97316);
  static const Color orangeLight = Color(0xFFFB923C);
  static const Color orangeDark = Color(0xFFEA6C0A);

  static const Color textWhite = Color(0xFFF1F5F9);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textSubtle = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF475569);

  // Status colors
  static const Color green = Color(0xFF22C55E);
  static const Color greenLight = Color(0xFF4ADE80);
  static const Color blue = Color(0xFF3B82F6);
  static const Color blueLight = Color(0xFF60A5FA);
  static const Color orange = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
  static const Color redLight = Color(0xFFF87171);
  static const Color purple = Color(0xFFA855F7);
  static const Color purpleLight = Color(0xFFC084FC);
  static const Color cyan = Color(0xFF06B6D4);

  // Gradients
  static const LinearGradient orangeGradient = LinearGradient(
    colors: [primaryOrange, orangeDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFF060D1F), Color(0xFF0A1628), Color(0xFF060D1F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sidebarGradient = LinearGradient(
    colors: [Color(0xFF060D1F), Color(0xFF0A1628), Color(0xFF060D1F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient heroBannerGradient = LinearGradient(
    colors: [Color(0x1EF97316), Color(0x990F1F3D), Color(0x00060D1F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Card Decoration
  static BoxDecoration cardDecoration({Color? border, Color? bg}) {
    return BoxDecoration(
      color: bg ?? cardDark.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: border ?? cardBorder,
        width: 1,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  // Text Styles
  static TextStyle headingLarge({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: color ?? textWhite,
      );

  static TextStyle headingMedium({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: color ?? textWhite,
      );

  static TextStyle headingSmall({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: color ?? textWhite,
      );

  static TextStyle body(
          {Color? color,
          double size = 14,
          FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color ?? textWhite,
      );

  static TextStyle label({Color? color, double size = 11}) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? textMuted,
        letterSpacing: 0.5,
      );
}

/// Styled Badge Widget for Partner Module
class PartnerBadge extends StatelessWidget {
  const PartnerBadge({
    super.key,
    required this.label,
    this.type = PartnerBadgeType.orange,
    this.icon,
  });

  final String label;
  final PartnerBadgeType type;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;

    switch (type) {
      case PartnerBadgeType.green:
        bg = const Color(0x1F22C55E);
        fg = PartnerTheme.greenLight;
        border = const Color(0x4022C55E);
        break;
      case PartnerBadgeType.blue:
        bg = const Color(0x1F3B82F6);
        fg = PartnerTheme.blueLight;
        border = const Color(0x403B82F6);
        break;
      case PartnerBadgeType.red:
        bg = const Color(0x1FEF4444);
        fg = PartnerTheme.redLight;
        border = const Color(0x40EF4444);
        break;
      case PartnerBadgeType.purple:
        bg = const Color(0x1FA855F7);
        fg = PartnerTheme.purpleLight;
        border = const Color(0x40A855F7);
        break;
      case PartnerBadgeType.gray:
        bg = const Color(0x1A94A3B8);
        fg = PartnerTheme.textMuted;
        border = const Color(0x3394A3B8);
        break;
      case PartnerBadgeType.orange:
        bg = const Color(0x26F97316);
        fg = PartnerTheme.orangeLight;
        border = const Color(0x4DF97316);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

enum PartnerBadgeType { orange, green, red, blue, gray, purple }
