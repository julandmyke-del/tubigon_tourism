import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Central Material 3 theme for every Tour Tubigon role portal.
abstract final class AppTheme {
  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final surfaceVariant =
        isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final onSurface =
        isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
    final outline = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: AppColors.white,
      primaryContainer:
          isDark ? AppColors.primaryContainer : const Color(0xFFD9E7FA),
      onPrimaryContainer:
          isDark ? AppColors.white : AppColors.lightOnBackground,
      secondary: AppColors.secondary,
      onSecondary: AppColors.white,
      secondaryContainer:
          isDark ? AppColors.secondaryContainer : const Color(0xFFE5E9EF),
      onSecondaryContainer: onSurface,
      tertiary: AppColors.accent,
      onTertiary: AppColors.white,
      tertiaryContainer:
          isDark ? AppColors.accentContainer : const Color(0xFFFFE7C2),
      onTertiaryContainer:
          isDark ? AppColors.accentLight : AppColors.accentDark,
      error: AppColors.error,
      onError: AppColors.white,
      errorContainer:
          isDark ? AppColors.errorContainer : const Color(0xFFFFDAD6),
      onErrorContainer: isDark ? AppColors.white : const Color(0xFF410002),
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceVariant,
      outline: outline,
      outlineVariant:
          isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E9EF),
      shadow: AppColors.black,
      scrim: AppColors.black,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: outline),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      splashColor: AppColors.accent.withValues(alpha: 0.12),
      highlightColor: AppColors.accent.withValues(alpha: 0.06),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: background,
        foregroundColor: onSurface,
        centerTitle: false,
        systemOverlayStyle:
            (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                .copyWith(statusBarColor: Colors.transparent),
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: onSurface, size: AppSpacing.iconMd),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: isDark ? AppColors.grey300 : AppColors.grey600,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: isDark ? 4 : 1,
        shadowColor: AppColors.black.withValues(alpha: isDark ? 0.3 : 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: outline),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          minimumSize: const Size(0, AppSpacing.buttonHeight),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: AppTypography.buttonText.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: onSurface,
          minimumSize: const Size(0, AppSpacing.buttonHeight),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: const BorderSide(color: AppColors.accent, width: 1.5),
          textStyle: AppTypography.buttonText.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accentDark),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.skyBlue, width: 1.5),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: isDark ? AppColors.grey300 : AppColors.grey600,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.grey500),
        prefixIconColor: isDark ? AppColors.grey300 : AppColors.grey600,
        suffixIconColor: isDark ? AppColors.grey300 : AppColors.grey600,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: surface,
        elevation: 16,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: outline),
        ),
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: onSurface,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: onSurface),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.secondary,
        contentTextStyle:
            AppTypography.bodyMedium.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: outline),
        labelStyle: AppTypography.bodyMedium.copyWith(color: onSurface),
      ),
      popupMenuTheme: PopupMenuThemeData(color: surface),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(surfaceVariant),
        dataTextStyle: AppTypography.bodyMedium.copyWith(color: onSurface),
        headingTextStyle: AppTypography.bodyMedium.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
