import 'package:flutter/rendering.dart';

import 'bloom_part_painter.dart';
import 'garden_plant_spec.dart';

class GardenPlantPainter {
  const GardenPlantPainter(this.spec);

  final GardenPlantSpec spec;

  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    canvas.save();
    canvas.scale(size.width / GardenPlantSpec.viewBoxWidth);
    BloomPartPainter(
      strokeColor: spec.strokeColor,
      strokeWidth: spec.strokeWidth,
    ).paintAll(canvas, spec.parts);
    canvas.restore();
  }
}
