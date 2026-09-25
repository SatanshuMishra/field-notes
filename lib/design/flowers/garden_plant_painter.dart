import 'package:flutter/rendering.dart';

import 'bloom_part.dart';
import 'bloom_part_painter.dart';
import 'flower_palette.dart';
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

const double sproutViewBoxHeight = 120;

const double sproutRatio = sproutViewBoxHeight / GardenPlantSpec.viewBoxWidth;

const List<BloomPart> sproutPlantParts = <BloomPart>[
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(50, 120),
      BloomCubicTo(49, 100, 51, 82, 50, 62),
    ],
    strokeColor: FlowerColors.gardenStemDeep,
    strokeWidth: 5,
  ),
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(50, 66),
      BloomCubicTo(40, 44, 20, 38, 8, 44),
      BloomCubicTo(16, 64, 36, 72, 50, 66),
    ],
    close: true,
    fill: FlowerColors.gardenLeafBright,
    strokeColor: FlowerColors.gardenLeafStroke,
    strokeWidth: 3,
  ),
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(50, 62),
      BloomCubicTo(58, 36, 78, 26, 94, 32),
      BloomCubicTo(86, 54, 66, 66, 50, 62),
    ],
    close: true,
    fill: FlowerColors.gardenLeafDeep,
    strokeColor: FlowerColors.gardenLeafStroke,
    strokeWidth: 3,
  ),
];

class GardenSproutPainter {
  const GardenSproutPainter();

  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    canvas.save();
    canvas.scale(size.width / GardenPlantSpec.viewBoxWidth);
    const BloomPartPainter(
      strokeColor: FlowerColors.gardenLeafStroke,
      strokeWidth: 3,
    ).paintAll(canvas, sproutPlantParts);
    canvas.restore();
  }
}
