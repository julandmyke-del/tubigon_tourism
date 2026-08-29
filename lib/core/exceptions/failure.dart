import 'app_exception.dart';

/// Functional failure wrapper for use-case results.
/// Repositories return `Either<Failure, T>` (or just throw [AppException]).
sealed class Failure {
  const Failure({required this.message, this.code});

  final String message;
  final String? code;

  /// Convert an [AppException] into the appropriate [Failure] subtype.
  factory Failure.fromException(AppException e) {
    return switch (e) {
      NetworkException() => NetworkFailure(message: e.message),
      AuthException() => AuthFailure(message: e.message),
      ValidationException() =>
        ValidationFailure(message: e.message, errors: e.errors),
      ServerException() =>
        ServerFailure(message: e.message, statusCode: e.statusCode),
      CacheException() => CacheFailure(message: e.message),
      SyncException() => SyncFailure(message: e.message),
      NotFoundException() => NotFoundFailure(message: e.message),
      UnknownException() => UnknownFailure(message: e.message),
    };
  }

  @override
  String toString() => '$runtimeType(message: $message)';
}

final class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'No internet connection.'});
}

final class AuthFailure extends Failure {
  const AuthFailure({super.message = 'Authentication failed.'});
}

final class ValidationFailure extends Failure {
  const ValidationFailure({
    super.message = 'Validation error.',
    this.errors = const {},
  });
  final Map<String, List<String>> errors;
}

final class ServerFailure extends Failure {
  const ServerFailure({
    super.message = 'Server error.',
    this.statusCode,
  });
  final int? statusCode;
}

final class CacheFailure extends Failure {
  const CacheFailure({super.message = 'Local data error.'});
}

final class SyncFailure extends Failure {
  const SyncFailure({super.message = 'Sync failed.'});
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure({super.message = 'Not found.'});
}

final class UnknownFailure extends Failure {
  const UnknownFailure({super.message = 'Unknown error.'});
}
