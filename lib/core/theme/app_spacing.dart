import 'package:flutter/material.dart';

/// Spacing tokens and border radius constants.
abstract final class AppSpacing {
  // ─── Spacing Scale ────────────────────────────────────────────────────────
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;

  // ─── Border Radius ────────────────────────────────────────────────────────
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusXxl = 24.0;
  static const double radiusFull = 100.0;

  // ─── Border Radius Objects ────────────────────────────────────────────────
  static const BorderRadius roundedXs = BorderRadius.all(Radius.circular(radiusXs));
  static const BorderRadius roundedSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius roundedMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius roundedLg = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius roundedXl = BorderRadius.all(Radius.circular(radiusXl));
  static const BorderRadius roundedXxl = BorderRadius.all(Radius.circular(radiusXxl));
  static const BorderRadius roundedFull = BorderRadius.all(Radius.circular(radiusFull));

  static const BorderRadius roundedTopLg = BorderRadius.only(
    topLeft: Radius.circular(radiusLg),
    topRight: Radius.circular(radiusLg),
  );

  static const BorderRadius roundedTopXxl = BorderRadius.only(
    topLeft: Radius.circular(radiusXxl),
    topRight: Radius.circular(radiusXxl),
  );

  // ─── Padding Presets ──────────────────────────────────────────────────────
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const EdgeInsets paddingHMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingHLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets paddingVSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets paddingVMd = EdgeInsets.symmetric(vertical: md);

  static const EdgeInsets paddingCard = EdgeInsets.all(md);
  static const EdgeInsets paddingPage = EdgeInsets.symmetric(horizontal: md, vertical: md);

  // ─── Icon Sizes ───────────────────────────────────────────────────────────
  static const double iconSm = 16.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;

  // ─── Avatar Sizes ─────────────────────────────────────────────────────────
  static const double avatarSm = 32.0;
  static const double avatarMd = 48.0;
  static const double avatarLg = 64.0;
  static const double avatarXl = 96.0;

  // ─── Component Sizes ─────────────────────────────────────────────────────
  static const double buttonHeight = 56.0;
  static const double inputHeight = 56.0;
  static const double appBarHeight = 64.0;
  static const double bottomNavHeight = 72.0;
  static const double cardImageHeight = 200.0;
  static const double heroImageHeight = 280.0;
}
