import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/bloom_part.dart';
import 'package:field_notes/design/flowers/bloom_part_painter.dart';
import 'package:field_notes/design/flowers/flower_palette.dart';
import 'package:field_notes/design/flowers/garden_plant_geometry.dart';
import 'package:field_notes/design/flowers/garden_plant_painter.dart';
import 'package:field_notes/design/flowers/garden_plant_spec.dart';
import 'package:field_notes/design/flowers/root_art.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/onboarding/onboarding_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const Key gardenSceneKey = ValueKey<String>('garden-scene');
const Key gardenSlideKey = ValueKey<String>('garden-slide');
const Key gardenSoilKey = ValueKey<String>('garden-soil');
const Key gardenPlantingKey = ValueKey<String>('garden-planting');
const Key gardenStakeKey = ValueKey<String>('garden-stake');

Key gardenFlowerKey(FlowerKind kind) =>
    ValueKey<String>('garden-flower-${kind.name}');

Key gardenRootsKey(FlowerKind kind) =>
    ValueKey<String>('garden-roots-${kind.name}');

const Duration gardenPlantingLength = Duration(milliseconds: 3500);
const Duration gardenRegrowLength = Duration(milliseconds: 900);
const Duration gardenSlideDelay = Duration(milliseconds: 100);
const Duration gardenSlideLength = Duration(milliseconds: 1100);

const Duration _seedFallStart = Duration(milliseconds: 200);
const Duration _seedFall = Duration(milliseconds: 950);
const Duration _seedGoneStart = Duration(milliseconds: 1200);
const Duration _seedGone = Duration(milliseconds: 250);
const Duration _crumbStart = Duration(milliseconds: 1120);
const Duration _crumbStagger = Duration(milliseconds: 15);
const Duration _crumbFly = Duration(milliseconds: 600);
const Duration _stemStart = Duration(milliseconds: 1250);
const Duration _stemDraw = Duration(milliseconds: 1050);
const Duration _leafStart = Duration(milliseconds: 1750);
const Duration _leafStagger = Duration(milliseconds: 230);
const Duration _leafUnfurl = Duration(milliseconds: 600);
const Duration _bloomStart = Duration(milliseconds: 2200);
const Duration _bloomOpen = Duration(milliseconds: 750);
const Duration _swayDelay = Duration(milliseconds: 3200);
const Duration _swayPeriod = Duration(milliseconds: 5500);
const Duration _stakeDelay = Duration(milliseconds: 900);
const Duration _stakeRise = Duration(milliseconds: 500);

const Cubic _fallCurve = Cubic(0.5, 0, 0.7, 1);
const Cubic _stemCurve = Cubic(0.45, 0.1, 0.3, 1);
const Cubic _springCurve = Cubic(0.2, 0.9, 0.3, 1.15);
const Cubic _regrowCurve = Cubic(0.3, 0.8, 0.3, 1);
const Cubic _slideCurve = Cubic(0.4, 0.1, 0.2, 1);

const double _seedShowAt = 0.12;
const double _seedLandAt = 0.8;
const double _seedBounceAt = 0.9;
const double _seedDrop = 240;
const double _seedStartTurn = -30;
const double _seedLandTurn = 10;
const double _seedBounce = 6;
const double _seedSink = 8;
const double _seedShrink = 0.6;
const double _crumbShowAt = 0.1;
const double _crumbInset = 2;
const double _unfurlTurn = -24;
const double _bloomPeakAt = 0.65;
const double _bloomPeak = 1.07;
const double _swayDegrees = 2.2;
const double _swayPhase = 0.25;
const double _driftPeakAt = 0.15;
const double _driftPeak = 0.9;
const Offset _driftTravel = Offset(46, -130);
const double _layerReach = 40;
const double _regrowFrom = 0.82;
const double _regrowSpill = 0.2;
const double _stakeTilt = 4;
const double _stakeRiseDistance = 14;
const double _stakeSlot = 240;
const int _longName = 9;

const Size _seedViewBox = Size(14, 18);
const Size _bigCrumb = Size(5, 4);
const Size _smallCrumb = Size(4, 3);

const List<Offset> _crumbs = <Offset>[
  Offset(-26, -22),
  Offset(-16, -34),
  Offset(-6, -28),
  Offset(8, -36),
  Offset(18, -26),
  Offset(28, -18),
  Offset(-34, -12),
];

const Color _crumbLight = Color(0xFFA37B52);
const Color _crumbDark = Color(0xFF7D5838);
const Color _driftBlush = Color(0xFFF6C3CA);

const Color _tagTop = Color(0xFFF6E7C8);
const Color _tagBottom = Color(0xFFEAD6AE);
const Color _tagEdge = Color(0xFF6B4A2C);
const Color _tagInk = Color(0xFF5B3F26);
const Color _tagShadow = Color.fromRGBO(40, 24, 12, 0.25);
const Color _postLight = Color(0xFFA07A4E);
const Color _postDark = Color(0xFF7A5634);

const List<BloomPart> _seedParts = <BloomPart>[
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(7, 1),
      BloomCubicTo(12, 4, 13, 11, 7, 17),
      BloomCubicTo(1, 11, 2, 4, 7, 1),
    ],
    close: true,
    fill: Color(0xFF7A5634),
    strokeColor: Color(0xFF4E341F),
    strokeWidth: 1.1,
    strokeCap: StrokeCap.butt,
    strokeJoin: StrokeJoin.miter,
  ),
  BloomShape(
    commands: <BloomCmd>[BloomMoveTo(7, 4), BloomQuadTo(9, 9, 7, 14)],
    strokeColor: Color(0xFFA37B52),
    strokeWidth: 0.9,
    strokeCap: StrokeCap.butt,
  ),
];

const BloomPartPainter _seedPainter = BloomPartPainter(
  strokeColor: Color(0xFF4E341F),
  strokeWidth: 1.1,
);

