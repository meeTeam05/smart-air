import 'package:flutter/material.dart';
import '../../design/tokens.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onPressed;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.loading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AtmosphereTokens.brand,
          foregroundColor: AtmosphereTokens.paper,
          disabledBackgroundColor: AtmosphereTokens.brand.withValues(alpha: 0.5),
          disabledForegroundColor: AtmosphereTokens.paper.withValues(alpha: 0.7),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AtmosphereTokens.space24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AtmosphereTokens.radiusButton),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AtmosphereTokens.paper),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: AtmosphereTokens.space8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}
