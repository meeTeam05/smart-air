// app/lib/app_theme.dart (modified - do not delete this file)
export 'design/tokens.dart';
export 'design/palette.dart';
export 'design/atmosphere_theme.dart';
export 'design/text_styles.dart';
export 'design/icons.dart';

import 'package:flutter/material.dart';
import 'design/tokens.dart';
import 'design/atmosphere_theme.dart';

/// Brand colors safe to reference directly per app.md CS-03.
/// Theme-adaptive colors (bg, surface, border, text*) MUST go through
/// `context.colors` (see `design/palette.dart`).
class AppColors {
  AppColors._();
  static const Color primary = AtmosphereTokens.brand;
  static const Color online = Color(0xFF1A8767);
  static const Color offline = AtmosphereTokens.ink3;
  static const Color warning = AtmosphereTokens.warn;
}

// Legacy AppTheme class retained for backward compatibility during migration
class AppTheme {
  AppTheme._();

  static ThemeData dark() => AtmosphereTheme.dark();
  static ThemeData light() => AtmosphereTheme.light();
}
