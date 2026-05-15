import 'package:flutter/material.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../design/text_styles.dart';
import 'primary_button.dart';
import 'ghost_button.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? primaryAction;
  final VoidCallback? onPrimaryAction;
  final String? secondaryAction;
  final VoidCallback? onSecondaryAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.primaryAction,
    this.onPrimaryAction,
    this.secondaryAction,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AtmosphereTokens.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.line2,
              ),
              child: Icon(
                icon,
                size: 48,
                color: c.ink3,
              ),
            ),
            const SizedBox(height: AtmosphereTokens.space24),
            Text(
              title,
              style: AtmosphereTextStyles.h1(c.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AtmosphereTokens.space12),
            Text(
              body,
              style: AtmosphereTextStyles.body(c.ink2),
              textAlign: TextAlign.center,
            ),
            if (primaryAction != null) ...[
              const SizedBox(height: AtmosphereTokens.space32),
              PrimaryButton(
                label: primaryAction!,
                onPressed: onPrimaryAction,
              ),
            ],
            if (secondaryAction != null) ...[
              const SizedBox(height: AtmosphereTokens.space12),
              GhostButton(
                label: secondaryAction!,
                onPressed: onSecondaryAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
