import 'package:flutter/material.dart';
import 'dart:math' as math;

class Sparkline extends StatelessWidget {
  final List<double> points;
  final Color color;
  final double height;

  const Sparkline({
    super.key,
    required this.points,
    required this.color,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(height: height);
    }

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(
          points: points,
          color: color,
        ),
        child: Container(),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;

  _SparklinePainter({
    required this.points,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final minValue = points.reduce(math.min);
    final maxValue = points.reduce(math.max);
    final range = maxValue - minValue;

    if (range == 0) {
      final y = size.height / 2;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
      return;
    }

    final path = Path();
    final stepX = size.width / (points.length - 1);

    for (var i = 0; i < points.length; i++) {
      final x = i * stepX;
      final normalizedValue = (points[i] - minValue) / range;
      final y = size.height - (normalizedValue * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}
