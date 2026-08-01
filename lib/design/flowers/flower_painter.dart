import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'package:field_notes/design/tokens/tokens.dart';

import 'bloom_part.dart';
import 'bloom_part_painter.dart';
import 'bloom_style.dart';
import 'flower_spec.dart';

class FlowerPainter extends CustomPainter {
  const FlowerPainter(this.spec);

  static const double viewBox = 44;

  final FlowerSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    final double d = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - d) / 2, (size.height - d) / 2);
    canvas.clipRect(Rect.fromLTWH(0, 0, d, d));
    canvas.scale(d / viewBox);
    _paintBloom(canvas);
    canvas.restore();
  }

  void _paintBloom(Canvas canvas) {
    final List<BloomPart>? parts = spec.parts;
    if (parts != null) {
      BloomPartPainter(
        strokeColor: spec.strokeColor,
        strokeWidth: spec.strokeWidth,
      ).paintAll(canvas, parts);
      return;
    }
    _paintProcedural(canvas, spec.procedural!);
  }

  void _paintProcedural(Canvas canvas, ProceduralBloom bloom) {
    const Offset center = Offset(viewBox / 2, viewBox / 2);
    final Paint stroke = _stroke;
    switch (spec.style) {
      case BloomStyle.partList:
      case BloomStyle.heartPendants:
        return;
      case BloomStyle.roundPetals:
      case BloomStyle.broadPetals:
        _paintRadial(canvas, bloom, center, stroke, rounded: true);
      case BloomStyle.rayPetals:
        _paintRadial(canvas, bloom, center, stroke, rounded: false);
      case BloomStyle.spiderPetals:
        _paintSpider(canvas, bloom, center, stroke);
      case BloomStyle.spike:
        _paintSpike(canvas, bloom, center, stroke);
      case BloomStyle.puff:
        _paintPuff(canvas, bloom, center, stroke);
    }
  }

  Paint get _stroke => Paint()
    ..color = spec.strokeColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = spec.strokeWidth
    ..strokeJoin = StrokeJoin.round
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

  void _paintRadial(
      Canvas canvas, ProceduralBloom bloom, Offset center, Paint stroke,
      {required bool rounded}) {
    final Paint fill = _fill(bloom.petalColor);
    final Paint shade = _fill(bloom.petalShade);
    final double length = bloom.petalLength * viewBox;
    final double width = bloom.petalWidth * viewBox;
    final double tilt = bloom.droop ? 0.35 : 0.0;
    final Path petal = _petal(length, width, rounded: rounded);
    for (int i = 0; i < bloom.petalCount; i++) {
      final double angle = (2 * math.pi * i / bloom.petalCount) + tilt;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      canvas.drawPath(petal, fill);
      canvas.drawPath(petal, stroke);
      canvas.restore();
    }
    if (rounded && bloom.petalCount >= 8) {
      final Path inner = _petal(length * 0.6, width * 0.7, rounded: true);
      for (int i = 0; i < bloom.petalCount; i++) {
        final double angle = (2 * math.pi * i / bloom.petalCount) +
            (math.pi / bloom.petalCount) +
            tilt;
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(angle);
        canvas.drawPath(inner, shade);
        canvas.drawPath(inner, stroke);
        canvas.restore();
      }
    }
    canvas.drawCircle(
        center, bloom.centerRadius * viewBox, _fill(bloom.centerColor));
    canvas.drawCircle(center, bloom.centerRadius * viewBox, stroke);
  }

  void _paintSpider(
      Canvas canvas, ProceduralBloom bloom, Offset center, Paint stroke) {
    final Paint fill = _fill(bloom.petalColor);
    final double length = bloom.petalLength * viewBox;
    final double width = bloom.petalWidth * viewBox;
    for (int i = 0; i < bloom.petalCount; i++) {
      final double angle = 2 * math.pi * i / bloom.petalCount;
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
    canvas.drawCircle(
        center, bloom.centerRadius * viewBox, _fill(bloom.centerColor));
    canvas.drawCircle(center, bloom.centerRadius * viewBox, stroke);
  }

  void _paintSpike(
      Canvas canvas, ProceduralBloom bloom, Offset center, Paint stroke) {
    final Paint fill = _fill(bloom.petalColor);
    final double top = center.dy - bloom.petalLength * viewBox;
    final double bottom = center.dy + bloom.centerRadius * viewBox;
    final int florets = bloom.petalCount;
    for (int i = 0; i < florets; i++) {
      final double t = i / (florets - 1);
      final double y = top + (bottom - top) * t;
      final double spread = bloom.petalWidth * viewBox * (0.4 + 0.6 * t);
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

  void _paintPuff(
      Canvas canvas, ProceduralBloom bloom, Offset center, Paint stroke) {
    final double r = bloom.centerRadius * viewBox;
    final Rect bulb = Rect.fromCenter(
      center: Offset(center.dx, center.dy + r * 1.2),
      width: r * 1.7,
      height: r * 2.1,
    );
    canvas.drawOval(bulb, _fill(bloom.centerColor));
    canvas.drawOval(bulb, stroke);
    final Paint spike = Paint()
      ..color = bloom.petalColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(Shapes.outlineWidth, viewBox * 0.02)
      ..strokeCap = StrokeCap.round;
    final double len = bloom.petalLength * viewBox;
    final int n = bloom.petalCount;
    for (int i = 0; i < n; i++) {
      final double angle = math.pi + (math.pi * i / (n - 1));
      final Offset tip =
          center + Offset(math.cos(angle), math.sin(angle)) * len;
      canvas.drawLine(center, tip, spike);
    }
  }

  @override
  bool shouldRepaint(covariant FlowerPainter oldDelegate) =>
      oldDelegate.spec != spec;
}
