import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'bloom_part.dart';
import 'flower_palette.dart';

BloomShape _path(
  List<BloomCmd> commands, {
  required Color stroke,
  required double width,
  Color? fill,
  bool close = false,
}) =>
    BloomShape(
      commands: commands,
      close: close,
      fill: fill,
      strokeColor: stroke,
      strokeWidth: width,
    );

BloomShape _solid(List<BloomCmd> commands, Color fill) =>
    BloomShape(commands: commands, close: true, fill: fill, strokeWidth: 0);

List<BloomCmd> _rotated(
  List<BloomCmd> commands,
  double degrees,
  double pivotX,
  double pivotY,
) {
  final double rad = degrees * math.pi / 180;
  final double cos = math.cos(rad);
  final double sin = math.sin(rad);
  double rx(double x, double y) =>
      pivotX + (x - pivotX) * cos - (y - pivotY) * sin;
  double ry(double x, double y) =>
      pivotY + (x - pivotX) * sin + (y - pivotY) * cos;
  return <BloomCmd>[
    for (final BloomCmd cmd in commands)
      switch (cmd) {
        BloomMoveTo() => BloomMoveTo(rx(cmd.x, cmd.y), ry(cmd.x, cmd.y)),
        BloomLineTo() => BloomLineTo(rx(cmd.x, cmd.y), ry(cmd.x, cmd.y)),
        BloomQuadTo() => BloomQuadTo(rx(cmd.cx, cmd.cy), ry(cmd.cx, cmd.cy),
            rx(cmd.x, cmd.y), ry(cmd.x, cmd.y)),
        BloomCubicTo() => BloomCubicTo(
            rx(cmd.c1x, cmd.c1y),
            ry(cmd.c1x, cmd.c1y),
            rx(cmd.c2x, cmd.c2y),
            ry(cmd.c2x, cmd.c2y),
            rx(cmd.x, cmd.y),
            ry(cmd.x, cmd.y)),
        BloomArcTo() => BloomArcTo(
            rx: cmd.rx,
            ry: cmd.ry,
            largeArc: cmd.largeArc,
            clockwise: cmd.clockwise,
            x: rx(cmd.x, cmd.y),
            y: ry(cmd.x, cmd.y)),
      },
  ];
}

const List<List<double>> _sunflowerSeeds = <List<double>>[
  <double>[50, 50],
  <double>[44, 53],
  <double>[56, 53],
  <double>[47, 59],
  <double>[53, 59],
  <double>[50, 56],
  <double>[42, 57],
  <double>[58, 57],
  <double>[50, 63],
  <double>[45, 63],
  <double>[55, 63],
];

final List<BloomPart> sunflowerPlantParts = <BloomPart>[
  _path(const <BloomCmd>[
    BloomMoveTo(50, 240),
    BloomCubicTo(48, 182, 54, 120, 50, 86),
  ], stroke: FlowerColors.gardenStemDeep, width: 5.4),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 152),
    BloomCubicTo(26, 140, 9, 150, 10, 172),
    BloomCubicTo(21, 177, 23, 188, 34, 181),
    BloomCubicTo(41, 190, 51, 182, 50, 152),
  ],
      fill: FlowerColors.gardenLeafDeep,
      stroke: FlowerColors.gardenLeafStroke,
      width: 2.3,
      close: true),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 152),
    BloomQuadTo(28, 162, 13, 170),
  ], stroke: FlowerColors.gardenLeafStroke, width: 1.3),
  _path(const <BloomCmd>[
    BloomMoveTo(52, 118),
    BloomCubicTo(76, 108, 92, 120, 90, 142),
    BloomCubicTo(79, 146, 78, 157, 67, 151),
    BloomCubicTo(61, 159, 50, 150, 52, 118),
  ],
      fill: FlowerColors.gardenLeafBright,
      stroke: FlowerColors.gardenLeafStroke,
      width: 2.3,
      close: true),
  _path(const <BloomCmd>[
    BloomMoveTo(52, 118),
    BloomQuadTo(72, 128, 86, 138),
  ], stroke: FlowerColors.gardenLeafStroke, width: 1.3),
  const BloomOvalRing(
    count: 15,
    cx: 50,
    cy: 30,
    rx: 5,
    ry: 13.5,
    stepDeg: 24,
    pivotX: 50,
    pivotY: 56,
    fill: FlowerColors.sunflowerRay,
  ),
  const BloomDisc(cx: 50, cy: 56, r: 17, fill: FlowerColors.sunflowerDisc),
  for (final List<double> seed in _sunflowerSeeds)
    BloomDisc(
      cx: seed[0],
      cy: seed[1],
      r: 1.5,
      fill: FlowerColors.sunflowerSeed,
      strokeWidth: 0,
    ),
];

