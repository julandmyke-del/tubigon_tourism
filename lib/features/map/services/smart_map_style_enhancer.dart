import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'barangay_boundary_data.dart';

class MapStyleLayerReference {
  const MapStyleLayerReference({
    required this.sourceId,
    required this.sourceLayer,
  });

  final String sourceId;
  final String sourceLayer;
}

/// Runtime-derived capabilities for the currently loaded MapLibre style.
///
/// No optional source layer is used unless the loaded style itself declares it
/// on a vector source. This keeps MAP_STYLE_URL overrides fail-open.
class SmartMapStylePlan {
  const SmartMapStylePlan({
    required this.layerIds,
    required this.firstSymbolLayerId,
    required this.firstTransportationLayerId,
    required this.transportation,
    required this.building,
    required this.waterway,
    required this.place,
    required this.labelFont,
    required this.localityTextField,
    required this.replacedVillageLabelIds,
  });

  final Set<String> layerIds;
  final String? firstSymbolLayerId;
  final String? firstTransportationLayerId;
  final MapStyleLayerReference? transportation;
  final MapStyleLayerReference? building;
  final MapStyleLayerReference? waterway;
  final MapStyleLayerReference? place;
  final String? labelFont;
  final dynamic localityTextField;
  final List<String> replacedVillageLabelIds;

  bool get canRenderLocalityLabels =>
      place != null && labelFont != null && localityTextField != null;

  @visibleForTesting
  factory SmartMapStylePlan.fromStyleJson(Map<String, dynamic> style) {
    final rawSources = style['sources'];
    final sources = rawSources is Map
        ? Map<String, dynamic>.from(rawSources)
        : const <String, dynamic>{};
    final rawLayers = style['layers'];
    final layers = rawLayers is List
        ? rawLayers
            .whereType<Map>()
            .map((layer) => Map<String, dynamic>.from(layer))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];

    bool isVectorSource(String id) {
      final value = sources[id];
      return value is Map && value['type'] == 'vector';
    }

    MapStyleLayerReference? referenceFor(String sourceLayer) {
      for (final layer in layers) {
        if (layer['source-layer'] != sourceLayer) continue;
        final sourceId = layer['source']?.toString();
        if (sourceId != null && isVectorSource(sourceId)) {
          return MapStyleLayerReference(
            sourceId: sourceId,
            sourceLayer: sourceLayer,
          );
        }
      }
      return null;
    }

    final hasGlyphs = style['glyphs']?.toString().trim().isNotEmpty == true;
    String? labelFont;
    dynamic localityTextField;
    final replacedVillageLabelIds = <String>[];
    for (final layer in layers) {
      if (layer['type'] != 'symbol' || layer['source-layer'] != 'place') {
        continue;
      }
      final layoutValue = layer['layout'];
      final layout = layoutValue is Map
          ? Map<String, dynamic>.from(layoutValue)
          : const <String, dynamic>{};
      final fontValue = layout['text-font'];
      if (hasGlyphs && fontValue is List && fontValue.isNotEmpty) {
        final fonts = fontValue.map((font) => font.toString()).toList();
        labelFont ??= fonts.first;
        if (fonts.contains('Noto Sans Regular')) {
          labelFont = 'Noto Sans Regular';
        }
      }
      if (_isSingleClassFilter(layer['filter'], 'village')) {
        final id = layer['id']?.toString();
        if (id != null && id.isNotEmpty) replacedVillageLabelIds.add(id);
        localityTextField ??= layout['text-field'];
      }
    }

