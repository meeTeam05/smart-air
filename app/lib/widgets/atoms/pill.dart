import 'package:flutter/material.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../design/text_styles.dart';

enum PillTone {
  online,
  offline,
  warn,
  brand,
  accent,
  danger,
}

class AtmospherePill extends StatelessWidget {
  final String label;
  final PillTone tone;

  const AtmospherePill({
    super.key,
    required this.label,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final colors = _getColors(c);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(AtmosphereTokens.radiusPill),
      ),
      child: Text(
        label.toUpperCase(),
        style: AtmosphereTextStyles.pill(colors.text),
      ),
    );
  }

  ({Color bg, Color text}) _getColors(AtmospherePalette c) {
    switch (tone) {
      case PillTone.online:
        return (
          bg: const Color(0xFF1A8767).withValues(alpha: 0.15),
          text: const Color(0xFF1A8767)
        );
      case PillTone.offline:
        return (bg: c.ink3.withValues(alpha: 0.15), text: c.ink3);
      case PillTone.warn:
        return (bg: c.warnTint, text: c.warn);
      case PillTone.brand:
        return (bg: c.brandTint, text: c.brand);
      case PillTone.accent:
        return (bg: c.accentTint, text: c.accent);
      case PillTone.danger:
        return (bg: c.dangerTint, text: c.danger);
    }
  }
}
