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

const List<BloomPart> chrysanthemumParts = <BloomPart>[
  BloomOvalRing(
    count: 12,
    cx: 22,
    cy: 7,
    rx: 2.2,
    ry: 8,
    startDeg: 0,
    stepDeg: 30,
    pivotX: 22,
    pivotY: 22,
    fill: FlowerColors.chrysanthemumOuter,
  ),
  BloomOvalRing(
    count: 9,
    cx: 22,
    cy: 12,
    rx: 2,
    ry: 6,
    startDeg: 20,
    stepDeg: 40,
    pivotX: 22,
    pivotY: 22,
    fill: FlowerColors.chrysanthemumInner,
  ),
  BloomDisc(
    cx: 22,
    cy: 22,
    r: 3,
    fill: FlowerColors.chrysanthemumCore,
    strokeWidth: 0,
  ),
];

const List<BloomPart> daffodilParts = <BloomPart>[
  BloomOvalRing(
    count: 6,
    cx: 22,
    cy: 9,
    rx: 4,
    ry: 8.5,
    startDeg: 0,
    stepDeg: 60,
    pivotX: 22,
    pivotY: 22,
    fill: FlowerColors.daffodilRay,
  ),
  BloomDisc(
    cx: 22,
    cy: 22,
    r: 7,
    fill: FlowerColors.daffodilCorona1,
    strokeColor: FlowerColors.daffodilCoronaStroke,
    strokeWidth: 1.3,
  ),
  BloomDisc(
    cx: 22,
    cy: 22,
    r: 4,
    fill: FlowerColors.daffodilCorona2,
    strokeWidth: 0,
  ),
  BloomDisc(
    cx: 22,
    cy: 22,
    r: 1.8,
    fill: FlowerColors.daffodilCorona3,
    strokeWidth: 0,
  ),
];

const List<BloomPart> lavenderParts = <BloomPart>[
  BloomOval(cx: 22, cy: 6, rx: 2.7, ry: 3.7, fill: FlowerColors.lavenderFloret),
  BloomOval(cx: 18, cy: 11, rx: 3, ry: 4, fill: FlowerColors.lavenderFloret),
  BloomOval(cx: 26, cy: 11, rx: 3, ry: 4, fill: FlowerColors.lavenderFloret),
  BloomOval(cx: 16, cy: 17, rx: 3.1, ry: 4.2, fill: FlowerColors.lavenderFloret),
  BloomOval(cx: 22, cy: 16, rx: 3.1, ry: 4.2, fill: FlowerColors.lavenderFloret),
  BloomOval(cx: 28, cy: 17, rx: 3.1, ry: 4.2, fill: FlowerColors.lavenderFloret),
  BloomOval(cx: 18, cy: 23, rx: 3, ry: 4, fill: FlowerColors.lavenderFloret),
  BloomOval(cx: 26, cy: 23, rx: 3, ry: 4, fill: FlowerColors.lavenderFloret),
  BloomOval(cx: 22, cy: 29, rx: 2.8, ry: 3.8, fill: FlowerColors.lavenderFloret),
];

const List<BloomPart> asterParts = <BloomPart>[
  BloomOvalRing(
    count: 12,
    cx: 22,
    cy: 8,
    rx: 2.3,
    ry: 7,
    startDeg: 0,
    stepDeg: 30,
    pivotX: 22,
    pivotY: 22,
    fill: FlowerColors.asterRay,
  ),
  BloomDisc(
    cx: 22,
    cy: 22,
    r: 5.5,
    fill: FlowerColors.asterDisc,
    strokeColor: FlowerColors.asterDiscStroke,
    strokeWidth: 1.2,
  ),
];

const List<BloomPart> bleedingHeartParts = <BloomPart>[
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(6, 9),
      BloomQuadTo(20, 4, 36, 11),
    ],
    strokeColor: FlowerColors.bleedingHeartArch,
    strokeWidth: 1.8,
  ),
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(13, 15),
      BloomCubicTo(11.5, 12, 8, 12.5, 8.7, 16),
      BloomCubicTo(9.3, 19, 13, 22.5, 13, 22.5),
      BloomCubicTo(13, 22.5, 16.7, 19, 17.3, 16),
      BloomCubicTo(18, 12.5, 14.5, 12, 13, 15),
    ],
    close: true,
    fill: FlowerColors.bleedingHeartLobe,
  ),
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(11.7, 21),
      BloomLineTo(13, 26),
      BloomLineTo(14.3, 21),
    ],
    close: true,
    fill: FlowerColors.bleedingHeartTear,
  ),
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(22, 18),
      BloomCubicTo(20.5, 15, 17, 15.5, 17.7, 19),
      BloomCubicTo(18.3, 22, 22, 25.5, 22, 25.5),
      BloomCubicTo(22, 25.5, 25.7, 22, 26.3, 19),
      BloomCubicTo(27, 15.5, 23.5, 15, 22, 18),
    ],
    close: true,
    fill: FlowerColors.bleedingHeartLobe,
  ),
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(20.7, 24),
      BloomLineTo(22, 29),
      BloomLineTo(23.3, 24),
    ],
    close: true,
    fill: FlowerColors.bleedingHeartTear,
  ),
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(31, 15),
      BloomCubicTo(29.5, 12, 26, 12.5, 26.7, 16),
      BloomCubicTo(27.3, 19, 31, 22.5, 31, 22.5),
      BloomCubicTo(31, 22.5, 34.7, 19, 35.3, 16),
      BloomCubicTo(36, 12.5, 32.5, 12, 31, 15),
    ],
    close: true,
    fill: FlowerColors.bleedingHeartLobe,
  ),
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(29.7, 21),
      BloomLineTo(31, 26),
      BloomLineTo(32.3, 21),
    ],
    close: true,
    fill: FlowerColors.bleedingHeartTear,
  ),
];

const List<BloomPart> redSpiderLilyParts = <BloomPart>[
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(22, 23),
      BloomQuadTo(30, 14, 26, 6),
    ],
  ),
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(22, 23),
      BloomQuadTo(34, 18, 34, 9),
    ],
  ),
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(22, 23),
      BloomQuadTo(37, 24, 40, 18),
    ],
  ),
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(22, 23),
      BloomQuadTo(14, 14, 18, 6),
    ],
  ),
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(22, 23),
      BloomQuadTo(10, 18, 10, 9),
    ],
  ),
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(22, 23),
      BloomQuadTo(7, 24, 4, 18),
    ],
  ),
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(22, 23),
      BloomQuadTo(25, 9, 21, 3),
    ],
    strokeColor: FlowerColors.spiderLilyStamen,
    strokeWidth: 1,
  ),
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(22, 23),
      BloomQuadTo(19, 9, 23, 3),
    ],
    strokeColor: FlowerColors.spiderLilyStamen,
    strokeWidth: 1,
  ),
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(22, 23),
      BloomQuadTo(38, 13, 42, 7),
    ],
    strokeColor: FlowerColors.spiderLilyStamen,
    strokeWidth: 1,
  ),
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(22, 23),
      BloomQuadTo(6, 13, 2, 7),
    ],
    strokeColor: FlowerColors.spiderLilyStamen,
    strokeWidth: 1,
  ),
  BloomDisc(
    cx: 22,
    cy: 23,
    r: 2.4,
    fill: FlowerColors.spiderLilyCore,
    strokeWidth: 0,
  ),
];
