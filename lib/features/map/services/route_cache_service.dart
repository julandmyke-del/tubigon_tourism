import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_storage_service.dart';
import 'directions_service.dart';

class CachedMapRoute {
  const CachedMapRoute({
    required this.destinationId,
    required this.origin,
    required this.destination,
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    required this.calculatedAt,
  });

  final String destinationId;
  final MapCoordinate origin;
  final MapCoordinate destination;
  final List<MapCoordinate> points;
  final double distanceKm;
  final int durationMinutes;
  final DateTime calculatedAt;

  Map<String, dynamic> toJson() => {
        'destination_id': destinationId,
        'origin': [origin.latitude, origin.longitude],
        'destination': [destination.latitude, destination.longitude],
        'points':
            points.map((point) => [point.latitude, point.longitude]).toList(),
        'distance_km': distanceKm,
        'duration_minutes': durationMinutes,
        'calculated_at': calculatedAt.toIso8601String(),
      };

  factory CachedMapRoute.fromJson(Map<String, dynamic> json) {
    final origin = json['origin'] as List<dynamic>;
    final destination = json['destination'] as List<dynamic>;
    return CachedMapRoute(
      destinationId: json['destination_id'].toString(),
      origin: MapCoordinate(
        (origin[0] as num).toDouble(),
        (origin[1] as num).toDouble(),
      ),
      destination: MapCoordinate(
        (destination[0] as num).toDouble(),
        (destination[1] as num).toDouble(),
      ),
      points: (json['points'] as List<dynamic>)
          .whereType<List<dynamic>>()
          .map((point) => MapCoordinate(
                (point[0] as num).toDouble(),
                (point[1] as num).toDouble(),
              ))
          .toList(growable: false),
      distanceKm: (json['distance_km'] as num).toDouble(),
      durationMinutes: (json['duration_minutes'] as num).toInt(),
      calculatedAt: DateTime.parse(json['calculated_at'].toString()),
    );
  }
}

class RouteCacheService {
  static const _key = 'smart_map_route_cache_v1';
  static const _maxRoutes = 20;

  Future<void> save({
    required String destinationId,
    required MapCoordinate origin,
    required MapCoordinate destination,
    required MapRouteResult route,
  }) async {
    final routes = _load()
      ..removeWhere((item) => item.destinationId == destinationId)
      ..insert(
        0,
        CachedMapRoute(
          destinationId: destinationId,
          origin: origin,
          destination: destination,
          points: route.points,
          distanceKm: route.distanceKm,
          durationMinutes: route.durationMinutes,
          calculatedAt: DateTime.now(),
        ),
      );
    if (routes.length > _maxRoutes)
      routes.removeRange(_maxRoutes, routes.length);
    await LocalStorageService.instance.setString(
      _key,
      jsonEncode(routes.map((route) => route.toJson()).toList()),
    );
  }

  CachedMapRoute? latestFor(String destinationId) {
    for (final route in _load()) {
      if (route.destinationId == destinationId) return route;
    }
    return null;
  }

  List<CachedMapRoute> _load() {
    final raw = LocalStorageService.instance.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map>()
          .map((item) =>
              CachedMapRoute.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

final routeCacheServiceProvider = Provider<RouteCacheService>((ref) {
  return RouteCacheService();
});
