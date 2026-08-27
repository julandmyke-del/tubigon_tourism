import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/sync_service.dart';
import '../../../database/database_helper.dart';
import '../models/tourist_spot.dart';

class TouristSpotRepository {
  TouristSpotRepository({required this.apiClient});

  final ApiClient apiClient;
  final dbHelper = DatabaseHelper.instance;

  /// Fetches the tourist spots list. Checks SQLite first, pulls from Laravel API if online.
  Future<List<TouristSpot>> getSpots() async {
    if (!DatabaseHelper.isSupported) {
      return _fetchRemoteSpots();
    }

    final localMaps = await dbHelper.query('tourist_spots',
        orderBy: 'is_featured DESC, id ASC');
    List<TouristSpot> spots =
        localMaps.map((m) => TouristSpot.fromJson(m)).toList();

    if (SyncService.instance.isOnline) {
      try {
        await getCategories();

        final response = await apiClient.get(ApiEndpoints.touristSpots);

        if (response.statusCode == 200 &&
            response.data['status'] == 'success') {
          final remoteData = response.data['data'] as List<dynamic>;

          for (final item in remoteData) {
            final row = item as Map<String, dynamic>;
            final uuid = row['id'] as String;
            final integerId = (row['integer_id'] as int?) ?? 1;

            final localSpotResult = await dbHelper.query(
              'tourist_spots',
              where: 'uuid = ?',
              whereArgs: [uuid],
            );

            final parsedSpot = TouristSpot.fromJson(row);
            final spotJson = parsedSpot.toJson();
            spotJson['id'] = integerId;

            if (localSpotResult.isEmpty) {
              await dbHelper.insert('tourist_spots', spotJson);
            } else {
              await dbHelper.update(
                'tourist_spots',
                spotJson,
                where: 'uuid = ?',
                whereArgs: [uuid],
              );
            }
          }

          final updatedLocal = await dbHelper.query('tourist_spots',
              orderBy: 'is_featured DESC, id ASC');
          spots = updatedLocal.map((m) => TouristSpot.fromJson(m)).toList();
        }
      } catch (e) {
        debugPrint('Error syncing spots from API: $e');
      }
    }

    return spots;
  }

  /// Fetches categories.
  Future<List<SpotCategory>> getCategories() async {
    if (!DatabaseHelper.isSupported) {
      return _fetchRemoteCategories();
    }

    final localMaps = await dbHelper.query('spot_categories');
    List<SpotCategory> categories =
        localMaps.map((m) => SpotCategory.fromJson(m)).toList();

    if (SyncService.instance.isOnline) {
      try {
        final response = await apiClient.get(ApiEndpoints.spotCategories);

        if (response.statusCode == 200 &&
            response.data['status'] == 'success') {
          final remoteData = response.data['data'] as List<dynamic>;

          for (final item in remoteData) {
            final row = item as Map<String, dynamic>;
            final uuid = row['id'] as String;
            final integerId = (row['integer_id'] as int?) ?? 1;

            final localCat = await dbHelper.query(
              'spot_categories',
              where: 'uuid = ?',
              whereArgs: [uuid],
            );

            final parsedCat = SpotCategory.fromJson(row);
            final catJson = parsedCat.toJson();
            catJson['id'] = integerId;

            if (localCat.isEmpty) {
              await dbHelper.insert('spot_categories', catJson);
            } else {
              await dbHelper.update(
                'spot_categories',
                catJson,
                where: 'uuid = ?',
                whereArgs: [uuid],
              );
            }
          }

          final updatedLocal = await dbHelper.query('spot_categories');
          categories =
              updatedLocal.map((m) => SpotCategory.fromJson(m)).toList();
        }
      } catch (e) {
        debugPrint('Error syncing categories from API: $e');
      }
    }

    return categories;
  }

  /// Fetches a single spot details by integer ID.
  Future<TouristSpot?> getSpotById(int id) async {
    if (!DatabaseHelper.isSupported) {
      final spots = await _fetchRemoteSpots();
      for (final spot in spots) {
        if (spot.id == id) return spot;
      }
      return null;
    }

    final localResult = await dbHelper.query(
      'tourist_spots',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (localResult.isNotEmpty) {
      return TouristSpot.fromJson(localResult.first);
    }
    return null;
  }

  Future<List<TouristSpot>> _fetchRemoteSpots() async {
    final response = await apiClient.get(ApiEndpoints.touristSpots);
    if (response.statusCode != 200 || response.data['status'] != 'success') {
      throw const FormatException('Invalid tourist spot response.');
    }
    final rows = response.data['data'];
    if (rows is! List) {
      throw const FormatException('Invalid tourist spot data.');
    }
    return rows
        .whereType<Map<String, dynamic>>()
        .map(TouristSpot.fromJson)
        .toList(growable: false);
  }

  Future<List<SpotCategory>> _fetchRemoteCategories() async {
    final response = await apiClient.get(ApiEndpoints.spotCategories);
    if (response.statusCode != 200 || response.data['status'] != 'success') {
      throw const FormatException('Invalid spot category response.');
    }
    final rows = response.data['data'];
    if (rows is! List) {
      throw const FormatException('Invalid spot category data.');
    }
    return rows
        .whereType<Map<String, dynamic>>()
        .map(SpotCategory.fromJson)
        .toList(growable: false);
  }
}

// ─── Riverpod Providers ────────────────────────────────────────────────────────

final touristSpotRepositoryProvider = Provider<TouristSpotRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return TouristSpotRepository(apiClient: client);
});

final touristSpotsListProvider = FutureProvider<List<TouristSpot>>((ref) async {
  final repo = ref.watch(touristSpotRepositoryProvider);
  return repo.getSpots();
});

final spotCategoriesProvider = FutureProvider<List<SpotCategory>>((ref) async {
  final repo = ref.watch(touristSpotRepositoryProvider);
  return repo.getCategories();
});
