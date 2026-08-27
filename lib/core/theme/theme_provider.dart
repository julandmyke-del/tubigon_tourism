import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'theme_mode';

/// Persists and exposes the current [ThemeMode].
class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kThemeModeKey);
    return _fromString(stored);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, _toString(mode));
  }

  Future<void> toggleTheme() async {
    final current = state.valueOrNull ?? ThemeMode.system;
    final next = current == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(next);
  }

  static ThemeMode _fromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