const int _soilSteps = 24;
const double _soilPeak = 0.2;
const double _soilShoulder = 0.55;
const double _ridgeJitter = 2.2;
const double _crustJitter = 2;
const double _speckSpacing = 4.5;
const double _pebbleSpacing = 70;
const double _pebbleMargin = 0.08;
const double _pebbleSpan = 0.84;
const double _pebbleClearing = 0.06;
const double _grassFloor = 0.14;
const double _grassReach = 0.12;
const double _narrowSoil = 300;
const int _narrowTufts = 4;
const double _shallowSoil = 1.2;
const List<double> _tuftsAt = <double>[0.05, 0.13, 0.84, 0.93, 0.24, 0.74];

const Color _soilTop = Color(0xFF7D5838);
const Color _soilMiddle = Color(0xFF5E3F27);
const Color _soilBottom = Color(0xFF3F2A1A);
const Color _soilShadow = Color(0xFF2A1A0E);
const double _soilShadowAlpha = 0.35;
const Color _speckDark = Color(0xFF3A2616);
const Color _speckLight = Color(0xFFA3794E);
const Color _crustColor = Color(0xFFA37B52);
const double _crustAlpha = 0.8;
const double _crustWidth = 2.4;
const Color _holeColor = Color(0xFF2E1D10);
const double _holeAlpha = 0.75;
const double _holeDepth = 2.5;
const double _holeWidth = 0.035;
const double _holeHeight = 2.6;
const Color _pebbleFill = Color(0xFFB7A68B);
const Color _pebbleEdge = Color(0xFF7A6A54);
const double _pebbleEdgeWidth = 0.9;
const Color _pebbleShine = Color(0xFFD8CCB6);
const double _pebbleShineAlpha = 0.7;
const Color _grassLight = Color(0xFF93A35E);
const Color _grassDark = Color(0xFF7F9A4F);
const double _grassWidth = 1.8;

typedef GardenDrift = ({
  Offset centre,
  double radius,
  Color color,
  Duration period,
  Duration delay,
});

typedef _Garden = ({
  OnboardingChapter chapter,
  bool planted,
  bool grown,
  Mood mood,
  bool picked,
});

_Garden? _gardenOf(OnboardingFlow flow) => switch (flow) {
  OnboardingFlowRunning(
    :final OnboardingChapter chapter,
    :final OnboardingDraft draft,
  ) =>
    (
      chapter: chapter,
      planted: draft.planted,
      grown: draft.grown,
      mood: draft.mood,
      picked: draft.picked,
    ),
  OnboardingFlowHidden() || OnboardingFlowMap() => null,
};

bool _showsPeony(_Garden garden) =>
    garden.chapter == OnboardingChapter.opening || !garden.picked;

double _phase(double elapsed, Duration start, Duration length) =>
    ((elapsed - start.inMicroseconds) / length.inMicroseconds).clamp(0.0, 1.0);

double gardenStemBaseX(GardenPlantSpec spec) => switch (spec.parts.first) {
  BloomShape(commands: [BloomMoveTo(:final double x), ...]) => x,
  _ => GardenPlantSpec.viewBoxWidth / 2,
};

@immutable
class _SceneMetrics {
  const _SceneMetrics({
    required this.soilHeight,
    required this.soilDrop,
    required this.soilShape,
    required this.soilSeed,
    required this.flowerBox,
    required this.flowerBottom,
    required this.rootsBox,
    required this.rootsBottom,
    required this.stakeFromHole,
    required this.stakeBottom,
    required this.tagMinWidth,
    required this.tagPadding,
    required this.tagSize,
    required this.tagLongSize,
    required this.post,
    required this.slide,
    required this.seedSize,
    required this.seedBottom,
    required this.crumbSpread,
    required this.drifts,
  });

  static const _SceneMetrics sidebar = _SceneMetrics(
    soilHeight: 360,
    soilDrop: 140,
    soilShape: 220,
    soilSeed: 71,
    flowerBox: Size(150, 285),
    flowerBottom: 172,
    rootsBox: Size(200, 90),
    rootsBottom: 84,
    stakeFromHole: 70,
    stakeBottom: 160,
    tagMinWidth: 84,
    tagPadding: EdgeInsets.fromLTRB(12, 6, 12, 5),
    tagSize: 24,
    tagLongSize: 24,
    post: Size(6, 54),
    slide: 118,
    seedSize: Size(14, 18),
    seedBottom: 176,
    crumbSpread: 1,
    drifts: <GardenDrift>[
      (
        centre: Offset(75.5, 33.5),
        radius: 3.5,
        color: FlowerColors.peonyPetalLight,
        period: Duration(milliseconds: 4200),
        delay: Duration.zero,
      ),
      (
        centre: Offset(63, 47),
        radius: 3,
        color: FlowerColors.peonyPetalMid,
        period: Duration(milliseconds: 4800),
        delay: Duration(milliseconds: 1400),
      ),
      (
        centre: Offset(86.5, 54.5),
        radius: 2.5,
        color: _driftBlush,
        period: Duration(milliseconds: 5400),
        delay: Duration(milliseconds: 2200),
      ),
    ],
  );

  static const _SceneMetrics bottomBar = _SceneMetrics(
    soilHeight: 420,
    soilDrop: 120,
    soilShape: 150,
    soilSeed: 33,
    flowerBox: Size(144, 274),
    flowerBottom: 266,
    rootsBox: Size(180, 160),
    rootsBottom: 104,
    stakeFromHole: 46,
    stakeBottom: 252,
    tagMinWidth: 72,
    tagPadding: EdgeInsets.fromLTRB(10, 5, 10, 4),
    tagSize: 21,
    tagLongSize: 18,
    post: Size(5, 44),
    slide: 72,
    seedSize: Size(12, 15),
    seedBottom: 269,
    crumbSpread: 0.8,
    drifts: <GardenDrift>[
      (
        centre: Offset(73, 31),
        radius: 3.5,
        color: FlowerColors.peonyPetalLight,
        period: Duration(milliseconds: 4200),
        delay: Duration.zero,
      ),
      (
        centre: Offset(61, 45),
        radius: 3,
        color: FlowerColors.peonyPetalMid,
        period: Duration(milliseconds: 4800),
        delay: Duration(milliseconds: 1400),
      ),
    ],
  );

