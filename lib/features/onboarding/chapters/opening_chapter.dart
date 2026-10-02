import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/bloom_part.dart';
import 'package:field_notes/design/flowers/bloom_part_painter.dart';
import 'package:field_notes/design/flowers/flower_palette.dart';
import 'package:field_notes/design/flowers/garden_plant_geometry.dart';
import 'package:field_notes/design/flowers/garden_plant_spec.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/flower_kind.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _kicker = 'field notes';
const String _title = "Most days won't feel like a story.";
const String _subtitle =
    "Write them down anyway. Each one becomes a flower, and they're yours "
    'to keep.';
const String _plantLabel = 'Plant your first seed';
const String _hintSidebar = 'click anywhere to plant your first seed';
const String _hintBottomBar = 'tap anywhere to plant your first seed';
const String _hintEnter = 'or press Enter';

const Duration _growDuration = Duration(milliseconds: 3500);
const Duration _hintDelay = Duration(milliseconds: 300);
const Duration _hintFadeIn = Duration(milliseconds: 800);
const Duration _hintFadeOut = Duration(milliseconds: 250);
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
const Duration _headingStart = Duration(milliseconds: 2600);
const Duration _headingRise = Duration(milliseconds: 800);
const Duration _swayPeriod = Duration(milliseconds: 5500);

const Cubic _fallCurve = Cubic(0.5, 0, 0.7, 1);
const Cubic _stemCurve = Cubic(0.45, 0.1, 0.3, 1);
const Cubic _springCurve = Cubic(0.2, 0.9, 0.3, 1.15);

const double _riseDistance = 14;
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

const Size _seedViewBox = Size(14, 18);
const Size _arrowViewBox = Size(44, 84);
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

const List<BloomPart> _arrowParts = <BloomPart>[
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(24, 4),
      BloomCubicTo(10, 22, 34, 40, 22, 76),
    ],
  ),
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(12, 64),
      BloomLineTo(22, 77),
      BloomLineTo(31, 62),
    ],
  ),
];

const BloomPartPainter _seedPainter = BloomPartPainter(
  strokeColor: Color(0xFF4E341F),
  strokeWidth: 1.1,
);

const double _arrowStroke = 2.3;

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

typedef _Planting = ({bool planted, bool grown});

_Planting? _plantingOf(OnboardingFlow flow) => switch (flow) {
  OnboardingFlowRunning(:final OnboardingDraft draft) => (
    planted: draft.planted,
    grown: draft.grown,
  ),
  OnboardingFlowHidden() || OnboardingFlowMap() => null,
};

double _phase(double elapsed, Duration start, Duration length) =>
    ((elapsed - start.inMicroseconds) / length.inMicroseconds).clamp(0.0, 1.0);

@immutable
class _Drift {
  const _Drift({
    required this.centre,
    required this.radius,
    required this.color,
    required this.period,
    required this.delay,
  });

  final Offset centre;
  final double radius;
  final Color color;
  final Duration period;
  final Duration delay;
}

@immutable
class _OpeningMetrics {
  const _OpeningMetrics({
    required this.headingTop,
    required this.headingSide,
    required this.kickerSize,
    required this.titleSize,
    required this.titleHeight,
    required this.titleSpacing,
    required this.titleGap,
    required this.subtitleSize,
    required this.subtitleGap,
    required this.subtitleWidth,
    required this.hint,
    required this.hintBottom,
    required this.hintSide,
    required this.hintWidth,
    required this.hintSize,
    required this.hintHeight,
    required this.hintGap,
    required this.showEnter,
    required this.arrowSize,
    required this.soilHeight,
    required this.plantWidth,
    required this.plantBottom,
    required this.seedSize,
    required this.seedBottom,
    required this.crumbBottom,
    required this.crumbSpread,
    required this.drifts,
  });

