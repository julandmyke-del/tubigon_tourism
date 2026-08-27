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
import '../../core/services/secure_storage_service.dart';
import '../../database/database_helper.dart';
import 'google_auth_service.dart';

// ─── User Role ────────────────────────────────────────────────────────────────
enum UserRole { guest, tourist, msmeOwner, lguStaff, admin, tourismPartner }

// ─── Custom Exceptions ────────────────────────────────────────────────────────
class UnverifiedEmailException implements Exception {
  final String email;
  final String message;

  const UnverifiedEmailException(this.email,
      [this.message = 'Please verify your email address before logging in.']);

  @override
  String toString() => message;
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
  final UserRole role;
  final String? name;
  final String? email;
  final String? userId;

  const AuthState({
    this.isLoggedIn = false,
    this.isGuest = false,
    this.role = UserRole.tourist,
    this.name,
    this.email,
    this.userId,
  });

  bool get isAuthenticated => isLoggedIn || isGuest;

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
    UserRole? role,
    String? name,
    String? email,
    String? userId,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isGuest: isGuest ?? this.isGuest,
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
      if (token != null && token.isNotEmpty) {
        final apiClient = ref.read(apiClientProvider);
        final response = await apiClient.get(ApiEndpoints.me).timeout(
              const Duration(seconds: 3),
            );
        if (response.statusCode == 200 &&
            response.data['status'] == 'success') {
          final userData =
              response.data['data']['user'] as Map<String, dynamic>?;
          final roleStr = response.data['data']['role'] as String?;
          if (userData != null) {
            final role = _parseRole(roleStr);
            final newState = AuthState(
              isLoggedIn: true,
              isGuest: false,
              role: role,
              name: userData['name'] as String? ?? 'Explorer',
              email: userData['email'] as String?,
              userId: userData['id'] as String?,
            );
            await _persist(newState);
            state = newState;
          }
        }
      }
    } catch (e) {
      debugPrint('[AUTH] _verifySession error or timeout: $e');
      if (e.toString().contains('401') ||
          e.toString().contains('Session expired')) {
        await _secureStorage.clearAuthData();
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
        throw UnverifiedEmailException(cleanEmail, e.message);
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
          'requires_verification': data?['requires_verification'] ?? true,
          'email': data?['email'] ?? cleanEmail,
          'email_sent': data?['email_sent'] ?? false,
        };
      } else {
        throw Exception('Registration failed.');
      }
    } catch (e) {
      throw Exception(_sanitizeAuthException(e));
    }
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
  Future<String> resendVerificationEmail(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) throw Exception('Email address is required.');

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        ApiEndpoints.resendVerificationEmail,
        data: {'email': cleanEmail},
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return response.data['message'] as String? ??
            'Verification email sent successfully.';
      } else if (response.data['status'] == 'already_verified') {
        return 'Email address is already verified.';
      }
      throw Exception(
          response.data['message'] ?? 'Failed to resend verification email.');
    } catch (e) {
      throw Exception(_sanitizeAuthException(e));
    }
  }

  /// Check verification status for given email
  Future<bool> checkVerificationStatus(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) return false;

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        '${ApiEndpoints.verificationStatus}?email=$cleanEmail',
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

    await _secureStorage.clearAuthData();

    final storage = LocalStorageService.instance;
    await storage.remove(_loggedInKey);
    await storage.remove(_guestKey);
    await storage.remove(_roleKey);
    await storage.remove(_nameKey);
    await storage.remove(_emailKey);
    await storage.remove(_userIdKey);

    state = const AuthState();
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
}

// ─── Provider ─────────────────────────────────────────────────────────────────
final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
