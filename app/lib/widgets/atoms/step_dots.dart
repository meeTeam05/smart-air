import 'package:flutter/material.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';

class StepDots extends StatelessWidget {
  final int current;
  final int total;

  const StepDots({
    super.key,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        final isActive = index == current;
        final isPast = index < current;

        return Container(
          margin:
              const EdgeInsets.symmetric(horizontal: AtmosphereTokens.space4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive || isPast ? c.brand : c.line2,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
