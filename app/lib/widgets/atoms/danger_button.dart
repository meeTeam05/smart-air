import 'package:flutter/material.dart';
import '../../design/tokens.dart';

class DangerButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const DangerButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AtmosphereTokens.danger,
          foregroundColor: AtmosphereTokens.paper,
          elevation: 0,
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
