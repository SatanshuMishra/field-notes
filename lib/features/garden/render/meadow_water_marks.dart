import 'dart:ui';

import 'package:field_notes/features/garden/render/meadow_layers.dart';

class MeadowWaterMark {
  const MeadowWaterMark({
    required this.oval,
    required this.colour,
    required this.opacity,
    this.stroke,
  });

  final Rect oval;
  final Color colour;
  final double opacity;
  final double? stroke;

  Color get shade => colour.withValues(alpha: colour.a * opacity);

  Rect get bounds {
    final double? width = stroke;
    return width == null ? oval : oval.inflate(width / 2);
  }
}

void paintMeadowWaterMarks(
  Canvas canvas, {
  required List<MeadowWaterMark> marks,
  required MeadowLayers layers,
}) {
  final List<MeadowImage> water = layers.water;
  if (marks.isEmpty || water.isEmpty) {
    return;
  }
  canvas.saveLayer(
    water
        .map((MeadowImage tile) => tile.rect)
        .reduce((Rect a, Rect b) => a.expandToInclude(b)),
    Paint(),
  );
  for (final MeadowWaterMark mark in marks) {
    final double? stroke = mark.stroke;
    canvas.drawOval(
      mark.oval,
      Paint()
        ..color = mark.shade
        ..style = stroke == null ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = stroke ?? 0,
    );
  }
  layers.maskToWater(canvas);
  canvas.restore();
}
