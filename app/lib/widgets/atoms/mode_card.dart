import 'package:flutter/material.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../design/text_styles.dart';
import 'atmosphere_switch.dart';

class DeviceModeCard extends StatelessWidget {
  final String mode;
  final bool online;
  final ValueChanged<bool>? onChanged;

  const DeviceModeCard({
    super.key,
    required this.mode,
    required this.online,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animationDuration =
        disableAnimations ? Duration.zero : const Duration(milliseconds: 280);
    final stackedLayout = MediaQuery.textScalerOf(context).scale(1) > 1.4 ||
        MediaQuery.sizeOf(context).width < 360;

    final isOn = mode.toLowerCase() == 'on';

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DEVICE MODE',
          style: AtmosphereTextStyles.label(c.ink2),
        ),
        const SizedBox(height: AtmosphereTokens.space8),
        Text(
          mode.toUpperCase(),
          style: AtmosphereTextStyles.h1(isOn ? c.brand : c.ink3),
        ),
        const SizedBox(height: AtmosphereTokens.space4),
        Text(
          online ? 'Online' : 'Offline',
          style: AtmosphereTextStyles.caption(c.ink3),
        ),
      ],
    );

    return AnimatedContainer(
      duration: animationDuration,
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(AtmosphereTokens.space20),
      decoration: BoxDecoration(
        gradient: isOn
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.brandTint, c.brandTint2],
              )
            : null,
        color: isOn ? null : c.bg,
        borderRadius: BorderRadius.circular(AtmosphereTokens.radiusCard),
        border: Border.all(color: c.line, width: 1),
      ),
      child: stackedLayout
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                details,
                const SizedBox(height: AtmosphereTokens.space16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AtmosphereSwitch(
                    value: isOn,
                    onChanged: onChanged,
                    size: SwitchSize.large,
                    duration: animationDuration,
                    semanticLabel: 'Device mode toggle',
                    semanticValue: isOn ? 'On' : 'Standby',
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: details),
                AtmosphereSwitch(
                  value: isOn,
                  onChanged: onChanged,
                  size: SwitchSize.large,
                  duration: animationDuration,
                  semanticLabel: 'Device mode toggle',
                  semanticValue: isOn ? 'On' : 'Standby',
                ),
              ],
            ),
    );
  }
}
