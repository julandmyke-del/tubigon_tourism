import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/sync_service.dart';
import '../../../database/database_helper.dart';
import '../models/eco_tip.dart';

class EcoRepository {
  EcoRepository({required this.apiClient});

  final ApiClient apiClient;
  final dbHelper = DatabaseHelper.instance;

  Future<List<EcoTip>> getEcoTips() async {
    if (!DatabaseHelper.isSupported) {
      return _fetchRemote();
    }

    final localMaps = await dbHelper.query('eco_tips', orderBy: 'id ASC');
    var items = localMaps.map(EcoTip.fromJson).toList();

    if (SyncService.instance.isOnline) {
      try {
        final remoteItems = await _fetchRemote();
        for (final parsedItem in remoteItems) {
          final localResult = await dbHelper.query(
            'eco_tips',
            where: 'uuid = ?',
            whereArgs: [parsedItem.uuid],
          );
          final itemJson = parsedItem.toJson();
          if (localResult.isEmpty) {
            await dbHelper.insert('eco_tips', itemJson);
          } else {
            await dbHelper.update(
              'eco_tips',
              itemJson,
              where: 'uuid = ?',
              whereArgs: [parsedItem.uuid],
            );
          }
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
