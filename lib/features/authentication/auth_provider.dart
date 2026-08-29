import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/exceptions/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/private_session_data_service.dart';
import '../../core/services/secure_storage_service.dart';
import '../../database/database_helper.dart';
import 'google_auth_service.dart';

// ─── User Role ────────────────────────────────────────────────────────────────
enum UserRole { guest, tourist, msmeOwner, lguStaff, admin, tourismPartner }

// ─── Custom Exceptions ────────────────────────────────────────────────────────
class UnverifiedEmailException implements Exception {
  final String email;
  final String message;
  final EmailVerificationContext? context;

  const UnverifiedEmailException(
    this.email, [
    this.message = 'Please verify your email address before logging in.',
    this.context,
  ]);

  @override
  String toString() => message;
}

class EmailVerificationContext {
  const EmailVerificationContext({
    required this.email,
    required this.attemptsUsed,
    required this.maxAttempts,
    required this.expiresInSeconds,
    required this.resendAvailableInSeconds,
    required this.codeSent,
  });

  final String email;
  final int attemptsUsed;
  final int maxAttempts;
  final int expiresInSeconds;
  final int resendAvailableInSeconds;
  final bool codeSent;

  int get attemptsRemaining =>
      (maxAttempts - attemptsUsed).clamp(0, maxAttempts);
  bool get isExpired => expiresInSeconds <= 0;

  factory EmailVerificationContext.fromMap(
    Map<String, dynamic>? data, {
    required String fallbackEmail,
  }) {
    int readInt(String key, int fallback) =>
        (data?[key] as num?)?.toInt() ?? fallback;

    return EmailVerificationContext(
      email: data?['email'] as String? ?? fallbackEmail,
      attemptsUsed: readInt('attempts_used', 0),
      maxAttempts: readInt('max_attempts', 5),
      expiresInSeconds: readInt('expires_in_seconds', 0),
      resendAvailableInSeconds: readInt('resend_available_in_seconds', 0),
      codeSent: data?['verification_code_sent'] as bool? ?? false,
    );
  }
}

class VerificationCodeException implements Exception {
  const VerificationCodeException(this.message, this.context);

  final String message;
  final EmailVerificationContext context;

  @override
  String toString() => message;
}

class VerifiedEmailSession {
  const VerifiedEmailSession({required this.token, required this.state});

  final String token;
  final AuthState state;
}

// ─── User Object ─────────────────────────────────────────────────────────────
class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  const User({
    this.id = '',
    this.name = '',
    this.email = '',
    this.role = UserRole.tourist,
  });
}

// ─── Auth State ───────────────────────────────────────────────────────────────
class AuthState {
  final bool isLoggedIn;
  final bool isGuest;
  final bool isRestoring;
  final UserRole role;
  final String? name;
  final String? email;
  final String? userId;

  const AuthState({
    this.isLoggedIn = false,
    this.isGuest = false,
    this.isRestoring = false,
    this.role = UserRole.tourist,
    this.name,
    this.email,
    this.userId,
  });

  bool get isAuthenticated => !isRestoring && (isLoggedIn || isGuest);

  String get homeRoute {
    switch (role) {
      case UserRole.admin:
        return '/admin';
      case UserRole.tourismPartner:
        return '/tourism-partner';
      case UserRole.lguStaff:
        return '/lgu';
      case UserRole.msmeOwner:
        return '/msme-portal';
      case UserRole.tourist:
      case UserRole.guest:
        return '/home';
    }
  }

  User? get user => (isLoggedIn || name != null || email != null)
      ? User(id: userId ?? '', name: name ?? '', email: email ?? '', role: role)
      : null;

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isGuest,
    bool? isRestoring,
    UserRole? role,
    String? name,
    String? email,
    String? userId,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isGuest: isGuest ?? this.isGuest,
      isRestoring: isRestoring ?? this.isRestoring,
      role: role ?? this.role,
      name: name ?? this.name,
      email: email ?? this.email,
      userId: userId ?? this.userId,
    );
  }
}

// ─── Auth Notifier ────────────────────────────────────────────────────────────
class AuthNotifier extends Notifier<AuthState> {
  static const _loggedInKey = 'auth_logged_in';
  static const _guestKey = 'auth_guest';
  static const _roleKey = 'auth_role';
  static const _nameKey = 'auth_name';
  static const _emailKey = 'auth_email';
  static const _userIdKey = 'auth_user_id';

