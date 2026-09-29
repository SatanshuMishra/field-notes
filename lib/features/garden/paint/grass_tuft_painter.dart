import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'package:field_notes/design/flowers/garden_art_colors.dart';

const double grassTuftViewBox = 60;
const double grassTuftRatio = 0.9;

const double _baseX = 30;
const double _baseY = 54;

const List<(double, double)> _blades = <(double, double)>[
  (-36, 42),
  (-22, 50),
  (-9, 55),
  (5, 54),
  (19, 49),
  (32, 41),
];

const List<(Color, Color)> grassTuftColours = <(Color, Color)>[
  (GardenArtColors.grassMeadow, GardenArtColors.grassMeadowShade),
  (GardenArtColors.grassBright, GardenArtColors.grassBrightShade),
  (GardenArtColors.grassDry, GardenArtColors.grassDryShade),
];

Path _bladePath(double degrees, double length) {
  final double radians = (degrees - 90) * math.pi / 180;
  final double dx = math.cos(radians);
  final double dy = math.sin(radians);
  return Path()
    ..moveTo(_baseX, _baseY)
    ..quadraticBezierTo(
      _baseX + dx * length * 0.5 + degrees * 0.12,
      _baseY + dy * length * 0.5,
      _baseX + dx * length,
      _baseY + dy * length,
    );
}

final List<Path> _bladePaths = List<Path>.unmodifiable(<Path>[
  for (final (double, double) blade in _blades) _bladePath(blade.$1, blade.$2),
]);

class GrassTuftPainter {
  const GrassTuftPainter(this.variant);

  final int variant;

  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final double scale = math.min(
      size.width / grassTuftViewBox,
      size.height / grassTuftViewBox,
    );
    final (Color, Color) colours =
        grassTuftColours[variant % grassTuftColours.length];
    canvas.save();
    canvas.translate(
      (size.width - grassTuftViewBox * scale) / 2,
      size.height - grassTuftViewBox * scale,
    );
    canvas.scale(scale);
    for (int i = 0; i < _blades.length; i++) {
      canvas.drawPath(
        _bladePaths[i],
        Paint()
          ..color = i.isOdd ? colours.$2 : colours.$1
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2 - _blades[i].$1.abs() * 0.02
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );
    }
    canvas.restore();
  }
}
