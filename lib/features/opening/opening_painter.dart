import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/bloom_part.dart';
import 'package:field_notes/design/flowers/petal_art.dart';
import 'package:field_notes/domain/mood/flower_kind.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';

import 'opening_art.dart';
import 'opening_plan.dart';

OpeningPlan openingPlanFor(BuildContext context) =>
    openingPlan(still: MediaQuery.disableAnimationsOf(context));

double openingRevealAlpha(OpeningPlan plan, double seconds) =>
    1 - _easeInOutCubic(_progress(seconds, plan.reveal.start, plan.reveal.end));

double _clamp01(double value) => value.clamp(0.0, 1.0).toDouble();

double _progress(double t, double from, double to) =>
    to <= from ? (t >= to ? 1 : 0) : _clamp01((t - from) / (to - from));

double _easeInOutCubic(double t) =>
    t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;

double _easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();

double _easeOut(double t) => 1 - (1 - t) * (1 - t);

double _easeInOutSine(double t) => -(math.cos(math.pi * t) - 1) / 2;

const double _phonePlantShare = 0.29;
const double _desktopPlantShare = 0.40;
const double _phoneCentreShare = 0.46;
const double _plantViewHeight = 190;
const double _drawingMiddle = 122;
const double _plantMiddleX = 50;

const double _bendAmount = 0.85;
const double _bendSway = 0.05;
const double _bendSwayRate = 11;
const double _releaseDamping = 3.2;
const double _releaseRate = 8;
const double _headSway = 16;
const double _headDrop = 1.6;
const double _headTurnDegrees = 15;
const Offset _headPivot = Offset(50, 92);
const Offset _coreCentre = Offset(50, 78);
const double _discShrinkSeconds = 0.14;

const List<Offset> _leafPivots = <Offset>[Offset(50, 148), Offset(50, 126)];
const List<Offset> _leafCentres = <Offset>[Offset(30, 153), Offset(70, 131)];
const List<double> _leafLean = <double>[9, 6];
const double _leafFlutter = 4;
const double _leafFlutterRate = 13;
const double _leafFlutterPhase = 1.7;
const double _leafReachSpan = 98;

const double _gustHeadSeconds = 0.5;
const double _gustTailDelay = 0.36;
const double _ribbonHalfWidth = 1.3;
const double _ribbonTaper = 0.7;
const double _ribbonFloor = 0.12;
const double _shortestRibbon = 0.6;
const double _windAlphaLight = 0.62;
const double _windAlphaDark = 0.55;

const int _flightSeed = 23;
const double _petalSpacing = 0.05;
const double _petalJitter = 0.02;
const double _petalSpread = 1.2;
const double _petalFan = 0.9;
const double _petalReach = 0.35;
const double _petalSizeShare = 0.85;
const double _corePetalSizeShare = 0.7;
const double _petalGrowth = 1.2;
const double _petalFadeIn = 0.08;
const double _flipFloor = 0.14;
const double _offRight = 80;
const double _offVertical = 100;

class _Flight {
  const _Flight({
    required this.vx,
    required this.vy,
    required this.ax,
    required this.g,
    required this.spin,
    required this.flipW,
    required this.flut,
    required this.flutW,
  });

  final (double, double) vx;
  final (double, double) vy;
  final (double, double) ax;
  final double g;
  final (double, double) spin;
  final (double, double) flipW;
  final (double, double) flut;
  final (double, double) flutW;
}

const _Flight _petalFlight = _Flight(
  vx: (0.55, 0.85),
  vy: (-0.34, -0.08),
  ax: (0.5, 0.9),
  g: 0.24,
  spin: (3, 7),
  flipW: (5, 9),
  flut: (0.006, 0.018),
  flutW: (5, 9),
);

const _Flight _leafFlight = _Flight(
  vx: (0.38, 0.52),
  vy: (-0.2, -0.08),
  ax: (0.35, 0.55),
  g: 0.34,
  spin: (2, 4),
  flipW: (3, 5),
  flut: (0.01, 0.02),
  flutW: (3, 5),
);

