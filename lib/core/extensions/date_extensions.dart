/// Utility extensions on [DateTime].
extension DateExtensions on DateTime {
  // ─── Formatting ───────────────────────────────────────────────────────────
  /// e.g. "July 10, 2026"
  String get formatted {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[month - 1]} $day, $year';
  }

  /// e.g. "Jul 10, 2026"
  String get shortFormatted {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[month - 1]} $day, $year';
  }

  /// e.g. "10/07/2026"
  String get numericFormatted =>
      '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$year';

  /// e.g. "10:30 AM"
  String get timeFormatted {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  /// e.g. "July 10, 2026 at 10:30 AM"
  String get fullFormatted => '$formatted at $timeFormatted';

  // ─── Relative Time ────────────────────────────────────────────────────────
  String get relativeTime {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
    }
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    }
    if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    }
    final years = (diff.inDays / 365).floor();
    return '$years ${years == 1 ? 'year' : 'years'} ago';
  }

  // ─── Comparisons ─────────────────────────────────────────────────────────
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year && month == tomorrow.month && day == tomorrow.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }

  bool get isPast => isBefore(DateTime.now());
  bool get isFuture => isAfter(DateTime.now());

  // ─── Helpers ─────────────────────────────────────────────────────────────
  DateTime get startOfDay => DateTime(year, month, day);
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);

  /// ISO8601 string for API payloads.
  String get toIso => toIso8601String();
}

/// Nullable DateTime extensions.
extension NullableDateExtensions on DateTime? {
  String get orDash => this?.formatted ?? '—';
  String get relativeOrDash => this?.relativeTime ?? '—';
}
