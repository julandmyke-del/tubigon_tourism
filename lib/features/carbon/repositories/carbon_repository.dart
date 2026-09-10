import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/services/local_storage_service.dart';

class CarbonFactor {
  const CarbonFactor({
    required this.id,
    required this.mode,
    required this.name,
    required this.factor,
    required this.unit,
    required this.sourceName,
    required this.sourceYear,
    required this.sourceUrl,
    required this.version,
    this.assumption,
    this.notes,
    this.isBundled = false,
  });

  final String id;
  final String mode;
  final String name;
  final double factor;
  final String unit;
  final String sourceName;
  final int sourceYear;
  final String sourceUrl;
  final String version;
  final String? assumption;
  final String? notes;
  final bool isBundled;

  bool get isFerry => mode.startsWith('ferry');
  bool get isActiveTravel => mode == 'walking' || mode == 'bicycle';

  factory CarbonFactor.fromJson(Map<String, dynamic> json) => CarbonFactor(
        id: json['id']?.toString() ?? '',
        mode: json['transport_mode']?.toString() ?? '',
        name: json['display_name']?.toString() ?? 'Transport',
        factor: double.tryParse(json['emission_factor']?.toString() ?? '') ?? 0,
        unit: json['unit']?.toString() ?? 'kg_co2e_per_passenger_km',
        sourceName: json['source_name']?.toString() ?? 'Unspecified source',
        sourceYear: int.tryParse(json['source_year']?.toString() ?? '') ?? 0,
        sourceUrl: json['source_url']?.toString() ?? '',
        version: json['version']?.toString() ?? 'unknown',
        assumption: json['occupancy_assumption']?.toString(),
        notes: json['notes']?.toString(),
        isBundled: json['is_bundled'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'transport_mode': mode,
        'display_name': name,
        'emission_factor': factor,
        'unit': unit,
        'source_name': sourceName,
        'source_year': sourceYear,
        'source_url': sourceUrl,
        'version': version,
        'occupancy_assumption': assumption,
        'notes': notes,
        'is_bundled': isBundled,
      };
}

class CarbonFactorCatalog {
  const CarbonFactorCatalog({
    required this.items,
    required this.cachedAt,
    required this.isOfflineCopy,
    required this.method,
    required this.disclaimer,
  });

  final List<CarbonFactor> items;
  final DateTime cachedAt;
  final bool isOfflineCopy;
  final String method;
  final String disclaimer;
}

class CarbonRepository {
  CarbonRepository(this._apiClient);

  final ApiClient _apiClient;
  static const _factorCacheKey = 'carbon_factor_catalog_v2';

  Future<CarbonFactorCatalog> factors() async {
    if (await checkConnectivity()) {
      try {
        final response = await _apiClient.get(ApiEndpoints.carbonFactors);
        final body = Map<String, dynamic>.from(response.data as Map);
        final rows = (body['data'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) =>
                CarbonFactor.fromJson(Map<String, dynamic>.from(item)))
            .where((item) => item.id.isNotEmpty && item.mode.isNotEmpty)
            .toList(growable: false);
        if (rows.isNotEmpty) {
          final meta = Map<String, dynamic>.from(body['meta'] as Map? ?? {});
          final value = <String, dynamic>{
            'items': rows.map((item) => item.toJson()).toList(),
            'cached_at': DateTime.now().toUtc().toIso8601String(),
            'method': meta['method'],
            'disclaimer': meta['disclaimer'],
          };
          await LocalStorageService.instance
              .setString(_factorCacheKey, jsonEncode(value));
          return _catalog(value, isOfflineCopy: false);
        }
      } catch (_) {
        // Fall through to the last-known catalog.
      }
    }
    final cached = LocalStorageService.instance.getString(_factorCacheKey);
    if (cached != null) {
      try {
        return _catalog(
          Map<String, dynamic>.from(jsonDecode(cached) as Map),
          isOfflineCopy: true,
        );
      } catch (_) {}
    }
    return _catalog(_bundledCatalog, isOfflineCopy: true);
  }

  Future<List<Map<String, dynamic>>> history(String userId) async {
    final key = 'carbon_history_$userId';
    if (await checkConnectivity()) {
      try {
        final response = await _apiClient.get(ApiEndpoints.carbonEstimates);
        final body = Map<String, dynamic>.from(response.data as Map);
        final rows = (body['data'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
        await LocalStorageService.instance.setString(key, jsonEncode(rows));
        return rows;
      } catch (_) {}
    }
    final raw = LocalStorageService.instance.getString(key);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>> save(
      String userId, Map<String, dynamic> payload) async {
    final response = await _apiClient.post(
      ApiEndpoints.carbonEstimates,
      data: payload,
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    final saved = Map<String, dynamic>.from(body['data'] as Map);
    final historyRows = await history(userId);
    final merged = [
      saved,
      ...historyRows.where((row) => row['id'] != saved['id'])
    ].take(100).toList(growable: false);
    await LocalStorageService.instance
        .setString('carbon_history_$userId', jsonEncode(merged));
    return saved;
  }

  CarbonFactorCatalog _catalog(Map<String, dynamic> json,
      {required bool isOfflineCopy}) {
    final items = (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => CarbonFactor.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    return CarbonFactorCatalog(
      items: items,
      cachedAt: DateTime.tryParse(json['cached_at']?.toString() ?? '') ??
          DateTime(2026, 1, 1),
      isOfflineCopy: isOfflineCopy,
      method: json['method']?.toString() ??
          'distance × passenger-km factor × travelers × trip multiplier',
      disclaimer: json['disclaimer']?.toString() ??
          'Approximate planning estimates, not measured or audited emissions.',
    );
  }

  static final Map<String, dynamic> _bundledCatalog = {
    'cached_at': '2026-01-01T00:00:00Z',
    'method': 'distance × passenger-km factor × travelers × trip multiplier',
    'disclaimer':
        'Bundled last-known planning factors. Reconnect before saving an estimate.',
    'items': const [
      ['walking', 'Walking', 0.0],
      ['bicycle', 'Bicycle', 0.0],
      ['motorcycle', 'Motorcycle', 0.113],
      ['tricycle', 'Motorized tricycle', 0.120],
      ['private_car', 'Private car', 0.170],
      ['van', 'Van', 0.105],
      ['bus', 'Bus', 0.102],
      ['ferry_foot', 'Ferry (foot passenger)', 0.019],
    ]
        .map((row) => {
              'id': 'bundled:${row[0]}',
              'transport_mode': row[0],
              'display_name': row[1],
              'emission_factor': row[2],
              'unit': 'kg_co2e_per_passenger_km',
              'source_name':
                  'UK Government GHG Conversion Factors 2026 (rounded planning adaptation)',
              'source_year': 2026,
              'source_url':
                  'https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2026',
              'version': '2026.1-bundled',
              'occupancy_assumption': row[0] == 'tricycle'
                  ? 'Transparent local proxy; replace after a verified Tubigon fleet study'
                  : 'Planning estimate; see methodology',
              'is_bundled': true,
            })
        .toList(),
  };
}

final carbonRepositoryProvider = Provider<CarbonRepository>((ref) {
  return CarbonRepository(ref.watch(apiClientProvider));
});

final carbonFactorCatalogProvider = FutureProvider<CarbonFactorCatalog>((ref) {
  return ref.watch(carbonRepositoryProvider).factors();
});
