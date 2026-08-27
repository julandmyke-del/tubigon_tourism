import 'package:flutter/material.dart';

/// Shadow presets for elevation layers — uses the new Dark Navy / Orange palette.
abstract final class AppShadows {
  static const List<BoxShadow> none = [];

  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x0F0B1F3A),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x1A0B1F3A),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x200B1F3A),
      blurRadius: 32,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> xl = [
    BoxShadow(
      color: Color(0x300B1F3A),
      blurRadius: 48,
      offset: Offset(0, 16),
    ),
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x120B1F3A),
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x300B1F3A),
      blurRadius: 24,
      spreadRadius: 0,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> modal = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 40,
      offset: Offset(0, -4),
    ),
  ];

  static List<BoxShadow> colored(Color color, {double opacity = 0.3}) => [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}
