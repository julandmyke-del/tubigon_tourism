/// Input validators for form fields across the app.
/// All validators return `null` on success, or an error message string.
abstract final class Validators {
  // ─── Required ─────────────────────────────────────────────────────────────
  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  // ─── Email ────────────────────────────────────────────────────────────────
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required.';
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  // ─── Password ────────────────────────────────────────────────────────────
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < 8) return 'Password must be at least 8 characters.';
    if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
      return 'Password must contain at least one letter.';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number.';
    }
    return null;
  }

  static String? Function(String?) confirmPassword(String? original) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return 'Please confirm your password.';
      }
      if (value != original) {
        return 'Passwords do not match.';
      }
      return null;
    };
  }

  // ─── Phone ────────────────────────────────────────────────────────────────
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required.';
    }
    final phoneRegex = RegExp(r'^(09|\+639)\d{9}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Enter a valid Philippine phone number (e.g. 09XXXXXXXXX).';
    }
    return null;
  }

  // ─── Name ─────────────────────────────────────────────────────────────────
  static String? name(String? value, {String fieldName = 'Name'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required.';
    if (value.trim().length < 2) {
      return '$fieldName must be at least 2 characters.';
    }
    if (value.trim().length > 100) {
      return '$fieldName must be at most 100 characters.';
    }
    return null;
  }

  // ─── Min/Max Length ───────────────────────────────────────────────────────
  static String? Function(String?) minLength(int min, {String? label}) {
    return (String? value) {
      if (value == null || value.isEmpty) return null;
      if (value.length < min) {
        return '${label ?? 'This field'} must be at least $min characters.';
      }
      return null;
    };
  }

  static String? Function(String?) maxLength(int max, {String? label}) {
    return (String? value) {
      if (value == null || value.isEmpty) return null;
      if (value.length > max) {
        return '${label ?? 'This field'} must be at most $max characters.';
      }
      return null;
    };
  }

  // ─── Number ───────────────────────────────────────────────────────────────
  static String? positiveNumber(String? value, {String fieldName = 'Value'}) {
    if (value == null || value.isEmpty) return '$fieldName is required.';
    final n = num.tryParse(value);
    if (n == null) return '$fieldName must be a number.';
    if (n <= 0) return '$fieldName must be greater than 0.';
    return null;
  }

  // ─── URL ──────────────────────────────────────────────────────────────────
  static String? url(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final urlRegex = RegExp(
      r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
      caseSensitive: false,
    );
    if (!urlRegex.hasMatch(value.trim())) {
      return 'Please enter a valid URL.';
    }
    return null;
  }

  // ─── Compose ──────────────────────────────────────────────────────────────
  /// Compose multiple validators; returns the first error found.
  static String? Function(String?) compose(
      List<String? Function(String?)> validators) {
    return (String? value) {
      for (final v in validators) {
        final result = v(value);
        if (result != null) return result;
      }
      return null;
    };
  }
}
