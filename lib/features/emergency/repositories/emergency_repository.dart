import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../database/database_helper.dart';
import '../models/emergency_contact.dart';

class EmergencyRepository {
  EmergencyRepository({required this.apiClient});

  final ApiClient apiClient;
  final dbHelper = DatabaseHelper.instance;
  static const _webCacheKey = 'emergency_contacts_public_cache_v1';
  static const _cacheUpdatedKey = 'emergency_contacts_cache_updated_at_v1';

  static DateTime? get cacheUpdatedAt => DateTime.tryParse(
        LocalStorageService.instance.getString(_cacheUpdatedKey) ?? '',
      );

  Future<void> _recordCacheRefresh() => LocalStorageService.instance.setString(
        _cacheUpdatedKey,
        DateTime.now().toUtc().toIso8601String(),
      );

  /// Fetches the current active directory and replaces the local safety cache.
  Future<List<EmergencyContact>> getEmergencyContacts() async {
    if (!DatabaseHelper.isSupported) {
      if (await checkConnectivity()) {
        try {
          final remote = await _fetchRemote();
          await LocalStorageService.instance.setString(
            _webCacheKey,
            jsonEncode(remote.map((item) => item.toJson()).toList()),
          );
          await _recordCacheRefresh();
          return remote;
        } catch (_) {}
      }
      final raw = LocalStorageService.instance.getString(_webCacheKey);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map>()
          .map((item) => EmergencyContact.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(growable: false);
    }

    if (SyncService.instance.isOnline) {
      try {
        final parsed = await _fetchRemote();

        // Replace rather than merge: deactivated and archived contacts must
        // disappear from the tourist cache as soon as the API is refreshed.
        await dbHelper.delete(
          'emergency_contacts',
          where: '1 = 1',
          whereArgs: const [],
        );
        for (final item in parsed) {
          final itemJson = item.toJson();
          await dbHelper.insert('emergency_contacts', itemJson);
        }
        await _recordCacheRefresh();
        return parsed;
      } catch (error) {
        debugPrint('Error refreshing emergency contacts from API: $error');
      }
    }

    final localMaps = await dbHelper.query(
      'emergency_contacts',
      where: 'is_active = ?',
      whereArgs: const [1],
      orderBy: 'category ASC, name ASC',
    );
    return localMaps.map(EmergencyContact.fromJson).toList(growable: false);
  }

  Future<List<EmergencyContact>> _fetchRemote() async {
    final response = await apiClient.get(ApiEndpoints.emergencyContacts);
    if (response.statusCode != 200 || response.data['status'] != 'success') {
      throw const FormatException('Invalid emergency contact response.');
    }
    final rows = response.data['data'];
    if (rows is! List) {
      throw const FormatException('Invalid emergency contact data.');
    }
    return rows
        .whereType<Map<String, dynamic>>()
        .map(EmergencyContact.fromJson)
        .toList(growable: false);
  }
}

final emergencyRepositoryProvider = Provider<EmergencyRepository>((ref) {
  return EmergencyRepository(apiClient: ref.watch(apiClientProvider));
});

final emergencyContactsListProvider =
    FutureProvider<List<EmergencyContact>>((ref) async {
  return ref.watch(emergencyRepositoryProvider).getEmergencyContacts();
});

final emergencyContactsProvider = emergencyContactsListProvider;
