import 'dart:convert';

import 'package:flutter/services.dart';

/// Municipality boundary sourced from the Philippine GeoRisk/PSA municipal
/// boundary layer (PSGC 0701245000). Longitude is stored before latitude in
/// GeoJSON, but the public API consistently accepts latitude first.
class TubigonBoundary {
  TubigonBoundary._(this.polygons);

  static const assetPath = 'backend/resources/data/tubigon_boundary.geojson';
  static const minLatitude = 9.884021;
  static const maxLatitude = 10.072237;
  static const minLongitude = 123.881415;
  static const maxLongitude = 124.029692;

  static Future<TubigonBoundary>? _cached;

  /// GeoJSON MultiPolygon -> polygons -> rings -> coordinates.
  final List<List<List<TubigonCoordinate>>> polygons;

  Iterable<List<TubigonCoordinate>> get outerRings => polygons
      .where((polygon) => polygon.isNotEmpty)
      .map((polygon) => polygon.first);

  static Future<TubigonBoundary> load() => _cached ??= _load();

  static Future<TubigonBoundary> _load() async {
    final source = await rootBundle.loadString(assetPath);
    return fromJson(jsonDecode(source) as Map<String, dynamic>);
  }

  static TubigonBoundary fromJson(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    if (geometry?['type'] != 'MultiPolygon') {
      throw const FormatException(
          'Tubigon boundary must be a GeoJSON MultiPolygon.');
    }
    final rawPolygons = geometry!['coordinates'] as List<dynamic>?;
    if (rawPolygons == null || rawPolygons.isEmpty) {
      throw const FormatException('Tubigon boundary contains no polygons.');
    }
    final polygons = rawPolygons.map((rawPolygon) {
      return (rawPolygon as List<dynamic>).map((rawRing) {
        return (rawRing as List<dynamic>).map((rawPoint) {
          final point = rawPoint as List<dynamic>;
          return TubigonCoordinate(
            latitude: (point[1] as num).toDouble(),
            longitude: (point[0] as num).toDouble(),
          );
        }).toList(growable: false);
      }).toList(growable: false);
    }).toList(growable: false);
    return TubigonBoundary._(polygons);
  }

  bool contains({required double latitude, required double longitude}) {
    if (latitude < minLatitude ||
        latitude > maxLatitude ||
        longitude < minLongitude ||
        longitude > maxLongitude) {
      return false;
    }
    for (final polygon in polygons) {
      if (polygon.isEmpty ||
          !_ringContains(polygon.first, latitude, longitude)) {
        continue;
      }
      final insideHole = polygon
          .skip(1)
          .any((ring) => _ringContains(ring, latitude, longitude));
      if (!insideHole) return true;
    }
    return false;
  }

  bool _ringContains(
    List<TubigonCoordinate> ring,
    double latitude,
    double longitude,
  ) {
    var inside = false;
    for (var current = 0, previous = ring.length - 1;
        current < ring.length;
        previous = current++) {
      final a = ring[previous];
      final b = ring[current];
      if (_onSegment(a, b, latitude, longitude)) return true;
      final crosses = (a.latitude > latitude) != (b.latitude > latitude);
      if (crosses) {
        final intersection = (b.longitude - a.longitude) *
                (latitude - a.latitude) /
                (b.latitude - a.latitude) +
            a.longitude;
        if (longitude < intersection) inside = !inside;
      }
    }
    return inside;
  }

  bool _onSegment(
    TubigonCoordinate a,
    TubigonCoordinate b,
    double latitude,
    double longitude,
  ) {
    const epsilon = 1e-9;
    final cross = (longitude - a.longitude) * (b.latitude - a.latitude) -
        (latitude - a.latitude) * (b.longitude - a.longitude);
    if (cross.abs() > epsilon) return false;
    final minLongitude = a.longitude < b.longitude ? a.longitude : b.longitude;
    final maxLongitude = a.longitude > b.longitude ? a.longitude : b.longitude;
    final minLatitude = a.latitude < b.latitude ? a.latitude : b.latitude;
    final maxLatitude = a.latitude > b.latitude ? a.latitude : b.latitude;
    return longitude >= minLongitude - epsilon &&
        longitude <= maxLongitude + epsilon &&
        latitude >= minLatitude - epsilon &&
        latitude <= maxLatitude + epsilon;
  }
}

class TubigonCoordinate {
  const TubigonCoordinate({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}