const List<OpeningInk> _discInks = <OpeningInk>[
  OpeningInk.disc0,
  OpeningInk.disc1,
  OpeningInk.disc2,
  OpeningInk.disc3,
  OpeningInk.disc4,
  OpeningInk.disc5,
];

const List<OpeningInk> _leafInks = <OpeningInk>[
  OpeningInk.leftLeaf,
  OpeningInk.rightLeaf,
];

@immutable
class OpeningLayout {
  const OpeningLayout({
    required this.size,
    required this.scale,
    required this.origin,
    required this.screen,
  });

  factory OpeningLayout.of(Size size, ShellLayout shell, double topInset) {
    final double height = size.height;
    final (double scale, double centreY) = switch (shell) {
      ShellLayout.bottomBar => (
        _phonePlantShare * height / _plantViewHeight,
        topInset + (height - topInset) * _phoneCentreShare,
      ),
      ShellLayout.sidebar => (
        _desktopPlantShare * height / _plantViewHeight,
        height / 2,
      ),
    };
    return OpeningLayout(
      size: size,
      scale: scale,
      origin: Offset(
        size.width / 2 - _plantMiddleX * scale,
        centreY - _drawingMiddle * scale,
      ),
      screen: switch (shell) {
        ShellLayout.bottomBar => PetalScreen.narrow,
        ShellLayout.sidebar => PetalScreen.wide,
      },
    );
  }

  final Size size;
  final double scale;
  final Offset origin;
  final PetalScreen screen;

  Offset toScreen(Offset plant) => origin + plant * scale;

  @override
  bool operator ==(Object other) =>
      other is OpeningLayout &&
      other.size == size &&
      other.scale == scale &&
      other.origin == origin &&
      other.screen == screen;

  @override
  int get hashCode => Object.hash(size, scale, origin, screen);
}

class _Pose {
  const _Pose({
    required this.dx,
    required this.dy,
    required this.headDegrees,
    required this.leafDegrees,
  });

  factory _Pose.at(OpeningPlan plan, double t) {
    final double bend = _bendAt(plan, t);
    return _Pose(
      dx: _headSway * bend,
      dy: _headDrop * bend.abs(),
      headDegrees: _headTurnDegrees * bend,
      leafDegrees: <double>[
        for (int i = 0; i < 2; i++)
          bend * _leafLean[i] +
              _leafFlutter *
                  bend *
                  math.sin(_leafFlutterRate * t + _leafFlutterPhase * i),
      ],
    );
  }

  final double dx;
  final double dy;
  final double headDegrees;
  final List<double> leafDegrees;

  Offset head(Offset point) =>
      _rotateAround(point, _headPivot, headDegrees) + Offset(dx, dy);

  Offset leaf(int index, Offset point) {
    final Offset pivot = _leafPivots[index];
    return _rotateAround(point, pivot, leafDegrees[index]) +
        Offset(dx * _leafReach(pivot), 0);
  }

  void applyHead(Canvas canvas) {
    canvas
      ..translate(dx + _headPivot.dx, dy + _headPivot.dy)
      ..rotate(headDegrees * math.pi / 180)
      ..translate(-_headPivot.dx, -_headPivot.dy);
  }

  void applyLeaf(Canvas canvas, int index) {
    final Offset pivot = _leafPivots[index];
    canvas
      ..translate(dx * _leafReach(pivot) + pivot.dx, pivot.dy)
      ..rotate(leafDegrees[index] * math.pi / 180)
      ..translate(-pivot.dx, -pivot.dy);
  }
}

double _leafReach(Offset pivot) =>
    math.pow((_plantViewHeight - pivot.dy) / _leafReachSpan, 2).toDouble();

