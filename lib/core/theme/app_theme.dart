import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';

/// Central Material Design 3 theme configuration for Tubigon Smart Tourism App.
abstract final class AppTheme {
  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.white,
      secondary: AppColors.secondary,
      onSecondary: AppColors.white,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.white,
      tertiary: AppColors.accent,
      onTertiary: AppColors.white,
      tertiaryContainer: AppColors.accentContainer,
      onTertiaryContainer: AppColors.accentLight,
      error: AppColors.error,
      onError: AppColors.white,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.white,
      surface: AppColors.darkSurface,
      onSurface: AppColors.white,
      surfaceContainerHighest: AppColors.cardBg,
      outline: AppColors.darkOutline,
      outlineVariant: Color(0x1AFFFFFF),
      shadow: AppColors.black,
      scrim: AppColors.black,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      splashColor: AppColors.accent.withValues(alpha: 0.12),
      highlightColor: AppColors.accent.withValues(alpha: 0.06),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.white,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: AppColors.white, size: AppSpacing.iconMd),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.cardBg,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.grey300,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: AppTypography.labelSmall.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.accent,
        ),
        unselectedLabelStyle: AppTypography.labelSmall.copyWith(
          color: AppColors.grey300,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 4,
        shadowColor: AppColors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x1AFFFFFF), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),

      // Elevated Button Theme (Primary Buttons)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          shadowColor: AppColors.black.withValues(alpha: 0.4),
          textStyle: AppTypography.buttonText.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),

      // Outlined Button Theme (Secondary Buttons)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.darkSurface,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: const BorderSide(color: AppColors.accent, width: 1.5),
          textStyle: AppTypography.buttonText.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: AppTypography.buttonText.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),

      // Input Field Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.skyBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.grey300),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.grey400),
        prefixIconColor: AppColors.grey300,
        suffixIconColor: AppColors.grey300,
      ),

      // Drawer Theme
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.primary,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        ),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardBg,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0x1AFFFFFF), width: 1),
        ),
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.grey300,
        ),
      ),

      // SnackBar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardBg,
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: AppColors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: Color(0x1AFFFFFF),
        thickness: 1,
        space: AppSpacing.lg,
      ),
    );
  }
}
