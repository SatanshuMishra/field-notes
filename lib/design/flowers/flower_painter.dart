import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'package:field_notes/design/tokens/tokens.dart';

import 'bloom_style.dart';
import 'flower_spec.dart';

class FlowerPainter extends CustomPainter {
  const FlowerPainter(this.spec, {this.headless = false});

  static const double viewBox = 44;

  final FlowerSpec spec;
  final bool headless;

  @override
  void paint(Canvas canvas, Size size) {
    final double d = size.shortestSide;
    if (headless) {
      canvas.save();
      canvas.translate((size.width - d) / 2, (size.height - d) / 2);
      canvas.clipRect(Rect.fromLTWH(0, 0, d, d));
      canvas.scale(d / viewBox);
      _paintBloom(
        canvas,
        const Size(viewBox, viewBox),
        const Offset(viewBox / 2, viewBox / 2),
        viewBox,
      );
      canvas.restore();
      return;
    }
    final Offset center = Offset(size.width / 2, size.height * 0.42);
    if (spec.style != BloomStyle.heartPendants) {
      _straightStem(canvas, size, center, d, _stroke(d));
    }
    _paintBloom(canvas, size, center, d);
  }

  void _paintBloom(Canvas canvas, Size size, Offset center, double d) {
    final Paint stroke = _stroke(d);
    switch (spec.style) {
      case BloomStyle.roundPetals:
      case BloomStyle.broadPetals:
        _paintRadial(canvas, center, d, stroke, rounded: true);
      case BloomStyle.rayPetals:
        _paintRadial(canvas, center, d, stroke, rounded: false);
      case BloomStyle.spiderPetals:
        _paintSpider(canvas, center, d, stroke);
      case BloomStyle.spike:
        _paintSpike(canvas, center, d, stroke);
      case BloomStyle.puff:
        _paintPuff(canvas, center, d, stroke);
      case BloomStyle.heartPendants:
        _paintHearts(canvas, size, d, stroke);
    }
  }

  Paint _stroke(double d) => Paint()
    ..color = spec.strokeColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = spec.strokeWidth * d / viewBox
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  Paint _stemStroke(double d) => Paint()
    ..color = spec.stemColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(Shapes.outlineWidth, d * 0.045)
    ..strokeCap = StrokeCap.round;