Offset _rotateAround(Offset point, Offset pivot, double degrees) {
  final double radians = degrees * math.pi / 180;
  final Offset d = point - pivot;
  return pivot +
      Offset(
        d.dx * math.cos(radians) - d.dy * math.sin(radians),
        d.dx * math.sin(radians) + d.dy * math.cos(radians),
      );
}

double _bendAt(OpeningPlan plan, double t) {
  final OpeningSpan bend = plan.bend;
  if (!(t >= bend.start)) {
    return 0;
  }
  final double rise = _easeOutCubic(_progress(t, bend.start, bend.end));
  final double since = t - bend.start;
  final double value =
      _bendAmount * rise * (1 + _bendSway * math.sin(_bendSwayRate * since));
  if (t > plan.bendRelease) {
    final double u = t - plan.bendRelease;
    return value * math.exp(-_releaseDamping * u) * math.cos(_releaseRate * u);
  }
  return value;
}

class _Polyline {
  _Polyline(this.points) : lengths = _cumulative(points) {
    path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final Offset point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
  }

  final List<Offset> points;
  final List<double> lengths;
  late final Path path;

  double get length => lengths.last;

  static List<double> _cumulative(List<Offset> points) {
    final List<double> lengths = <double>[0];
    for (int i = 1; i < points.length; i++) {
      lengths.add(lengths.last + (points[i] - points[i - 1]).distance);
    }
    return List<double>.unmodifiable(lengths);
  }

  Offset pointAt(double s) {
    if (s <= 0) {
      return points.first;
    }
    if (s >= length) {
      return points.last;
    }
    int lo = 0;
    int hi = points.length - 1;
    while (hi - lo > 1) {
      final int mid = (lo + hi) >> 1;
      if (lengths[mid] < s) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final double span = lengths[hi] - lengths[lo];
    final double f = span == 0 ? 0 : (s - lengths[lo]) / span;
    return Offset.lerp(points[lo], points[hi], f)!;
  }

  Path upTo(double s) {
    final Path partial = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      if (lengths[i] <= s) {
        partial.lineTo(points[i].dx, points[i].dy);
        continue;
      }
      final double span = lengths[i] - lengths[i - 1];
      final double f = span == 0 ? 0 : (s - lengths[i - 1]) / span;
      final Offset end = Offset.lerp(points[i - 1], points[i], f)!;
      partial.lineTo(end.dx, end.dy);
      break;
    }
    return partial;
  }

  Path? ribbon(double from, double to) {
    if (to - from < _shortestRibbon) {
      return null;
    }
    final List<(Offset, double)> spine = <(Offset, double)>[
      (pointAt(from), from),
      for (int i = 0; i < points.length; i++)
        if (lengths[i] > from && lengths[i] < to) (points[i], lengths[i]),
      (pointAt(to), to),
    ];
    final List<Offset> left = <Offset>[];
    final List<Offset> right = <Offset>[];
    for (int i = 0; i < spine.length; i++) {
      final Offset before = spine[math.max(0, i - 1)].$1;
      final Offset after = spine[math.min(spine.length - 1, i + 1)].$1;
      final Offset along = after - before;
      final double distance = along.distance == 0 ? 1 : along.distance;
      final Offset unit = along / distance;
      final double f = (spine[i].$2 - from) / (to - from);
      final double half =
          _ribbonHalfWidth *
              math.pow(math.sin(math.pi * _clamp01(f)), _ribbonTaper) +
          _ribbonFloor;
      final Offset normal = Offset(-unit.dy, unit.dx) * half;
      left.add(spine[i].$1 + normal);
      right.add(spine[i].$1 - normal);
    }
    final Path outline = Path()..moveTo(left.first.dx, left.first.dy);
    for (final Offset point in left.skip(1)) {
      outline.lineTo(point.dx, point.dy);
    }
    for (final Offset point in right.reversed) {
      outline.lineTo(point.dx, point.dy);
    }
    return outline..close();
  }
}

class _StrokeArt {
  _StrokeArt(this.stroke) : line = _Polyline(stroke.points);

  final OpeningStroke stroke;
  final _Polyline line;
}

