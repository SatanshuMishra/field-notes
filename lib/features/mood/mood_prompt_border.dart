import 'dart:ui' show MaskFilter, PathMetric;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';

class MoodPromptBorderPainter extends CustomPainter {
  const MoodPromptBorderPainter({
    this.color = Palette.ink,
    this.fill = Palette.cardWarm,
    this.shadows = Shadows.heroSoft,
    this.strokeWidth = Shapes.outlineWidth,
    this.radius = Shapes.radiusLg,
    this.dashLength = Shapes.dashLength,
    this.dashGap = Shapes.dashGap,
  });

  final Color color;
  final Color fill;
  final List<BoxShadow> shadows;
  final double strokeWidth;
  final double radius;
  final double dashLength;
  final double dashGap;

  @override
  void paint(Canvas canvas, Size size) {
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
    for (final BoxShadow shadow in shadows) {
      canvas.drawRRect(
        rrect.shift(shadow.offset).inflate(shadow.spreadRadius),
        _shadowPaint(shadow),
      );
    }
    canvas.drawRRect(rrect, Paint()..color = fill);
    final Paint stroke = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
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

  Paint _shadowPaint(BoxShadow shadow) {
    final Paint paint = Paint()..color = shadow.color;
    if (shadow.blurSigma > 0) {
      paint.maskFilter = MaskFilter.blur(shadow.blurStyle, shadow.blurSigma);
    }
    return paint;
  }

  @override
  bool shouldRepaint(MoodPromptBorderPainter oldDelegate) {
    return color != oldDelegate.color ||
        fill != oldDelegate.fill ||
        !listEquals(shadows, oldDelegate.shadows) ||
        strokeWidth != oldDelegate.strokeWidth ||
        radius != oldDelegate.radius ||
        dashLength != oldDelegate.dashLength ||
        dashGap != oldDelegate.dashGap;
  }
}
