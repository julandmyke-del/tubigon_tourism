import 'package:shared_preferences/shared_preferences.dart';

/// Wrapper around [SharedPreferences] for non-sensitive local storage.
class LocalStorageService {
  LocalStorageService._(this._prefs);

  final SharedPreferences _prefs;

  static LocalStorageService? _instance;

  static bool get isInitialized => _instance != null;

  static Future<LocalStorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    _instance = LocalStorageService._(prefs);
    return _instance!;
  }

  static LocalStorageService get instance {
    assert(_instance != null,
        'LocalStorageService not initialized. Call init() first.');
    return _instance!;
  }

  // ─── String ───────────────────────────────────────────────────────────────
  String? getString(String key) => _prefs.getString(key);
  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  // ─── Bool ─────────────────────────────────────────────────────────────────
  bool? getBool(String key) => _prefs.getBool(key);
  Future<bool> setBool(String key, {required bool value}) =>
      _prefs.setBool(key, value);

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
  Future<bool> remove(String key) => _prefs.remove(key);
  Future<bool> clear() => _prefs.clear();
  bool containsKey(String key) => _prefs.containsKey(key);

  Set<String> get keys => _prefs.getKeys();
}
