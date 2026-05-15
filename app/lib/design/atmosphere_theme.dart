import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tokens.dart';
import 'palette.dart';

class AtmosphereTheme {
  AtmosphereTheme._();

  static ThemeData light() {
    const palette = AtmospherePalette.light;
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: palette.brand,
        onPrimary: Colors.white,
        secondary: palette.accent,
        onSecondary: Colors.white,
        error: palette.danger,
        onError: Colors.white,
        surface: palette.paper,
        onSurface: palette.ink,
      ),
      scaffoldBackgroundColor: palette.bg,
      
      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: palette.bg,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: palette.ink,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      
      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.paper,
        selectedItemColor: palette.brand,
        unselectedItemColor: palette.ink3,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      
      // Cards
      cardTheme: CardThemeData(
        color: palette.paper,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AtmosphereTokens.radiusCard),
          side: BorderSide(color: palette.line, width: 1),
        ),
      ),
      
      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.paper,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AtmosphereTokens.radiusInput),
          borderSide: BorderSide(color: palette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AtmosphereTokens.radiusInput),
          borderSide: BorderSide(color: palette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AtmosphereTokens.radiusInput),
          borderSide: BorderSide(color: palette.brand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AtmosphereTokens.radiusInput),
          borderSide: BorderSide(color: palette.danger),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AtmosphereTokens.space16,
          vertical: AtmosphereTokens.space16,
        ),
      ),
      
      // Switches
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return palette.ink3;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.brand;
          return palette.line2;
        }),
      ),
      
      // Elevated buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AtmosphereTokens.space24,
            vertical: AtmosphereTokens.space16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AtmosphereTokens.radiusButton),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Dividers
      dividerTheme: DividerThemeData(
        color: palette.line,
        thickness: 1,
        space: 0,
      ),
    );
  }

  static ThemeData dark() {
    const palette = AtmospherePalette.dark;
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: palette.brand,
        onPrimary: Colors.white,
        secondary: palette.accent,
        onSecondary: Colors.white,
        error: palette.danger,
        onError: Colors.white,
        surface: palette.paper,
        onSurface: palette.ink,
      ),
      scaffoldBackgroundColor: palette.bg,
      
      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: palette.bg,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: palette.ink,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      
      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.paper,
        selectedItemColor: palette.brand,
        unselectedItemColor: palette.ink3,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      
      // Cards
      cardTheme: CardThemeData(
        color: palette.paper,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AtmosphereTokens.radiusCard),
          side: BorderSide(color: palette.line, width: 1),
        ),
      ),
      
      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.paper,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AtmosphereTokens.radiusInput),
          borderSide: BorderSide(color: palette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AtmosphereTokens.radiusInput),
          borderSide: BorderSide(color: palette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AtmosphereTokens.radiusInput),
          borderSide: BorderSide(color: palette.brand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AtmosphereTokens.radiusInput),
          borderSide: BorderSide(color: palette.danger),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AtmosphereTokens.space16,
          vertical: AtmosphereTokens.space16,
        ),
      ),
      
      // Switches
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return palette.ink3;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.brand;
          return palette.line2;
        }),
      ),
      
      // Elevated buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AtmosphereTokens.space24,
            vertical: AtmosphereTokens.space16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AtmosphereTokens.radiusButton),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Dividers
      dividerTheme: DividerThemeData(
        color: palette.line,
        thickness: 1,
        space: 0,
      ),
    );
  }
}
