import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubigon_tourism/core/exceptions/app_exception.dart';
import 'package:tubigon_tourism/core/services/local_storage_service.dart';
import 'package:tubigon_tourism/core/services/private_session_data_service.dart';
import 'package:tubigon_tourism/core/widgets/live_greeting.dart';

void main() {
  test('greeting periods cover all local hours at the expected boundaries', () {
    expect(greetingKeyForHour(0), 'good_evening');
    expect(greetingKeyForHour(4), 'good_evening');
    expect(greetingKeyForHour(5), 'good_morning');
    expect(greetingKeyForHour(11), 'good_morning');
    expect(greetingKeyForHour(12), 'good_afternoon');
    expect(greetingKeyForHour(17), 'good_afternoon');
    expect(greetingKeyForHour(18), 'good_evening');
    expect(greetingKeyForHour(23), 'good_evening');
  });

  test('typed API exceptions expose only their user-safe message', () {
    const error = AuthException(
      message: 'You do not have permission to access this feature.',
      statusCode: 403,
      isUnauthorized: true,
    );
    expect(
        error.toString(), 'You do not have permission to access this feature.');
    expect(error.toString(), isNot(contains('AuthException')));
    expect(error.toString(), isNot(contains('statusCode')));
  });

  test('native auth metadata remains available through local storage',
      () async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
    final storage = LocalStorageService.instance;
    await storage.setBool('auth_logged_in', value: true);
    await storage.setString('auth_role', 'tourist');
    await storage.setString('auth_user_id', 'tourist-a');

    expect(storage.getBool('auth_logged_in'), isTrue);
    expect(storage.getString('auth_role'), 'tourist');
    expect(storage.getString('auth_user_id'), 'tourist-a');
  });

  test('private map cache keys differ between users and roles', () {
    final tourist = PrivateSessionDataService.mapCacheKey(
      isLoggedIn: true,
      role: 'tourist',
      userId: 'user-a',
    );
    final msmeA = PrivateSessionDataService.mapCacheKey(
      isLoggedIn: true,
      role: 'msmeOwner',
      userId: 'user-a',
    );
    final msmeB = PrivateSessionDataService.mapCacheKey(
      isLoggedIn: true,
      role: 'msmeOwner',
      userId: 'user-b',
    );

    expect(tourist, 'smart_map_cache_public');
    expect(msmeA, isNot(msmeB));
  });
}