List<BloomPart> _asterDaisy(
  double cx,
  double cy,
  double petalLength,
  double discRadius,
) {
  final double petalCy = cy - discRadius - petalLength * 0.55;
  BloomOvalRing half(double startDeg, Color fill) => BloomOvalRing(
        count: 8,
        cx: cx,
        cy: petalCy,
        rx: 1.9,
        ry: petalLength,
        startDeg: startDeg,
        stepDeg: 45,
        pivotX: cx,
        pivotY: cy,
        fill: fill,
        strokeColor: FlowerColors.asterStroke,
        strokeWidth: 0.9,
      );
  return <BloomPart>[
    half(0, FlowerColors.asterRayPale),
    half(22.5, FlowerColors.asterRay),
    BloomDisc(
      cx: cx,
      cy: cy,
      r: discRadius,
      fill: FlowerColors.asterDisc,
      strokeColor: FlowerColors.asterDiscStroke,
      strokeWidth: 1.2,
    ),
  ];
}

final List<BloomPart> asterPlantParts = <BloomPart>[
  _path(const <BloomCmd>[
    BloomMoveTo(50, 210),
    BloomCubicTo(47, 168, 52, 122, 50, 60),
  ], stroke: FlowerColors.gardenStemDeep, width: 3.4),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 150),
    BloomCubicTo(34, 138, 27, 120, 30, 96),
  ], stroke: FlowerColors.gardenStemMid, width: 2.5),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 138),
    BloomCubicTo(66, 128, 74, 112, 72, 88),
  ], stroke: FlowerColors.gardenStemMid, width: 2.5),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 168),
    BloomQuadTo(35, 164, 27, 153),
  ], stroke: FlowerColors.gardenLeafStroke, width: 1.5),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 128),
    BloomQuadTo(64, 123, 71, 113),
  ], stroke: FlowerColors.gardenLeafStroke, width: 1.5),
  _path(const <BloomCmd>[
    BloomMoveTo(44, 156),
    BloomLineTo(27, 150),
    BloomLineTo(32, 158),
  ],
      fill: FlowerColors.gardenLeafDeep,
      stroke: FlowerColors.gardenLeafStroke,
      width: 1.4,
      close: true),
  _path(const <BloomCmd>[
    BloomMoveTo(56, 144),
    BloomLineTo(73, 138),
    BloomLineTo(68, 146),
  ],
      fill: FlowerColors.gardenLeafBright,
      stroke: FlowerColors.gardenLeafStroke,
      width: 1.4,
      close: true),
  ..._asterDaisy(30, 90, 8.5, 4.4),
  ..._asterDaisy(72, 84, 8.5, 4.4),
  ..._asterDaisy(50, 54, 11, 5.5),
];

const List<List<double>> _bleedingHeartPendants = <List<double>>[
  <double>[45, 82],
  <double>[56, 74],
  <double>[66, 71],
  <double>[76, 73],
  <double>[85, 80],
];

