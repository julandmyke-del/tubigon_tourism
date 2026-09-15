import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_storage_bridge.dart';

/// Wrapper around [FlutterSecureStorage] for sensitive data (tokens, PII).
class SecureStorageService {
  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final FlutterSecureStorage _storage;

  // ─── Basic CRUD ───────────────────────────────────────────────────────────
  Future<String?> read(String key) async {
    if (sessionStorageAvailable && _sessionKeys.contains(key)) {
      return readSessionValue(key);
    }
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, String value) async {
    if (sessionStorageAvailable && _sessionKeys.contains(key)) {
      writeSessionValue(key, value);
      return;
    }
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {}
  }

  Future<void> delete(String key) async {
    if (sessionStorageAvailable && _sessionKeys.contains(key)) {
      removeSessionValue(key);
      return;
    }
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  Future<void> deleteAll() async {
    if (sessionStorageAvailable) {
      clearSessionValues(_sessionKeys);
      // Remove the origin-wide secure-storage entries used by older web
      // releases. Current tab tokens are never written there.
      for (final key in _sessionKeys) {
        try {
          await _storage.delete(key: key);
        } catch (_) {}
      }
      return;
    }
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }

  Future<Map<String, String>> readAll() async {
    if (sessionStorageAvailable) {
      return {
        for (final key in _sessionKeys)
          if (readSessionValue(key) case final value?) key: value,
      };
    }
    try {
      return await _storage.readAll();
    } catch (_) {
      return {};
    }
  }

  Future<bool> containsKey(String key) async {
    if (sessionStorageAvailable && _sessionKeys.contains(key)) {
      return readSessionValue(key) != null;
    }
    try {
      return await _storage.containsKey(key: key);
    } catch (_) {
      return false;
    }
  }

  // ─── Auth Token Shortcuts ─────────────────────────────────────────────────
  Future<String?> readAuthToken() => read('auth_token');
  Future<void> writeAuthToken(String token) => write('auth_token', token);
  Future<void> deleteAuthToken() => delete('auth_token');

  Future<String?> readRefreshToken() => read('refresh_token');
  Future<void> writeRefreshToken(String token) => write('refresh_token', token);

  Future<void> clearAuthData() async {
    await deleteAll();
  }

  static const _sessionKeys = <String>{'auth_token', 'refresh_token'};
}
