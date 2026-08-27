import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper around [FlutterSecureStorage] for sensitive data (tokens, PII).
class SecureStorageService {
  SecureStorageService() : _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final FlutterSecureStorage _storage;

  // ─── Basic CRUD ───────────────────────────────────────────────────────────
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {}
  }

  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }

  Future<Map<String, String>> readAll() async {
    try {
      return await _storage.readAll();
    } catch (_) {
      return {};
    }
  }

  Future<bool> containsKey(String key) async {
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
}
