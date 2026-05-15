import 'package:flutter/material.dart';

import '../../design/icons.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../atoms/ghost_button.dart';
import '../atoms/primary_button.dart';
import '../atoms/step_dots.dart';

class BleStepShell extends StatelessWidget {
  const BleStepShell({
    super.key,
    required this.currentStep,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryLoading = false,
    this.primaryEnabled = true,
    this.onCancel,
  });

  final int currentStep;
  final String title;
  final String subtitle;
  final Widget body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool primaryLoading;
  final bool primaryEnabled;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AtmosphereTokens.space20,
            AtmosphereTokens.space12,
            AtmosphereTokens.space20,
            AtmosphereTokens.space20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed:
                        onCancel ?? () => Navigator.of(context).maybePop(),
                    icon: Icon(AppIcons.close, color: c.ink),
                  ),
                  const Spacer(),
                  Text(
                    'Provisioning',
                    style: TextStyle(
                      color: c.ink3,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
              const SizedBox(height: AtmosphereTokens.space12),
              StepDots(current: currentStep, total: 5),
              const SizedBox(height: AtmosphereTokens.space24),
              Text(
                title,
                style: TextStyle(
                  color: c.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: AtmosphereTokens.space8),
              Text(
                subtitle,
                style: TextStyle(
                  color: c.ink2,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AtmosphereTokens.space24),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: body,
                ),
              ),
              const SizedBox(height: AtmosphereTokens.space16),
              PrimaryButton(
                label: primaryLabel,
                loading: primaryLoading,
                onPressed: primaryEnabled ? onPrimary : null,
              ),
              if (secondaryLabel != null) ...[
                const SizedBox(height: AtmosphereTokens.space12),
                GhostButton(
                  label: secondaryLabel!,
                  onPressed: onSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
