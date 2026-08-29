import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/features/authentication/google_auth_service.dart';

void main() {
  const webClientId =
      '1010833384154-bifqdi8htq4mvtnm1d6ogm6j0u0v7df3.apps.googleusercontent.com';

  test('Web configuration contains clientId only', () {
    final configuration = GoogleAuthService.platformConfiguration(
      isWeb: true,
      platform: TargetPlatform.android,
      webClientId: webClientId,
      serverClientId: '',
      iosClientId: '',
    );

    expect(configuration.clientId, webClientId);
    expect(configuration.serverClientId, isNull);
  });

  test('Android configuration contains serverClientId only', () {
    final configuration = GoogleAuthService.platformConfiguration(
      isWeb: false,
      platform: TargetPlatform.android,
      webClientId: '',
      serverClientId: webClientId,
      iosClientId: '',
    );

    expect(configuration.clientId, isNull);
    expect(configuration.serverClientId, webClientId);
  });

  test('missing platform client IDs produce controlled errors', () {
    expect(
      () => GoogleAuthService.platformConfiguration(
        isWeb: true,
        platform: TargetPlatform.android,
        webClientId: '',
        serverClientId: webClientId,
        iosClientId: '',
      ),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('GOOGLE_CLIENT_ID'),
        ),
      ),
    );
    expect(
      () => GoogleAuthService.platformConfiguration(
        isWeb: false,
        platform: TargetPlatform.android,
        webClientId: webClientId,
        serverClientId: '',
        iosClientId: '',
      ),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('GOOGLE_SERVER_CLIENT_ID'),
        ),
      ),
    );
  });
}
