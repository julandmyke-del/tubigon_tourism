import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../database/database_helper.dart';
import '../models/eco_tip.dart';

class EcoRepository {
  EcoRepository({required this.apiClient});

  final ApiClient apiClient;
  final dbHelper = DatabaseHelper.instance;
  static const _webCacheKey = 'eco_tips_public_cache_v2';

  Future<List<EcoTip>> getEcoTips() async {
    if (!DatabaseHelper.isSupported) {
      try {
        final remote = await _fetchRemote();
        await LocalStorageService.instance.setString(_webCacheKey,
            jsonEncode(remote.map((item) => item.toJson()).toList()));
        return remote;
      } catch (_) {
        final cached = LocalStorageService.instance.getString(_webCacheKey);
        if (cached == null) rethrow;
        return (jsonDecode(cached) as List<dynamic>)
            .whereType<Map>()
            .map((item) => EcoTip.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false);
      }
    }

    final localMaps = await dbHelper.query('eco_tips', orderBy: 'id ASC');
    var items = localMaps.map(EcoTip.fromJson).toList();

    if (SyncService.instance.isOnline) {
      try {
        final remoteItems = await _fetchRemote();
        await dbHelper.delete('eco_tips', where: '1 = 1', whereArgs: const []);
        for (final parsedItem in remoteItems) {
          final itemJson = parsedItem.toJson();
          await dbHelper.insert('eco_tips', itemJson);
        }
        final updatedLocal =
            await dbHelper.query('eco_tips', orderBy: 'id ASC');
        items = updatedLocal.map(EcoTip.fromJson).toList();
      } catch (error) {
        debugPrint('Error syncing eco tips from API: $error');
      }
    }

    return items;
  }

  Future<List<EcoTip>> _fetchRemote() async {
    final response = await apiClient.get(ApiEndpoints.ecoTips);
    if (response.statusCode != 200 || response.data['status'] != 'success') {
      throw const FormatException('Invalid eco tip response.');
    }
    final rows = response.data['data'];
    if (rows is! List) throw const FormatException('Invalid eco tip data.');
    return rows
        .whereType<Map<String, dynamic>>()
        .map(EcoTip.fromJson)
        .toList(growable: false);
  }
}

final ecoRepositoryProvider = Provider<EcoRepository>((ref) {
  return EcoRepository(apiClient: ref.watch(apiClientProvider));
});

final ecoTipsListProvider = FutureProvider<List<EcoTip>>((ref) async {
  return ref.watch(ecoRepositoryProvider).getEcoTips();
});

final ecoTipsProvider = ecoTipsListProvider;
