import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

import '../constants/app_constants.dart';

final _logger = Logger();
const _storage = FlutterSecureStorage();

/// Injects the Bearer token into every request that requires authentication.
class AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth header for public endpoints
    if (_isPublicEndpoint(options.path)) {
      return handler.next(options);
    }

    try {
      final token = await _storage.read(key: AppConstants.authTokenKey);
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      _logger.w('AuthInterceptor: could not read token — $e');
    }

    return handler.next(options);
  }

  bool _isPublicEndpoint(String path) {
    const publicPaths = [
      '/auth/login',
      '/auth/register',
      '/auth/forgot-password',
      '/auth/google'
    ];
    return publicPaths.any((p) => path.endsWith(p));
  }
}

/// Logs all requests, responses, and errors for debugging.
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final safeHeaders = Map<String, dynamic>.from(options.headers);
    if (safeHeaders.containsKey('Authorization')) {
      safeHeaders['Authorization'] = '<redacted>';
    }
    _logger.d(
      '→ ${options.method} ${options.uri}\n'
      '  Headers: $safeHeaders\n'
      '  Data: ${_redact(options.data)}',
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logger.d(
      '← ${response.statusCode} ${response.requestOptions.uri}\n'
      '  Data: ${_redact(response.data)}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.e(
      '✕ ${err.type} ${err.requestOptions.uri}\n'
      '  Message: ${err.message}\n'
      '  Response: ${_redact(err.response?.data)}',
      error: err,
    );
    handler.next(err);
  }

  dynamic _redact(dynamic value) {
    const sensitiveKeys = {
      'password',
      'password_confirmation',
      'current_password',
      'token',
      'access_token',
      'refresh_token',
      'id_token',
      'client_secret',
      'verification_token',
    };

    if (value is Map) {
      return value.map((key, item) {
        final normalizedKey = key.toString().toLowerCase();
        return MapEntry(
          key,
          sensitiveKeys.contains(normalizedKey) ? '<redacted>' : _redact(item),
        );
      });
    }
    if (value is List) return value.map(_redact).toList();
    return value;
  }
}

/// Retries failed requests up to [maxRetries] times with exponential back-off.
/// Only retries on network errors and 5xx server errors.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({this.maxRetries = AppConstants.apiMaxRetries});

  final int maxRetries;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = err.requestOptions.extra['retryCount'] as int? ?? 0;

    final shouldRetry = attempt < maxRetries &&
        (err.type == DioExceptionType.connectionError ||
            err.type == DioExceptionType.connectionTimeout ||
            (err.response?.statusCode != null &&
                err.response!.statusCode! >= 500));

    if (!shouldRetry) {
      return handler.next(err);
    }

    // Exponential back-off: 1s, 2s, 4s
    final delay = Duration(seconds: 1 << attempt);
    _logger.w(
        'Retrying (${attempt + 1}/$maxRetries) after ${delay.inSeconds}s...');
    await Future<void>.delayed(delay);

    try {
      final options = err.requestOptions;
      options.extra['retryCount'] = attempt + 1;
      final dio = Dio(BaseOptions(baseUrl: options.baseUrl));
      final response = await dio.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }
}