  static const _OpeningMetrics sidebar = _OpeningMetrics(
    headingTop: 78,
    headingSide: 40,
    kickerSize: 26,
    titleSize: 48,
    titleHeight: 1.06,
    titleSpacing: -0.48,
    titleGap: 10,
    subtitleSize: 16,
    subtitleGap: 10,
    subtitleWidth: 500,
    hint: _hintSidebar,
    hintBottom: 273,
    hintSide: 24,
    hintWidth: double.infinity,
    hintSize: 32,
    hintHeight: null,
    hintGap: 6,
    showEnter: true,
    arrowSize: Size(44, 84),
    soilHeight: 220,
    plantWidth: 150,
    plantBottom: 172,
    seedSize: Size(14, 18),
    seedBottom: 176,
    crumbBottom: 172,
    crumbSpread: 1,
    drifts: <_Drift>[
      _Drift(
        centre: Offset(75.5, 33.5),
        radius: 3.5,
        color: FlowerColors.peonyPetalLight,
        period: Duration(milliseconds: 4200),
        delay: Duration.zero,
      ),
      _Drift(
        centre: Offset(63, 47),
        radius: 3,
        color: FlowerColors.peonyPetalMid,
        period: Duration(milliseconds: 4800),
        delay: Duration(milliseconds: 1400),
      ),
      _Drift(
        centre: Offset(86.5, 54.5),
        radius: 2.5,
        color: _driftBlush,
        period: Duration(milliseconds: 5400),
        delay: Duration(milliseconds: 2200),
      ),
    ],
  );

  static const _OpeningMetrics bottomBar = _OpeningMetrics(
    headingTop: 30,
    headingSide: 22,
    kickerSize: 22,
    titleSize: 28,
    titleHeight: 1.1,
    titleSpacing: 0,
    titleGap: 8,
    subtitleSize: 12.5,
    subtitleGap: 7,
    subtitleWidth: 280,
    hint: _hintBottomBar,
    hintBottom: 261,
    hintSide: 30,
    hintWidth: 280,
    hintSize: 26,
    hintHeight: 1.1,
    hintGap: 2,
    showEnter: false,
    arrowSize: Size(36, 70),
    soilHeight: 150,
    plantWidth: 124,
    plantBottom: 116,
    seedSize: Size(12, 15),
    seedBottom: 119,
    crumbBottom: 116,
    crumbSpread: 0.8,
    drifts: <_Drift>[
      _Drift(
        centre: Offset(63, 27),
        radius: 3,
        color: FlowerColors.peonyPetalLight,
        period: Duration(milliseconds: 4200),
        delay: Duration.zero,
      ),
      _Drift(
        centre: Offset(52.5, 38.5),
        radius: 2.5,
        color: FlowerColors.peonyPetalMid,
        period: Duration(milliseconds: 4800),
        delay: Duration(milliseconds: 1400),
      ),
    ],
  );

  static _OpeningMetrics of(ShellLayout layout) => switch (layout) {
    ShellLayout.sidebar => sidebar,
    ShellLayout.bottomBar => bottomBar,
  };

  final double headingTop;
  final double headingSide;
  final double kickerSize;
  final double titleSize;
  final double titleHeight;
  final double titleSpacing;
  final double titleGap;
  final double subtitleSize;
  final double subtitleGap;
  final double subtitleWidth;
  final String hint;
  final double hintBottom;
  final double hintSide;
  final double hintWidth;
  final double hintSize;
  final double? hintHeight;
  final double hintGap;
  final bool showEnter;
  final Size arrowSize;
  final double soilHeight;
  final double plantWidth;
  final double plantBottom;
  final Size seedSize;
  final double seedBottom;
  final double crumbBottom;
  final double crumbSpread;
  final List<_Drift> drifts;
}

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
    required this.ridge,
    required this.crust,
    required this.specks,
    required this.pebbles,
    required this.blades,
  });

  factory _Soil.generate({
    required double width,
    required double height,
    required int seed,
  }) {
    final double Function() next = _sequence(seed);
    final double peak = height * _soilPeak;
    double top(double x) {
      final double t = x / width * 2 - 1;
      return peak + (height * _soilShoulder - peak) * t * t;
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
      final double reach = height * _grassFloor + next() * height * _grassReach;
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
      for (int index = 0; index < (width / _speckSpacing).round(); index++)
        if (speck() case final _Speck found) found,
    ];
    final List<_Pebble> pebbles = <_Pebble>[
      for (int index = 0; index < (width / _pebbleSpacing).round(); index++)
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
  final List<Offset> ridge;
  final List<Offset> crust;
  final List<_Speck> specks;
  final List<_Pebble> pebbles;
  final List<_Blade> blades;
}

final _Soil _sidebarSoil = _Soil.generate(width: 1140, height: 220, seed: 71);

final _Soil _bottomBarSoil = _Soil.generate(width: 300, height: 150, seed: 33);

_Soil _soilOf(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => _sidebarSoil,
  ShellLayout.bottomBar => _bottomBarSoil,
};

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
    _paintShadow(canvas, design);
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

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double fit = math.min(
      size.width / _arrowViewBox.width,
      size.height / _arrowViewBox.height,
    );
    canvas.save();
    canvas.translate(
      (size.width - _arrowViewBox.width * fit) / 2,
      (size.height - _arrowViewBox.height * fit) / 2,
    );
    canvas.scale(fit);
    BloomPartPainter(
      strokeColor: color,
      strokeWidth: _arrowStroke,
    ).paintAll(canvas, _arrowParts);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => oldDelegate.color != color;
}

