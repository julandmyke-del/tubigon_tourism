/// Typed exception hierarchy for Tour Tubigon.
/// All exceptions extend [AppException] for consistent catch blocks.
sealed class AppException implements Exception {
  const AppException({
    required this.message,
    this.code,
    this.statusCode,
    this.responseData,
  });

  final String message;
  final String? code;
  final int? statusCode;
  final Map<String, dynamic>? responseData;

  @override
  String toString() => message;
}

/// Thrown when there is no internet connectivity or request times out.
final class NetworkException extends AppException {
  const NetworkException({
    super.message = 'No internet connection. Please check your network.',
    super.code,
    super.statusCode,
    super.responseData,
    this.isTimeout = false,
  });

  final bool isTimeout;
}

/// Thrown for authentication / authorization failures (401, 403).
final class AuthException extends AppException {
  const AuthException({
    super.message = 'Authentication failed. Please log in again.',
    super.code,
    super.statusCode,
    super.responseData,
    this.isExpired = false,
    this.isUnauthorized = false,
  });

  final bool isExpired;
  final bool isUnauthorized;
}

/// Thrown when server-side validation fails (422).
final class ValidationException extends AppException {
  const ValidationException({
    super.message = 'Please check the information you entered.',
    super.code,
    super.statusCode,
    super.responseData,
    this.errors = const {},
  });

  /// Map of field name → list of error messages from the server.
  final Map<String, List<String>> errors;

  String? errorFor(String field) => errors[field]?.firstOrNull;
}

/// Thrown when the server returns 5xx or unexpected responses.
final class ServerException extends AppException {
  const ServerException({
    super.message = 'Server error. Please try again later.',
    super.code,
    super.statusCode,
    super.responseData,
  });
}

/// Thrown when an optimistic-concurrency check detects a stale screen.
final class ConflictException extends AppException {
  const ConflictException({
    super.message =
        'This information was updated in another session. Please refresh and try again.',
    super.code = 'stale_record',
    super.statusCode = 409,
    super.responseData,
  });

  bool get isStaleRecord => code == 'stale_record';
}

/// Thrown when there is a problem reading/writing local SQLite cache.
final class CacheException extends AppException {
  const CacheException({
    super.message = 'Local data error. Try clearing the cache.',
    super.code,
    super.responseData,
  });
}

/// Thrown when offline sync encounters a conflict or failure.
final class SyncException extends AppException {
  const SyncException({
    super.message = 'Sync failed. Your data will sync when reconnected.',
    super.code,
    this.conflictId,
  });

  final String? conflictId;
}

/// Thrown when a resource is not found (404).
final class NotFoundException extends AppException {
  const NotFoundException({
    super.message = 'The requested resource was not found.',
    super.code,
    super.statusCode = 404,
    super.responseData,
  });
}

/// Thrown for unexpected or unhandled errors.
final class UnknownException extends AppException {
  const UnknownException({
    super.message = 'An unexpected error occurred. Please try again.',
    super.code,
    super.statusCode,
    super.responseData,
    this.originalError,
  });

  final Object? originalError;
}