List<BloomPart> _pendantHeart(double cx, double cy, double s) {
  double px(double a) => cx + a * s;
  double py(double b) => cy + b * s;
  return <BloomPart>[
    _path(<BloomCmd>[
      BloomMoveTo(px(0), py(0.3)),
      BloomCubicTo(px(-0.05), py(0), px(-0.62), py(-0.05), px(-0.62), py(0.34)),
      BloomCubicTo(px(-0.62), py(0.68), px(-0.18), py(0.88), px(0), py(1.16)),
      BloomCubicTo(px(0.18), py(0.88), px(0.62), py(0.68), px(0.62), py(0.34)),
      BloomCubicTo(px(0.62), py(-0.05), px(0.05), py(0), px(0), py(0.3)),
    ],
        fill: FlowerColors.bleedingHeartLobe,
        stroke: FlowerColors.bleedingHeartStroke,
        width: 1.6,
        close: true),
    _path(<BloomCmd>[
      BloomMoveTo(px(-0.13), py(1.02)),
      BloomLineTo(px(0), py(1.5)),
      BloomLineTo(px(0.13), py(1.02)),
    ],
        fill: FlowerColors.bleedingHeartTear,
        stroke: FlowerColors.bleedingHeartTearStroke,
        width: 1,
        close: true),
  ];
}

final List<BloomPart> bleedingHeartPlantParts = <BloomPart>[
  _path(const <BloomCmd>[
    BloomMoveTo(30, 200),
    BloomCubicTo(26, 150, 28, 100, 42, 76),
    BloomCubicTo(55, 55, 74, 52, 90, 60),
  ], stroke: FlowerColors.gardenStemDeep, width: 3.4),
  _path(const <BloomCmd>[
    BloomMoveTo(32, 152),
    BloomCubicTo(16, 152, 6, 160, 4, 172),
    BloomCubicTo(14, 172, 14, 180, 22, 174),
    BloomCubicTo(26, 180, 34, 172, 32, 152),
  ],
      fill: FlowerColors.gardenLeafSoft,
      stroke: FlowerColors.gardenLeafStroke,
      width: 1.7,
      close: true),
  _path(const <BloomCmd>[
    BloomMoveTo(34, 124),
    BloomCubicTo(20, 122, 12, 128, 9, 139),
    BloomCubicTo(18, 141, 17, 149, 25, 144),
    BloomCubicTo(30, 149, 38, 140, 34, 124),
  ],
      fill: FlowerColors.gardenLeafMist,
      stroke: FlowerColors.gardenLeafStroke,
      width: 1.7,
      close: true),
  for (final List<double> p in _bleedingHeartPendants)
    _path(<BloomCmd>[
      BloomMoveTo(p[0], p[1]),
      BloomQuadTo(p[0], p[1] + 6, p[0], p[1] + 9),
    ], stroke: FlowerColors.gardenStemMid, width: 1.6),
  for (final List<double> p in _bleedingHeartPendants)
    ..._pendantHeart(p[0], p[1] + 9, 8),
];

List<BloomPart> _spiderLilyBloom() {
  const double cx = 50;
  const double cy = 60;
  const int count = 6;
  final List<BloomPart> petals = <BloomPart>[];
  final List<BloomPart> stamens = <BloomPart>[];
  for (int i = 0; i < count; i++) {
    final double a = (i * 360 / count - 90) * math.pi / 180;
    final double dx = math.cos(a);
    final double dy = math.sin(a);
    final double ex = cx + dx * 24;
    final double ey = cy + dy * 24;
    petals.add(_path(<BloomCmd>[
      const BloomMoveTo(cx, cy),
      BloomQuadTo(cx + dx * 14 - dy * 8, cy + dy * 14 + dx * 8, ex, ey),
      BloomQuadTo(ex - dy * 4, ey + dx * 4, ex - dy * 7, ey + dx * 7),
    ], stroke: FlowerColors.spiderLilyStroke, width: 2.6));
    final double sx = cx + dx * 30;
    final double sy = cy + dy * 30 - 18;
    stamens.add(_path(<BloomCmd>[
      const BloomMoveTo(cx, cy),
      BloomQuadTo(cx + dx * 20 - dy * 4, cy + dy * 16 - 6, sx, sy),
    ], stroke: FlowerColors.spiderLilyStamenDeep, width: 1.2));
    stamens.add(BloomDisc(
      cx: sx,
      cy: sy,
      r: 1.7,
      fill: FlowerColors.spiderLilyCore,
      strokeWidth: 0,
    ));
  }
  return <BloomPart>[...petals, ...stamens];
}