class _GrowthPainter extends CustomPainter {
  _GrowthPainter({
    required this.metrics,
    required this.growth,
    required this.loop,
  }) : super(repaint: Listenable.merge(<Listenable>[growth, loop]));

  final _OpeningMetrics metrics;
  final Animation<double> growth;
  final ValueListenable<Duration> loop;

  @override
  void paint(Canvas canvas, Size size) {
    final double elapsed = growth.value * _growDuration.inMicroseconds;
    final double looped = loop.value.inMicroseconds.toDouble();
    _paintPlant(canvas, size, elapsed, looped);
    _paintSeed(canvas, size, elapsed);
    _paintCrumbs(canvas, size, elapsed);
  }

  void _paintPlant(Canvas canvas, Size size, double elapsed, double looped) {
    final double scale = metrics.plantWidth / GardenPlantSpec.viewBoxWidth;
    canvas.save();
    canvas.translate(size.width / 2, size.height - metrics.plantBottom);
    canvas.rotate(_swayAt(looped));
    canvas.translate(-metrics.plantWidth / 2, -_peony.viewBoxHeight * scale);
    canvas.save();
    canvas.scale(scale);
    for (final _PartGroup group in _peonyGroups) {
      _paintGroup(canvas, group, elapsed);
    }
    canvas.restore();
    for (final _Drift drift in metrics.drifts) {
      _paintDrift(canvas, drift, looped);
    }
    canvas.restore();
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

  double _swayAt(double looped) {
    final double cycle = (looped / _swayPeriod.inMicroseconds + _swayPhase) % 1;
    final double swing = cycle < 0.5
        ? Curves.easeInOut.transform(cycle * 2)
        : 1 - Curves.easeInOut.transform((cycle - 0.5) * 2);
    return (2 * swing - 1) * _swayDegrees * math.pi / 180;
  }

  void _paintDrift(Canvas canvas, _Drift drift, double looped) {
    final double since = looped - drift.delay.inMicroseconds;
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
              size.height - metrics.crumbBottom - crumb.height + shift.dy,
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
  bool shouldRepaint(_GrowthPainter oldDelegate) =>
      oldDelegate.metrics != metrics ||
      oldDelegate.growth != growth ||
      oldDelegate.loop != loop;
}

class OpeningChapter extends ConsumerStatefulWidget {
  const OpeningChapter({super.key, required this.layout});

  final ShellLayout layout;

  @override
  ConsumerState<OpeningChapter> createState() => _OpeningChapterState();
}

class _OpeningChapterState extends ConsumerState<OpeningChapter>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: _hintDelay + _hintFadeIn,
  );
  late final AnimationController _growth = AnimationController(
    vsync: this,
    duration: _growDuration,
  )..addStatusListener(_onGrowth);
  late final Ticker _loop = createTicker(_onLoop);
  final ValueNotifier<Duration> _looped = ValueNotifier<Duration>(
    Duration.zero,
  );
  late final Listenable _hintMotion = Listenable.merge(<Listenable>[
    _entrance,
    _growth,
  ]);
  bool _still = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (!_started) {
      _started = true;
      if (_still) {
        _entrance.value = 1;
      } else {
        _entrance.forward();
      }
      _follow(_plantingOf(ref.read(onboardingControllerProvider)));
    } else if (_still) {
      _entrance.value = 1;
      if (_growth.isAnimating) {
        _growth.value = 1;
      }
      _stopLoop();
    } else if (_growth.isCompleted) {
      _startLoop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _growth.dispose();
    _entrance.dispose();
    _looped.dispose();
    super.dispose();
  }

  OnboardingController get _controller =>
      ref.read(onboardingControllerProvider.notifier);

  double get _elapsed => _growth.value * _growDuration.inMicroseconds;

  void _plant() => _controller.plant();

  void _follow(_Planting? planting) {
    if (planting == null) {
      return;
    }
    if (!planting.planted) {
      _growth.value = 0;
      _stopLoop();
    } else if (planting.grown || _still) {
      _growth.value = 1;
    } else if (_growth.isDismissed) {
      _growth.forward();
    }
  }

  void _onGrowth(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    scheduleMicrotask(_reportGrown);
    if (!_still) {
      _startLoop();
    }
  }

