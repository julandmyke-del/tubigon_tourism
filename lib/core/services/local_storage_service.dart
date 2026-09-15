import 'package:shared_preferences/shared_preferences.dart';

import 'session_storage_bridge.dart';

/// Wrapper around [SharedPreferences] for non-sensitive local storage.
class LocalStorageService {
  LocalStorageService._(this._prefs);

  final SharedPreferences _prefs;

  static LocalStorageService? _instance;

  static bool get isInitialized => _instance != null;

  static Future<LocalStorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    if (sessionStorageAvailable) {
      // Auth metadata from older releases lived in origin-wide localStorage.
      // Remove it rather than allowing a stale account to seed a new tab.
      for (final key in prefs.getKeys().where(_isAuthKey)) {
        await prefs.remove(key);
      }
    }
    _instance = LocalStorageService._(prefs);
    return _instance!;
  }

  static LocalStorageService get instance {
    assert(_instance != null,
        'LocalStorageService not initialized. Call init() first.');
    return _instance!;
  }

  // ─── String ───────────────────────────────────────────────────────────────
  String? getString(String key) =>
      _isWebSessionKey(key) ? readSessionValue(key) : _prefs.getString(key);
  Future<bool> setString(String key, String value) async {
    if (_isWebSessionKey(key)) {
      writeSessionValue(key, value);
      return true;
    }
    return _prefs.setString(key, value);
  }

  // ─── Bool ─────────────────────────────────────────────────────────────────
  bool? getBool(String key) {
    if (!_isWebSessionKey(key)) return _prefs.getBool(key);
    final value = readSessionValue(key);
    if (value == null) return null;
    return value == 'true';
  }

  Future<bool> setBool(String key, {required bool value}) async {
    if (_isWebSessionKey(key)) {
      writeSessionValue(key, value.toString());
      return true;
    }
    return _prefs.setBool(key, value);
  }

  // ─── Int ──────────────────────────────────────────────────────────────────
  int? getInt(String key) => _prefs.getInt(key);
  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);

  // ─── Double ───────────────────────────────────────────────────────────────
  double? getDouble(String key) => _prefs.getDouble(key);
  Future<bool> setDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  // ─── StringList ───────────────────────────────────────────────────────────
  List<String>? getStringList(String key) => _prefs.getStringList(key);
  Future<bool> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  // ─── Convenience ──────────────────────────────────────────────────────────
  Future<bool> remove(String key) async {
    if (_isWebSessionKey(key)) {
      removeSessionValue(key);
      return true;
    }
    return _prefs.remove(key);
  }

  Future<bool> clear() async {
    if (sessionStorageAvailable) {
      clearSessionValues(sessionStorageKeys().where(_isAuthKey));
    }
    return _prefs.clear();
  }

  bool containsKey(String key) => _isWebSessionKey(key)
      ? readSessionValue(key) != null
      : _prefs.containsKey(key);

  Set<String> get keys => {
        ..._prefs.getKeys(),
        if (sessionStorageAvailable) ...sessionStorageKeys().where(_isAuthKey),
      };

  static bool _isAuthKey(String key) => key.startsWith('auth_');

  static bool _isWebSessionKey(String key) =>
      sessionStorageAvailable && _isAuthKey(key);
}
