import 'package:flutter/material.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';

class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: c.paper,
          foregroundColor: c.brand,
          side: BorderSide(color: c.brand, width: 1.5),
          padding: const EdgeInsets.symmetric(
            horizontal: AtmosphereTokens.space24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AtmosphereTokens.radiusButton),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
