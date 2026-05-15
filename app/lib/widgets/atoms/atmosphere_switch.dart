import 'package:flutter/material.dart';
import '../../design/palette.dart';

enum SwitchSize { normal, large }

class AtmosphereSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final SwitchSize size;
  final Duration duration;
  final String? semanticLabel;
  final String? semanticValue;

  const AtmosphereSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.size = SwitchSize.normal,
    this.duration = const Duration(milliseconds: 200),
    this.semanticLabel,
    this.semanticValue,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animationDuration = disableAnimations ? Duration.zero : duration;
    final isLarge = size == SwitchSize.large;
    final trackWidth = isLarge ? 58.0 : 52.0;
    final trackHeight = isLarge ? 34.0 : 30.0;
    final thumbSize = isLarge ? 28.0 : 24.0;
    final outerWidth = isLarge ? 72.0 : 64.0;

    return Semantics(
      button: true,
      enabled: onChanged != null,
      toggled: value,
      label: semanticLabel,
      value: semanticValue ?? (value ? 'On' : 'Off'),
      onTap: onChanged == null ? null : () => onChanged?.call(!value),
      child: ExcludeSemantics(
        child: Opacity(
          opacity: onChanged == null ? 0.6 : 1,
          child: SizedBox(
            width: outerWidth,
            height: 48,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onChanged == null ? null : () => onChanged?.call(!value),
                borderRadius: BorderRadius.circular(999),
                child: Center(
                  child: AnimatedContainer(
                    duration: animationDuration,
                    curve: Curves.easeInOut,
                    width: trackWidth,
                    height: trackHeight,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: value ? c.brand : c.line2,
                      borderRadius: BorderRadius.circular(trackHeight / 2),
                    ),
                    child: AnimatedAlign(
                      duration: animationDuration,
                      curve: Curves.easeInOut,
                      alignment:
                          value ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: thumbSize,
                        height: thumbSize,
                        decoration: BoxDecoration(
                          color: value ? c.paper : c.ink3,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