final List<BloomPart> spiderLilyPlantParts = <BloomPart>[
  _path(const <BloomCmd>[
    BloomMoveTo(50, 214),
    BloomCubicTo(49, 164, 51, 112, 50, 66),
  ], stroke: FlowerColors.gardenScape, width: 3.2),
  ..._spiderLilyBloom(),
  const BloomDisc(
    cx: 50,
    cy: 60,
    r: 3.6,
    fill: FlowerColors.spiderLilyStamen,
    strokeWidth: 0,
  ),
];

final List<BloomPart> daffodilPlantParts = <BloomPart>[
  _path(const <BloomCmd>[
    BloomMoveTo(50, 214),
    BloomCubicTo(48, 162, 52, 110, 50, 66),
  ], stroke: FlowerColors.gardenStemDeep, width: 3.8),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 212),
    BloomCubicTo(40, 170, 36, 122, 41, 84),
    BloomCubicTo(47, 124, 49, 170, 50, 212),
  ],
      fill: FlowerColors.gardenLeafPale,
      stroke: FlowerColors.gardenLeafStroke,
      width: 1.6,
      close: true),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 212),
    BloomCubicTo(60, 172, 64, 126, 59, 90),
    BloomCubicTo(53, 128, 51, 172, 50, 212),
  ],
      fill: FlowerColors.gardenLeafBright,
      stroke: FlowerColors.gardenLeafStroke,
      width: 1.6,
      close: true),
  const BloomOvalRing(
    count: 6,
    cx: 50,
    cy: 43,
    rx: 7,
    ry: 14,
    stepDeg: 60,
    pivotX: 50,
    pivotY: 60,
    fill: FlowerColors.daffodilRay,
  ),
  const BloomDisc(
    cx: 50,
    cy: 60,
    r: 11,
    fill: FlowerColors.daffodilCorona1,
    strokeColor: FlowerColors.daffodilCoronaStroke,
    strokeWidth: 1.8,
  ),
  const BloomDisc(
    cx: 50,
    cy: 60,
    r: 6.5,
    fill: FlowerColors.daffodilCorona2,
    strokeColor: FlowerColors.daffodilCoronaStroke,
    strokeWidth: 1.3,
  ),
  const BloomDisc(
    cx: 50,
    cy: 60,
    r: 2.6,
    fill: FlowerColors.daffodilCorona3,
    strokeWidth: 0,
  ),
];

final List<BloomPart> chrysanthemumPlantParts = <BloomPart>[
  _path(const <BloomCmd>[
    BloomMoveTo(50, 196),
    BloomCubicTo(47, 152, 53, 112, 50, 88),
  ], stroke: FlowerColors.gardenStemDeep, width: 4.2),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 152),
    BloomCubicTo(34, 152, 22, 145, 13, 154),
    BloomCubicTo(22, 158, 21, 166, 30, 163),
    BloomCubicTo(31, 170, 40, 167, 43, 160),
    BloomCubicTo(48, 163, 53, 156, 50, 152),
  ],
      fill: FlowerColors.gardenLeafDeep,
      stroke: FlowerColors.gardenLeafStroke,
      width: 2,
      close: true),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 130),
    BloomCubicTo(66, 130, 78, 123, 87, 132),
    BloomCubicTo(78, 136, 79, 144, 70, 141),
    BloomCubicTo(69, 148, 60, 145, 57, 138),
    BloomCubicTo(52, 141, 47, 134, 50, 130),
  ],
      fill: FlowerColors.gardenLeafBright,
      stroke: FlowerColors.gardenLeafStroke,
      width: 2,
      close: true),
  const BloomOvalRing(
    count: 18,
    cx: 50,
    cy: 42,
    rx: 2.5,
    ry: 12,
    stepDeg: 20,
    pivotX: 50,
    pivotY: 64,
    fill: FlowerColors.chrysanthemumOuter,
  ),
  const BloomOvalRing(
    count: 15,
    cx: 50,
    cy: 48,
    rx: 2.5,
    ry: 10,
    startDeg: 11,
    stepDeg: 24,
    pivotX: 50,
    pivotY: 64,
    fill: FlowerColors.chrysanthemumMid,
  ),
  const BloomOvalRing(
    count: 12,
    cx: 50,
    cy: 53,
    rx: 2.5,
    ry: 7.5,
    stepDeg: 30,
    pivotX: 50,
    pivotY: 64,
    fill: FlowerColors.chrysanthemumInner,
  ),
  const BloomOvalRing(
    count: 9,
    cx: 50,
    cy: 58,
    rx: 2.5,
    ry: 5,
    startDeg: 11,
    stepDeg: 40,
    pivotX: 50,
    pivotY: 64,
    fill: FlowerColors.chrysanthemumPale,
  ),
  const BloomDisc(
    cx: 50,
    cy: 64,
    r: 3.4,
    fill: FlowerColors.chrysanthemumCore,
    strokeWidth: 0,
  ),
];

