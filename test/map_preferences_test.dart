import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubigon_tourism/core/constants/app_constants.dart';
import 'package:tubigon_tourism/core/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('place-label preference persists through Web-safe local storage',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.init();

    expect(storage.getBool(AppConstants.mapLabelsVisibleKey), isNull);
    await storage.setBool(
      AppConstants.mapLabelsVisibleKey,
      value: false,
    );

    expect(storage.getBool(AppConstants.mapLabelsVisibleKey), isFalse);
  });

  test('resolved API base URL never has a trailing slash', () {
    expect(AppConstants.apiBaseUrl, isNotEmpty);
    expect(AppConstants.apiBaseUrl.endsWith('/'), isFalse);
  });
}