int _layerOf(OpeningInk ink) => switch (ink) {
  OpeningInk.leftLeaf => 1,
  OpeningInk.leftVein => 2,
  OpeningInk.rightLeaf => 3,
  OpeningInk.rightVein => 4,
  OpeningInk.stem => 5,
  OpeningInk.mound => 8,
  OpeningInk.tuft => 9,
  OpeningInk.disc0 => 20,
  OpeningInk.disc1 => 21,
  OpeningInk.disc2 => 22,
  OpeningInk.disc3 => 23,
  OpeningInk.disc4 => 24,
  OpeningInk.disc5 => 25,
  OpeningInk.crease => 40,
};

class _PlanArt {
  _PlanArt(OpeningPlan plan)
    : layered = List<_StrokeArt>.unmodifiable(
        <_StrokeArt>[
          for (final OpeningStroke stroke in plan.strokes) _StrokeArt(stroke),
        ]..sort(
          (_StrokeArt a, _StrokeArt b) =>
              _layerOf(a.stroke.ink).compareTo(_layerOf(b.stroke.ink)),
        ),
      ),
      curls = List<_Polyline>.unmodifiable(<_Polyline>[
        for (final OpeningPolyline curl in openingCurlPolylines)
          _Polyline(curl.points),
      ]),
      sketchEnd = math.min(
        plan.washes.values
            .map((OpeningSpan wash) => wash.end)
            .fold(double.negativeInfinity, math.max),
        plan.bend.start,
      );

  final List<_StrokeArt> layered;
  final List<_Polyline> curls;
  final double sketchEnd;
  (OpeningLayout, List<_Piece>)? _pieces;

  List<_Piece> piecesFor(OpeningPlan plan, OpeningLayout layout) {
    final (OpeningLayout, List<_Piece>)? cached = _pieces;
    if (cached != null && cached.$1 == layout) {
      return cached.$2;
    }
    final List<_Piece> built = _buildPieces(plan, layout);
    _pieces = (layout, built);
    return built;
  }
}

final Expando<_PlanArt> _planArts = Expando<_PlanArt>('opening plan art');

_PlanArt _artFor(OpeningPlan plan) => _planArts[plan] ??= _PlanArt(plan);

sealed class _Piece {
  const _Piece({
    required this.t0,
    required this.start,
    required this.rot0,
    required this.motion,
  });

  final double t0;
  final Offset start;
  final double rot0;
  final _Motion motion;
}

final class _PetalPiece extends _Piece {
  const _PetalPiece({
    required super.t0,
    required super.start,
    required super.rot0,
    required super.motion,
    required this.size0,
    required this.alternate,
  });

  final double size0;
  final bool alternate;
}

final class _LeafPiece extends _Piece {
  const _LeafPiece({
    required super.t0,
    required super.start,
    required super.rot0,
    required super.motion,
    required this.leaf,
  });

  final int leaf;
}

class _Motion {
  const _Motion({
    required this.vx,
    required this.vy,
    required this.ax,
    required this.g,
    required this.spin,
    required this.flipW,
    required this.flipP,
    required this.flut,
    required this.flutW,
    required this.flutP,
  });

  factory _Motion.draw(MeadowRandom random, _Flight flight, Size size) {
    double pick((double, double) range) => random.between(range.$1, range.$2);
    final double vx = pick(flight.vx) * size.width;
    final double vy = pick(flight.vy) * size.height;
    final double ax = pick(flight.ax) * size.width;
    final double spinMagnitude = pick(flight.spin);
    final double spin = random.next() < 0.25 ? -spinMagnitude : spinMagnitude;
    final double flipW = pick(flight.flipW);
    final double flipP = (random.next() - 0.5) * 0.6;
    final double flut = pick(flight.flut) * size.height;
    final double flutW = pick(flight.flutW);
    final double flutP = random.next() * 2 * math.pi;
    return _Motion(
      vx: vx,
      vy: vy,
      ax: ax,
      g: flight.g * size.height,
      spin: spin,
      flipW: flipW,
      flipP: flipP,
      flut: flut,
      flutW: flutW,
      flutP: flutP,
    );
  }