final List<BloomPart> rosePlantParts = <BloomPart>[
  _path(const <BloomCmd>[
    BloomMoveTo(50, 205),
    BloomCubicTo(47, 165, 53, 128, 50, 98),
  ], stroke: FlowerColors.gardenStemDeep, width: 4),
  _solid(const <BloomCmd>[
    BloomMoveTo(49, 150),
    BloomLineTo(40, 146),
    BloomLineTo(46, 153),
  ], FlowerColors.gardenStemDeep),
  _solid(const <BloomCmd>[
    BloomMoveTo(51, 128),
    BloomLineTo(60, 124),
    BloomLineTo(54, 131),
  ], FlowerColors.gardenStemDeep),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 146),
    BloomQuadTo(35, 149, 21, 145),
  ], stroke: FlowerColors.gardenLeafStroke, width: 1.9),
  _path(const <BloomCmd>[
    BloomMoveTo(36, 145),
    BloomCubicTo(32, 138, 24, 138, 21, 145),
    BloomCubicTo(25, 151, 32, 151, 36, 145),
  ],
      fill: FlowerColors.gardenLeafDeep,
      stroke: FlowerColors.gardenLeafStroke,
      width: 1.9,
      close: true),
  _path(const <BloomCmd>[
    BloomMoveTo(24, 146),
    BloomCubicTo(20, 139, 12, 139, 9, 146),
    BloomCubicTo(13, 152, 20, 152, 24, 146),
  ],
      fill: FlowerColors.gardenLeafBright,
      stroke: FlowerColors.gardenLeafStroke,
      width: 1.9,
      close: true),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 130),
    BloomQuadTo(65, 133, 79, 129),
  ], stroke: FlowerColors.gardenLeafStroke, width: 1.9),
  _path(const <BloomCmd>[
    BloomMoveTo(64, 129),
    BloomCubicTo(68, 122, 76, 122, 79, 129),
    BloomCubicTo(75, 135, 68, 135, 64, 129),
  ],
      fill: FlowerColors.gardenLeafBright,
      stroke: FlowerColors.gardenLeafStroke,
      width: 1.9,
      close: true),
  const BloomDisc(cx: 50, cy: 74, r: 16, fill: FlowerColors.roseDisc),
  const BloomShape(commands: <BloomCmd>[
    BloomMoveTo(50, 60),
    BloomArcTo(
        rx: 13.5, ry: 13.5, largeArc: true, clockwise: true, x: 41, y: 84),
  ]),
  const BloomShape(commands: <BloomCmd>[
    BloomMoveTo(50, 65),
    BloomArcTo(rx: 9, ry: 9, largeArc: true, clockwise: true, x: 44, y: 81),
  ]),
  const BloomDisc(
    cx: 50,
    cy: 74,
    r: 4,
    fill: FlowerColors.roseCore,
    strokeWidth: 0,
  ),
  _path(const <BloomCmd>[
    BloomMoveTo(38, 88),
    BloomQuadTo(33, 95, 36, 101),
  ], stroke: FlowerColors.gardenStemDeep, width: 2),
  _path(const <BloomCmd>[
    BloomMoveTo(62, 88),
    BloomQuadTo(67, 95, 64, 101),
  ], stroke: FlowerColors.gardenStemDeep, width: 2),
];