  static _SceneMetrics of(ShellLayout layout) => switch (layout) {
    ShellLayout.sidebar => sidebar,
    ShellLayout.bottomBar => bottomBar,
  };

  final double soilHeight;
  final double soilDrop;
  final double soilShape;
  final int soilSeed;
  final Size flowerBox;
  final double flowerBottom;
  final Size rootsBox;
  final double rootsBottom;
  final double stakeFromHole;
  final double stakeBottom;
  final double tagMinWidth;
  final EdgeInsets tagPadding;
  final double tagSize;
  final double tagLongSize;
  final Size post;
  final double slide;
  final Size seedSize;
  final double seedBottom;
  final double crumbSpread;
  final List<GardenDrift> drifts;
}

double gardenHoleBottom(ShellLayout layout) {
  final _SceneMetrics metrics = _SceneMetrics.of(layout);
  return metrics.soilHeight -
      metrics.soilDrop -
      metrics.soilShape * _soilPeak -
      _holeDepth;
}

double gardenSlide(ShellLayout layout) => _SceneMetrics.of(layout).slide;

enum _Growth { stem, leaf, bloom }

@immutable
class _PartGroup {
  const _PartGroup({
    required this.growth,
    required this.pivot,
    required this.tip,
    required this.order,
    required this.parts,
  });

  final _Growth growth;
  final Offset pivot;
  final Offset tip;
  final int order;
  final List<BloomPart> parts;

  _PartGroup adding(BloomPart part) => _PartGroup(
    growth: growth,
    pivot: pivot,
    tip: tip,
    order: order,
    parts: List<BloomPart>.unmodifiable(<BloomPart>[...parts, part]),
  );
}

Offset _pointOf(BloomCmd command) => switch (command) {
  BloomMoveTo(:final double x, :final double y) ||
  BloomLineTo(:final double x, :final double y) ||
  BloomQuadTo(:final double x, :final double y) ||
  BloomCubicTo(:final double x, :final double y) ||
  BloomArcTo(:final double x, :final double y) => Offset(x, y),
};

Offset _anchorOf(BloomPart part) => switch (part) {
  BloomShape(commands: [final BloomCmd first, ...]) => _pointOf(first),
  BloomShape() => Offset.zero,
  BloomDisc(:final double cx, :final double cy) ||
  BloomOval(:final double cx, :final double cy) ||
  BloomOvalRing(:final double cx, :final double cy) => Offset(cx, cy),
};

Offset _tipOf(BloomPart part) => switch (part) {
  BloomShape(commands: [..., final BloomCmd last]) => _pointOf(last),
  _ => _anchorOf(part),
};

List<_PartGroup> _groupsOf(GardenPlantSpec spec) {
  final BloomPart stem = spec.parts.first;
  final List<BloomPart> head = gardenBloomHeadParts(spec.kind);
  final Offset crown = _tipOf(stem);
  final List<Offset> leaves = <Offset>{
    for (final BloomPart part in spec.parts)
      if (!identical(part, stem) && !head.contains(part)) _anchorOf(part),
  }.toList();
  _PartGroup groupFor(BloomPart part) {
    final _Growth growth = identical(part, stem)
        ? _Growth.stem
        : head.contains(part)
        ? _Growth.bloom
        : _Growth.leaf;
    final Offset pivot = growth == _Growth.bloom ? crown : _anchorOf(part);
    return _PartGroup(
      growth: growth,
      pivot: pivot,
      tip: _tipOf(part),
      order: leaves.indexOf(pivot),
      parts: List<BloomPart>.unmodifiable(<BloomPart>[part]),
    );
  }

  return List<_PartGroup>.unmodifiable(
    spec.parts.fold<List<_PartGroup>>(<_PartGroup>[], (
      List<_PartGroup> groups,
      BloomPart part,
    ) {
      final _PartGroup next = groupFor(part);
      final _PartGroup? last = groups.lastOrNull;
      if (last != null &&
          last.growth == next.growth &&
          last.pivot == next.pivot) {
        return <_PartGroup>[
          ...groups.take(groups.length - 1),
          last.adding(part),
        ];
      }
      return <_PartGroup>[...groups, next];
    }),
  );
}

final GardenPlantSpec _peony = gardenPlantSpecFor(FlowerKind.peony);

final List<_PartGroup> _peonyGroups = _groupsOf(_peony);

final BloomPartPainter _peonyPainter = BloomPartPainter(
  strokeColor: _peony.strokeColor,
  strokeWidth: _peony.strokeWidth,
);

double Function() _sequence(int seed) {
  int state = seed & 0xFFFFFFFF;
  return () {
    state = (state + 0x6D2B79F5) & 0xFFFFFFFF;
    final int mixed = ((state ^ (state >> 15)) * (1 | state)) & 0xFFFFFFFF;
    final int folded =
        ((mixed + (((mixed ^ (mixed >> 7)) * (61 | mixed)) & 0xFFFFFFFF)) &
            0xFFFFFFFF) ^
        mixed;
    return ((folded ^ (folded >> 14)) & 0xFFFFFFFF) / 4294967296;
  };
}

@immutable
class _Speck {
  const _Speck(this.centre, this.radii, this.color);

  final Offset centre;
  final Size radii;
  final Color color;
}

@immutable
class _Pebble {
  const _Pebble(this.centre, this.radius);

  final Offset centre;
  final double radius;
}

@immutable
class _Blade {
  const _Blade(this.from, this.bend, this.to, this.color);

  final Offset from;
  final Offset bend;
  final Offset to;
  final Color color;
}

@immutable
class _Soil {
  const _Soil({
    required this.size,
    required this.peak,
    required this.shoulder,
    required this.shaded,
    required this.ridge,
    required this.crust,
    required this.specks,
    required this.pebbles,
    required this.blades,
  });

