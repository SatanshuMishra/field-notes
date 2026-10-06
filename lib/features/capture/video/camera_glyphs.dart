import 'dart:math' as math;

import 'package:flutter/widgets.dart';

const Color cameraGlyphInk = Color(0xF2FFFFFF);

const double cameraGlyphSize = 20;

const double _stroke = 1.8;
const double _viewBox = 24;

enum CameraGlyphKind { camera, cameraOff, flip }

class CameraGlyph extends StatelessWidget {
  const CameraGlyph(this.kind, {super.key});

  final CameraGlyphKind kind;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: cameraGlyphSize,
      child: CustomPaint(painter: _CameraGlyphPainter(kind)),
    );
  }
}

class _CameraGlyphPainter extends CustomPainter {
  const _CameraGlyphPainter(this.kind);

  final CameraGlyphKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = cameraGlyphInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(size.shortestSide / _viewBox);
    switch (kind) {
      case CameraGlyphKind.camera:
        _videoCamera(canvas, stroke);
      case CameraGlyphKind.cameraOff:
        _videoCamera(canvas, stroke);
        canvas.drawLine(const Offset(3, 3.5), const Offset(21, 20.5), stroke);
      case CameraGlyphKind.flip:
        _flip(canvas, stroke);
    }
    canvas.restore();
  }

  void _videoCamera(Canvas canvas, Paint stroke) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2.5, 6.5, 13, 11),
        const Radius.circular(2.5),
      ),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(15.5, 10.5)
        ..lineTo(21.5, 7.2)
        ..lineTo(21.5, 16.8)
        ..lineTo(15.5, 13.5),
      stroke,
    );
  }

  void _flip(Canvas canvas, Paint stroke) {
    const Offset centre = Offset(12, 12);
    const double radius = 7.5;
    final Rect circle = Rect.fromCircle(center: centre, radius: radius);
    canvas.drawArc(circle, math.pi * 1.15, math.pi * 0.85, false, stroke);
    canvas.drawArc(circle, math.pi * 0.15, math.pi * 0.85, false, stroke);
    _arrowHead(canvas, stroke, centre, radius, math.pi * 2);
    _arrowHead(canvas, stroke, centre, radius, math.pi);
    canvas.drawCircle(centre, 2.2, stroke);
  }

  void _arrowHead(
    Canvas canvas,
    Paint stroke,
    Offset centre,
    double radius,
    double angle,
  ) {
    final Offset tip =
        centre + Offset(math.cos(angle), math.sin(angle)) * radius;
    final Offset along = Offset(-math.sin(angle), math.cos(angle));
    final Offset outward = Offset(math.cos(angle), math.sin(angle));
    final Offset outer = tip - along * 3 + outward * 2.4;
    final Offset inner = tip - along * 3 - outward * 2.4;
    canvas.drawPath(
      Path()
        ..moveTo(outer.dx, outer.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(inner.dx, inner.dy),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_CameraGlyphPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
