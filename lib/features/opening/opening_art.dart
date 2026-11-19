import 'dart:math' as math;
import 'dart:ui';

import 'package:field_notes/design/flowers/bloom_part.dart';
import 'package:field_notes/design/flowers/bloom_part_painter.dart';
import 'package:field_notes/design/flowers/flower_palette.dart';
import 'package:field_notes/design/flowers/garden_plant_geometry.dart';
import 'package:field_notes/design/flowers/garden_plant_spec.dart';
import 'package:field_notes/domain/mood/flower_kind.dart';

const double openingSampleStep = 0.8;

const Color openingMoundFill = Color(0xFFA9875F);
const Color openingMoundInk = Color(0xFF5B4632);
const double openingMoundInkWidth = 2;
const Color openingTuftInk = FlowerColors.gardenLeafStroke;
const double openingTuftInkWidth = 1.6;

class OpeningPolyline {
  OpeningPolyline(List<Offset> points)
    : points = List<Offset>.unmodifiable(points),
      length = polylineLength(points);

  final List<Offset> points;
  final double length;

  Offset get first => points.first;
  Offset get last => points.last;

  OpeningPolyline reversed() => OpeningPolyline(points.reversed.toList());
}

double polylineLength(List<Offset> points) {
  double length = 0;
  for (int i = 1; i < points.length; i++) {
    length += (points[i] - points[i - 1]).distance;
  }
  return length;
}

OpeningPolyline sampleOpeningPath(
  Path path, {
  double step = openingSampleStep,
}) {
  final List<Offset> points = <Offset>[];
  for (final PathMetric metric in path.computeMetrics()) {
    final int count = math.max(2, (metric.length / step).ceil());
    for (int i = 0; i <= count; i++) {
      final Tangent? tangent = metric.getTangentForOffset(
        metric.length * i / count,
      );
      if (tangent == null) {
        throw StateError('The path has no point at ${i / count} of a contour.');
      }
      points.add(tangent.position);
    }
  }
  if (points.isEmpty) {
    throw ArgumentError.value(path, 'path', 'has no contour to sample');
  }
  return OpeningPolyline(points);
}

OpeningPolyline openingArc(
  BloomDisc disc,
  double fromAngle,
  double toAngle, {
  double step = openingSampleStep,
}) {
  final int count = math.max(
    2,
    (disc.r * (toAngle - fromAngle).abs() / step).ceil(),
  );
  return OpeningPolyline(<Offset>[
    for (int i = 0; i <= count; i++)
      _onCircle(disc, fromAngle + (toAngle - fromAngle) * i / count),
  ]);
}

Offset _onCircle(BloomDisc disc, double angle) => Offset(
  disc.cx + disc.r * math.cos(angle),
  disc.cy + disc.r * math.sin(angle),
);

T _peonyPart<T extends BloomPart>(int index) {
  final BloomPart part = peonyPlantParts[index];
  if (part is T) {
    return part;
  }
  throw StateError('peonyPlantParts[$index] is ${part.runtimeType}, not $T.');
}

final BloomShape openingStemShape = _peonyPart<BloomShape>(0);
final BloomShape openingLeftLeafShape = _peonyPart<BloomShape>(1);
final BloomShape openingLeftVeinShape = _peonyPart<BloomShape>(2);
final BloomShape openingRightLeafShape = _peonyPart<BloomShape>(3);
final BloomShape openingRightVeinShape = _peonyPart<BloomShape>(4);
final List<BloomDisc> openingDiscs = List<BloomDisc>.unmodifiable(<BloomDisc>[
  for (int index = 5; index <= 10; index++) _peonyPart<BloomDisc>(index),
]);
final BloomShape openingCreaseShape = _peonyPart<BloomShape>(11);

final Color openingPetalInk = gardenPlantSpecFor(FlowerKind.peony).strokeColor;
final double openingPetalInkWidth = gardenPlantSpecFor(FlowerKind.peony)
    .strokeWidth;

final Path openingStemPath = bloomShapePath(openingStemShape);
final Path openingLeftLeafPath = bloomShapePath(openingLeftLeafShape);
final Path openingLeftVeinPath = bloomShapePath(openingLeftVeinShape);
final Path openingRightLeafPath = bloomShapePath(openingRightLeafShape);
final Path openingRightVeinPath = bloomShapePath(openingRightVeinShape);
final Path openingCreasePath = bloomShapePath(openingCreaseShape);

