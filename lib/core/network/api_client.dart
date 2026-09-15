import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../constants/app_constants.dart';
import '../exceptions/app_exception.dart';

import 'api_interceptors.dart';

final _logger = Logger();

/// Dio-based HTTP client with auth injection, error mapping, and retry logic.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  static Dio createDio() {
    final baseUrl = AppConstants.apiBaseUrl;
    debugPrint('[DEBUG][API_CLIENT] Initializing Dio with Base URL: $baseUrl');
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: AppConstants.apiConnectTimeout,
        receiveTimeout: AppConstants.apiTimeout,
        sendTimeout: AppConstants.apiTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.addAll([
      OfflineWriteInterceptor(),
      AuthInterceptor(),
      LoggingInterceptor(),
      RetryInterceptor(),
    ]);

    return dio;
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e) {
      throw UnknownException(message: e.toString(), originalError: e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    debugPrint('[API] POST ${_dio.options.baseUrl}$path');
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      debugPrint('[API] POST $path → ${response.statusCode}');
      return response;
    } on DioException catch (e) {
      debugPrint(
          '[API] DioException on POST $path — type: ${e.type}, message: ${e.message}');
      debugPrint(
          '[API] Response: ${e.response?.statusCode} — ${e.response?.data}');
      throw _mapDioException(e);
    } catch (e) {
      debugPrint('[API] Unknown error on POST $path: $e');
      throw UnknownException(message: e.toString(), originalError: e);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e) {
      throw UnknownException(message: e.toString(), originalError: e);
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Options? options,
  }) async {
    try {
      return await _dio.patch<T>(path, data: data, options: options);
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e) {
      throw UnknownException(message: e.toString(), originalError: e);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(path, data: data, options: options);
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e) {
      throw UnknownException(message: e.toString(), originalError: e);
    }
  }

  AppException _mapDioException(DioException e) {
    _logger.e('DioException: ${e.type} — ${e.message}', error: e);

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const NetworkException(
          message: 'Connection timed out. Please try again.',
          isTimeout: true,
        );

      case DioExceptionType.connectionError:
        return NetworkException(
          message: (e.message ?? '').contains('Offline mode is read-only')
              ? 'Offline mode is read-only. Reconnect to complete this action.'
              : 'No internet connection. Please check your network.',
        );

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;

        if (statusCode == 401) {
          return AuthException(
            message:
                _extractMessage(data, 'Session expired. Please log in again.'),
            statusCode: statusCode,
            isExpired: true,
            responseData: _responseData(data),
          );
        }
        if (statusCode == 403) {
          return AuthException(
            // Server details remain available in responseData for development
            // diagnostics, but ordinary users should never see policy names,
            // framework exception text, or minified exception output.
            message: 'You do not have permission to access this feature.',
            statusCode: statusCode,
            isUnauthorized: true,
            responseData: _responseData(data),
          );
        }
        if (statusCode == 404) {
          return NotFoundException(
            message: _extractMessage(data, 'Resource not found.'),
            statusCode: statusCode,
            responseData: _responseData(data),
          );
        }
        if (statusCode == 422) {
          return ValidationException(
            message: _extractMessage(
                data, 'Please check the information you entered.'),
            statusCode: statusCode,
            errors: _extractErrors(data),
            responseData: _responseData(data),
          );
        }
        if (statusCode != null && statusCode >= 500) {
          return ServerException(
            message:
                _extractMessage(data, 'Server error. Please try again later.'),
            statusCode: statusCode,
            responseData: _responseData(data),
          );
        }
        return ServerException(
          message: _extractMessage(data, 'An error occurred.'),
          statusCode: statusCode,
          responseData: _responseData(data),
        );

      case DioExceptionType.cancel:
        return const NetworkException(message: 'Request was cancelled.');

      case DioExceptionType.badCertificate:
        return const NetworkException(message: 'SSL certificate error.');

      case DioExceptionType.unknown:
      default:
        // On Flutter Web, CORS failures and unreachable backends both surface
        // as DioExceptionType.unknown with an XMLHttpRequest error object.
        // Detect this and surface a clean NetworkException.
        final errStr = e.error?.toString() ?? '';
        final msgStr = (e.message ?? '').toLowerCase();
        if (errStr.toLowerCase().contains('xmlhttprequest') ||
            msgStr.contains('xmlhttprequest') ||
            msgStr.contains('cors') ||
            msgStr.contains('failed to fetch') ||
            msgStr.contains('networkerror')) {
          debugPrint('[API] Web network/CORS error — ${e.error}');
          return const NetworkException(
            message: 'Connection lost. Please check your internet connection.',
          );
        }
        debugPrint(
            '[API] Unknown Dio error — this may be a CORS error on Web. Error: ${e.error}');
        return UnknownException(
          message: e.message ?? 'An unexpected error occurred.',
          originalError: e,
        );
    }
  }

  String _extractMessage(dynamic data, String fallback) {
    if (data is Map<String, dynamic>) {
      return (data['message'] as String?) ??
          (data['error'] as String?) ??
          fallback;
    }
    return fallback;
  }

  Map<String, dynamic>? _responseData(dynamic data) {
    return data is Map<String, dynamic> ? data : null;
  }

  Map<String, List<String>> _extractErrors(dynamic data) {
    if (data is Map<String, dynamic> && data['errors'] is Map) {
      final raw = data['errors'] as Map<String, dynamic>;
      return raw.map((k, v) {
        if (v is List) {
          return MapEntry(k, v.map((e) => e.toString()).toList());
        }
        return MapEntry(k, [v.toString()]);
      });
    }
    return {};
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = ApiClient.createDio();
  // Interceptors are added by the interceptors provider (lazy injection)
  return ApiClient(dio);
});
