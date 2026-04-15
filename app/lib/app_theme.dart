import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // ── Dark palette ─────────────────────────────────────────────────────────
  static const Color bg = Color(0xFF0B0F19);
  static const Color surface = Color(0xFF131A2A);
  static const Color surfaceVar = Color(0xFF1E283C);
  static const Color border = Color(0xFF26324D);
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryGlow = Color(0xFF818CF8);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  
  // Status colors
  static const Color online = Color(0xFF10B981);
  static const Color onlineGlow = Color(0xFF34D399);
  static const Color offline = Color(0xFF64748B);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        surface: AppColors.surface,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent, // We will use custom headers
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary);
          }
          return const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary);
        }),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 0.5,
        space: 0,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme),
    );
  }

  static ThemeData light() {
    const lightBg = Color(0xFFF8FAFC);
    const lightSurface = Color(0xFFFFFFFF);
    const lightSurfaceVar = Color(0xFFF1F5F9);
    const lightBorder = Color(0xFFE2E8F0);
    const lightText = Color(0xFF0F172A);
    const lightTextSec = Color(0xFF64748B);

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        surface: lightSurface,
        onSurface: lightText,
        onSurfaceVariant: lightTextSec,
      ),
      scaffoldBackgroundColor: lightBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: lightText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: lightBorder, width: 0.5),
        ),
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme),
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
    bg: AppColors.bg,
    surface: AppColors.surface,
    surfaceVar: AppColors.surfaceVar,
    border: AppColors.border,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
  );

  static const _light = AppPalette(
    bg: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    surfaceVar: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
  );
}

extension AppPaletteContext on BuildContext {
  /// Returns a theme-adaptive colour palette.
  AppPalette get colors => Theme.of(this).brightness == Brightness.dark
      ? AppPalette._dark
      : AppPalette._light;
}
