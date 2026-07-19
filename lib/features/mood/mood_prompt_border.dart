import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';

class MoodPromptBorderPainter extends CustomPainter {
  const MoodPromptBorderPainter({
    this.color = Palette.ink,
    this.strokeWidth = Shapes.outlineWidth,
    this.radius = Shapes.radiusMd,
    this.dashLength = Shapes.dashLength,
    this.dashGap = Shapes.dashGap,
  });

  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashLength;
  final double dashGap;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    final double inset = strokeWidth / 2;
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final Path path = Path()..addRRect(rrect);
    final double step = dashLength + dashGap;
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double end = distance + dashLength;
        canvas.drawPath(
          metric.extractPath(
            distance,
            end < metric.length ? end : metric.length,
          ),
          stroke,
        );
        distance += step;
      }
    }
  }

  @override
  bool shouldRepaint(MoodPromptBorderPainter oldDelegate) {
    return color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        radius != oldDelegate.radius ||
        dashLength != oldDelegate.dashLength ||
        dashGap != oldDelegate.dashGap;
  }
}
