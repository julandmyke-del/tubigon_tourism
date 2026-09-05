import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

class SettingsRepository {
  const SettingsRepository(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> getSettings() async {
    final response = await _client.get(ApiEndpoints.appSettings);
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> getSystemSettings() async {
    final response = await _client.get(ApiEndpoints.systemSettings);
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> updateSettings(
      Map<String, dynamic> values) async {
    final response = await _client.put(ApiEndpoints.appSettings, data: values);
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(apiClientProvider));
});

final touristSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(settingsRepositoryProvider).getSettings();
});

final systemSettingsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  final timer = Timer(const Duration(minutes: 1), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(settingsRepositoryProvider).getSystemSettings();
});
