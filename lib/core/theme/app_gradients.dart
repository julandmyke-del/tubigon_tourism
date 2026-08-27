import 'package:flutter/material.dart';

/// Gradient definitions for the Tubigon design system.
abstract final class AppGradients {
  // ─── Primary Gradients ────────────────────────────────────────────────────
  static const LinearGradient primary = LinearGradient(
    colors: [Color(0xFF0B1F3A), Color(0xFF2B2F36)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primarySoft = LinearGradient(
    colors: [Color(0xFF162A45), Color(0xFF1F2937)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryVertical = LinearGradient(
    colors: [Color(0xFF0B1F3A), Color(0xFF1B365D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient premium = LinearGradient(
    colors: [Color(0xFF0B1F3A), Color(0xFF2B2F36), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.6, 1.0],
  );

  // ─── Secondary Gradients ──────────────────────────────────────────────────
  static const LinearGradient secondary = LinearGradient(
    colors: [Color(0xFF2B2F36), Color(0xFF1F2937)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient eco = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Hero/Overlay Gradients ───────────────────────────────────────────────
  static const LinearGradient heroOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xCC0B1F3A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.4, 1.0],
  );

  static const LinearGradient cardOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xB30B1F3A)],
    begin: Alignment.center,
    end: Alignment.bottomCenter,
  );

  // ─── Background Gradients ─────────────────────────────────────────────────
  static const LinearGradient lightBackground = LinearGradient(
    colors: [Color(0xFF0B1F3A), Color(0xFF2B2F36)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkBackground = LinearGradient(
    colors: [Color(0xFF0B1F3A), Color(0xFF2B2F36)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Sunrise / Tropical ───────────────────────────────────────────────────
  static const LinearGradient sunrise = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFF97316), Color(0xFF4DA8DA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient ocean = LinearGradient(
    colors: [Color(0xFF0B1F3A), Color(0xFF2B2F36), Color(0xFF4DA8DA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Radial ───────────────────────────────────────────────────────────────
  static const RadialGradient radialPrimary = RadialGradient(
    colors: [Color(0xFF1B365D), Color(0xFF0B1F3A)],
    center: Alignment.center,
    radius: 0.8,
  );
}
