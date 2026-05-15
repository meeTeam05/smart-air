import 'package:flutter/material.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../design/text_styles.dart';
import 'sparkline.dart';

enum SensorTone { cool, warm, air, no2 }

class SensorTile extends StatelessWidget {
  final String? value;
  final String unit;
  final String label;
  final IconData icon;
  final SensorTone tone;
  final Color sparkColor;
  final List<double>? sparklineData;
  final bool dimmed;

  const SensorTile({
    super.key,
    this.value,
    required this.unit,
    required this.label,
    required this.icon,
    required this.tone,
    required this.sparkColor,
    this.sparklineData,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animationDuration =
        disableAnimations ? Duration.zero : const Duration(milliseconds: 180);
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;

    final bgColor = _getBackgroundColor(c);
    final displayValue = dimmed ? '—' : (value ?? '—');
    final semanticValue =
        displayValue == '—' ? 'Unavailable' : '$displayValue $unit';

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: c.ink2),
            const SizedBox(width: AtmosphereTokens.space4),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: AtmosphereTextStyles.label(c.ink2),
              ),
            ),
          ],
        ),
        const Spacer(),
        largeText
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayValue,
                    style: AtmosphereTextStyles.sensorValue(
                      dimmed ? c.ink3 : c.ink,
                    ),
                  ),
                  const SizedBox(height: AtmosphereTokens.space4),
                  Text(
                    unit,
                    style: AtmosphereTextStyles.body(c.ink2),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    displayValue,
                    style: AtmosphereTextStyles.sensorValue(
                      dimmed ? c.ink3 : c.ink,
                    ),
                  ),
                  const SizedBox(width: AtmosphereTokens.space4),
                  Text(
                    unit,
                    style: AtmosphereTextStyles.body(c.ink2),
                  ),
                ],
              ),
        const SizedBox(height: AtmosphereTokens.space8),
        if (!dimmed && sparklineData != null && sparklineData!.isNotEmpty)
          Sparkline(
            points: sparklineData!,
            color: sparkColor,
            height: 32,
          )
        else
          const SizedBox(height: 32),
      ],
    );

    return Semantics(
      container: true,
      label: '$label sensor',
      value: semanticValue,
      child: TweenAnimationBuilder<double>(
        key: ValueKey('$label-$displayValue-$dimmed'),
        tween: Tween(begin: 0, end: 1),
        duration: animationDuration,
        curve: Curves.easeOut,
        child: content,
        builder: (context, value, child) {
          final glow = (1 - value) * 0.18;
          return Container(
            padding: const EdgeInsets.all(AtmosphereTokens.space16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [bgColor, bgColor.withValues(alpha: 0.6)],
              ),
              borderRadius: BorderRadius.circular(AtmosphereTokens.radiusTile),
              border: Border.all(color: c.line, width: 1),
              boxShadow: glow == 0 || dimmed
                  ? null
                  : [
                      BoxShadow(
                        color: sparkColor.withValues(alpha: glow),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
            ),
            child: child,
          );
        },
      ),
    );
  }

  Color _getBackgroundColor(AtmospherePalette c) {
    switch (tone) {
      case SensorTone.cool:
        return c.tileCoolA;
      case SensorTone.warm:
        return c.tileWarmA;
      case SensorTone.air:
        return c.tileAirA;
      case SensorTone.no2:
        return c.tileNo2A;
    }
  }
}
