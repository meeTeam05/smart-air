import 'package:flutter/material.dart';

class AtmosphereDotLogo extends StatelessWidget {
  final double size;
  final Color color;

  const AtmosphereDotLogo({
    super.key,
    this.size = 40,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DotLogoPainter(color: color),
      ),
    );
  }
}

class _DotLogoPainter extends CustomPainter {
  final Color color;

  _DotLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final dotSize = size.width / 9;
    final spacing = size.width / 6;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final positions = [
      (0, 0, 0.3),
      (1, 0, 0.5),
      (2, 0, 0.7),
      (3, 0, 0.5),
      (4, 0, 0.3),
      (0, 1, 0.5),
      (1, 1, 1.0),
      (2, 1, 1.0),
      (3, 1, 1.0),
      (4, 1, 0.5),
      (0, 2, 0.7),
      (1, 2, 1.0),
      (2, 2, 1.0),
      (3, 2, 1.0),
      (4, 2, 0.7),
      (0, 3, 0.5),
      (1, 3, 1.0),
      (2, 3, 1.0),
      (3, 3, 1.0),
      (4, 3, 0.5),
      (0, 4, 0.3),
      (1, 4, 0.5),
      (2, 4, 0.7),
      (3, 4, 0.5),
      (4, 4, 0.3),
    ];

    for (final (x, y, opacity) in positions) {
      final cx = x * spacing + dotSize / 2;
      final cy = y * spacing + dotSize / 2;
      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(cx, cy), dotSize / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_DotLogoPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
