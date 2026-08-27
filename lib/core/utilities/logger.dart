import 'package:logger/logger.dart';

/// Structured logger wrapper for the Tubigon Smart Tourism App.
///
/// Usage:
/// ```dart
/// AppLogger.debug('Loading tourist spots...');
/// AppLogger.info('User logged in: $userId');
/// AppLogger.warning('Token expiring soon');
/// AppLogger.error('Failed to fetch data', error: e, stackTrace: st);
/// ```
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 100,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: Level.debug,
  );

  static void debug(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.d(message, error: error, stackTrace: stackTrace);

  static void info(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.i(message, error: error, stackTrace: stackTrace);

  static void warning(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.w(message, error: error, stackTrace: stackTrace);

  static void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.e(message, error: error, stackTrace: stackTrace);

  static void fatal(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.f(message, error: error, stackTrace: stackTrace);

  static void trace(String message) => _logger.t(message);
}
