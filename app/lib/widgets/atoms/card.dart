import 'package:flutter/material.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';

class AtmosphereCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Gradient? gradient;
  final bool elevated;

  const AtmosphereCard({
    super.key,
    required this.child,
    this.padding,
    this.gradient,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: padding ?? const EdgeInsets.all(AtmosphereTokens.space16),
      decoration: BoxDecoration(
        color: gradient == null ? c.paper : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(AtmosphereTokens.radiusCard),
        border: Border.all(color: c.line, width: 1),
        boxShadow: elevated ? AtmosphereTokens.shadowCard : null,
      ),
      child: child,
    );
  }
}
