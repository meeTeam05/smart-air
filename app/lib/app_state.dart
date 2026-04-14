import 'package:flutter/material.dart';

/// Lightweight global state using ValueNotifier — no package dependency.
class AppState {
  AppState._();

  /// Current ThemeMode — light (default), dark, or system.
  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

  static const Map<String, String> themeModeLabels = {
    'dark': 'Dark',
    'light': 'Light',
    'system': 'System',
  };

  static ThemeMode themeModeFromKey(String key) {
    switch (key) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  static String keyFromThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
      default:
        return 'dark';
    }
  }
}
