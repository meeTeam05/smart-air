import 'package:flutter/material.dart';

/// Atmosphere brand palette — Source: tmp/app/Atmosphere.html.
/// These are the only raw color literals allowed in the codebase.
/// All other widgets MUST consume via [context.colors] extension.
class AtmosphereTokens {
  AtmosphereTokens._();

  // Brand
  static const brand        = Color(0xFF0F6B5C);
  static const brandDeep    = Color(0xFF0A4F44);
  static const brandTint    = Color(0xFFE4F0EC);
  static const brandTint2   = Color(0xFFD5E8E1);

  // Secondary
  static const accent       = Color(0xFF2C6BF0);
  static const accentTint   = Color(0xFFE5EEFD);

  // Semantic
  static const warn         = Color(0xFFE07A1A);
  static const warnTint     = Color(0xFFFFF1DF);
  static const danger       = Color(0xFFD9462E);
  static const dangerTint   = Color(0xFFFFE5E0);
  static const amber        = Color(0xFFE8A33C);
  static const mint         = Color(0xFFBFE6D8);

  // Neutrals (light theme defaults — dark overrides in palette)
  static const ink          = Color(0xFF0E1F1B);
  static const ink2         = Color(0xFF3F5751);
  static const ink3         = Color(0xFF6E827D);
  static const line         = Color(0xFFE3EAE7);
  static const line2        = Color(0xFFEEF3F1);
  static const bg           = Color(0xFFF5F7F6);
  static const paper        = Color(0xFFFFFFFF);

  // Tile gradients (sensor cards) — 2-stop
  static const tileCoolA    = Color(0xFFE8F4EF);
  static const tileWarmA    = Color(0xFFFFEFE3);
  static const tileAirA     = Color(0xFFE5EEFD);
  static const tileNo2A     = Color(0xFFF0E8FB);

  // Radii
  static const radiusCard    = 22.0;
  static const radiusButton  = 14.0;
  static const radiusTile    = 20.0;
  static const radiusInput   = 16.0;
  static const radiusPill    = 999.0;

  // Spacing scale
  static const space2  = 2.0;
  static const space4  = 4.0;
  static const space6  = 6.0;
  static const space8  = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space20 = 20.0;
  static const space24 = 24.0;
  static const space32 = 32.0;

  // Elevation shadows
  static const shadowCard = [
    BoxShadow(color: Color(0x11000000), offset: Offset(0, 4), blurRadius: 12),
  ];
  static const shadowFab  = [
    BoxShadow(color: Color(0x290F6B5C), offset: Offset(0, 10), blurRadius: 24),
  ];
}
