import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_storage_service.dart';
import 'ceb.dart';
import 'en.dart';
import 'fil.dart';

const _localeStorageKey = 'preferred_locale';

class LocaleController extends StateNotifier<Locale> {
  LocaleController([Locale? deviceLocale])
      : super(Locale(_initialLanguage(deviceLocale)));

  static String _initialLanguage(Locale? deviceLocale) {
    final stored = LocalStorageService.isInitialized
        ? LocalStorageService.instance.getString(_localeStorageKey)
        : null;
    if (stored == 'en' || stored == 'fil' || stored == 'ceb') return stored!;
    final device = (deviceLocale ?? PlatformDispatcher.instance.locale)
        .languageCode
        .toLowerCase();
    if (device == 'fil' || device == 'tl') return 'fil';
    if (device == 'ceb') return 'ceb';
    return 'en';
  }

  Future<void> select(String languageCode) async {
    final supported = switch (languageCode) {
      'fil' || 'tl' => 'fil',
      'ceb' => 'ceb',
      _ => 'en',
    };
    if (LocalStorageService.isInitialized) {
      await LocalStorageService.instance
          .setString(_localeStorageKey, supported);
    }
    state = Locale(supported);
  }
}

final localeProvider = StateNotifierProvider<LocaleController, Locale>(
    (ref) => LocaleController());

/// Flutter does not ship framework-level Cebuano strings. These delegates keep
/// standard Material/Cupertino controls usable while app-owned text comes from
/// [cebStrings].
class CebuanoMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const CebuanoMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ceb';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture<MaterialLocalizations>(
          const DefaultMaterialLocalizations());

  @override
  bool shouldReload(CebuanoMaterialLocalizationsDelegate old) => false;
}

class CebuanoWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const CebuanoWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ceb';

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      SynchronousFuture<WidgetsLocalizations>(
          const DefaultWidgetsLocalizations());

  @override
  bool shouldReload(CebuanoWidgetsLocalizationsDelegate old) => false;
}

class CebuanoCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const CebuanoCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ceb';

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture<CupertinoLocalizations>(
          const DefaultCupertinoLocalizations());

  @override
  bool shouldReload(CebuanoCupertinoLocalizationsDelegate old) => false;
}

extension LocalizedBuildContext on BuildContext {
  String tr(String key) {
    final language = Localizations.localeOf(this).languageCode;
    final strings = switch (language) {
      'fil' || 'tl' => filStrings,
      'ceb' => cebStrings,
      _ => enStrings,
    };
    return strings[key] ?? enStrings[key] ?? key;
  }
}
