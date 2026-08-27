/// Utility extensions on [String].
extension StringExtensions on String {
  // ─── Casing ───────────────────────────────────────────────────────────────
  String get titleCase {
    if (isEmpty) return this;
    return split(' ')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  String get sentenceCase {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }

  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  // ─── Truncation ───────────────────────────────────────────────────────────
  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - suffix.length)}$suffix';
  }

  String truncateWords(int maxWords, {String suffix = '...'}) {
    final words = split(' ');
    if (words.length <= maxWords) return this;
    return '${words.take(maxWords).join(' ')}$suffix';
  }

  // ─── Validation Helpers ───────────────────────────────────────────────────
  bool get isValidEmail {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(this);
  }

  bool get isValidPhoneNumber {
    // Philippine mobile numbers: 09XXXXXXXXX or +639XXXXXXXXX
    return RegExp(r'^(09|\+639)\d{9}$').hasMatch(this);
  }

  bool get isValidPassword => length >= 8;

  bool get isNotBlank => trim().isNotEmpty;
  bool get isBlank => trim().isEmpty;

  // ─── Formatting ───────────────────────────────────────────────────────────
  String get toSlug {
    return toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'[\s_-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String get removeHtml {
    return replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  /// Returns initials (up to 2 chars) from a display name.
  String get initials {
    final parts = trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }
}

/// Nullable String extensions.
extension NullableStringExtensions on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
  bool get isNullOrBlank => this == null || this!.trim().isEmpty;
  String get orEmpty => this ?? '';
}