  factory _Soil.generate({
    required double width,
    required double height,
    required double shape,
    required int seed,
  }) {
    final double Function() next = _sequence(seed);
    final double depth = height / shape;
    final double peak = shape * _soilPeak;
    double top(double x) {
      final double t = x / width * 2 - 1;
      return peak + (shape * _soilShoulder - peak) * t * t;
    }

    List<Offset> edge(double jitter) => <Offset>[
      for (int step = 0; step <= _soilSteps; step++)
        Offset(
          width * step / _soilSteps,
          top(width * step / _soilSteps) + (next() - 0.5) * jitter,
        ),
    ];

    _Speck? speck() {
      final double x = next() * width;
      final double y = top(x) + 3 + next() * (height - top(x) - 4);
      if (y >= height - 1) {
        return null;
      }
      final Color color = next() < 0.5 ? _speckDark : _speckLight;
      final Size radii = Size(0.8 + next() * 1.8, 0.6 + next() * 1.1);
      return _Speck(
        Offset(x, y),
        radii,
        color.withValues(alpha: 0.35 + next() * 0.4),
      );
    }

    _Pebble? pebble() {
      final double x = width * _pebbleMargin + next() * width * _pebbleSpan;
      final double y = top(x) + 6 + next() * (height - top(x) - 10);
      if ((x - width / 2).abs() < width * _pebbleClearing) {
        return null;
      }
      return _Pebble(Offset(x, y), 2 + next() * 3.5);
    }

    _Blade blade(Offset root, int index, int count) {
      final double lean = (index - (count - 1) / 2) * 4 + (next() - 0.5) * 3;
      final double reach = shape * _grassFloor + next() * shape * _grassReach;
      return _Blade(
        root.translate(index * 1.6 - count, 0),
        root.translate(lean * 0.4, -reach * 0.6),
        root.translate(lean, -reach),
        index.isOdd ? _grassDark : _grassLight,
      );
    }

    List<_Blade> tuft(double at) {
      final Offset root = Offset(width * at, top(width * at) + 2);
      final int count = 4 + (next() * 3).floor();
      return <_Blade>[
        for (int index = 0; index < count; index++) blade(root, index, count),
      ];
    }

    final List<Offset> ridge = edge(_ridgeJitter);
    final List<Offset> crust = edge(_crustJitter);
    final List<_Speck> specks = <_Speck>[
      for (
        int index = 0;
        index < (width / _speckSpacing * depth).round();
        index++
      )
        if (speck() case final _Speck found) found,
    ];
    final List<_Pebble> pebbles = <_Pebble>[
      for (
        int index = 0;
        index < (width / _pebbleSpacing * depth).round();
        index++
      )
        if (pebble() case final _Pebble found) found,
    ];
    final List<_Blade> blades = <_Blade>[
      for (final (int index, double at) in _tuftsAt.indexed)
        if (width >= _narrowSoil || index < _narrowTufts) ...tuft(at),
    ];
    return _Soil(
      size: Size(width, height),
      peak: peak,
      shoulder: top(0),
      shaded: depth <= _shallowSoil,
      ridge: List<Offset>.unmodifiable(ridge),
      crust: List<Offset>.unmodifiable(crust),
      specks: List<_Speck>.unmodifiable(specks),
      pebbles: List<_Pebble>.unmodifiable(pebbles),
      blades: List<_Blade>.unmodifiable(blades),
    );
  }

  final Size size;
  final double peak;
  final double shoulder;
  final bool shaded;
  final List<Offset> ridge;
  final List<Offset> crust;
  final List<_Speck> specks;
  final List<_Pebble> pebbles;
  final List<_Blade> blades;
}

class _SoilPainter extends CustomPainter {
  const _SoilPainter(this.soil);

  final _Soil soil;

  @override
  void paint(Canvas canvas, Size size) {
    final Size design = soil.size;
    if (size.isEmpty || design.isEmpty) {
      return;
    }
    canvas.save();
    canvas.scale(size.width / design.width, size.height / design.height);
    canvas.clipRect(Offset.zero & design);
    if (soil.shaded) {
      _paintShadow(canvas, design);
    }
    _paintBody(canvas, design);
    for (final _Speck speck in soil.specks) {
      canvas.drawOval(
        Rect.fromCenter(
          center: speck.centre,
          width: speck.radii.width * 2,
          height: speck.radii.height * 2,
        ),
        Paint()..color = speck.color,
      );
    }
    canvas.drawPath(
      _line(Offset(0, soil.shoulder), soil.crust),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _crustWidth
        ..strokeJoin = StrokeJoin.round
        ..color = _crustColor.withValues(alpha: _crustAlpha),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(design.width / 2, soil.peak + _holeDepth),
        width: design.width * _holeWidth * 2,
        height: _holeHeight * 2,
      ),
      Paint()..color = _holeColor.withValues(alpha: _holeAlpha),
    );
    for (final _Pebble pebble in soil.pebbles) {
      _paintPebble(canvas, pebble);
    }
    for (final _Blade blade in soil.blades) {
      canvas.drawPath(
        Path()
          ..moveTo(blade.from.dx, blade.from.dy)
          ..quadraticBezierTo(
            blade.bend.dx,
            blade.bend.dy,
            blade.to.dx,
            blade.to.dy,
          ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _grassWidth
          ..strokeCap = StrokeCap.round
          ..color = blade.color,
      );
    }
    canvas.restore();
  }

