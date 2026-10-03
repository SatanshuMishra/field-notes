import 'dart:ui' as ui;

import 'package:field_notes/features/garden/scene/meadow_palette.dart';
import 'package:flutter/rendering.dart';

void meadowDrawUnit(
  Canvas canvas, {
  required Rect box,
  required Offset centre,
  required Size radii,
  required Paint paint,
}) {
  canvas
    ..save()
    ..translate(centre.dx, centre.dy)
    ..scale(radii.width, radii.height)
    ..drawRect(
      Rect.fromLTRB(
        (box.left - centre.dx) / radii.width,
        (box.top - centre.dy) / radii.height,
        (box.right - centre.dx) / radii.width,
        (box.bottom - centre.dy) / radii.height,
      ),
      paint,
    )
    ..restore();
}

ui.Gradient meadowOverlayShader(MeadowPalette palette) =>
    ui.Gradient.radial(Offset.zero, 1, <Color>[
      palette.overlayColour.withValues(alpha: palette.overlayCentreAlpha),
      palette.overlayColour.withValues(alpha: palette.overlayAlpha),
    ]);