    return SmartMapStylePlan(
      layerIds: layers
          .map((layer) => layer['id']?.toString())
          .whereType<String>()
          .toSet(),
      firstSymbolLayerId: _firstLayerId(layers, type: 'symbol'),
      firstTransportationLayerId:
          _firstLayerId(layers, sourceLayer: 'transportation'),
      transportation: referenceFor('transportation'),
      building: referenceFor('building'),
      waterway: referenceFor('waterway'),
      place: referenceFor('place'),
      labelFont: hasGlyphs ? labelFont : null,
      localityTextField: localityTextField,
      replacedVillageLabelIds: List.unmodifiable(replacedVillageLabelIds),
    );
  }

  @visibleForTesting
  static SmartMapStylePlan decode(String rawStyle) {
    final decoded = jsonDecode(rawStyle);
    if (decoded is! Map) {
      throw const FormatException('MapLibre style root must be an object.');
    }
    return SmartMapStylePlan.fromStyleJson(
      Map<String, dynamic>.from(decoded),
    );
  }

  static String? _firstLayerId(
    List<Map<String, dynamic>> layers, {
    String? type,
    String? sourceLayer,
  }) {
    for (final layer in layers) {
      if (type != null && layer['type'] != type) continue;
      if (sourceLayer != null && layer['source-layer'] != sourceLayer) {
        continue;
      }
      final id = layer['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  static bool _isSingleClassFilter(dynamic filter, String value) {
    return filter is List &&
        filter.length == 3 &&
        filter.first == '==' &&
        filter[1] is List &&
        (filter[1] as List).length == 2 &&
        (filter[1] as List).first == 'get' &&
        (filter[1] as List)[1] == 'class' &&
        filter[2] == value;
  }
}

class SmartMapStyleEnhancementResult {
  const SmartMapStyleEnhancementResult({
    required this.installedLayers,
    required this.barangayBoundariesInstalled,
  });

  final Set<String> installedLayers;
  final bool barangayBoundariesInstalled;
}

/// Adds subtle contextual layers after inspecting the loaded style.
///
/// Every operation is optional and isolated. A provider/style mismatch or a
/// missing barangay asset is logged in debug builds and never takes down the
/// base map or its authoritative annotations.
class SmartMapStyleEnhancer {
  const SmartMapStyleEnhancer();

  static const localRoadLayerId = 'tubigon-context-local-roads';
  static const serviceRoadLayerId = 'tubigon-context-service-roads';
  static const buildingLayerId = 'tubigon-context-buildings';
  static const waterwayLayerId = 'tubigon-context-waterways';
  static const localityLabelLayerId = 'tubigon-context-locality-labels';
  static const barangaySourceId = 'tubigon-verified-barangays';
  static const barangayFillLayerId = 'tubigon-barangay-fill';
  static const barangayLineLayerId = 'tubigon-barangay-line';
  static const barangayLabelLayerId = 'tubigon-barangay-label';

  Future<SmartMapStyleEnhancementResult> install(
    MapLibreMapController controller, {
    required bool Function() isActive,
    AssetBundle? assetBundle,
  }) async {
    final installed = <String>{};
    SmartMapStylePlan plan;
    try {
      final rawStyle = await controller.getStyle();
      if (!isActive() || rawStyle == null || rawStyle.trim().isEmpty) {
        return const SmartMapStyleEnhancementResult(
          installedLayers: {},
          barangayBoundariesInstalled: false,
        );
      }
      plan = SmartMapStylePlan.decode(rawStyle);
    } catch (error) {
      _log('Unable to inspect the loaded style; contextual layers skipped',
          error);
      return const SmartMapStyleEnhancementResult(
        installedLayers: {},
        barangayBoundariesInstalled: false,
      );
    }

    final transportation = plan.transportation;
    if (transportation != null) {
      await _installLayer(
        controller,
        localRoadLayerId,
        plan,
        isActive,
        installed,
        () => controller.addLineLayer(
          transportation.sourceId,
          localRoadLayerId,
          const LineLayerProperties(
            lineColor: '#CBD5E1',
            lineOpacity: [
              'interpolate',
              ['linear'],
              ['zoom'],
              13,
              0.18,
              15,
              0.42,
              18,
              0.62,
            ],
            lineWidth: [
              'interpolate',
              ['exponential', 1.2],
              ['zoom'],
              13,
              0.25,
              15,
              0.8,
              18,
              1.6,
            ],
            lineCap: 'round',
            lineJoin: 'round',
          ),
          sourceLayer: transportation.sourceLayer,
          minzoom: 13,
          maxzoom: 20,
          belowLayerId: plan.firstSymbolLayerId,
          enableInteraction: false,
          filter: const [
            'all',
            [
              'match',
              ['geometry-type'],
              ['LineString', 'MultiLineString'],
              true,
              false,
            ],
            [
              'match',
              ['get', 'brunnel'],
              ['bridge', 'tunnel'],
              false,
              true,
            ],
            [
              'match',
              ['get', 'class'],
              ['minor', 'street', 'street_limited'],
              true,
              false,
            ],
          ],
        ),
      );
      await _installLayer(
        controller,
        serviceRoadLayerId,
        plan,
        isActive,
        installed,
        () => controller.addLineLayer(
          transportation.sourceId,
          serviceRoadLayerId,
          const LineLayerProperties(
            lineColor: '#E2E8F0',
            lineOpacity: 0.46,
            lineWidth: [
              'interpolate',
              ['linear'],
              ['zoom'],
              15,
              0.2,
              18,
              1.1,
            ],
            lineCap: 'round',
            lineJoin: 'round',
          ),
          sourceLayer: transportation.sourceLayer,
          minzoom: 15,
          maxzoom: 20,
          belowLayerId: plan.firstSymbolLayerId,
          enableInteraction: false,
          filter: const [
            'all',
            [
              'match',
              ['get', 'brunnel'],
              ['bridge', 'tunnel'],
              false,
              true,
            ],
            [
              'match',
              ['get', 'class'],
              ['service', 'track'],
              true,
              false,
            ],
          ],
        ),
      );
    }

    final building = plan.building;
    if (building != null) {
      await _installLayer(
        controller,
        buildingLayerId,
        plan,
        isActive,
        installed,
        () => controller.addFillLayer(
          building.sourceId,
          buildingLayerId,
          const FillLayerProperties(
            fillColor: '#94A3B8',
            fillOpacity: [
              'interpolate',
              ['linear'],
              ['zoom'],
              14,
              0.12,
              16,
              0.24,
              19,
              0.32,
            ],
            fillOutlineColor: '#64748B',
          ),
          sourceLayer: building.sourceLayer,
          minzoom: 14,
          maxzoom: 20,
          belowLayerId: plan.firstTransportationLayerId,
          enableInteraction: false,
        ),
      );
    }

    final waterway = plan.waterway;
    if (waterway != null) {
      await _installLayer(
        controller,
        waterwayLayerId,
        plan,
        isActive,
        installed,
        () => controller.addLineLayer(
          waterway.sourceId,
          waterwayLayerId,
          const LineLayerProperties(
            lineColor: '#60A5FA',
            lineOpacity: 0.58,
            lineWidth: [
              'interpolate',
              ['linear'],
              ['zoom'],
              13,
              0.35,
              16,
              1.1,
              19,
              1.8,
            ],
            lineCap: 'round',
          ),
          sourceLayer: waterway.sourceLayer,
          minzoom: 13,
          maxzoom: 20,
          belowLayerId: plan.firstTransportationLayerId,
          enableInteraction: false,
          filter: const [
            'all',
            [
              '!=',
              ['get', 'brunnel'],
              'tunnel'
            ],
            [
              'match',
              ['geometry-type'],
              ['LineString', 'MultiLineString'],
              true,
              false,
            ],
          ],
        ),
      );
    }

    final place = plan.place;
    if (place != null && plan.canRenderLocalityLabels) {
      final added = await _installLayer(
        controller,
        localityLabelLayerId,
        plan,
        isActive,
        installed,
        () => controller.addSymbolLayer(
          place.sourceId,
          localityLabelLayerId,
          SymbolLayerProperties(
            textField: plan.localityTextField,
            textFont: [plan.labelFont!],
            textSize: const [
              'interpolate',
              ['linear'],
              ['zoom'],
              10.5,
              10,
              13,
              12,
              16,
              14,
            ],
            textColor: '#1E293B',
            textHaloColor: '#FFFFFF',
            textHaloWidth: 1.5,
            textHaloBlur: 0.5,
            textMaxWidth: 10,
            textPadding: 8,
            textAllowOverlap: false,
            textIgnorePlacement: false,
            textOptional: true,
          ),
          sourceLayer: place.sourceLayer,
          minzoom: 10.5,
          maxzoom: 20,
          belowLayerId: plan.firstSymbolLayerId,
          enableInteraction: false,
          filter: const [
            '==',
            ['get', 'class'],
            'village'
          ],
        ),
      );
      if (added) {
        for (final baseLayerId in plan.replacedVillageLabelIds) {
          if (!isActive()) break;
          try {
            await controller.setLayerVisibility(baseLayerId, false);
          } catch (error) {
            _log('Could not suppress duplicate locality layer $baseLayerId',
                error);
          }
        }
      }
    } else if (place != null && kDebugMode) {
      debugPrint(
        '[MAP CONTEXT] Locality labels skipped because the loaded style has '
        'no proven glyph/font configuration.',
      );
    }

    final barangays = await BarangayBoundaryData.loadOptional(
      bundle: assetBundle,
    );
    final barangayInstalled = barangays != null &&
        await _installBarangayLayers(
          controller,
          plan,
          barangays,
          isActive,
          installed,
        );

    return SmartMapStyleEnhancementResult(
      installedLayers: Set.unmodifiable(installed),
      barangayBoundariesInstalled: barangayInstalled,
    );
  }

  Future<bool> _installBarangayLayers(
    MapLibreMapController controller,
    SmartMapStylePlan plan,
    BarangayBoundaryData data,
    bool Function() isActive,
    Set<String> installed,
  ) async {
    if (!isActive()) return false;
    try {
      if (!plan.layerIds.contains(barangayFillLayerId)) {
        await controller.addGeoJsonSource(barangaySourceId, data.geoJson);
      }
      if (!isActive()) return false;
      final fillAdded = await _installLayer(
        controller,
        barangayFillLayerId,
        plan,
        isActive,
        installed,
        () => controller.addFillLayer(
          barangaySourceId,
          barangayFillLayerId,
          const FillLayerProperties(
            fillColor: '#F59E0B',
            fillOpacity: 0.045,
          ),
          minzoom: 10,
          maxzoom: 20,
          belowLayerId: plan.firstTransportationLayerId,
          enableInteraction: false,
        ),
      );
      await _installLayer(
        controller,
        barangayLineLayerId,
        plan,
        isActive,
        installed,
        () => controller.addLineLayer(
          barangaySourceId,
          barangayLineLayerId,
          const LineLayerProperties(
            lineColor: '#F59E0B',
            lineOpacity: 0.56,
            lineWidth: [
              'interpolate',
              ['linear'],
              ['zoom'],
              10,
              0.6,
              15,
              1.2,
            ],
            lineDasharray: [3, 2],
          ),
          minzoom: 10,
          maxzoom: 20,
          belowLayerId: plan.firstSymbolLayerId,
          enableInteraction: false,
        ),
      );
      if (plan.labelFont != null) {
        await _installLayer(
          controller,
          barangayLabelLayerId,
          plan,
          isActive,
          installed,
          () => controller.addSymbolLayer(
            barangaySourceId,
            barangayLabelLayerId,
            SymbolLayerProperties(
              textField: const ['get', 'name'],
              textFont: [plan.labelFont!],
              textSize: const [
                'interpolate',
                ['linear'],
                ['zoom'],
                11,
                10,
                14,
                12.5,
              ],
              textColor: '#92400E',
              textHaloColor: '#FFFBEB',
              textHaloWidth: 1.5,
              textPadding: 12,
              textAllowOverlap: false,
            ),
            minzoom: 11,
            maxzoom: 16,
            belowLayerId: plan.firstSymbolLayerId,
            enableInteraction: false,
          ),
        );
      } else {
        _log(
          'Verified barangay polygons loaded, but labels were skipped because '
          'the style has no proven glyph/font stack',
        );
      }
      return fillAdded;
    } catch (error) {
      _log('Verified barangay layers could not be installed', error);
      return false;
    }
  }

  Future<bool> _installLayer(
    MapLibreMapController controller,
    String layerId,
    SmartMapStylePlan plan,
    bool Function() isActive,
    Set<String> installed,
    Future<void> Function() operation,
  ) async {
    if (!isActive() || plan.layerIds.contains(layerId)) return false;
    try {
      await operation();
      if (!isActive()) return false;
      installed.add(layerId);
      return true;
    } catch (error) {
      _log('Optional layer $layerId was skipped', error);
      return false;
    }
  }

  static void _log(String message, [Object? error]) {
    if (!kDebugMode) return;
    debugPrint('[MAP CONTEXT] $message${error == null ? '' : ': $error'}');
  }
}