  void _reportGrown() {
    if (mounted &&
        _plantingOf(ref.read(onboardingControllerProvider)) ==
            (planted: true, grown: false)) {
      _controller.markGrown();
    }
  }

  void _onLoop(Duration elapsed) => _looped.value = elapsed;

  void _startLoop() {
    if (!_loop.isActive) {
      _loop.start();
    }
  }

  void _stopLoop() {
    _loop.stop();
    _looped.value = Duration.zero;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<_Planting?>(
      onboardingControllerProvider.select(_plantingOf),
      (_Planting? previous, _Planting? next) => _follow(next),
    );
    final _Planting? planting = ref.watch(
      onboardingControllerProvider.select(_plantingOf),
    );
    if (planting == null) {
      return const SizedBox.expand();
    }
    final bool planted = planting.planted;
    final ShellLayout layout = widget.layout;
    final _OpeningMetrics metrics = _OpeningMetrics.of(layout);
    final FieldNotesColors colors = context.colors;
    return SizedBox.expand(
      child: Semantics(
        container: true,
        button: planted ? null : true,
        label: planted ? null : _plantLabel,
        onTap: planted ? null : _plant,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: planted ? null : _plant,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                top: metrics.headingTop,
                child: _heading(metrics, colors, planted: planted),
              ),
              Positioned(
                left: metrics.hintSide,
                right: metrics.hintSide,
                bottom: metrics.hintBottom,
                child: _hint(metrics, colors),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: metrics.soilHeight,
                child: ExcludeSemantics(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _SoilPainter(_soilOf(layout))),
                  ),
                ),
              ),
              if (planted)
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _GrowthPainter(
                          metrics: metrics,
                          growth: _growth,
                          loop: _looped,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(
    _OpeningMetrics metrics,
    FieldNotesColors colors, {
    required bool planted,
  }) {
    return AnimatedBuilder(
      animation: _growth,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: metrics.headingSide),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Semantics(
              container: true,
              child: Text(
                _kicker,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TypographyTokens.accent,
                  fontSize: metrics.kickerSize,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: colors.accentInk,
                ),
              ),
            ),
            SizedBox(height: metrics.titleGap),
            Semantics(
              container: true,
              header: true,
              child: Text(
                _title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TypographyTokens.serif,
                  fontSize: metrics.titleSize,
                  fontWeight: FontWeight.w500,
                  height: metrics.titleHeight,
                  letterSpacing: metrics.titleSpacing,
                  color: colors.ink,
                ),
              ),
            ),
            SizedBox(height: metrics.subtitleGap),
            Semantics(
              container: true,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: metrics.subtitleWidth),
                child: Text(
                  _subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TypographyTokens.sans,
                    fontSize: metrics.subtitleSize,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    color: colors.mutedDeep,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      builder: (BuildContext context, Widget? child) {
        final double shown = Curves.ease.transform(
          _phase(_elapsed, _headingStart, _headingRise),
        );
        return Opacity(
          opacity: shown,
          alwaysIncludeSemantics: planted,
          child: Transform.translate(
            offset: Offset(0, _riseDistance * (1 - shown)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _hint(_OpeningMetrics metrics, FieldNotesColors colors) {
    return AnimatedBuilder(
      animation: _hintMotion,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: metrics.hintWidth),
              child: Text(
                metrics.hint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TypographyTokens.accent,
                  fontSize: metrics.hintSize,
                  fontWeight: FontWeight.w600,
                  height: metrics.hintHeight,
                  color: colors.ink,
                ),
              ),
            ),
            if (metrics.showEnter) ...<Widget>[
              SizedBox(height: metrics.hintGap),
              Text(
                _hintEnter,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TypographyTokens.sans,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.muted,
                ),
              ),
            ],
            SizedBox(height: metrics.hintGap),
            SizedBox.fromSize(
              size: metrics.arrowSize,
              child: CustomPaint(painter: _ArrowPainter(colors.ink)),
            ),
          ],
        ),
      ),
      builder: (BuildContext context, Widget? child) {
        final double gone = Curves.ease.transform(
          _phase(_elapsed, Duration.zero, _hintFadeOut),
        );
        if (gone >= 1) {
          return const SizedBox.shrink();
        }
        final double shown = Curves.ease.transform(
          _phase(
            _entrance.value * (_hintDelay + _hintFadeIn).inMicroseconds,
            _hintDelay,
            _hintFadeIn,
          ),
        );
        return Opacity(opacity: shown * (1 - gone), child: child);
      },
    );
  }
}
