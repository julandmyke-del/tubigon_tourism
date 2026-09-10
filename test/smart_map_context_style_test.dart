import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/features/map/services/barangay_boundary_data.dart';
import 'package:tubigon_tourism/features/map/services/smart_map_style_enhancer.dart';

class _MissingAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) =>
      Future<ByteData>.error(StateError('Asset $key is not bundled.'));
}

Map<String, dynamic> _style({bool includeGlyphs = true}) => {
      'version': 8,
      if (includeGlyphs)
        'glyphs': 'https://tiles.example/fonts/{fontstack}/{range}.pbf',
      'sources': {
        'basemap': {'type': 'vector', 'url': 'https://tiles.example/planet'},
        'hillshade': {'type': 'raster'},
      },
      'layers': [
        {'id': 'background', 'type': 'background'},
        {
          'id': 'landuse',
          'type': 'fill',
          'source': 'basemap',
          'source-layer': 'landuse',
        },
        {
          'id': 'buildings',
          'type': 'fill',
          'source': 'basemap',
          'source-layer': 'building',
        },
        {
          'id': 'waterways',
          'type': 'line',
          'source': 'basemap',
          'source-layer': 'waterway',
        },
        {
          'id': 'roads',
          'type': 'line',
          'source': 'basemap',
          'source-layer': 'transportation',
        },
        {
          'id': 'village-labels',
          'type': 'symbol',
          'source': 'basemap',
          'source-layer': 'place',
          'filter': [
            '==',
            ['get', 'class'],
            'village',
          ],
          'layout': {
            'text-field': ['get', 'name'],
            'text-font': ['Noto Sans Regular'],
          },
        },
      ],
    };

String _verifiedBarangayGeoJson({
  String psgc = BarangayBoundaryData.municipalityPsgc,
  String name = 'Panadtaran',
}) =>
    jsonEncode({
      'type': 'FeatureCollection',
      'metadata': {
        'municipality_psgc': psgc,
        'source': 'Verified LGU GIS export',
        'source_url': 'https://example.gov.ph/tubigon/barangays',
      },
      'features': [
        {
          'type': 'Feature',
          'properties': {'name': name},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [
              [
                [123.95, 9.95],
                [123.96, 9.95],
                [123.96, 9.96],
                [123.95, 9.95],
              ],
            ],
          },
        },
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('style plan uses only source layers declared by a vector style', () {
    final plan = SmartMapStylePlan.fromStyleJson(_style());

    expect(plan.transportation?.sourceId, 'basemap');
    expect(plan.transportation?.sourceLayer, 'transportation');
    expect(plan.building?.sourceLayer, 'building');
    expect(plan.waterway?.sourceLayer, 'waterway');
    expect(plan.place?.sourceLayer, 'place');
    expect(plan.firstTransportationLayerId, 'roads');
    expect(plan.firstSymbolLayerId, 'village-labels');
    expect(plan.labelFont, 'Noto Sans Regular');
    expect(plan.canRenderLocalityLabels, isTrue);
    expect(plan.replacedVillageLabelIds, ['village-labels']);
  });

  test('unsupported layers and missing glyphs are skipped by the plan', () {
    final style = _style(includeGlyphs: false);
    (style['layers'] as List).removeWhere(
      (layer) =>
          layer is Map &&
          {'building', 'waterway'}.contains(layer['source-layer']),
    );
    final plan = SmartMapStylePlan.fromStyleJson(style);

    expect(plan.building, isNull);
    expect(plan.waterway, isNull);
    expect(plan.labelFont, isNull);
    expect(plan.canRenderLocalityLabels, isFalse);
  });

  test('verified barangay GeoJSON preserves names and provenance', () {
    final data = BarangayBoundaryData.parse(_verifiedBarangayGeoJson());

    expect(data.names, ['Panadtaran']);
    expect(data.source, 'Verified LGU GIS export');
    expect(data.sourceUrl, 'https://example.gov.ph/tubigon/barangays');
    expect(data.geoJson['type'], 'FeatureCollection');
  });

  test('wrong-municipality or unattributed barangay data is rejected', () {
    expect(
      () => BarangayBoundaryData.parse(
        _verifiedBarangayGeoJson(psgc: 'not-tubigon'),
      ),
      throwsFormatException,
    );
    expect(
      () => BarangayBoundaryData.parse(jsonEncode({
        'type': 'FeatureCollection',
        'features': const [],
      })),
      throwsFormatException,
    );
  });

  test('missing optional barangay asset fails open', () async {
    final data = await BarangayBoundaryData.loadOptional(
      bundle: _MissingAssetBundle(),
    );

    expect(data, isNull);
  });
}