  final double vx;
  final double vy;
  final double ax;
  final double g;
  final double spin;
  final double flipW;
  final double flipP;
  final double flut;
  final double flutW;
  final double flutP;
}

List<_Piece> _buildPieces(OpeningPlan plan, OpeningLayout layout) {
  if (plan.sheds.isEmpty) {
    return const <_Piece>[];
  }
  final MeadowRandom random = MeadowRandom(_flightSeed);
  final List<_Piece> pieces = <_Piece>[];
  for (int d = 0; d < openingDiscs.length; d++) {
    final BloomDisc disc = openingDiscs[d];
    final bool core = d == openingDiscs.length - 1;
    final int count = core ? 3 : 2;
    final double shed = _shedOf(plan, _discInks[d]);
    for (int j = 0; j < count; j++) {
      final double t0 = shed + _petalSpacing * j + _petalJitter * random.next();
      final _Pose pose = _Pose.at(plan, t0);
      final double angle =
          math.atan2(
            disc.cy - _coreCentre.dy,
            disc.cx - _coreCentre.dx + 0.001,
          ) +
          (random.next() - 0.5) * _petalSpread +
          (j - (count - 1) / 2) * _petalFan;
      final bool alternate = random.next() < 0.5;
      final _Motion motion = _Motion.draw(random, _petalFlight, layout.size);
      final Offset root = Offset(
        disc.cx + math.cos(angle) * _petalReach * disc.r,
        disc.cy + math.sin(angle) * _petalReach * disc.r,
      );
      pieces.add(
        _PetalPiece(
          t0: t0,
          start: layout.toScreen(pose.head(root)),
          rot0: angle + math.pi / 2 + pose.headDegrees * math.pi / 180,
          motion: motion,
          size0:
              disc.r *
              2 *
              layout.scale *
              (core ? _corePetalSizeShare : _petalSizeShare),
          alternate: alternate,
        ),
      );
    }
  }
  for (int i = 0; i < _leafInks.length; i++) {
    final double t0 = _shedOf(plan, _leafInks[i]);
    final _Pose pose = _Pose.at(plan, t0);
    pieces.add(
      _LeafPiece(
        t0: t0,
        start: layout.toScreen(pose.leaf(i, _leafCentres[i])),
        rot0: pose.leafDegrees[i] * math.pi / 180,
        motion: _Motion.draw(random, _leafFlight, layout.size),
        leaf: i,
      ),
    );
  }
  return List<_Piece>.unmodifiable(pieces);
}

double _shedOf(OpeningPlan plan, OpeningInk ink) =>
    plan.sheds[ink] ??
    (throw StateError('The moving plan sheds no time for $ink.'));

final PetalArt _petalArt =
    petalArtFor(FlowerKind.peony) ??
    (throw StateError('There is no peony petal art.'));

class OpeningPainter extends CustomPainter {
  OpeningPainter({
    required this.plan,
    required this.seconds,
    required this.paper,
    required this.ink,
    required this.brightness,
    required this.shell,
    required this.topInset,
    required this.paintsPaper,
    required this.fade,
  });

  final OpeningPlan plan;
  final double seconds;
  final Color paper;
  final Color ink;
  final Brightness brightness;
  final ShellLayout shell;
  final double topInset;
  final bool paintsPaper;
  final double fade;

