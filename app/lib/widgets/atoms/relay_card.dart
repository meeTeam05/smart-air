import 'package:flutter/material.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../design/text_styles.dart';
import '../../design/icons.dart';
import 'atmosphere_switch.dart';

class RelayCard extends StatelessWidget {
  final int channel;
  final String name;
  final bool on;
  final bool disabled;
  final VoidCallback? onTap;

  const RelayCard({
    super.key,
    required this.channel,
    required this.name,
    required this.on,
    this.disabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return MergeSemantics(
      child: Opacity(
        opacity: disabled ? 0.55 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(AtmosphereTokens.space16),
          decoration: BoxDecoration(
            color: c.paper,
            borderRadius: BorderRadius.circular(AtmosphereTokens.radiusCard),
            border: Border.all(color: c.line, width: 1),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'R$channel',
                    style: AtmosphereTextStyles.label(c.ink3),
                  ),
                  const SizedBox(height: AtmosphereTokens.space8),
                  Text(
                    name,
                    style: AtmosphereTextStyles.body(c.ink),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AtmosphereTokens.space12),
                  AtmosphereSwitch(
                    value: on,
                    onChanged: disabled ? null : (_) => onTap?.call(),
                    semanticLabel: 'Relay $channel $name toggle',
                    semanticValue: on ? 'On' : 'Off',
                  ),
                  const SizedBox(height: AtmosphereTokens.space8),
                  Text(
                    on ? 'ON' : 'OFF',
                    style: AtmosphereTextStyles.caption(c.ink3),
                  ),
                ],
              ),
              if (disabled)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    AppIcons.lock,
                    size: 16,
                    color: c.ink3,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