  Paint _fill(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  Path _petal(double length, double width, {required bool rounded}) {
    final Path p = Path()..moveTo(0, 0);
    if (rounded) {
      p.cubicTo(-width * 0.9, -length * 0.35, -width * 0.6, -length, 0, -length);
      p.cubicTo(width * 0.6, -length, width * 0.9, -length * 0.35, 0, 0);
    } else {
      p.quadraticBezierTo(-width * 0.5, -length * 0.55, 0, -length);
      p.quadraticBezierTo(width * 0.5, -length * 0.55, 0, 0);
    }
    p.close();
    return p;
  }

  void _straightStem(
      Canvas canvas, Size size, Offset center, double d, Paint stroke) {
    final Path stem = Path()
      ..moveTo(center.dx, center.dy)
      ..quadraticBezierTo(
          center.dx + d * 0.06, size.height * 0.75, center.dx, size.height * 0.98);
    canvas.drawPath(stem, _stemStroke(d));
    final double ly = size.height * 0.72;
    final Path leaf = Path()
      ..moveTo(center.dx, ly)
      ..quadraticBezierTo(
          center.dx + d * 0.22, ly - d * 0.12, center.dx + d * 0.30, ly + d * 0.02)
      ..quadraticBezierTo(center.dx + d * 0.18, ly + d * 0.10, center.dx, ly)
      ..close();
    canvas.drawPath(leaf, _fill(spec.leafColor));
    canvas.drawPath(leaf, stroke);
  }

  void _paintRadial(Canvas canvas, Offset center, double d, Paint stroke,
      {required bool rounded}) {
    final Paint fill = _fill(spec.petalColor);
    final Paint shade = _fill(spec.petalShade);
    final double length = spec.petalLength * d;
    final double width = spec.petalWidth * d;
    final double tilt = spec.droop ? 0.35 : 0.0;
    final Path petal = _petal(length, width, rounded: rounded);
    for (int i = 0; i < spec.petalCount; i++) {
      final double angle = (2 * math.pi * i / spec.petalCount) + tilt;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      canvas.drawPath(petal, fill);
      canvas.drawPath(petal, stroke);
      canvas.restore();
    }
    if (rounded && spec.petalCount >= 8) {
      final Path inner = _petal(length * 0.6, width * 0.7, rounded: true);
      for (int i = 0; i < spec.petalCount; i++) {
        final double angle = (2 * math.pi * i / spec.petalCount) +
            (math.pi / spec.petalCount) +
            tilt;
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(angle);
        canvas.drawPath(inner, shade);
        canvas.drawPath(inner, stroke);
        canvas.restore();
      }
    }
    canvas.drawCircle(center, spec.centerRadius * d, _fill(spec.centerColor));
    canvas.drawCircle(center, spec.centerRadius * d, stroke);
  }

  void _paintSpider(Canvas canvas, Offset center, double d, Paint stroke) {
    final Paint fill = _fill(spec.petalColor);
    final double length = spec.petalLength * d;
    final double width = spec.petalWidth * d;
    for (int i = 0; i < spec.petalCount; i++) {
      final double angle = 2 * math.pi * i / spec.petalCount;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      final Path p = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(-width * 0.5, -length * 0.6, width * 0.2, -length)
        ..quadraticBezierTo(width * 0.9, -length * 0.7, 0, 0)
        ..close();
      canvas.drawPath(p, fill);
      canvas.drawPath(p, stroke);
      canvas.drawLine(
          Offset.zero, Offset(width * 0.2, -length * 1.15), stroke);
      canvas.restore();
    }
    canvas.drawCircle(center, spec.centerRadius * d, _fill(spec.centerColor));
    canvas.drawCircle(center, spec.centerRadius * d, stroke);
  }

  void _paintSpike(Canvas canvas, Offset center, double d, Paint stroke) {
    final Paint fill = _fill(spec.petalColor);
    final double top = center.dy - spec.petalLength * d;
    final double bottom = center.dy + spec.centerRadius * d;
    final int florets = spec.petalCount;
    for (int i = 0; i < florets; i++) {
      final double t = i / (florets - 1);
      final double y = top + (bottom - top) * t;
      final double spread = spec.petalWidth * d * (0.4 + 0.6 * t);
      final double side = (i.isEven ? -1 : 1) * spread;
      final Rect r = Rect.fromCenter(
        center: Offset(center.dx + side, y),
        width: spread * 0.9,
        height: spread * 1.3,
      );
      canvas.drawOval(r, fill);
      canvas.drawOval(r, stroke);
    }
  }

  void _paintPuff(Canvas canvas, Offset center, double d, Paint stroke) {
    final double r = spec.centerRadius * d;
    final Rect bulb = Rect.fromCenter(
      center: Offset(center.dx, center.dy + r * 1.2),
      width: r * 1.7,
      height: r * 2.1,
    );
    canvas.drawOval(bulb, _fill(spec.centerColor));
    canvas.drawOval(bulb, stroke);
    final Paint spike = Paint()
      ..color = spec.petalColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(Shapes.outlineWidth, d * 0.02)
      ..strokeCap = StrokeCap.round;
    final double len = spec.petalLength * d;
    final int n = spec.petalCount;
    for (int i = 0; i < n; i++) {
      final double angle = math.pi + (math.pi * i / (n - 1));
      final Offset tip =
          center + Offset(math.cos(angle), math.sin(angle)) * len;
      canvas.drawLine(center, tip, spike);
    }
  }

  void _paintHearts(Canvas canvas, Size size, double d, Paint stroke) {
    final Paint fill = _fill(spec.petalColor);
    final Paint drop = _fill(spec.centerColor);
    final double archY = size.height * 0.18;
    final Path stem = Path()
      ..moveTo(size.width * 0.20, size.height * 0.95)
      ..cubicTo(size.width * 0.14, size.height * 0.40, size.width * 0.50, archY,
          size.width * 0.85, archY + d * 0.05);
    canvas.drawPath(stem, _stemStroke(d));
    final int hearts = spec.petalCount;
    final double hs = spec.petalWidth * d;
    final double startX = size.width * 0.25;
    for (int i = 0; i < hearts; i++) {
      final double t = (i + 1) / (hearts + 1);
      final double hx = startX + (size.width * 0.55) * t;
      final double hy = archY + d * 0.14 + t * d * 0.10;
      final Path heart = _heart(Offset(hx, hy), hs);
      canvas.drawPath(heart, fill);
      canvas.drawPath(heart, stroke);
      final Path tear = Path()
        ..moveTo(hx, hy + hs * 0.60)
        ..lineTo(hx - hs * 0.12, hy + hs * 0.92)
        ..lineTo(hx + hs * 0.12, hy + hs * 0.92)
        ..close();
      canvas.drawPath(tear, drop);
      canvas.drawPath(tear, stroke);
    }
  }

  Path _heart(Offset c, double s) {
    final Path p = Path()..moveTo(c.dx, c.dy + s * 0.65);
    p.cubicTo(c.dx - s * 0.70, c.dy + s * 0.10, c.dx - s * 0.55, c.dy - s * 0.50,
        c.dx, c.dy - s * 0.10);
    p.cubicTo(c.dx + s * 0.55, c.dy - s * 0.50, c.dx + s * 0.70, c.dy + s * 0.10,
        c.dx, c.dy + s * 0.65);
    p.close();
    return p;
  }

  @override
  bool shouldRepaint(covariant FlowerPainter oldDelegate) =>
      oldDelegate.spec != spec || oldDelegate.headless != headless;
}
