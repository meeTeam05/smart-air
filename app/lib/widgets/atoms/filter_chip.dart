import 'package:flutter/material.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../design/text_styles.dart';

class AtmosphereFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const AtmosphereFilterChip({
    super.key,
    required this.label,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AtmosphereTokens.space16,
          vertical: AtmosphereTokens.space8,
        ),
        decoration: BoxDecoration(
          color: active ? c.brandTint : c.paper,
          border: Border.all(
            color: active ? c.brand : c.line,
            width: active ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(AtmosphereTokens.radiusPill),
        ),
        child: Text(
          label,
          style: AtmosphereTextStyles.body(active ? c.brand : c.ink2),
        ),
      ),
    );
  }
}