  void _paintShadow(Canvas canvas, Size design) {
    canvas.save();
    canvas.translate(design.width / 2, design.height - 2);
    canvas.scale(design.width * 0.52, design.height * 0.16);
    canvas.drawCircle(
      Offset.zero,
      1,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, 1, <Color>[
          _soilShadow.withValues(alpha: _soilShadowAlpha),
          _soilShadow.withValues(alpha: 0),
        ]),
    );
    canvas.restore();
  }

  void _paintBody(Canvas canvas, Size design) {
    final Path body = Path()
      ..moveTo(0, design.height)
      ..lineTo(0, soil.shoulder);
    for (final Offset point in soil.ridge) {
      body.lineTo(point.dx, point.dy);
    }
    body
      ..lineTo(design.width, design.height)
      ..close();
    final double crest = soil.ridge.fold(
      soil.shoulder,
      (double highest, Offset point) => math.min(highest, point.dy),
    );
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, crest),
          Offset(0, design.height),
          const <Color>[_soilTop, _soilMiddle, _soilBottom],
          const <double>[0, 0.55, 1],
        ),
    );
  }

  void _paintPebble(Canvas canvas, _Pebble pebble) {
    final Rect stone = Rect.fromCenter(
      center: pebble.centre,
      width: pebble.radius * 2,
      height: pebble.radius * 0.62 * 2,
    );
    canvas.drawOval(stone, Paint()..color = _pebbleFill);
    canvas.drawOval(
      stone,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _pebbleEdgeWidth
        ..color = _pebbleEdge,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: pebble.centre.translate(
          -pebble.radius * 0.3,
          -pebble.radius * 0.2,
        ),
        width: pebble.radius * 0.35 * 2,
        height: pebble.radius * 0.18 * 2,
      ),
      Paint()..color = _pebbleShine.withValues(alpha: _pebbleShineAlpha),
    );
  }

  Path _line(Offset start, List<Offset> points) {
    final Path line = Path()..moveTo(start.dx, start.dy);
    for (final Offset point in points) {
      line.lineTo(point.dx, point.dy);
    }
    return line;
  }

  @override
  bool shouldRepaint(_SoilPainter oldDelegate) => oldDelegate.soil != soil;
}

class GardenPeonyPainter extends CustomPainter {
  GardenPeonyPainter({
    required this.growth,
    required this.clock,
    required this.drifts,
  }) : super(repaint: Listenable.merge(<Listenable>[growth, clock]));

  final Animation<double> growth;
  final ValueListenable<Duration> clock;
  final List<GardenDrift> drifts;

  @override
  void paint(Canvas canvas, Size size) {
    final double elapsed = growth.value * gardenPlantingLength.inMicroseconds;
    final double scale = size.width / GardenPlantSpec.viewBoxWidth;
    canvas.save();
    canvas.scale(scale);
    for (final _PartGroup group in _peonyGroups) {
      _paintGroup(canvas, group, elapsed);
    }
    canvas.restore();
    final double drifted = (clock.value - _swayDelay).inMicroseconds.toDouble();
    if (growth.value >= 1 && drifted > 0) {
      for (final GardenDrift drift in drifts) {
        _paintDrift(canvas, drift, drifted);
      }
    }
  }

  void _paintGroup(Canvas canvas, _PartGroup group, double elapsed) {
    switch (group.growth) {
      case _Growth.stem:
        _paintStem(canvas, group, elapsed);
      case _Growth.leaf:
        final double unfurled = _phase(
          elapsed,
          _leafStart + _leafStagger * group.order,
          _leafUnfurl,
        );
        if (unfurled <= 0) {
          return;
        }
        final double eased = _springCurve.transform(unfurled);
        _paintPosed(
          canvas,
          group,
          scale: eased,
          turn: _unfurlTurn * (1 - eased),
          opacity: eased,
        );
      case _Growth.bloom:
        final double opened = _phase(elapsed, _bloomStart, _bloomOpen);
        if (opened <= 0) {
          return;
        }
        if (opened < _bloomPeakAt) {
          final double eased = _springCurve.transform(opened / _bloomPeakAt);
          _paintPosed(
            canvas,
            group,
            scale: _bloomPeak * eased,
            turn: 0,
            opacity: eased,
          );
        } else {
          final double eased = _springCurve.transform(
            (opened - _bloomPeakAt) / (1 - _bloomPeakAt),
          );
          _paintPosed(
            canvas,
            group,
            scale: _bloomPeak + (1 - _bloomPeak) * eased,
            turn: 0,
            opacity: 1,
          );
        }
    }
  }

  void _paintStem(Canvas canvas, _PartGroup group, double elapsed) {
    final double drawn = _stemCurve.transform(
      _phase(elapsed, _stemStart, _stemDraw),
    );
    if (drawn <= 0) {
      return;
    }
    final double margin = group.parts
        .map((BloomPart part) => part.strokeWidth ?? _peony.strokeWidth)
        .fold<double>(0, math.max);
    final double root = math.max(group.pivot.dy, group.tip.dy) + margin;
    canvas.save();
    if (drawn < 1) {
      canvas.clipRect(
        Rect.fromLTRB(
          -_layerReach,
          ui.lerpDouble(group.pivot.dy + margin, group.tip.dy - margin, drawn)!,
          GardenPlantSpec.viewBoxWidth + _layerReach,
          root,
        ),
      );
    }
    for (final BloomPart part in group.parts) {
      _peonyPainter.paintOne(canvas, part);
    }
    canvas.restore();
  }

