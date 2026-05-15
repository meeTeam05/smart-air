import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

class Sparkline extends StatelessWidget {
  final List<double> points;
  final Color color;
  final double height;
  /// Maximum number of data points to render. Older points are dropped.
  final int maxPoints;

  const Sparkline({
    super.key,
    required this.points,
    required this.color,
    this.height = 40,
    this.maxPoints = 30,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(height: height);
    }

    // Keep only the latest maxPoints to avoid an over-dense chart.
    final trimmed =
        points.length > maxPoints ? points.sublist(points.length - maxPoints) : points;

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(
          points: trimmed,
          color: color,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;

  _SparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final minValue = points.reduce(math.min);
    final maxValue = points.reduce(math.max);
    final range = maxValue - minValue;

    // Vertical padding so the line doesn't clip at top/bottom edges.
    const vPad = 4.0;
    final drawH = size.height - vPad * 2;

    double toY(double v) {
      if (range == 0) return vPad + drawH / 2;
      return vPad + drawH - ((v - minValue) / range) * drawH;
    }

    final stepX = size.width / (points.length - 1);

    // Build the smooth line path using cubic bezier control points.
    final linePath = Path();
    final offsets = List.generate(
      points.length,
      (i) => Offset(i * stepX, toY(points[i])),
    );

    linePath.moveTo(offsets[0].dx, offsets[0].dy);
    for (var i = 0; i < offsets.length - 1; i++) {
      final p0 = offsets[i];
      final p1 = offsets[i + 1];
      // Smooth control points: 1/3 of the horizontal step on each side.
      final cpX = (p1.dx - p0.dx) / 3;
      linePath.cubicTo(
        p0.dx + cpX, p0.dy,
        p1.dx - cpX, p1.dy,
        p1.dx, p1.dy,
      );
    }

    // Fill path: close along the bottom of the canvas.
    final fillPath = Path.from(linePath)
      ..lineTo(offsets.last.dx, size.height)
      ..lineTo(offsets.first.dx, size.height)
      ..close();

    // Gradient fill under the line.
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, vPad),
        Offset(0, size.height),
        [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
      )
      ..style = PaintingStyle.fill;

    // Stroke paint for the line itself.
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.points != points || old.color != color;
}
