import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'bloom_part.dart';

class BloomPartPainter {
  const BloomPartPainter({
    required this.strokeColor,
    required this.strokeWidth,
  });

  final Color strokeColor;
  final double strokeWidth;

  void paintAll(Canvas canvas, List<BloomPart> parts) {
    for (final BloomPart part in parts) {
      paintOne(canvas, part);
    }
  }

  void paintOne(Canvas canvas, BloomPart part) {
    final Color? fillColor = part.fill;
    final Paint? fill = fillColor == null ? null : _fill(fillColor);
    final double width = part.strokeWidth ?? strokeWidth;
    final Paint? stroke = width == 0
        ? null
        : (Paint()
          ..color = part.strokeColor ?? strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = part.strokeCap
          ..strokeJoin = part.strokeJoin
          ..isAntiAlias = true);
    switch (part) {
      case BloomDisc():
        final Offset c = Offset(part.cx, part.cy);
        if (fill != null) {
          canvas.drawCircle(c, part.r, fill);
        }
        if (stroke != null) {
          canvas.drawCircle(c, part.r, stroke);
        }
      case BloomOval():
        _paintOval(canvas, part.cx, part.cy, part.rx, part.ry, part.rotationDeg,
            part.pivotX, part.pivotY, fill, stroke);
      case BloomOvalRing():
        for (int i = 0; i < part.count; i++) {
          _paintOval(
            canvas,
            part.cx,
            part.cy,
            part.rx,
            part.ry,
            part.startDeg + part.stepDeg * i,
            part.pivotX,
            part.pivotY,
            fill,
            stroke,
          );
        }
      case BloomShape():
        final Path path = _shapePath(part);
        if (fill != null) {
          canvas.drawPath(path, fill);
        }
        if (stroke != null) {
          canvas.drawPath(path, stroke);
        }
    }
  }

  void _paintOval(Canvas canvas, double cx, double cy, double rx, double ry,
      double rotationDeg, double pivotX, double pivotY, Paint? fill,
      Paint? stroke) {
    final Rect rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: rx * 2,
      height: ry * 2,
    );
    canvas.save();
    if (rotationDeg != 0) {
      canvas.translate(pivotX, pivotY);
      canvas.rotate(rotationDeg * math.pi / 180);
      canvas.translate(-pivotX, -pivotY);
    }
    if (fill != null) {
      canvas.drawOval(rect, fill);
    }
    if (stroke != null) {
      canvas.drawOval(rect, stroke);
    }
    canvas.restore();
  }

  Path _shapePath(BloomShape shape) {
    final Path path = Path();
    for (final BloomCmd cmd in shape.commands) {
      switch (cmd) {
        case BloomMoveTo():
          path.moveTo(cmd.x, cmd.y);
        case BloomLineTo():
          path.lineTo(cmd.x, cmd.y);
        case BloomQuadTo():
          path.quadraticBezierTo(cmd.cx, cmd.cy, cmd.x, cmd.y);
        case BloomCubicTo():
          path.cubicTo(cmd.c1x, cmd.c1y, cmd.c2x, cmd.c2y, cmd.x, cmd.y);
        case BloomArcTo():
          path.arcToPoint(
            Offset(cmd.x, cmd.y),
            radius: Radius.elliptical(cmd.rx, cmd.ry),
            largeArc: cmd.largeArc,
            clockwise: cmd.clockwise,
          );
      }
    }
    if (shape.close) {
      path.close();
    }
    return path;
  }

  Paint _fill(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
}