  void _paintPosed(
    Canvas canvas,
    _PartGroup group, {
    required double scale,
    required double turn,
    required double opacity,
  }) {
    if (scale <= 0) {
      return;
    }
    final double alpha = opacity.clamp(0.0, 1.0);
    final Offset pivot = group.pivot;
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(turn * math.pi / 180);
    canvas.scale(scale);
    canvas.translate(-pivot.dx, -pivot.dy);
    if (alpha < 1) {
      canvas.saveLayer(
        Rect.fromLTWH(
          -_layerReach,
          -_layerReach,
          GardenPlantSpec.viewBoxWidth + 2 * _layerReach,
          _peony.viewBoxHeight + 2 * _layerReach,
        ),
        Paint()..color = const Color(0xFF000000).withValues(alpha: alpha),
      );
    }
    for (final BloomPart part in group.parts) {
      _peonyPainter.paintOne(canvas, part);
    }
    if (alpha < 1) {
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintDrift(Canvas canvas, GardenDrift drift, double drifted) {
    final double since = drifted - drift.delay.inMicroseconds;
    if (since <= 0) {
      return;
    }
    final int period = drift.period.inMicroseconds;
    final double cycle = (since % period) / period;
    final double alpha = cycle < _driftPeakAt
        ? _driftPeak * Curves.easeOut.transform(cycle / _driftPeakAt)
        : _driftPeak *
              (1 -
                  Curves.easeOut.transform(
                    (cycle - _driftPeakAt) / (1 - _driftPeakAt),
                  ));
    canvas.drawCircle(
      drift.centre + _driftTravel * Curves.easeOut.transform(cycle),
      drift.radius,
      Paint()..color = drift.color.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(GardenPeonyPainter oldDelegate) =>
      oldDelegate.growth != growth ||
      oldDelegate.clock != clock ||
      !listEquals(oldDelegate.drifts, drifts);
}

class _PlantingPainter extends CustomPainter {
  _PlantingPainter({required this.metrics, required this.growth})
    : super(repaint: growth);

  final _SceneMetrics metrics;
  final Animation<double> growth;

  @override
  void paint(Canvas canvas, Size size) {
    final double elapsed = growth.value * gardenPlantingLength.inMicroseconds;
    _paintSeed(canvas, size, elapsed);
    _paintCrumbs(canvas, size, elapsed);
  }

  void _paintSeed(Canvas canvas, Size size, double elapsed) {
    final double fall = _phase(elapsed, _seedFallStart, _seedFall);
    final double gone = Curves.ease.transform(
      _phase(elapsed, _seedGoneStart, _seedGone),
    );
    final double shown = fall < _seedShowAt
        ? _fallCurve.transform(fall / _seedShowAt)
        : 1;
    final double alpha = (shown * (1 - gone)).clamp(0.0, 1.0);
    if (alpha <= 0) {
      return;
    }
    final (double drop, double turn) = _seedPose(fall);
    final Size box = metrics.seedSize;
    final double fit = math.min(
      box.width / _seedViewBox.width,
      box.height / _seedViewBox.height,
    );
    canvas.save();
    canvas.translate(
      size.width / 2,
      size.height -
          metrics.seedBottom -
          box.height / 2 +
          drop +
          _seedSink * gone,
    );
    canvas.rotate(turn * math.pi / 180);
    canvas.scale(fit * (1 - _seedShrink * gone));
    canvas.translate(-_seedViewBox.width / 2, -_seedViewBox.height / 2);
    canvas.saveLayer(
      (Offset.zero & _seedViewBox).inflate(_seedViewBox.width),
      Paint()..color = const Color(0xFF000000).withValues(alpha: alpha),
    );
    _seedPainter.paintAll(canvas, _seedParts);
    canvas.restore();
    canvas.restore();
  }

  (double, double) _seedPose(double fall) {
    if (fall <= _seedLandAt) {
      final double eased = _fallCurve.transform(fall / _seedLandAt);
      return (
        -_seedDrop * (1 - eased),
        _seedStartTurn + (_seedLandTurn - _seedStartTurn) * eased,
      );
    }
    if (fall <= _seedBounceAt) {
      final double eased = _fallCurve.transform(
        (fall - _seedLandAt) / (_seedBounceAt - _seedLandAt),
      );
      return (-_seedBounce * eased, _seedLandTurn * (1 - eased));
    }
    final double eased = _fallCurve.transform(
      (fall - _seedBounceAt) / (1 - _seedBounceAt),
    );
    return (-_seedBounce * (1 - eased), 0);
  }

  void _paintCrumbs(Canvas canvas, Size size, double elapsed) {
    for (final (int index, Offset spread) in _crumbs.indexed) {
      final double flown = _phase(
        elapsed,
        _crumbStart + _crumbStagger * index,
        _crumbFly,
      );
      if (flown <= 0 || flown >= 1) {
        continue;
      }
      final double alpha = flown < _crumbShowAt
          ? Curves.easeOut.transform(flown / _crumbShowAt)
          : 1 -
                Curves.easeOut.transform(
                  (flown - _crumbShowAt) / (1 - _crumbShowAt),
                );
      final Offset shift =
          spread * metrics.crumbSpread * Curves.easeOut.transform(flown);
      final Size crumb = index % 3 == 0 ? _bigCrumb : _smallCrumb;
      canvas.drawOval(
        Offset(
              size.width / 2 - _crumbInset + shift.dx,
              size.height - metrics.flowerBottom - crumb.height + shift.dy,
            ) &
            crumb,
        Paint()
          ..color = (index.isOdd ? _crumbDark : _crumbLight).withValues(
            alpha: alpha,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_PlantingPainter oldDelegate) =>
      oldDelegate.metrics != metrics || oldDelegate.growth != growth;
}

class GardenBloomPainter extends CustomPainter {
  const GardenBloomPainter({required this.spec, required this.growth});

  final GardenPlantSpec spec;
  final double growth;

  @override
  void paint(Canvas canvas, Size size) {
    if (growth <= 0 || size.isEmpty) {
      return;
    }
    final double width = size.width;
    final double height = size.height;
    canvas.save();
    canvas.translate(width / 2, height);
    canvas.scale(1, _regrowFrom + (1 - _regrowFrom) * growth);
    canvas.translate(-width / 2, -height);
    canvas.clipRect(
      Rect.fromLTRB(
        -width * _regrowSpill * growth,
        height * (1 - (1 + _regrowSpill) * growth),
        width * (1 + _regrowSpill * growth),
        height,
      ),
    );
    GardenPlantPainter(spec).paint(canvas, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(GardenBloomPainter oldDelegate) =>
      oldDelegate.spec != spec || oldDelegate.growth != growth;
}

class _Regrow extends StatefulWidget {
  const _Regrow({
    super.key,
    required this.kind,
    required this.size,
    required this.growing,
    required this.onGrown,
  });

  final FlowerKind kind;
  final Size size;
  final bool growing;
  final VoidCallback onGrown;

  @override
  State<_Regrow> createState() => _RegrowState();
}

class _RegrowState extends State<_Regrow> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: gardenRegrowLength,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      if (MediaQuery.disableAnimationsOf(context) && _clock.isAnimating) {
        _finish();
      }
      return;
    }
    _started = true;
    if (!widget.growing) {
      _clock.value = 1;
    } else if (MediaQuery.disableAnimationsOf(context)) {
      _finish();
    } else {
      _clock.forward().whenCompleteOrCancel(_onDone);
    }
  }

  @override
  void didUpdateWidget(_Regrow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.growing && _clock.isAnimating) {
      _clock.stop();
      _clock.value = 1;
    }
  }

  void _finish() {
    _clock.value = 1;
    scheduleMicrotask(_report);
  }

  void _onDone() {
    if (_clock.isCompleted) {
      scheduleMicrotask(_report);
    }
  }

  void _report() {
    if (mounted) {
      widget.onGrown();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GardenPlantSpec spec = gardenPlantSpecFor(widget.kind);
    return AnimatedBuilder(
      animation: _clock,
      builder: (BuildContext context, Widget? child) => CustomPaint(
        key: gardenFlowerKey(widget.kind),
        size: widget.size,
        painter: GardenBloomPainter(
          spec: spec,
          growth: _regrowCurve.transform(_clock.value),
        ),
      ),
    );
  }
}

class _Stake extends StatelessWidget {
  const _Stake({required this.name, required this.metrics});

  final String name;
  final _SceneMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final double size = name.length > _longName
        ? metrics.tagLongSize
        : metrics.tagSize;
    return Semantics(
      key: gardenStakeKey,
      container: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            constraints: BoxConstraints(minWidth: metrics.tagMinWidth),
            padding: metrics.tagPadding,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[_tagTop, _tagBottom],
              ),
              border: Border.fromBorderSide(
                BorderSide(color: _tagEdge, width: 1.5),
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(color: _tagShadow, offset: Offset(2, 3)),
              ],
            ),
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontFamily: TypographyTokens.accent,
                fontSize: size,
                fontWeight: FontWeight.w700,
                height: 1,
                color: _tagInk,
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -1),
            child: SizedBox.fromSize(
              size: metrics.post,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[_postLight, _postDark],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(2),
                    bottomRight: Radius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiseIn extends StatefulWidget {
  const _RiseIn({
    required this.delay,
    required this.duration,
    required this.child,
  });

  final Duration delay;
  final Duration duration;
  final Widget child;

  @override
  State<_RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<_RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.value = 1;
    } else if (_clock.isDismissed) {
      _clock.forward();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double shown = Curves.ease.transform(
          _phase(
            _clock.value * (widget.delay + widget.duration).inMicroseconds,
            widget.delay,
            widget.duration,
          ),
        );
        return Opacity(
          opacity: shown,
          alwaysIncludeSemantics: true,
          child: Transform.translate(
            offset: Offset(0, _stakeRiseDistance * (1 - shown)),
            child: child,
          ),
        );
      },
    );
  }
}

class GardenScene extends ConsumerStatefulWidget {
  const GardenScene({super.key, required this.layout});

  final ShellLayout layout;

  @override
  ConsumerState<GardenScene> createState() => _GardenSceneState();
}

class _GardenSceneState extends ConsumerState<GardenScene>
    with TickerProviderStateMixin {
  late final AnimationController _planting = AnimationController(
    vsync: this,
    duration: gardenPlantingLength,
  )..addStatusListener(_onPlanting);
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: gardenSlideDelay + gardenSlideLength,
  );
  late final Ticker _sway = createTicker(_onSway);
  final ValueNotifier<Duration> _swayed = ValueNotifier<Duration>(
    Duration.zero,
  );
  double _slideFrom = 0;
  double _slideTo = 0;
  FlowerKind? _regrowing;
  bool _still = false;
  bool _started = false;
  _Soil? _soil;

  _SceneMetrics get _metrics => _SceneMetrics.of(widget.layout);

  OnboardingController get _controller =>
      ref.read(onboardingControllerProvider.notifier);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    final _Garden? garden = _gardenOf(ref.read(onboardingControllerProvider));
    if (!_started) {
      _started = true;
      if (garden != null) {
        _slideFrom = _slideTo = _slideFor(garden);
        _slide.value = 1;
        _followPlanting(garden);
      }
    } else if (_still) {
      if (_planting.isAnimating) {
        _planting.value = 1;
      }
      _slide.value = 1;
    }
    _followSway(garden);
  }

  @override
  void dispose() {
    _sway.dispose();
    _slide.dispose();
    _planting.dispose();
    _swayed.dispose();
    super.dispose();
  }

  double _slideFor(_Garden garden) =>
      garden.chapter == OnboardingChapter.day ? _metrics.slide : 0;

  double get _slideShown {
    final double t = _phase(
      _slide.value * (gardenSlideDelay + gardenSlideLength).inMicroseconds,
      gardenSlideDelay,
      gardenSlideLength,
    );
    return _slideFrom + (_slideTo - _slideFrom) * _slideCurve.transform(t);
  }

  void _follow(_Garden? previous, _Garden? next) {
    if (next == null) {
      return;
    }
    if (previous == null || previous.chapter != next.chapter) {
      _regrowing = null;
      _slideFrom = previous == null ? _slideFor(next) : _slideShown;
      _slideTo = _slideFor(next);
      if (_still || previous == null) {
        _slide.value = 1;
      } else {
        _slide.forward(from: 0);
      }
    } else if (next.chapter == OnboardingChapter.day &&
        next.picked &&
        (!previous.picked || previous.mood != next.mood)) {
      _regrowing = next.mood.flower;
    }
    _followPlanting(next);
    _followSway(next);
  }

  void _followPlanting(_Garden garden) {
    if (!garden.planted) {
      _planting.value = 0;
    } else if (garden.grown || _still) {
      _planting.value = 1;
    } else if (_planting.isDismissed) {
      _planting.forward();
    }
  }

  void _followSway(_Garden? garden) {
    final bool swaying = garden != null && garden.planted && !_still;
    if (swaying && !_sway.isActive) {
      _sway.start();
    } else if (!swaying && _sway.isActive) {
      _sway.stop();
      _swayed.value = Duration.zero;
    }
  }

  void _onSway(Duration elapsed) => _swayed.value = elapsed;

  void _onPlanting(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      scheduleMicrotask(_reportGrown);
    }
  }

