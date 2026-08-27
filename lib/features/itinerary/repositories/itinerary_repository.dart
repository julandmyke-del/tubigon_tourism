import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/local_storage_service.dart';
import '../../authentication/auth_provider.dart';
import '../models/itinerary.dart';

class ItineraryRepository {
  const ItineraryRepository(this._client, this._ref);

  final ApiClient _client;
  final Ref _ref;

  String get _ownerKey => _ref.read(authProvider).userId ?? 'guest';
  String get _listCacheKey => 'itineraries_cache_$_ownerKey';
  String _detailCacheKey(String id) => 'itinerary_detail_${_ownerKey}_$id';

  Future<List<Itinerary>> getItineraries() async {
    try {
      final response = await _client.get(ApiEndpoints.itineraries);
      final rows = response.data['data'];
      if (response.statusCode != 200 || rows is! List) {
        throw const FormatException('Invalid itinerary response.');
      }
      final items = rows
          .whereType<Map>()
          .map((row) => Itinerary.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      await LocalStorageService.instance.setString(_listCacheKey,
          jsonEncode(items.map((item) => item.toJson()).toList()));
      return items;
    } catch (_) {
      final cached = LocalStorageService.instance.getString(_listCacheKey);
      if (cached == null) rethrow;
      return (jsonDecode(cached) as List<dynamic>)
          .whereType<Map>()
          .map((row) => Itinerary.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    }
  }

  Future<Itinerary> getItinerary(String id) async {
    try {
      final response = await _client.get(ApiEndpoints.itinerary(id));
      final row = response.data['data'];
      if (response.statusCode != 200 || row is! Map) {
        throw const FormatException('Invalid itinerary response.');
      }
      final itinerary = Itinerary.fromJson(Map<String, dynamic>.from(row));
      await _cacheDetail(itinerary);
      return itinerary;
    } catch (_) {
      final cached =
          LocalStorageService.instance.getString(_detailCacheKey(id));
      if (cached == null) rethrow;
      return Itinerary.fromJson(
          Map<String, dynamic>.from(jsonDecode(cached) as Map));
    }
  }

  Future<Itinerary> createItinerary(Map<String, dynamic> data) async {
    final response = await _client.post(ApiEndpoints.itineraries, data: data);
    final itinerary = _itineraryFromResponse(response.data);
    await _cacheDetail(itinerary);
    return itinerary;
  }

  Future<Itinerary> updateItinerary(
      String id, Map<String, dynamic> data) async {
    final response = await _client.put(ApiEndpoints.itinerary(id), data: data);
    final itinerary = _itineraryFromResponse(response.data);
    await _cacheDetail(itinerary);
    return itinerary;
  }

  Future<void> archiveItinerary(String id) async {
    await _client.delete(ApiEndpoints.itinerary(id));
    await LocalStorageService.instance.remove(_detailCacheKey(id));
  }

  Future<ItineraryItem> addItem(
    String itineraryId, {
    required String entityType,
    required String entityId,
    required int dayNumber,
    String? plannedStartTime,
    String? plannedEndTime,
    String? notes,
    String? reservationId,
    bool allowDuplicate = false,
  }) async {
    final response = await _client.post(
      ApiEndpoints.itineraryItems(itineraryId),
      data: {
        'entity_type': entityType,
        'entity_id': entityId,
        'day_number': dayNumber,
        'planned_start_time': plannedStartTime,
        'planned_end_time': plannedEndTime,
        'notes': notes,
        'reservation_id': reservationId,
        'allow_duplicate': allowDuplicate,
      },
    );
    return ItineraryItem.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map));
  }

  Future<ItineraryItem> updateItem(
    String itineraryId,
    String itemId,
    Map<String, dynamic> data,
  ) async {
    final response = await _client
        .put(ApiEndpoints.itineraryItem(itineraryId, itemId), data: data);
    return ItineraryItem.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map));
  }

  Future<void> removeItem(String itineraryId, String itemId) async {
    await _client.delete(ApiEndpoints.itineraryItem(itineraryId, itemId));
  }

  Future<Itinerary> reorderItems(
      String itineraryId, List<Map<String, dynamic>> items) async {
    final response = await _client.put(
      ApiEndpoints.reorderItineraryItems(itineraryId),
      data: {'items': items},
    );
    final itinerary = _itineraryFromResponse(response.data);
    await _cacheDetail(itinerary);
    return itinerary;
  }

  Itinerary _itineraryFromResponse(dynamic body) {
    final row = body['data'];
    if (row is! Map) throw const FormatException('Invalid itinerary response.');
    return Itinerary.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> _cacheDetail(Itinerary itinerary) => LocalStorageService.instance
      .setString(_detailCacheKey(itinerary.id), jsonEncode(itinerary.toJson()));
}

final itineraryRepositoryProvider = Provider<ItineraryRepository>((ref) {
  return ItineraryRepository(ref.watch(apiClientProvider), ref);
});

final itinerariesProvider = FutureProvider<List<Itinerary>>((ref) {
  ref.watch(authProvider);
  return ref.watch(itineraryRepositoryProvider).getItineraries();
});

final itineraryDetailProvider =
    FutureProvider.autoDispose.family<Itinerary, String>((ref, id) {
  return ref.watch(itineraryRepositoryProvider).getItinerary(id);
});

void refreshItineraries(WidgetRef ref, [String? id]) {
  ref.invalidate(itinerariesProvider);
  if (id != null) ref.invalidate(itineraryDetailProvider(id));
}
