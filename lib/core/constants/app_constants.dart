import 'package:flutter/foundation.dart';

/// Tubigon Smart Tourism — Application Constants
abstract final class AppConstants {
  // ─── App Metadata ─────────────────────────────────────────────────────────
  static const String appName = 'Tubigon Smart Tourism';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';
  static const String municipality = 'Tubigon';
  static const String province = 'Bohol';
  static const String country = 'Philippines';

  // ─── API ──────────────────────────────────────────────────────────────────
  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _webApiBaseUrl =
      String.fromEnvironment('WEB_API_BASE_URL');
  static const String _androidApiBaseUrl =
      String.fromEnvironment('ANDROID_API_BASE_URL');
  static const String _iosApiBaseUrl =
      String.fromEnvironment('IOS_API_BASE_URL');

  static String get apiBaseUrl {
    if (_apiBaseUrl.isNotEmpty) return _withoutTrailingSlash(_apiBaseUrl);
    if (kIsWeb) {
      return _withoutTrailingSlash(
          _webApiBaseUrl.isNotEmpty ? _webApiBaseUrl : 'http://localhost:8000');
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _withoutTrailingSlash(_androidApiBaseUrl.isNotEmpty
          ? _androidApiBaseUrl
          : 'http://10.0.2.2:8000');
    }
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        _iosApiBaseUrl.isNotEmpty) {
      return _withoutTrailingSlash(_iosApiBaseUrl);
    }
    return 'http://127.0.0.1:8000';
  }

  static String _withoutTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;

  static const String apiVersion = 'v1';
  static const String apiPrefix = '/api/$apiVersion';
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration apiConnectTimeout = Duration(seconds: 10);
  static const Duration apiReceiveTimeout = Duration(seconds: 30);
  static const int apiMaxRetries = 3;

  // ─── Pagination ────────────────────────────────────────────────────────────
  static const int defaultPageSize = 15;
  static const int maxPageSize = 50;

  // ─── Sync ─────────────────────────────────────────────────────────────────
  static const Duration syncInterval = Duration(minutes: 5);
  static const Duration cacheExpiry = Duration(hours: 24);
  static const Duration offlineCacheExpiry = Duration(days: 7);

  // ─── Location ─────────────────────────────────────────────────────────────
  // Tubigon, Bohol municipality center
  static const double tubigonLat = 9.9515287;
  static const double tubigonLng = 123.9618897;
  static const double defaultMapZoom = 13.0;
  static const double nearbyRadiusKm = 10.0;
  static const String mapStyleUrl = String.fromEnvironment(
    'MAP_STYLE_URL',
    defaultValue: 'https://tiles.openfreemap.org/styles/liberty',
  );

  // ─── Storage Keys ─────────────────────────────────────────────────────────
  static const String authTokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String onboardingKey = 'onboarding_complete';
  static const String languageKey = 'app_language';
  static const String lastSyncKey = 'last_sync_timestamp';
  static const String mapLabelsVisibleKey = 'smart_map_show_place_labels';

  // ─── Image ────────────────────────────────────────────────────────────────
  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5MB
  static const int imageQuality = 85;
  static const int thumbnailSize = 400;

  // ─── Validation ───────────────────────────────────────────────────────────
  static const int minPasswordLength = 8;
  static const int maxBioLength = 500;
  static const int maxReviewLength = 1000;

  // ─── Animation ────────────────────────────────────────────────────────────
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);
  static const Duration animPageTransition = Duration(milliseconds: 350);

  // ─── Supported Languages ──────────────────────────────────────────────────
  static const List<String> supportedLocales = ['en', 'ceb'];
  static const String defaultLocale = 'en';
}