  @override
  void paint(Canvas canvas, Size size) {
    final OpeningLayout layout = OpeningLayout.of(size, shell, topInset);
    final _PlanArt art = _artFor(plan);
    final double t = seconds;
    final double alpha = openingRevealAlpha(plan, t) * fade;
    if (paintsPaper && alpha > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = _faded(paper, alpha),
      );
    }
    if (alpha > 0) {
      canvas
        ..save()
        ..translate(layout.origin.dx, layout.origin.dy)
        ..scale(layout.scale);
      if (!plan.still && t < art.sketchEnd) {
        _paintSketch(canvas, art, t, alpha);
      } else {
        _paintPosed(canvas, t, alpha);
      }
      canvas.restore();
    }
    if (!plan.still && fade > 0) {
      _paintWind(canvas, art, layout, t);
    }
    if (fade > 0) {
      _paintPieces(canvas, art.piecesFor(plan, layout), layout, t);
    }
  }

  void _paintSketch(Canvas canvas, _PlanArt art, double t, double alpha) {
    _wash(canvas, OpeningInk.leftLeaf, openingLeftLeafWashBlob, t, () {
      canvas.drawPath(
        openingLeftLeafPath,
        _fill(_shapeFill(openingLeftLeafShape), alpha),
      );
    });
    _wash(canvas, OpeningInk.rightLeaf, openingRightLeafWashBlob, t, () {
      canvas.drawPath(
        openingRightLeafPath,
        _fill(_shapeFill(openingRightLeafShape), alpha),
      );
    });
    _wash(canvas, OpeningInk.mound, openingMoundWashBlob, t, () {
      canvas.drawPath(openingMoundFillPath, _fill(openingMoundFill, alpha));
    });
    for (int d = 0; d < openingDiscs.length; d++) {
      final BloomDisc disc = openingDiscs[d];
      _wash(canvas, _discInks[d], openingDiscWashBlobs[d], t, () {
        canvas.drawCircle(
          Offset(disc.cx, disc.cy),
          disc.r,
          _fill(_discFill(disc), alpha),
        );
      });
    }
    for (final _StrokeArt stroke in art.layered) {
      final OpeningStroke timing = stroke.stroke;
      if (t < timing.start) {
        continue;
      }
      final Paint paint = _inkPaint(timing.ink, alpha);
      if (t >= timing.end) {
        canvas.drawPath(stroke.line.path, paint);
        continue;
      }
      final double k = _easeInOutSine(_progress(t, timing.start, timing.end));
      canvas.drawPath(stroke.line.upTo(k * stroke.line.length), paint);
    }
  }

  void _wash(
    Canvas canvas,
    OpeningInk part,
    OpeningWashBlob blob,
    double t,
    VoidCallback paintPart,
  ) {
    final OpeningSpan span =
        plan.washes[part] ??
        (throw StateError('The plan has no wash for $part.'));
    final double growth = _easeOutCubic(_progress(t, span.start, span.end));
    if (growth <= 0) {
      return;
    }
    canvas.save();
    if (growth < 1) {
      canvas.clipPath(openingWashBlobPath(blob, growth));
    }
    paintPart();
    canvas.restore();
  }

  void _paintPosed(Canvas canvas, double t, double alpha) {
    final _Pose pose = _Pose.at(plan, t);
    for (int i = 0; i < _leafInks.length; i++) {
      final double? shed = plan.sheds[_leafInks[i]];
      if (shed != null && t >= shed) {
        continue;
      }
      canvas.save();
      pose.applyLeaf(canvas, i);
      _paintLeaf(canvas, i, alpha);
      canvas.restore();
    }
    final Path stem = Path()
      ..moveTo(50, 190)
      ..cubicTo(
        46 + 0.12 * pose.dx,
        150,
        53 + 0.5 * pose.dx,
        116,
        50 + pose.dx,
        92 + pose.dy,
      );
    canvas.drawPath(stem, _inkPaint(OpeningInk.stem, alpha));
    canvas
      ..drawPath(openingMoundFillPath, _fill(openingMoundFill, alpha))
      ..drawPath(openingMoundTopPath, _inkPaint(OpeningInk.mound, alpha));
    for (final Path tuft in openingTuftPaths) {
      canvas.drawPath(tuft, _inkPaint(OpeningInk.tuft, alpha));
    }
    canvas.save();
    pose.applyHead(canvas);
    double coreScale = 1;
    for (int d = 0; d < openingDiscs.length; d++) {
      final BloomDisc disc = openingDiscs[d];
      final double? shed = plan.sheds[_discInks[d]];
      final double shrink = shed == null || t < shed
          ? 1
          : 1 - _easeInOutCubic(_progress(t, shed, shed + _discShrinkSeconds));
      if (d == openingDiscs.length - 1) {
        coreScale = shrink;
      }
      if (shrink <= 0) {
        continue;
      }
      final Offset centre = Offset(disc.cx, disc.cy);
      canvas
        ..drawCircle(centre, disc.r * shrink, _fill(_discFill(disc), alpha))
        ..drawCircle(centre, disc.r * shrink, _inkPaint(_discInks[d], alpha));
    }
    if (coreScale > 0) {
      canvas
        ..translate(_coreCentre.dx, _coreCentre.dy)
        ..scale(coreScale)
        ..translate(-_coreCentre.dx, -_coreCentre.dy)
        ..drawPath(openingCreasePath, _inkPaint(OpeningInk.crease, alpha));
    }
    canvas.restore();
  }

  void _paintLeaf(Canvas canvas, int index, double alpha) {
    final (
      BloomShape leaf,
      Path outline,
      Path vein,
      OpeningInk outlineInk,
      OpeningInk veinInk,
    ) = index == 0
        ? (
            openingLeftLeafShape,
            openingLeftLeafPath,
            openingLeftVeinPath,
            OpeningInk.leftLeaf,
            OpeningInk.leftVein,
          )
        : (
            openingRightLeafShape,
            openingRightLeafPath,
            openingRightVeinPath,
            OpeningInk.rightLeaf,
            OpeningInk.rightVein,
          );
    canvas
      ..drawPath(outline, _fill(_shapeFill(leaf), alpha))
      ..drawPath(outline, _inkPaint(outlineInk, alpha))
      ..drawPath(vein, _inkPaint(veinInk, alpha));
  }

  void _paintWind(Canvas canvas, _PlanArt art, OpeningLayout layout, double t) {
    final double windAlpha =
        switch (brightness) {
          Brightness.light => _windAlphaLight,
          Brightness.dark => _windAlphaDark,
        } *
        fade;
    final Paint paint = Paint()
      ..color = ink.withValues(alpha: ink.a * windAlpha)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas
      ..save()
      ..translate(layout.origin.dx, layout.origin.dy)
      ..scale(layout.scale);
    for (int c = 0; c < art.curls.length && c < plan.gustStarts.length; c++) {
      final double gust = plan.gustStarts[c];
      final _Polyline curl = art.curls[c];
      final double head =
          _easeInOutSine(_progress(t, gust, gust + _gustHeadSeconds)) *
          curl.length;
      final double tail =
          _easeInOutSine(
            _progress(
              t,
              gust + _gustTailDelay,
              gust + _gustTailDelay + _gustHeadSeconds,
            ),
          ) *
          curl.length;
      final Path? ribbon = curl.ribbon(tail, head);
      if (ribbon != null) {
        canvas.drawPath(ribbon, paint);
      }
    }
    canvas.restore();
  }

  void _paintPieces(
    Canvas canvas,
    List<_Piece> pieces,
    OpeningLayout layout,
    double t,
  ) {
    final Size size = layout.size;
    final double driftSize =
        _petalArt.sizeOn(layout.screen).longestSide * _petalGrowth;
    for (final _Piece piece in pieces) {
      final double u = t - piece.t0;
      if (u < 0) {
        continue;
      }
      final _Motion m = piece.motion;
      final double x = piece.start.dx + m.vx * u + 0.5 * m.ax * u * u;
      final double y =
          piece.start.dy +
          m.vy * u +
          0.5 * m.g * u * u +
          m.flut * math.sin(m.flutW * u + m.flutP) * math.min(1, 2 * u);
      if (x > size.width + _offRight ||
          y < -_offVertical ||
          y > size.height + _offVertical) {
        continue;
      }
      final double rotation = piece.rot0 + m.spin * u;
      final double turn = math.cos(m.flipP + m.flipW * u);
      final double flip =
          (turn < 0 ? -1 : 1) * math.max(_flipFloor, turn.abs());
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(rotation);
      switch (piece) {
        case _PetalPiece():
          final double side =
              piece.size0 + (driftSize - piece.size0) * _easeOut(_clamp01(u));
          canvas.scale(flip, 1);
          _petalArt.paint(
            canvas,
            size: Size.square(side),
            opacity: math.min(1, u / _petalFadeIn) * fade,
            alternate: piece.alternate,
          );
        case _LeafPiece():
          final Offset centre = _leafCentres[piece.leaf];
          canvas
            ..scale(flip * layout.scale, layout.scale)
            ..translate(-centre.dx, -centre.dy);
          _paintLeaf(canvas, piece.leaf, fade);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(OpeningPainter oldDelegate) =>
      oldDelegate.seconds != seconds ||
      oldDelegate.plan != plan ||
      oldDelegate.paper != paper ||
      oldDelegate.ink != ink ||
      oldDelegate.brightness != brightness ||
      oldDelegate.shell != shell ||
      oldDelegate.topInset != topInset ||
      oldDelegate.paintsPaper != paintsPaper ||
      oldDelegate.fade != fade;
}

Color _faded(Color color, double alpha) =>
    color.withValues(alpha: color.a * alpha);

Paint _fill(Color color, double alpha) => Paint()
  ..color = _faded(color, alpha)
  ..style = PaintingStyle.fill
  ..isAntiAlias = true;

Color _shapeFill(BloomShape shape) =>
    shape.fill ?? (throw StateError('The leaf shape has no fill.'));

Color _discFill(BloomDisc disc) =>
    disc.fill ?? (throw StateError('A petal disc has no fill.'));

(Color, double) _inkOf(OpeningInk ink) => switch (ink) {
  OpeningInk.disc0 ||
  OpeningInk.disc1 ||
  OpeningInk.disc2 ||
  OpeningInk.disc3 ||
  OpeningInk.disc4 ||
  OpeningInk.disc5 => (openingPetalInk, openingPetalInkWidth),
  OpeningInk.crease => _shapeInk(openingCreaseShape),
  OpeningInk.stem => _shapeInk(openingStemShape),
  OpeningInk.mound => (openingMoundInk, openingMoundInkWidth),
  OpeningInk.tuft => (openingTuftInk, openingTuftInkWidth),
  OpeningInk.leftLeaf => _shapeInk(openingLeftLeafShape),
  OpeningInk.leftVein => _shapeInk(openingLeftVeinShape),
  OpeningInk.rightLeaf => _shapeInk(openingRightLeafShape),
  OpeningInk.rightVein => _shapeInk(openingRightVeinShape),
};

(Color, double) _shapeInk(BloomShape shape) => (
  shape.strokeColor ?? (throw StateError('A plant shape has no ink.')),
  shape.strokeWidth ?? (throw StateError('A plant shape has no width.')),
);

Paint _inkPaint(OpeningInk ink, double alpha) {
  final (Color colour, double width) = _inkOf(ink);
  final bool petal = switch (ink) {
    OpeningInk.disc0 ||
    OpeningInk.disc1 ||
    OpeningInk.disc2 ||
    OpeningInk.disc3 ||
    OpeningInk.disc4 ||
    OpeningInk.disc5 => true,
    OpeningInk.crease ||
    OpeningInk.stem ||
    OpeningInk.mound ||
    OpeningInk.tuft ||
    OpeningInk.leftLeaf ||
    OpeningInk.leftVein ||
    OpeningInk.rightLeaf ||
    OpeningInk.rightVein => false,
  };
  return Paint()
    ..color = _faded(colour, alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = petal ? StrokeCap.butt : StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
}
