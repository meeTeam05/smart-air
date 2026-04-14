import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Dark palette ─────────────────────────────────────────────────────────
  static const Color bg = Color(0xFF0A0A12);
  static const Color surface = Color(0xFF15151F);
  static const Color surfaceVar = Color(0xFF1E1E2C);
  static const Color border = Color(0xFF2A2A3A);
  static const Color primary = Color(0xFF2B7FFF);
  static const Color textPrimary = Color(0xFFE8E8F0);
  static const Color textSecondary = Color(0xFF8A8A9A);
  static const Color online = Color(0xFF10B981);
  static const Color offline = Color(0xFF6B7280);
  static const Color warning = Color(0xFFFF9500);
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        surface: AppColors.surface,
      ).copyWith(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primary.withValues(alpha: 0.2),
        elevation: 0,
        height: 64,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 0.5,
        space: 0,
      ),
    );
  }

  static ThemeData light() {
    const lightSurface = Color(0xFFFFFFFF);
    const lightBg = Color(0xFFF2F4F7);
    const lightBorder = Color(0xFFE0E4EA);
    const lightText = Color(0xFF1A1A2E);
    const lightTextSec = Color(0xFF6B7280);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        surface: lightSurface,
        onSurface: lightText,
        onSurfaceVariant: lightTextSec,
      ),
      scaffoldBackgroundColor: lightBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        foregroundColor: lightText,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: lightText,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        elevation: 0,
        height: 64,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: lightTextSec,
        textColor: lightText,
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 0.5,
        space: 0,
      ),
    );
  }
}

// ── Adaptive colour palette ───────────────────────────────────────────────────
/// Theme-aware colour set. Use via [BuildContext.colors].
class AppPalette {
  final Color bg;
  final Color surface;
  final Color surfaceVar;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceVar,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
  });

  static const _dark = AppPalette(
    bg: Color(0xFF0A0A12),
    surface: Color(0xFF15151F),
    surfaceVar: Color(0xFF1E1E2C),
    border: Color(0xFF2A2A3A),
    textPrimary: Color(0xFFE8E8F0),
    textSecondary: Color(0xFF8A8A9A),
  );

  static const _light = AppPalette(
    bg: Color(0xFFF2F4F7),
    surface: Color(0xFFFFFFFF),
    surfaceVar: Color(0xFFEEF0F5),
    border: Color(0xFFE0E4EA),
    textPrimary: Color(0xFF1A1A2E),
    textSecondary: Color(0xFF6B7280),
  );
}

extension AppPaletteContext on BuildContext {
  /// Returns a theme-adaptive colour palette.
  AppPalette get colors => Theme.of(this).brightness == Brightness.dark
      ? AppPalette._dark
      : AppPalette._light;
}
