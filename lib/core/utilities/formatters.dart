import 'package:intl/intl.dart';

/// Formatting utilities for currency, dates, numbers, and distances.
abstract final class Formatters {
  // ─── Currency ─────────────────────────────────────────────────────────────
  static final _peso = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );

  static final _pesoCompact = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 0,
  );

  /// Format a number as Philippine Peso (e.g. "₱1,250.00").
  static String peso(num amount) => _peso.format(amount);

  /// Compact peso without decimals (e.g. "₱1,250").
  static String pesoCompact(num amount) => _pesoCompact.format(amount);

  /// Format as "₱50 – ₱200" range.
  static String pesoRange(num min, num max) =>
      '${pesoCompact(min)} – ${pesoCompact(max)}';

  // ─── Numbers ──────────────────────────────────────────────────────────────
  static final _compact = NumberFormat.compact(locale: 'en_US');
  static final _decimal = NumberFormat('#,##0.##', 'en_US');

  /// "1,234,567" or "1.2M"
  static String compact(num value) => _compact.format(value);

  /// "1,250"
  static String number(num value) => _decimal.format(value);

  // ─── Ratings ──────────────────────────────────────────────────────────────
  static String rating(double value) => value.toStringAsFixed(1);

  /// "4.5 (128 reviews)"
  static String ratingWithCount(double rating, int count) =>
      '${Formatters.rating(rating)} (${number(count)} ${count == 1 ? 'review' : 'reviews'})';

  // ─── Distance ─────────────────────────────────────────────────────────────
  /// e.g. "250 m" or "3.2 km"
  static String distance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    final km = meters / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  // ─── Duration ─────────────────────────────────────────────────────────────
  /// "2 hrs 30 min" or "45 min"
  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '$m min';
    if (m == 0) return '$h hr${h > 1 ? 's' : ''}';
    return '$h hr${h > 1 ? 's' : ''} $m min';
  }

  // ─── File Size ────────────────────────────────────────────────────────────
  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // ─── Pluralize ────────────────────────────────────────────────────────────
  static String pluralize(int count, String singular, [String? plural]) {
    return count == 1 ? '$count $singular' : '$count ${plural ?? '${singular}s'}';
  }

  // ─── Phone ────────────────────────────────────────────────────────────────
  static String phone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('0')) {
      return '${digits.substring(0, 4)}-${digits.substring(4, 7)}-${digits.substring(7)}';
    }
    return raw;
  }
}