  void _reportGrown() {
    final _Garden? garden = _gardenOf(ref.read(onboardingControllerProvider));
    if (mounted && garden != null && garden.planted && !garden.grown) {
      _controller.markGrown();
    }
  }

  double _swayAngle(Duration elapsed) {
    final double since = (elapsed - _swayDelay).inMicroseconds.toDouble();
    if (since <= 0) {
      return 0;
    }
    final double cycle = (since / _swayPeriod.inMicroseconds + _swayPhase) % 1;
    final double swing = cycle < 0.5
        ? Curves.easeInOut.transform(cycle * 2)
        : 1 - Curves.easeInOut.transform((cycle - 0.5) * 2);
    return (2 * swing - 1) * _swayDegrees * math.pi / 180;
  }

  _Soil _soilFor(double width) {
    final _SceneMetrics metrics = _metrics;
    final _Soil? cached = _soil;
    if (cached != null &&
        cached.size.width == width &&
        cached.size.height == metrics.soilHeight) {
      return cached;
    }
    final _Soil soil = _Soil.generate(
      width: width,
      height: metrics.soilHeight,
      shape: metrics.soilShape,
      seed: metrics.soilSeed,
    );
    _soil = soil;
    return soil;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<_Garden?>(
      onboardingControllerProvider.select(_gardenOf),
      _follow,
    );
    final _Garden? garden = ref.watch(
      onboardingControllerProvider.select(_gardenOf),
    );
    if (garden == null) {
      return const SizedBox.expand();
    }
    final _SceneMetrics metrics = _metrics;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          final double holeX = width / 2;
          final Widget scene = Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                bottom: -metrics.soilDrop,
                height: metrics.soilHeight,
                child: ExcludeSemantics(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: gardenSoilKey,
                      painter: _SoilPainter(_soilFor(width)),
                    ),
                  ),
                ),
              ),
              if (garden.planted) ...<Widget>[
                Positioned(
                  left: holeX - metrics.rootsBox.width / 2,
                  bottom: metrics.rootsBottom,
                  width: metrics.rootsBox.width,
                  height: metrics.rootsBox.height,
                  child: _roots(garden),
                ),
                Positioned(
                  left: holeX - metrics.flowerBox.width / 2,
                  bottom: metrics.flowerBottom,
                  width: metrics.flowerBox.width,
                  height: metrics.flowerBox.height,
                  child: ExcludeSemantics(
                    child: ValueListenableBuilder<Duration>(
                      valueListenable: _swayed,
                      child: RepaintBoundary(child: _flower(garden, metrics)),
                      builder:
                          (
                            BuildContext context,
                            Duration swayed,
                            Widget? art,
                          ) => Transform.rotate(
                            angle: _swayAngle(swayed),
                            alignment: Alignment.bottomCenter,
                            child: art,
                          ),
                    ),
                  ),
                ),
              ],
              if (garden.planted &&
                  !garden.grown &&
                  garden.chapter == OnboardingChapter.opening)
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      key: gardenPlantingKey,
                      painter: _PlantingPainter(
                        metrics: metrics,
                        growth: _planting,
                      ),
                    ),
                  ),
                ),
              if (garden.chapter == OnboardingChapter.day)
                Positioned(
                  left: holeX + metrics.stakeFromHole - _stakeSlot / 2,
                  width: _stakeSlot,
                  bottom: metrics.stakeBottom,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _RiseIn(
                      delay: _stakeDelay,
                      duration: _stakeRise,
                      child: Transform.rotate(
                        angle: _stakeTilt * math.pi / 180,
                        alignment: Alignment.bottomCenter,
                        child: _Stake(
                          name:
                              (_showsPeony(garden)
                                      ? FlowerKind.peony
                                      : garden.mood.flower)
                                  .label
                                  .toLowerCase(),
                          metrics: metrics,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
          return AnimatedBuilder(
            animation: _slide,
            child: scene,
            builder: (BuildContext context, Widget? child) =>
                Transform.translate(
                  key: gardenSlideKey,
                  offset: Offset(0, -_slideShown),
                  child: child,
                ),
          );
        },
      ),
    );
  }

  Widget _roots(_Garden garden) {
    final bool peony = _showsPeony(garden);
    final FlowerKind kind = peony ? FlowerKind.peony : garden.mood.flower;
    final RootMode mode = peony
        ? (garden.grown ? RootMode.still : RootMode.open)
        : (_regrowing == kind ? RootMode.grow : RootMode.still);
    return RootArt(key: gardenRootsKey(kind), kind: kind, mode: mode);
  }

  Widget _flower(_Garden garden, _SceneMetrics metrics) {
    final bool peony = _showsPeony(garden);
    final FlowerKind kind = peony ? FlowerKind.peony : garden.mood.flower;
    final GardenPlantSpec spec = gardenPlantSpecFor(kind);
    final Size box = metrics.flowerBox;
    final double scale = math.min(
      box.width / GardenPlantSpec.viewBoxWidth,
      box.height / spec.viewBoxHeight,
    );
    final Size art = Size(
      GardenPlantSpec.viewBoxWidth * scale,
      spec.viewBoxHeight * scale,
    );
    final double shift =
        (GardenPlantSpec.viewBoxWidth / 2 - gardenStemBaseX(spec)) * scale;
    final Mood mood = garden.mood;
    final Widget paint = peony
        ? CustomPaint(
            key: gardenFlowerKey(FlowerKind.peony),
            size: art,
            painter: GardenPeonyPainter(
              growth: _planting,
              clock: _swayed,
              drifts: metrics.drifts,
            ),
          )
        : _Regrow(
            key: ValueKey<FlowerKind>(kind),
            kind: kind,
            size: art,
            growing: _regrowing == kind,
            onGrown: () => _controller.markPlantGrown(mood),
          );
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: (box.width - art.width) / 2 + shift,
          bottom: 0,
          width: art.width,
          height: art.height,
          child: paint,
        ),
      ],
    );
  }
}