  final SecureStorageService _secureStorage = SecureStorageService();

  @override
  AuthState build() {
    final storage = LocalStorageService.instance;
    final isLoggedIn = storage.getBool(_loggedInKey) ?? false;
    final isGuest = storage.getBool(_guestKey) ?? false;
    final roleStr = storage.getString(_roleKey) ?? 'tourist';
    final role = _parseRole(roleStr);

    final localState = AuthState(
      isLoggedIn: isLoggedIn,
      isGuest: isGuest,
      isRestoring: isLoggedIn,
      role: role,
      name: storage.getString(_nameKey),
      email: storage.getString(_emailKey),
      userId: storage.getString(_userIdKey),
    );

    if (isLoggedIn) {
      _verifySession();
    }

    return localState;
  }

  UserRole _parseRole(String? roleStr) {
    if (roleStr == null || roleStr.trim().isEmpty) return UserRole.tourist;
    final clean =
        roleStr.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');

    if (clean == 'admin') {
      return UserRole.admin;
    }
    if (clean == 'lgu_staff' ||
        clean == 'lgustaff' ||
        clean == 'lgu' ||
        clean == 'lgu_admin') {
      return UserRole.lguStaff;
    }
    if (clean == 'msme_owner' ||
        clean == 'msmeowner' ||
        clean == 'msme' ||
        clean == 'msme_admin') {
      return UserRole.msmeOwner;
    }
    if (clean == 'tourism_partner' ||
        clean == 'tourismpartner' ||
        clean == 'partner' ||
        clean == 'tourism_partner_owner') {
      return UserRole.tourismPartner;
    }
    if (clean == 'guest') {
      return UserRole.guest;
    }
    return UserRole.tourist;
  }

  Future<void> _verifySession() async {
    try {
      final token = await _secureStorage.readAuthToken().timeout(
            const Duration(seconds: 2),
            onTimeout: () => null,
          );
      if (token == null || token.isEmpty) {
        await _clearPersistedSession();
        return;
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(ApiEndpoints.me).timeout(
            const Duration(seconds: 3),
          );
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final userData = response.data['data']['user'] as Map<String, dynamic>?;
        final roleStr = response.data['data']['role'] as String?;
        if (userData != null) {
          final role = _parseRole(roleStr);
          final newState = AuthState(
            isLoggedIn: true,
            isGuest: false,
            isRestoring: false,
            role: role,
            name: userData['name'] as String? ?? 'Explorer',
            email: userData['email'] as String?,
            userId: userData['id'] as String?,
          );
          await _persist(newState);
          state = newState;
        } else {
          state = const AuthState();
        }
      } else {
        state = const AuthState();
      }
    } catch (e) {
      debugPrint('[AUTH] _verifySession error or timeout: $e');
      if ((e is AuthException && e.statusCode == 401) ||
          e.toString().contains('401') ||
          e.toString().contains('Session expired')) {
        await _clearPersistedSession();
      } else {
        // Never render a privileged shell from unverified persisted role data.
        // Keep the token for a later retry, but reset the in-memory identity.
        state = const AuthState();
      }
    }
  }

  String _sanitizeAuthException(Object error) {
    if (error is UnverifiedEmailException) {
      return error.message;
    }
    if (error is AppException) {
      return error.message;
    }
    if (error is GoogleAuthCancelledException) {
      return error.toString();
    }
    final msg = error.toString().toLowerCase();
    if (msg.contains('socketexception') ||
        msg.contains('no internet') ||
        msg.contains('connection refused') ||
        msg.contains('xmlhttprequest') ||
        msg.contains('cors') ||
        msg.contains('networkerror') ||
        msg.contains('failed to fetch') ||
        msg.contains('connection lost') ||
        msg.contains('no internet connection')) {
      return 'Connection lost. Please check your internet connection.';
    }
    if (msg.contains('invalid email or password') ||
        msg.contains('incorrect') ||
        msg.contains('401')) {
      return 'Invalid email or password.';
    }
    if (msg.contains('account disabled') ||
        msg.contains('disabled or suspended')) {
      return 'Account disabled or suspended. Please contact support.';
    }
    return error.toString().replaceAll('Exception: ', '');
  }

