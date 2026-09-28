import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'package:field_notes/design/flowers/garden_plant_painter.dart';
import 'package:field_notes/design/flowers/garden_plant_spec.dart';
import 'package:field_notes/design/tokens/tokens.dart';

import '../model/garden_insect.dart';
import '../model/meadow_layout.dart';

class MeadowPainter extends CustomPainter {
  const MeadowPainter({
    required this.t,
    required this.planted,
    required this.insects,
    required this.showInsects,
  });

  final double t;
  final List<PlantedBloom> planted;
  final List<GardenInsect> insects;
  final bool showInsects;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    _paintSky(canvas, size);
    _paintSun(canvas, size);
    _paintSoil(canvas, size);
    for (final PlantedBloom bloom in planted) {
      _paintBloom(canvas, bloom);
    }
    if (showInsects) {
      for (final GardenInsect insect in insects) {
        _paintInsect(canvas, size, insect);
      }
    }
  }

  void _paintSky(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Palette.gardenSky,
          Palette.gardenMint,
          Palette.gardenDeep,
        ],
        stops: <double>[0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, sky);
  }

  void _paintSun(Canvas canvas, Size size) {
    final Offset center = Offset(size.width * 0.82, size.height * 0.18);
    final double radius = size.shortestSide * 0.30;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Paint glow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Palette.sunGlow,
          Palette.sunGlow.withValues(alpha: 0.0),
        ],
      ).createShader(rect);
    canvas.drawCircle(center, radius, glow);
  }

  void _paintSoil(Canvas canvas, Size size) {
    final double soilTop = size.height * soilLineFraction;
    final Rect rect = Rect.fromLTRB(0, soilTop, size.width, size.height);
    final Paint soil = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Palette.soilLight, Palette.soilDark],
      ).createShader(rect);
    final Path path = Path()
      ..moveTo(0, soilTop + 6)
      ..quadraticBezierTo(
        size.width * 0.5,
        soilTop - 8,
        size.width,
        soilTop + 6,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, soil);
  }

  void _paintBloom(Canvas canvas, PlantedBloom bloom) {
    final double sway =
        bloom.swayAmplitude * math.sin(2 * math.pi * t + bloom.swayPhase);
    if (bloom.isSprout) {
      final double height = bloom.size * sproutRatio;
      canvas.save();
      canvas.translate(bloom.dx, bloom.baseY);
      canvas.rotate(sway);
      canvas.translate(-bloom.size * 0.5, -height);
      const GardenSproutPainter().paint(canvas, Size(bloom.size, height));
      canvas.restore();
      return;
    }
    final GardenPlantSpec spec = gardenPlantSpecFor(bloom.kind);
    final double height = bloom.size * spec.ratio;
    canvas.save();
    canvas.translate(bloom.dx, bloom.baseY);
    canvas.rotate(sway);
    canvas.translate(-bloom.size * 0.5, -height);
    GardenPlantPainter(spec).paint(canvas, Size(bloom.size, height));
    canvas.restore();
  }

  void _paintInsect(Canvas canvas, Size size, GardenInsect insect) {
    final Offset p =
        insectOffset(insect, t, size, size.height * soilLineFraction);
    final double flap = math.sin(2 * math.pi * (t * 8 + insect.phase));
    switch (insect.kind) {
      case GardenInsectKind.butterfly:
        _paintButterfly(canvas, p, flap);
      case GardenInsectKind.bee:
        _paintBee(canvas, p, flap);
    }
  }

  Paint get _insectStroke => Paint()
    ..color = Palette.ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = Shapes.outlineWidth
    ..strokeCap = StrokeCap.round;

  void _paintButterfly(Canvas canvas, Offset c, double flap) {
    final double wingW = 5 + flap.abs() * 4;
    final Paint wing = Paint()
      ..color = Palette.coral
      ..style = PaintingStyle.fill;
    final Rect left = Rect.fromCenter(
      center: c.translate(-wingW * 0.6, 0),
      width: wingW,
      height: wingW * 1.5,
    );
    final Rect right = Rect.fromCenter(
      center: c.translate(wingW * 0.6, 0),
      width: wingW,
      height: wingW * 1.5,
    );
    canvas.drawOval(left, wing);
    canvas.drawOval(left, _insectStroke);
    canvas.drawOval(right, wing);
    canvas.drawOval(right, _insectStroke);
    canvas.drawLine(
      c.translate(0, -wingW * 0.7),
      c.translate(0, wingW * 0.7),
      _insectStroke,
    );
  }

  void _paintBee(Canvas canvas, Offset c, double flap) {
    final double wingW = 4 + flap.abs() * 3;
    final Rect body = Rect.fromCenter(center: c, width: 12, height: 8);
    final Paint bodyPaint = Paint()
      ..color = Palette.sage
      ..style = PaintingStyle.fill;
    canvas.drawOval(body, bodyPaint);
    canvas.drawOval(body, _insectStroke);
    final Rect wing = Rect.fromCenter(
      center: c.translate(0, -6),
      width: wingW * 2,
      height: wingW,
    );
    final Paint wingPaint = Paint()
      ..color = Palette.cardBright.withValues(alpha: 0.8);
    canvas.drawOval(wing, wingPaint);
    canvas.drawOval(wing, _insectStroke);
  }

  @override
  bool shouldRepaint(covariant MeadowPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.planted != planted ||
      oldDelegate.insects != insects ||
      oldDelegate.showInsects != showInsects;
}