const List<List<double>> _lavenderTips = <List<double>>[
  <double>[30, 72],
  <double>[40, 56],
  <double>[50, 48],
  <double>[60, 56],
  <double>[70, 72],
];

List<BloomPart> _lavenderSpikes() {
  final List<BloomPart> stems = <BloomPart>[];
  final List<BloomPart> florets = <BloomPart>[];
  for (int i = 0; i < _lavenderTips.length; i++) {
    final double tipX = _lavenderTips[i][0];
    final double tipY = _lavenderTips[i][1];
    final double baseX = 50 + (tipX - 50) * 0.12;
    stems.add(_path(<BloomCmd>[
      BloomMoveTo(baseX, 185),
      BloomQuadTo(
          (baseX + tipX) / 2 + (i - 2) * 3, (185 + tipY) / 2, tipX, tipY),
    ], stroke: FlowerColors.gardenStemMid, width: 2.6));
    for (int k = 0; k < 6; k++) {
      florets.add(BloomOval(
        cx: tipX + (k.isOdd ? 0.8 : -0.8),
        cy: tipY - k * 6.2,
        rx: 3.1,
        ry: 4.2,
        fill: k.isOdd
            ? FlowerColors.lavenderFloret
            : FlowerColors.lavenderFloretDeep,
        strokeColor: FlowerColors.lavenderStroke,
        strokeWidth: 1,
      ));
    }
  }
  return <BloomPart>[...stems, ...florets];
}

final List<BloomPart> lavenderPlantParts = <BloomPart>[
  _path(const <BloomCmd>[
    BloomMoveTo(50, 188),
    BloomCubicTo(40, 178, 34, 166, 34, 150),
    BloomCubicTo(42, 160, 48, 172, 50, 188),
  ],
      fill: FlowerColors.gardenLeafBright,
      stroke: FlowerColors.gardenLeafStroke,
      width: 1.7,
      close: true),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 188),
    BloomCubicTo(60, 178, 66, 166, 66, 150),
    BloomCubicTo(58, 160, 52, 172, 50, 188),
  ],
      fill: FlowerColors.gardenLeafDeep,
      stroke: FlowerColors.gardenLeafStroke,
      width: 1.7,
      close: true),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 188),
    BloomCubicTo(44, 176, 41, 164, 42, 150),
    BloomCubicTo(47, 162, 50, 174, 50, 188),
  ],
      fill: FlowerColors.gardenLeafDusk,
      stroke: FlowerColors.gardenLeafStroke,
      width: 1.7,
      close: true),
  ..._lavenderSpikes(),
];

List<BloomPart> _poppyStamens() => <BloomPart>[
      for (int i = 0; i < 11; i++)
        _path(<BloomCmd>[
          const BloomMoveTo(50, 64),
          BloomLineTo(
            50 + math.cos(i * 360 / 11 * math.pi / 180) * 9,
            64 + math.sin(i * 360 / 11 * math.pi / 180) * 9,
          ),
        ], stroke: FlowerColors.poppyCore, width: 1.3),
    ];

