import 'package:flutter/material.dart';

/// Convenience extensions on [BuildContext].
extension ContextExtensions on BuildContext {
  // ─── Theme ────────────────────────────────────────────────────────────────
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // ─── Media Query ──────────────────────────────────────────────────────────
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => MediaQuery.of(this).size;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  EdgeInsets get padding => MediaQuery.of(this).padding;
  EdgeInsets get viewInsets => MediaQuery.of(this).viewInsets;
  double get statusBarHeight => MediaQuery.of(this).padding.top;
  double get bottomBarHeight => MediaQuery.of(this).padding.bottom;
  bool get isKeyboardOpen => MediaQuery.of(this).viewInsets.bottom > 0;

  // ─── Responsive Breakpoints ───────────────────────────────────────────────
  bool get isMobile => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1024;
  bool get isDesktop => screenWidth >= 1024;

  // ─── Scaffold ─────────────────────────────────────────────────────────────
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colorScheme.error : null,
      ),
    );
  }

  void hideKeyboard() => FocusScope.of(this).unfocus();

  // ─── Shortcuts ────────────────────────────────────────────────────────────
  void pop<T>([T? result]) => Navigator.of(this).pop(result);
}
