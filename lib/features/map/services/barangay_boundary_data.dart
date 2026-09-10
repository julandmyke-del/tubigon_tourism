import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Optional, presentation-only barangay geometry.
///
/// The asset is deliberately separate from the tourism database. It is loaded
/// only when a verified GIS export has been added to [assetPath] with the
/// provenance metadata validated below. A missing or invalid asset disables
/// only barangay polygons; the base map and authoritative markers keep working.
class BarangayBoundaryData {
  const BarangayBoundaryData._({
    required this.geoJson,
    required this.names,
    required this.source,
    required this.sourceUrl,
  });

  static const assetPath = 'assets/data/tubigon_barangay_boundaries.geojson';
  static const municipalityPsgc = '0701245000';
  static Future<BarangayBoundaryData?>? _defaultLoad;

  final Map<String, dynamic> geoJson;
  final List<String> names;
  final String source;
  final String sourceUrl;

  static Future<BarangayBoundaryData?> loadOptional({
    AssetBundle? bundle,
  }) {
    if (bundle != null) return _load(bundle);
    return _defaultLoad ??= _load(rootBundle);
  }

  static Future<BarangayBoundaryData?> _load(AssetBundle bundle) async {
    try {
      final raw = await bundle.loadString(assetPath);
      return parse(raw);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[MAP CONTEXT] Verified barangay boundary asset unavailable; '
          'continuing without barangay polygons: $error',
        );
      }
      return null;
    }
  }

  @visibleForTesting
  static BarangayBoundaryData parse(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Barangay GeoJSON root must be an object.');
    }
    final geoJson = Map<String, dynamic>.from(decoded);
    if (geoJson['type'] != 'FeatureCollection') {
      throw const FormatException(
        'Barangay GeoJSON must be a FeatureCollection.',
      );
    }

    final metadataValue = geoJson['metadata'];
    if (metadataValue is! Map) {
      throw const FormatException(
        'Barangay GeoJSON requires provenance metadata.',
      );
    }
    final metadata = Map<String, dynamic>.from(metadataValue);
    final psgc = metadata['municipality_psgc']?.toString().trim();
    final source = metadata['source']?.toString().trim() ?? '';
    final sourceUrl = metadata['source_url']?.toString().trim() ?? '';
    if (psgc != municipalityPsgc || source.isEmpty || sourceUrl.isEmpty) {
      throw const FormatException(
        'Barangay GeoJSON provenance must identify Tubigon PSGC 0701245000 '
        'and a source URL.',
      );
    }

    final featuresValue = geoJson['features'];
    if (featuresValue is! List || featuresValue.isEmpty) {
      throw const FormatException(
        'Barangay GeoJSON must contain polygon features.',
      );
    }

    final names = <String>[];
    for (final featureValue in featuresValue) {
      if (featureValue is! Map) {
        throw const FormatException(
            'Every barangay feature must be an object.');
      }
      final feature = Map<String, dynamic>.from(featureValue);
      if (feature['type'] != 'Feature') {
        throw const FormatException('Every barangay item must be a Feature.');
      }
      final propertiesValue = feature['properties'];
      final geometryValue = feature['geometry'];
      if (propertiesValue is! Map || geometryValue is! Map) {
        throw const FormatException(
          'Every barangay feature needs properties and geometry.',
        );
      }
      final properties = Map<String, dynamic>.from(propertiesValue);
      final geometry = Map<String, dynamic>.from(geometryValue);
      final name = properties['name']?.toString().trim() ?? '';
      final geometryType = geometry['type']?.toString();
      if (name.isEmpty ||
          (geometryType != 'Polygon' && geometryType != 'MultiPolygon') ||
          geometry['coordinates'] is! List ||
          (geometry['coordinates'] as List).isEmpty) {
        throw const FormatException(
          'Every barangay feature needs a name and Polygon/MultiPolygon '
          'coordinates.',
        );
      }
      names.add(name);
    }
    if (names.toSet().length != names.length) {
      throw const FormatException('Barangay names must be unique.');
    }

    return BarangayBoundaryData._(
      geoJson: geoJson,
      names: List.unmodifiable(names),
      source: source,
      sourceUrl: sourceUrl,
    );
  }
}
