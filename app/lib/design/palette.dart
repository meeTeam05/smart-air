import 'package:flutter/material.dart';
import 'tokens.dart';

class AtmospherePalette {
  final Color brand, brandDeep, brandTint, brandTint2;
  final Color accent, accentTint;
  final Color warn, warnTint, danger, dangerTint, amber, mint;
  final Color ink, ink2, ink3;
  final Color line, line2;
  final Color bg, paper;
  final Color tileCoolA, tileWarmA, tileAirA, tileNo2A;

  const AtmospherePalette({
    required this.brand,
    required this.brandDeep,
    required this.brandTint,
    required this.brandTint2,
    required this.accent,
    required this.accentTint,
    required this.warn,
    required this.warnTint,
    required this.danger,
    required this.dangerTint,
    required this.amber,
    required this.mint,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.line2,
    required this.bg,
    required this.paper,
    required this.tileCoolA,
    required this.tileWarmA,
    required this.tileAirA,
    required this.tileNo2A,
  });

  Color get textPrimary => ink;
  Color get textSecondary => ink3;
  Color get surface => paper;
  Color get surfaceVar => line2;
  Color get border => line;

  static const light = AtmospherePalette(
    brand: AtmosphereTokens.brand,
    brandDeep: AtmosphereTokens.brandDeep,
    brandTint: AtmosphereTokens.brandTint,
    brandTint2: AtmosphereTokens.brandTint2,
    accent: AtmosphereTokens.accent,
    accentTint: AtmosphereTokens.accentTint,
    warn: AtmosphereTokens.warn,
    warnTint: AtmosphereTokens.warnTint,
    danger: AtmosphereTokens.danger,
    dangerTint: AtmosphereTokens.dangerTint,
    amber: AtmosphereTokens.amber,
    mint: AtmosphereTokens.mint,
    ink: AtmosphereTokens.ink,
    ink2: AtmosphereTokens.ink2,
    ink3: AtmosphereTokens.ink3,
    line: AtmosphereTokens.line,
    line2: AtmosphereTokens.line2,
    bg: AtmosphereTokens.bg,
    paper: AtmosphereTokens.paper,
    tileCoolA: AtmosphereTokens.tileCoolA,
    tileWarmA: AtmosphereTokens.tileWarmA,
    tileAirA: AtmosphereTokens.tileAirA,
    tileNo2A: AtmosphereTokens.tileNo2A,
  );

  static const dark = AtmospherePalette(
    brand: AtmosphereTokens.brand,
    brandDeep: AtmosphereTokens.brandDeep,
    brandTint: Color(0xFF143C36),
    brandTint2: Color(0xFF1B5048),
    accent: AtmosphereTokens.accent,
    accentTint: Color(0xFF152643),
    warn: AtmosphereTokens.warn,
    warnTint: Color(0xFF3A2410),
    danger: AtmosphereTokens.danger,
    dangerTint: Color(0xFF3A1612),
    amber: AtmosphereTokens.amber,
    mint: AtmosphereTokens.mint,
    ink: Color(0xFFE8EEEC),
    ink2: Color(0xFFB6C5C0),
    ink3: Color(0xFF8A9994),
    line: Color(0xFF1F2A26),
    line2: Color(0xFF17211E),
    bg: Color(0xFF0B1411),
    paper: Color(0xFF12201C),
    tileCoolA: Color(0xFF143C36),
    tileWarmA: Color(0xFF3A2410),
    tileAirA: Color(0xFF152643),
    tileNo2A: Color(0xFF231538),
  );
}

extension AtmospherePaletteContext on BuildContext {
  AtmospherePalette get colors => Theme.of(this).brightness == Brightness.dark
      ? AtmospherePalette.dark
      : AtmospherePalette.light;
}