final Path openingMoundTopPath = Path()
  ..moveTo(7, 195)
  ..cubicTo(19, 181, 81, 181, 93, 195);

final Path openingMoundFillPath = Path()
  ..moveTo(7, 195)
  ..cubicTo(19, 181, 81, 181, 93, 195)
  ..close();

final List<Path> openingTuftPaths = List<Path>.unmodifiable(<Path>[
  _segment(const Offset(20, 187), const Offset(17, 180)),
  _segment(const Offset(24, 186), const Offset(25, 178)),
  _segment(const Offset(75, 186), const Offset(74, 178)),
  _segment(const Offset(79, 187), const Offset(83, 180)),
]);

Path _segment(Offset from, Offset to) => Path()
  ..moveTo(from.dx, from.dy)
  ..lineTo(to.dx, to.dy);

class OpeningCurl {
  const OpeningCurl({
    required this.from,
    required this.to,
    required this.radius,
    required this.wave,
  });

  final Offset from;
  final Offset to;
  final double radius;
  final double wave;

  OpeningPolyline get polyline {
    final Offset centre = Offset(to.dx, to.dy - radius);
    return OpeningPolyline(<Offset>[
      for (int i = 0; i <= 140; i++) _waveAt(i / 140),
      for (int k = 1; k <= 90; k++) _loopAt(centre, k / 90),
    ]);
  }

  Offset _waveAt(double u) {
    final Offset along = Offset.lerp(from, to, u)!;
    return Offset(
      along.dx,
      along.dy + wave * math.sin(2 * math.pi * u) * (1 - u),
    );
  }

  Offset _loopAt(Offset centre, double f) {
    final double angle = math.pi / 2 - 1.7 * math.pi * f;
    final double reach = radius * (1 - 0.62 * f);
    return Offset(
      centre.dx + reach * math.cos(angle),
      centre.dy + reach * math.sin(angle),
    );
  }
}

const List<OpeningCurl> openingCurls = <OpeningCurl>[
  OpeningCurl(from: Offset(-150, 70), to: Offset(2, 62), radius: 10, wave: 6),
  OpeningCurl(
    from: Offset(-175, 112),
    to: Offset(12, 106),
    radius: 8,
    wave: -5,
  ),
  OpeningCurl(from: Offset(-140, 152), to: Offset(2, 146), radius: 9, wave: 5),
];

final List<OpeningPolyline> openingCurlPolylines =
    List<OpeningPolyline>.unmodifiable(<OpeningPolyline>[
      for (final OpeningCurl curl in openingCurls) curl.polyline,
    ]);

class OpeningWashBlob {
  const OpeningWashBlob({
    required this.centre,
    required this.radius,
    required this.phase,
    this.verticalFactor = 1,
  });

  final Offset centre;
  final double radius;
  final double phase;
  final double verticalFactor;
}

Path openingWashBlobPath(OpeningWashBlob blob, double growth) {
  final Path path = Path();
  for (int k = 0; k <= 96; k++) {
    final double theta = 2 * math.pi * k / 96;
    final double reach =
        blob.radius *
        growth *
        (1 +
            0.08 * math.sin(3 * theta + blob.phase) +
            0.03 * math.sin(5 * theta + 2 * blob.phase));
    final Offset point = Offset(
      blob.centre.dx + reach * math.cos(theta),
      blob.centre.dy + reach * math.sin(theta) * blob.verticalFactor,
    );
    if (k == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}

final List<OpeningWashBlob> openingDiscWashBlobs =
    List<OpeningWashBlob>.unmodifiable(<OpeningWashBlob>[
      for (int i = 0; i < openingDiscs.length; i++)
        OpeningWashBlob(
          centre: Offset(openingDiscs[i].cx, openingDiscs[i].cy),
          radius: openingDiscs[i].r * 1.3,
          phase: 1.7 * i,
        ),
    ]);

const OpeningWashBlob openingLeftLeafWashBlob = OpeningWashBlob(
  centre: Offset(30, 153),
  radius: 30,
  phase: 0.4,
  verticalFactor: 0.6,
);

const OpeningWashBlob openingRightLeafWashBlob = OpeningWashBlob(
  centre: Offset(70, 131),
  radius: 30,
  phase: 2.2,
  verticalFactor: 0.6,
);

const OpeningWashBlob openingMoundWashBlob = OpeningWashBlob(
  centre: Offset(50, 191),
  radius: 52,
  phase: 1.1,
  verticalFactor: 0.3,
);
