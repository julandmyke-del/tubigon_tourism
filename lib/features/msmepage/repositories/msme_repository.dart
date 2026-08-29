import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/sync_service.dart';
import '../../../database/database_helper.dart';
import '../models/msme.dart';

class MsmeRepository {
  MsmeRepository({required this.apiClient});

  final ApiClient apiClient;
  final dbHelper = DatabaseHelper.instance;

  Future<List<Msme>> getMsmes() async {
    if (!DatabaseHelper.isSupported) {
      return _fetchRemote();
    }

    final localMaps =
        await dbHelper.query('msmes', orderBy: 'is_verified DESC, id ASC');
    List<Msme> msmes = localMaps.map((m) => Msme.fromJson(m)).toList();

    if (SyncService.instance.isOnline) {
      try {
        final response = await apiClient.get(ApiEndpoints.msmes);
        if (response.statusCode == 200 &&
            response.data['status'] == 'success') {
          final remoteData = response.data['data'] as List<dynamic>;

          // Public MSME responses contain verified businesses only. Replace
          // the cache so unverified/archived entries disappear immediately.
          await dbHelper.delete(
            'msmes',
            where: '1 = 1',
            whereArgs: const [],
          );

          for (final item in remoteData) {
            final row = item as Map<String, dynamic>;
            final integerId = (row['integer_id'] as int?) ?? 1;

            final parsedMsme = Msme.fromJson(row);
            final msmeJson = parsedMsme.toJson();
            msmeJson['id'] = integerId;
            await dbHelper.insert('msmes', msmeJson);
          }

          final updatedLocal = await dbHelper.query('msmes',
              orderBy: 'is_verified DESC, id ASC');
          msmes = updatedLocal.map((m) => Msme.fromJson(m)).toList();
        }
      } catch (e) {
        debugPrint('Error syncing MSMEs from API: $e');
      }
    }

    return msmes;
  }

  Future<Msme?> getMsmeById(int id) async {
    if (!DatabaseHelper.isSupported) {
      final msmes = await _fetchRemote();
      for (final msme in msmes) {
        if (msme.id == id) return msme;
      }
      return null;
    }

    final localResult = await dbHelper.query(
      'msmes',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (localResult.isNotEmpty) {
      return Msme.fromJson(localResult.first);
    }
    return null;
  }

  Future<List<Msme>> _fetchRemote() async {
    final response = await apiClient.get(ApiEndpoints.msmes);
    if (response.statusCode != 200 || response.data['status'] != 'success') {
      throw const FormatException('Invalid MSME response.');
    }
    final rows = response.data['data'];
    if (rows is! List) throw const FormatException('Invalid MSME data.');
    return rows
        .whereType<Map<String, dynamic>>()
        .map(Msme.fromJson)
        .toList(growable: false);
  }
}

final msmeRepositoryProvider = Provider<MsmeRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return MsmeRepository(apiClient: client);
});

final msmeListProvider = FutureProvider<List<Msme>>((ref) async {
  final repo = ref.watch(msmeRepositoryProvider);
  return repo.getMsmes();
});

final msmesProvider = msmeListProvider;
