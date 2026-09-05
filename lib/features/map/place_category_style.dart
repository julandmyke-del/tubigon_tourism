import 'package:flutter/material.dart';

/// Centralized rendering for icon identifiers supplied by managed categories.
IconData placeCategoryIcon(String name,
    {IconData fallback = Icons.place_rounded}) {
  return switch (name) {
    'landscape' => Icons.landscape_rounded,
    'storefront' => Icons.storefront_rounded,
    'shopping_bag' => Icons.shopping_bag_rounded,
    'fastfood' => Icons.fastfood_rounded,
    'restaurant' => Icons.restaurant_rounded,
    'deck' => Icons.deck_rounded,
    'hotel' => Icons.hotel_rounded,
    'forest' => Icons.forest_rounded,
    'account_balance' => Icons.account_balance_rounded,
    'emergency' => Icons.emergency_rounded,
    'local_fire_department' => Icons.local_fire_department_rounded,
    'local_hospital' => Icons.local_hospital_rounded,
    'local_police' => Icons.local_police_rounded,
    'directions_boat' => Icons.directions_boat_rounded,
    'directions_bus' => Icons.directions_bus_rounded,
    'anchor' => Icons.anchor_rounded,
    'account_balance_wallet' => Icons.account_balance_wallet_rounded,
    'delete_sweep' => Icons.delete_sweep_rounded,
    'eco' => Icons.eco_rounded,
    _ => fallback,
  };
}

Color placeCategoryColor(String value,
    {Color fallback = const Color(0xFFF59E0B)}) {
  final hex = value.replaceFirst('#', '');
  if (hex.length == 6) {
    final parsed = int.tryParse('FF$hex', radix: 16);
    if (parsed != null) return Color(parsed);
  }
  return fallback;
}