final List<BloomPart> poppyPlantParts = <BloomPart>[
  _path(const <BloomCmd>[
    BloomMoveTo(50, 236),
    BloomCubicTo(46, 180, 55, 120, 50, 72),
  ], stroke: FlowerColors.gardenStemMid, width: 3),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 152),
    BloomCubicTo(62, 140, 71, 120, 66, 104),
  ], stroke: FlowerColors.gardenStemMid, width: 2.3),
  const BloomOval(
    cx: 66,
    cy: 98,
    rx: 6,
    ry: 8.5,
    rotationDeg: 18,
    pivotX: 66,
    pivotY: 100,
    fill: FlowerColors.gardenLeafPale,
    strokeColor: FlowerColors.gardenLeafStroke,
    strokeWidth: 1.7,
  ),
  _path(
      _rotated(const <BloomCmd>[
        BloomMoveTo(62, 96),
        BloomQuadTo(66, 92, 70, 96),
      ], 18, 66, 100),
      stroke: FlowerColors.gardenLeafStroke,
      width: 1.1),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 176),
    BloomQuadTo(37, 175, 27, 165),
  ], stroke: FlowerColors.gardenLeafPale, width: 1.8),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 180),
    BloomQuadTo(38, 184, 29, 183),
  ], stroke: FlowerColors.gardenLeafPale, width: 1.8),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 172),
    BloomQuadTo(39, 164, 33, 154),
  ], stroke: FlowerColors.gardenLeafPale, width: 1.8),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 177),
    BloomQuadTo(63, 176, 73, 166),
  ], stroke: FlowerColors.gardenLeafDeep, width: 1.8),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 181),
    BloomQuadTo(62, 185, 71, 184),
  ], stroke: FlowerColors.gardenLeafDeep, width: 1.8),
  const BloomOval(cx: 50, cy: 56, rx: 15, ry: 13, fill: FlowerColors.poppyLobe),
  const BloomOval(
      cx: 38, cy: 65, rx: 12, ry: 11, fill: FlowerColors.poppyLobeShade),
  const BloomOval(
      cx: 62, cy: 65, rx: 12, ry: 11, fill: FlowerColors.poppyLobeShade),
  const BloomOval(
      cx: 50, cy: 70, rx: 13.5, ry: 11, fill: FlowerColors.poppyLobe),
  const BloomDisc(
    cx: 50,
    cy: 64,
    r: 6.5,
    fill: FlowerColors.poppyCore,
    strokeWidth: 0,
  ),
  ..._poppyStamens(),
];

final List<BloomPart> peonyPlantParts = <BloomPart>[
  _path(const <BloomCmd>[
    BloomMoveTo(50, 190),
    BloomCubicTo(46, 150, 53, 116, 50, 92),
  ], stroke: FlowerColors.gardenStemDeep, width: 4.6),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 148),
    BloomCubicTo(32, 148, 18, 140, 9, 149),
    BloomCubicTo(19, 154, 17, 162, 27, 160),
    BloomCubicTo(27, 168, 37, 166, 41, 159),
    BloomCubicTo(47, 163, 53, 156, 50, 148),
  ],
      fill: FlowerColors.gardenLeafDeep,
      stroke: FlowerColors.gardenLeafStroke,
      width: 2.1,
      close: true),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 148),
    BloomQuadTo(30, 150, 12, 150),
  ], stroke: FlowerColors.gardenLeafStroke, width: 1.3),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 126),
    BloomCubicTo(68, 126, 82, 118, 91, 127),
    BloomCubicTo(81, 132, 83, 140, 73, 138),
    BloomCubicTo(73, 146, 63, 144, 59, 137),
    BloomCubicTo(53, 141, 47, 134, 50, 126),
  ],
      fill: FlowerColors.gardenLeafBright,
      stroke: FlowerColors.gardenLeafStroke,
      width: 2.1,
      close: true),
  _path(const <BloomCmd>[
    BloomMoveTo(50, 126),
    BloomQuadTo(70, 128, 88, 129),
  ], stroke: FlowerColors.gardenLeafStroke, width: 1.3),
  const BloomDisc(cx: 50, cy: 64, r: 15, fill: FlowerColors.peonyPetalLight),
  const BloomDisc(cx: 34, cy: 74, r: 14, fill: FlowerColors.peonyPetalMid),
  const BloomDisc(cx: 66, cy: 74, r: 14, fill: FlowerColors.peonyPetalMid),
  const BloomDisc(cx: 41, cy: 87, r: 13.5, fill: FlowerColors.peonyPetalLight),
  const BloomDisc(cx: 59, cy: 87, r: 13.5, fill: FlowerColors.peonyPetalLight),
  const BloomDisc(cx: 50, cy: 78, r: 12, fill: FlowerColors.peonyCore),
  _path(const <BloomCmd>[
    BloomMoveTo(44, 78),
    BloomQuadTo(50, 71, 56, 78),
  ], stroke: FlowerColors.peonyCrease, width: 1.5),
];
