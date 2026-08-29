import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class MsmeTheme {
  static const Color bgDark = Color(0xFF060D1F);
  static const Color surfaceDark = Color(0xFF0A1628);
  static const Color cardDark = Color(0xFF0F1F3D);
  static const Color cardBorder = Color(0x1AFFFFFF);

  static const Color primaryOrange = Color(0xFFF97316);
  static const Color orangeLight = Color(0xFFFB923C);
  static const Color orangeDark = Color(0xFFEA6C0A);
  static const Color orangeDim = Color(0x26F97316);
  static const Color orangeGlow = Color(0x40F97316);

  static const Color textWhite = Color(0xFFF1F5F9);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textSubtle = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF475569);

  static const Color green = Color(0xFF22C55E);
  static const Color greenLight = Color(0xFF4ADE80);
  static const Color blue = Color(0xFF3B82F6);
  static const Color blueLight = Color(0xFF60A5FA);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
  static const Color redLight = Color(0xFFF87171);
  static const Color purple = Color(0xFFA855F7);
  static const Color purpleLight = Color(0xFFC084FC);
  static const Color cyan = Color(0xFF06B6D4);

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

  static BoxDecoration cardDecoration({Color? border, Color? bg}) {
    return BoxDecoration(
      color: bg ?? cardDark.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border ?? cardBorder, width: 1),
      boxShadow: const [
        BoxShadow(
            color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 4)),
      ],
    );
  }

  static TextStyle headingLarge({Color? color}) => GoogleFonts.plusJakartaSans(
      fontSize: 24, fontWeight: FontWeight.w800, color: color ?? textWhite);
  static TextStyle headingMedium({Color? color}) => GoogleFonts.plusJakartaSans(
      fontSize: 18, fontWeight: FontWeight.w700, color: color ?? textWhite);
  static TextStyle headingSmall({Color? color}) => GoogleFonts.plusJakartaSans(
      fontSize: 15, fontWeight: FontWeight.w700, color: color ?? textWhite);
  static TextStyle body(
          {Color? color,
          double size = 14,
          FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.inter(
          fontSize: size, fontWeight: weight, color: color ?? textWhite);
  static TextStyle label({Color? color, double size = 11}) => GoogleFonts.inter(
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: color ?? textMuted,
      letterSpacing: 0.5);
}

class MsmeBadge extends StatelessWidget {
  const MsmeBadge(
      {super.key,
      required this.label,
      this.type = MsmeBadgeType.orange,
      this.icon});

  final String label;
  final MsmeBadgeType type;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;
    switch (type) {
      case MsmeBadgeType.green:
        bg = const Color(0x1F22C55E);
        fg = MsmeTheme.greenLight;
        border = const Color(0x4022C55E);
        break;
      case MsmeBadgeType.blue:
        bg = const Color(0x1F3B82F6);
        fg = MsmeTheme.blueLight;
        border = const Color(0x403B82F6);
        break;
      case MsmeBadgeType.red:
        bg = const Color(0x1FEF4444);
        fg = MsmeTheme.redLight;
        border = const Color(0x40EF4444);
        break;
      case MsmeBadgeType.purple:
        bg = const Color(0x1FA855F7);
        fg = MsmeTheme.purpleLight;
        border = const Color(0x40A855F7);
        break;
      case MsmeBadgeType.amber:
        bg = const Color(0x1FF59E0B);
        fg = MsmeTheme.amber;
        border = const Color(0x40F59E0B);
        break;
      case MsmeBadgeType.gray:
        bg = const Color(0x1A94A3B8);
        fg = MsmeTheme.textMuted;
        border = const Color(0x3394A3B8);
        break;
      case MsmeBadgeType.orange:
        bg = const Color(0x26F97316);
        fg = MsmeTheme.orangeLight;
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
          if (icon != null) ...[icon!, const SizedBox(width: 4)],
          Text(label.toUpperCase(),
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

enum MsmeBadgeType { orange, green, red, blue, gray, purple, amber }