  /// Sign in with email/password via Laravel REST API
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw Exception('Email and password cannot be empty.');
    }

    bool isOnline = true;
    if (!kIsWeb) {
      final hasInternet = await Connectivity().checkConnectivity();
      isOnline = hasInternet.any((r) => r != ConnectivityResult.none);
    }

    if (!isOnline) {
      throw const SocketException(
          'No internet connection. Cannot authenticate.');
    }

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        ApiEndpoints.login,
        data: {'email': cleanEmail, 'password': password},
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final data = response.data['data'];
        final token = data['token'] as String;
        final roleStr = data['role'] as String? ?? 'tourist';
        final userMap = data['user'] as Map<String, dynamic>?;

        await _secureStorage.writeAuthToken(token);

        final role = _parseRole(roleStr);
        final name = userMap?['name'] as String? ?? 'Explorer';
        final userId = userMap?['id'] as String?;

        await _clearPreviousIdentityIfNeeded(userId);

        final newState = AuthState(
          isLoggedIn: true,
          isGuest: false,
          role: role,
          name: name,
          email: cleanEmail,
          userId: userId,
        );

        await _persist(newState);
        state = newState;
      } else {
        throw Exception('Invalid email or password.');
      }
    } catch (e) {
      if (e is DioException && e.response != null) {
        final resData = e.response!.data;
        if (resData is Map && resData['status'] == 'unverified') {
          final unverifiedEmail =
              resData['data']?['email'] as String? ?? cleanEmail;
          final msg = resData['message'] as String? ??
              'Please verify your email address before logging in.';
          throw UnverifiedEmailException(unverifiedEmail, msg);
        }
      }
      if (e is AuthException && e.message.toLowerCase().contains('verify')) {
        final rawData = e.responseData?['data'];
        final data = rawData is Map
            ? Map<String, dynamic>.from(rawData)
            : <String, dynamic>{};
        final pendingEmail = data['email'] as String? ?? cleanEmail;
        throw UnverifiedEmailException(
          pendingEmail,
          e.message,
          EmailVerificationContext.fromMap(
            data,
            fallbackEmail: pendingEmail,
          ),
        );
      }
      debugPrint('[AUTH] signIn error: $e');
      throw Exception(_sanitizeAuthException(e));
    }
  }

  /// Sign up with email/password and name via Laravel REST API
  Future<Map<String, dynamic>> signUp({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final cleanEmail = email.trim();
    final cleanName = name.trim();
    if (cleanEmail.isEmpty || password.isEmpty || cleanName.isEmpty) {
      throw Exception('All fields are required.');
    }

    bool isOnline = true;
    if (!kIsWeb) {
      final hasInternet = await Connectivity().checkConnectivity();
      isOnline = hasInternet.any((r) => r != ConnectivityResult.none);
    }

    if (!isOnline) {
      throw const SocketException('No internet connection. Cannot sign up.');
    }

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        ApiEndpoints.register,
        data: {
          'name': cleanName,
          'email': cleanEmail,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );

      if ((response.statusCode == 201 || response.statusCode == 200) &&
          response.data['status'] == 'success') {
        final data = response.data['data'] as Map<String, dynamic>?;
        return {
          'requires_email_verification':
              data?['requires_email_verification'] ?? true,
          'requires_verification': data?['requires_verification'] ?? true,
          'email': data?['email'] ?? cleanEmail,
          'email_sent': data?['email_sent'] ?? false,
          'verification_context': EmailVerificationContext.fromMap(
            data,
            fallbackEmail: data?['email'] as String? ?? cleanEmail,
          ),
        };
      } else {
        throw Exception('Registration failed.');
      }
    } catch (e) {
      throw Exception(_sanitizeAuthException(e));
    }
  }

  /// Verify the SMTP code and establish the returned Sanctum session.
  Future<VerifiedEmailSession> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    final cleanEmail = email.trim();
    final cleanCode = code.trim();
    if (cleanEmail.isEmpty || !RegExp(r'^\d{6}$').hasMatch(cleanCode)) {
      throw Exception('Enter the 6-digit verification code.');
    }

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        ApiEndpoints.verifyEmailCode,
        data: {'email': cleanEmail, 'code': cleanCode},
      );

      if (response.statusCode != 200 || response.data['status'] != 'success') {
        throw Exception(response.data['message'] ?? 'Verification failed.');
      }

      final data = response.data['data'];
      final token = data['token'] as String;
      final role = _parseRole(data['role'] as String? ?? 'tourist');
      final userMap = data['user'] as Map<String, dynamic>?;
      final userId = userMap?['id'] as String?;

      final newState = AuthState(
        isLoggedIn: true,
        isGuest: false,
        role: role,
        name: userMap?['name'] as String? ?? 'Explorer',
        email: userMap?['email'] as String? ?? cleanEmail,
        userId: userId,
      );
      return VerifiedEmailSession(token: token, state: newState);
    } on AppException catch (e) {
      final rawData = e.responseData?['data'];
      final data = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{};
      throw VerificationCodeException(
        e.message,
        EmailVerificationContext.fromMap(
          data,
          fallbackEmail: cleanEmail,
        ),
      );
    } catch (e) {
      throw Exception(_sanitizeAuthException(e));
    }
  }

  Future<void> completeVerifiedEmailSession(
      VerifiedEmailSession session) async {
    await _secureStorage.writeAuthToken(session.token);
    await _clearPreviousIdentityIfNeeded(session.state.userId);
    await _persist(session.state);
    state = session.state;
  }

  /// Starts the official Google account picker and authenticates its ID token.
  Future<void> googleSignIn() async {
    final account = await GoogleAuthService.authenticate();
    await completeGoogleSignIn(account);
  }

  /// Completes Google auth for accounts emitted by the official web button.
  Future<void> completeGoogleSignIn(GoogleSignInAccount account) async {
    try {
      final idToken = GoogleAuthService.idTokenFor(account);
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        ApiEndpoints.googleAuth,
        data: {'id_token': idToken},
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final data = response.data['data'];
        final token = data['token'] as String;
        final roleStr = data['role'] as String? ?? 'tourist';
        final userMap = data['user'] as Map<String, dynamic>?;

        await _secureStorage.writeAuthToken(token);

        final role = _parseRole(roleStr);
        final nameStr =
            userMap?['name'] as String? ?? account.displayName ?? 'Explorer';
        final email = userMap?['email'] as String? ?? account.email;
        final userId = userMap?['id'] as String?;

        await _clearPreviousIdentityIfNeeded(userId);

        final newState = AuthState(
          isLoggedIn: true,
          isGuest: false,
          role: role,
          name: nameStr,
          email: email,
          userId: userId,
        );

        await _persist(newState);
        state = newState;
      } else {
        throw Exception('Google authentication failed.');
      }
    } catch (e) {
      debugPrint('[AUTH] googleSignIn error: $e');
      throw Exception(_sanitizeAuthException(e));
    }
  }

  /// Resend verification email
  Future<EmailVerificationContext> resendVerificationEmail(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) throw Exception('Email address is required.');

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        ApiEndpoints.resendVerificationEmail,
        data: {'email': cleanEmail},
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final data = Map<String, dynamic>.from(response.data['data'] as Map);
        return EmailVerificationContext.fromMap(
          data,
          fallbackEmail: cleanEmail,
        );
      } else if (response.data['status'] == 'already_verified') {
        throw Exception('Email address is already verified.');
      }
      throw Exception(
          response.data['message'] ?? 'Failed to resend verification email.');
    } on AppException catch (e) {
      final rawData = e.responseData?['data'];
      final data = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{};
      throw VerificationCodeException(
        e.message,
        EmailVerificationContext.fromMap(
          data,
          fallbackEmail: cleanEmail,
        ),
      );
    } catch (e) {
      throw Exception(_sanitizeAuthException(e));
    }
  }

  Future<EmailVerificationContext> getEmailVerificationContext(
      String email) async {
    final cleanEmail = email.trim();
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get(
      ApiEndpoints.verificationStatus,
      queryParameters: {'email': cleanEmail},
    );
    final data = Map<String, dynamic>.from(response.data['data'] as Map);

    return EmailVerificationContext.fromMap(
      data,
      fallbackEmail: cleanEmail,
    );
  }

  Future<EmailVerificationContext> changeUnverifiedEmail({
    required String email,
    required String password,
    required String newEmail,
  }) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        ApiEndpoints.changeUnverifiedEmail,
        data: {
          'email': email.trim(),
          'password': password,
          'new_email': newEmail.trim(),
        },
      );
      final data = Map<String, dynamic>.from(response.data['data'] as Map);

      return EmailVerificationContext.fromMap(
        data,
        fallbackEmail: newEmail.trim(),
      );
    } on AppException catch (error) {
      throw Exception(error.message);
    }
  }

  /// Check verification status for given email
  Future<bool> checkVerificationStatus(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) return false;

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        ApiEndpoints.verificationStatus,
        queryParameters: {'email': cleanEmail},
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return (response.data['data']?['is_verified'] as bool?) ?? false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Send password reset link
  Future<void> resetPassword(String email) async {
    final cleanEmail = email.trim();

    bool isOnline = true;
    if (!kIsWeb) {
      final hasInternet = await Connectivity().checkConnectivity();
      isOnline = hasInternet.any((r) => r != ConnectivityResult.none);
    }

    if (!isOnline) {
      throw const SocketException('No internet connection.');
    }

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post(
        ApiEndpoints.forgotPassword,
        data: {'email': cleanEmail},
      );
    } catch (e) {
      throw Exception(_sanitizeAuthException(e));
    }
  }

  /// Continue as guest
  Future<void> continueAsGuest() async {
    const newState = AuthState(
      isLoggedIn: false,
      isGuest: true,
      role: UserRole.guest,
      name: 'Guest',
    );
    await _persist(newState);
    state = newState;
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post(ApiEndpoints.logout);
    } catch (_) {}

    try {
      await GoogleAuthService.signOut();
    } catch (_) {}

    await _clearPersistedSession();
  }

  /// Alias for signOut
  Future<void> logout() => signOut();

  /// Reload active profile information from Laravel API
  Future<void> reloadProfile() async {
    await _verifySession();
  }

  Future<void> _persist(AuthState s) async {
    final storage = LocalStorageService.instance;
    await storage.setBool(_loggedInKey, value: s.isLoggedIn);
    await storage.setBool(_guestKey, value: s.isGuest);
    await storage.setString(_roleKey, s.role.name);
    if (s.name != null) await storage.setString(_nameKey, s.name!);
    if (s.email != null) await storage.setString(_emailKey, s.email!);
    if (s.userId != null) await storage.setString(_userIdKey, s.userId!);
    await _persistLocalUser(s);
  }

  Future<void> _persistLocalUser(AuthState auth) async {
    if (!DatabaseHelper.isSupported || !auth.isLoggedIn) return;
    final id = auth.userId;
    final email = auth.email;
    if (id == null || id.isEmpty || email == null || email.isEmpty) return;

    final db = DatabaseHelper.instance;
    final values = <String, dynamic>{
      'name': auth.name ?? 'Explorer',
      'email': email,
      'role': auth.role.name,
      'updated_at': DateTime.now().toIso8601String(),
    };
    final existing = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (existing.isEmpty) {
      await db.insert('users', {
        'id': id,
        ...values,
        'created_at': DateTime.now().toIso8601String(),
      });
    } else {
      await db.update('users', values, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> _clearPersistedSession() async {
    final localUserId =
        state.userId ?? LocalStorageService.instance.getString(_userIdKey);
    final localRole = state.role.name;

    await PrivateSessionDataService.clear(
      userId: localUserId,
      role: localRole,
    );

    await _secureStorage.clearAuthData();

    final storage = LocalStorageService.instance;
    await storage.remove(_loggedInKey);
    await storage.remove(_guestKey);
    await storage.remove(_roleKey);
    await storage.remove(_nameKey);
    await storage.remove(_emailKey);
    await storage.remove(_userIdKey);

    if (DatabaseHelper.isSupported &&
        localUserId != null &&
        localUserId.isNotEmpty) {
      await DatabaseHelper.instance.delete(
        'users',
        where: 'id = ?',
        whereArgs: [localUserId],
      );
    }

    state = const AuthState();
  }

  Future<void> _clearPreviousIdentityIfNeeded(String? nextUserId) async {
    final storage = LocalStorageService.instance;
    final previousUserId = storage.getString(_userIdKey);
    if (previousUserId == null ||
        previousUserId.isEmpty ||
        previousUserId == nextUserId) {
      return;
    }
    final previousRole = storage.getString(_roleKey) ?? state.role.name;
    await PrivateSessionDataService.clear(
      userId: previousUserId,
      role: previousRole,
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
