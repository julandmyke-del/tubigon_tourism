import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MapCoordinate {
  const MapCoordinate(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

class MapRouteResult {
  const MapRouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    this.legs = const [],
  });

  final List<MapCoordinate> points;
  final double distanceKm;
  final int durationMinutes;
  final List<MapRouteLeg> legs;
}

class MapRouteLeg {
  const MapRouteLeg({required this.distanceKm, required this.durationMinutes});

  final double distanceKm;
  final int durationMinutes;
}

class DirectionsService {
  DirectionsService()
      : _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

  final Dio _dio;

  Future<MapRouteResult> route({
    required MapCoordinate origin,
    required MapCoordinate destination,
  }) async {
    return routeThrough([origin, destination]);
  }

  Future<MapRouteResult> routeThrough(List<MapCoordinate> waypoints) async {
    if (waypoints.length < 2) {
      throw ArgumentError('At least two route points are required.');
    }
    final coordinates = waypoints
        .map((point) => '${point.longitude},${point.latitude}')
        .join(';');
    final response = await _dio.get<Map<String, dynamic>>(
      'https://router.project-osrm.org/route/v1/driving/$coordinates',
      queryParameters: const {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
      },
    );
    final body = response.data;
    final routes = body?['routes'] as List<dynamic>?;
    if (body?['code'] != 'Ok' || routes == null || routes.isEmpty) {
      throw StateError('No driving route is available for this destination.');
    }
    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>;
    final coordinatesJson = geometry['coordinates'] as List<dynamic>;
    final points = coordinatesJson.map((item) {
      final pair = item as List<dynamic>;
      return MapCoordinate(
        (pair[1] as num).toDouble(),
        (pair[0] as num).toDouble(),
      );
    }).toList(growable: false);
    final legs = (route['legs'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((leg) => MapRouteLeg(
              distanceKm: ((leg['distance'] as num?)?.toDouble() ?? 0) / 1000,
              durationMinutes:
                  (((leg['duration'] as num?)?.toDouble() ?? 0) / 60).ceil(),
            ))
        .toList(growable: false);
    return MapRouteResult(
      points: points,
      distanceKm: ((route['distance'] as num?)?.toDouble() ?? 0) / 1000,
      durationMinutes:
          (((route['duration'] as num?)?.toDouble() ?? 0) / 60).ceil(),
      legs: legs,
    );
  }
}

final directionsServiceProvider = Provider<DirectionsService>((ref) {
  return DirectionsService();
});
