import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthCancelledException implements Exception {
  const GoogleAuthCancelledException();

  @override
  String toString() => 'Google sign-in was cancelled.';
}

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static Future<void>? _initialization;

  static Stream<GoogleSignInAuthenticationEvent> get authenticationEvents =>
      _googleSignIn.authenticationEvents;

  static Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    const webClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
    const serverClientId = String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
      defaultValue: webClientId,
    );
    const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

    if (serverClientId.isEmpty) {
      throw Exception(
        'Google sign-in is not configured. Provide GOOGLE_SERVER_CLIENT_ID at build time.',
      );
    }

    final clientId = kIsWeb
        ? webClientId
        : defaultTargetPlatform == TargetPlatform.iOS && iosClientId.isNotEmpty
            ? iosClientId
            : null;

    await _googleSignIn.initialize(
      clientId: clientId,
      serverClientId: serverClientId,
    );
  }

  static Future<GoogleSignInAccount> authenticate() async {
    await initialize();

    if (!_googleSignIn.supportsAuthenticate()) {
      throw UnsupportedError(
        'This platform requires the official Google-rendered sign-in button.',
      );
    }

    try {
      // Authentication requests only the default OpenID identity scopes.
      return await _googleSignIn.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        throw const GoogleAuthCancelledException();
      }
      throw Exception('Google sign-in failed. Please try again.');
    }
  }

  static String idTokenFor(GoogleSignInAccount account) {
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google did not return a valid identity token.');
    }
    return idToken;
  }

  static Future<void> signOut() async {
    if (_initialization == null) return;
    await _initialization;
    await _googleSignIn.signOut();
  }
}
