import 'bloom_part.dart';
import 'flower_palette.dart';

const List<BloomPart> peonyParts = <BloomPart>[
  BloomDisc(cx: 22, cy: 15, r: 8, fill: FlowerColors.peonyPetalLight),
  BloomDisc(cx: 14, cy: 22, r: 8, fill: FlowerColors.peonyPetalMid),
  BloomDisc(cx: 30, cy: 22, r: 8, fill: FlowerColors.peonyPetalMid),
  BloomDisc(cx: 18, cy: 29, r: 8, fill: FlowerColors.peonyPetalLight),
  BloomDisc(cx: 26, cy: 29, r: 8, fill: FlowerColors.peonyPetalLight),
  BloomDisc(cx: 22, cy: 23, r: 6.5, fill: FlowerColors.peonyCore),
];

const List<BloomPart> roseParts = <BloomPart>[
  BloomDisc(cx: 22, cy: 22, r: 14, fill: FlowerColors.roseDisc),
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(22, 10),
      BloomArcTo(rx: 12, ry: 12, largeArc: true, clockwise: true, x: 14, y: 31),
    ],
  ),
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(22, 14),
      BloomArcTo(rx: 8, ry: 8, largeArc: true, clockwise: true, x: 17, y: 28),
    ],
  ),
  BloomDisc(
    cx: 22,
    cy: 22,
    r: 3.5,
    fill: FlowerColors.roseCore,
    strokeWidth: 0,
  ),
];

const List<BloomPart> poppyParts = <BloomPart>[
  BloomDisc(cx: 22, cy: 13, r: 8, fill: FlowerColors.poppyLobe),
  BloomDisc(cx: 13, cy: 24, r: 8, fill: FlowerColors.poppyLobe),
  BloomDisc(cx: 31, cy: 24, r: 8, fill: FlowerColors.poppyLobe),
  BloomDisc(cx: 22, cy: 30, r: 8, fill: FlowerColors.poppyLobe),
  BloomDisc(cx: 22, cy: 22, r: 5, fill: FlowerColors.poppyCore),
];

const List<BloomPart> sunflowerParts = <BloomPart>[
  BloomOvalRing(
    count: 8,
    cx: 22,
    cy: 9,
    rx: 3.4,
    ry: 7,
    startDeg: 0,
    stepDeg: 45,
    pivotX: 22,
    pivotY: 22,
    fill: FlowerColors.sunflowerRay,
  ),
  BloomDisc(cx: 22, cy: 22, r: 7, fill: FlowerColors.sunflowerDisc),
];
