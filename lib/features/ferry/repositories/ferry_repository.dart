import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../database/database_helper.dart';
import '../models/ferry.dart';

class FerryRepository {
  FerryRepository({required this.apiClient});

  final ApiClient apiClient;
  final dbHelper = DatabaseHelper.instance;
  static const _webCacheKey = 'ferry_schedules_public_cache_v1';

  Future<List<FerryOperator>> getFerryOperators() async {
    final response = await apiClient.get(ApiEndpoints.ferryOperators);
    if (response.statusCode != 200 || response.data['status'] != 'success') {
      throw const FormatException('Invalid ferry operator response.');
    }
    final rows = response.data['data'];
    if (rows is! List) {
      throw const FormatException('Invalid ferry operator data.');
    }
    return rows
        .whereType<Map<String, dynamic>>()
        .map(FerryOperator.fromJson)
        .toList(growable: false);
  }

  Future<List<Ferry>> getFerrySchedules() async {
    if (!DatabaseHelper.isSupported) {
      if (await checkConnectivity()) {
        try {
          final remote = await _fetchRemote();
          await LocalStorageService.instance.setString(
            _webCacheKey,
            jsonEncode(remote.map((item) => item.toJson()).toList()),
          );
          return remote;
        } catch (_) {
          final cached = LocalStorageService.instance.getString(_webCacheKey);
          if (cached == null) rethrow;
        }
      }
      final raw = LocalStorageService.instance.getString(_webCacheKey);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map>()
          .map((item) => Ferry.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    }

    final localMaps =
        await dbHelper.query('ferry_schedules', orderBy: 'departure_time ASC');
    var items = localMaps.map(Ferry.fromJson).toList();

    if (SyncService.instance.isOnline) {
      try {
        final remoteItems = await _fetchRemote();
        // The public API is authoritative. Replace the cache so archived
        // schedules disappear instead of surviving an upsert-only sync.
        await dbHelper.delete(
          'ferry_schedules',
          where: '1 = 1',
          whereArgs: const [],
        );
        for (final parsedItem in remoteItems) {
          await dbHelper.insert('ferry_schedules', parsedItem.toJson());
        }
        final updatedLocal = await dbHelper.query(
          'ferry_schedules',
          orderBy: 'departure_time ASC',
        );
        items = updatedLocal.map(Ferry.fromJson).toList();
      } catch (error) {
        debugPrint('Error syncing ferry schedules from API: $error');
        if (items.isEmpty) rethrow;
      }
    }

    return items;
  }

  Future<List<Ferry>> _fetchRemote() async {
    final response = await apiClient.get(ApiEndpoints.ferrySchedules);
    if (response.statusCode != 200 || response.data['status'] != 'success') {
      throw const FormatException('Invalid ferry schedule response.');
    }
    final rows = response.data['data'];
    if (rows is! List) {
      throw const FormatException('Invalid ferry schedule data.');
    }
    return rows
        .whereType<Map<String, dynamic>>()
        .map(Ferry.fromJson)
        .toList(growable: false);
  }
}

final ferryRepositoryProvider = Provider<FerryRepository>((ref) {
  return FerryRepository(apiClient: ref.watch(apiClientProvider));
});

final ferrySchedulesListProvider = FutureProvider<List<Ferry>>((ref) async {
  return ref.watch(ferryRepositoryProvider).getFerrySchedules();
});

final ferrySchedulesProvider = ferrySchedulesListProvider;

final ferryOperatorsProvider = FutureProvider<List<FerryOperator>>((ref) async {
  return ref.watch(ferryRepositoryProvider).getFerryOperators();
});
