import 'dart:math' as math;
import 'dart:ui';

import 'package:field_notes/design/flowers/bloom_part.dart';

import 'opening_art.dart';

enum OpeningInk {
  disc0,
  disc1,
  disc2,
  disc3,
  disc4,
  disc5,
  crease,
  stem,
  mound,
  tuft,
  leftLeaf,
  leftVein,
  rightLeaf,
  rightVein,
}

class OpeningStroke {
  const OpeningStroke({
    required this.ink,
    required this.points,
    required this.length,
    required this.start,
    required this.end,
  });

  final OpeningInk ink;
  final List<Offset> points;
  final double length;
  final double start;
  final double end;
}

class OpeningSpan {
  const OpeningSpan(this.start, this.end);

  final double start;
  final double end;
}

class OpeningPlan {
  const OpeningPlan({
    required this.still,
    required this.strokes,
    required this.washes,
    required this.windStart,
    required this.gustStarts,
    required this.windArrival,
    required this.bend,
    required this.bendRelease,
    required this.sheds,
    required this.reveal,
    required this.total,
  });

  final bool still;
  final List<OpeningStroke> strokes;
  final Map<OpeningInk, OpeningSpan> washes;
  final double windStart;
  final List<double> gustStarts;
  final double windArrival;
  final OpeningSpan bend;
  final double bendRelease;
  final Map<OpeningInk, double> sheds;
  final OpeningSpan reveal;
  final double total;
}

OpeningPlan openingPlan({bool still = false}) =>
    still ? _stillPlan : _movingPlan;

const double _firstStrokeStart = 0.05;
const double _penSpeed = 1250;
const double _shortestStroke = 0.035;
const double _liftAfterStroke = 0.022;
const double _liftAfterTuft = 0.012;
const double _washDelay = 0.04;
const double _washLength = 0.36;
const double _windBeforeLastWashEnd = 0.3;
const List<double> _gustOffsets = <double>[0, 0.09, 0.18];
const double _windTravel = 0.33;
const double _bendLead = 0.08;
const double _bendPeak = 0.25;
const double _shedAfterArrival = 0.1;
const double _releaseAfterLastShed = 0.06;
const double _revealStartAfterLastShed = 0.08;
const double _revealEndAfterLastShed = 0.62;
const double _piecesAfterReveal = 0.55;
const OpeningSpan _stillReveal = OpeningSpan(0.4, 0.7);

const Map<OpeningInk, double> _shedOffsets = <OpeningInk, double>{
  OpeningInk.disc1: 0,
  OpeningInk.disc0: 0.06,
  OpeningInk.disc3: 0.12,
  OpeningInk.disc2: 0.18,
  OpeningInk.disc4: 0.24,
  OpeningInk.disc5: 0.3,
  OpeningInk.leftLeaf: 0.22,
  OpeningInk.rightLeaf: 0.33,
};

const List<OpeningInk> _washedInks = <OpeningInk>[
  OpeningInk.disc0,
  OpeningInk.disc1,
  OpeningInk.disc2,
  OpeningInk.disc3,
  OpeningInk.disc4,
  OpeningInk.disc5,
  OpeningInk.leftLeaf,
  OpeningInk.rightLeaf,
  OpeningInk.mound,
];

OpeningInk openingWashOwner(OpeningInk ink) => switch (ink) {
  OpeningInk.disc0 => OpeningInk.disc0,
  OpeningInk.disc1 => OpeningInk.disc1,
  OpeningInk.disc2 => OpeningInk.disc2,
  OpeningInk.disc3 => OpeningInk.disc3,
  OpeningInk.disc4 => OpeningInk.disc4,
  OpeningInk.disc5 || OpeningInk.crease => OpeningInk.disc5,
  OpeningInk.leftLeaf || OpeningInk.leftVein => OpeningInk.leftLeaf,
  OpeningInk.rightLeaf || OpeningInk.rightVein => OpeningInk.rightLeaf,
  OpeningInk.mound || OpeningInk.tuft => OpeningInk.mound,
  OpeningInk.stem => OpeningInk.stem,
};

int openingDiscIndex(OpeningInk ink) => switch (ink) {
  OpeningInk.disc0 => 0,
  OpeningInk.disc1 => 1,
  OpeningInk.disc2 => 2,
  OpeningInk.disc3 => 3,
  OpeningInk.disc4 => 4,
  OpeningInk.disc5 => 5,
  OpeningInk.crease ||
  OpeningInk.stem ||
  OpeningInk.mound ||
  OpeningInk.tuft ||
  OpeningInk.leftLeaf ||
  OpeningInk.leftVein ||
  OpeningInk.rightLeaf ||
  OpeningInk.rightVein => throw ArgumentError.value(
    ink,
    'ink',
    'is not a petal disc',
  ),
};

enum _Start { asSampled, nearerEnd }

typedef _Line = ({OpeningInk ink, OpeningPolyline polyline, _Start start});

final List<_Line> _lines = List<_Line>.unmodifiable(<_Line>[
  (ink: OpeningInk.disc5, polyline: _discLine(5), start: _Start.nearerEnd),
  (
    ink: OpeningInk.crease,
    polyline: sampleOpeningPath(openingCreasePath),
    start: _Start.nearerEnd,
  ),
  for (final OpeningInk disc in const <OpeningInk>[
    OpeningInk.disc3,
    OpeningInk.disc4,
    OpeningInk.disc1,
    OpeningInk.disc2,
    OpeningInk.disc0,
  ])
    (
      ink: disc,
      polyline: _discLine(openingDiscIndex(disc)),
      start: _Start.nearerEnd,
    ),
  (ink: OpeningInk.stem, polyline: _stemLine(), start: _Start.asSampled),
  (
    ink: OpeningInk.mound,
    polyline: sampleOpeningPath(openingMoundTopPath),
    start: _Start.nearerEnd,
  ),
  for (final Path tuft in openingTuftPaths)
    (
      ink: OpeningInk.tuft,
      polyline: sampleOpeningPath(tuft),
      start: _Start.asSampled,
    ),
  (
    ink: OpeningInk.leftLeaf,
    polyline: sampleOpeningPath(openingLeftLeafPath),
    start: _Start.asSampled,
  ),
  (
    ink: OpeningInk.leftVein,
    polyline: sampleOpeningPath(openingLeftVeinPath),
    start: _Start.asSampled,
  ),
  (
    ink: OpeningInk.rightLeaf,
    polyline: sampleOpeningPath(openingRightLeafPath),
    start: _Start.asSampled,
  ),
  (
    ink: OpeningInk.rightVein,
    polyline: sampleOpeningPath(openingRightVeinPath),
    start: _Start.asSampled,
  ),
]);

OpeningPolyline _discLine(int index) {
  final List<OpeningPolyline> runs = _visibleRuns(index);
  if (runs.length != 1) {
    throw StateError(
      'Petal disc $index shows ${runs.length} runs of outline, not one.',
    );
  }
  return runs.single;
}

const int _outlineSamples = 720;
const double _coverInset = 0.05;
const double _shortestRun = 2;
const double _wholeRingStart = -0.85 * math.pi;

List<OpeningPolyline> _visibleRuns(int index) {
  final BloomDisc disc = openingDiscs[index];
  final List<bool> visible = <bool>[
    for (int k = 0; k < _outlineSamples; k++)
      !_coveredByLaterDisc(index, _angleOf(k)),
  ];
  if (visible.every((bool shows) => shows)) {
    return <OpeningPolyline>[
      openingArc(disc, _wholeRingStart, _wholeRingStart + 2 * math.pi),
    ];
  }
  final int firstHidden = visible.indexOf(false);
  final List<(int, int)> runs = <(int, int)>[];
  int? runStart;
  for (int k = 1; k <= _outlineSamples; k++) {
    final int step = firstHidden + k;
    if (visible[step % _outlineSamples]) {
      runStart ??= step;
    } else if (runStart != null) {
      runs.add((runStart, step - 1));
      runStart = null;
    }
  }
  return <OpeningPolyline>[
    for (final (int from, int to) in runs)
      if ((_angleOf(to) - _angleOf(from)) * disc.r > _shortestRun)
        openingArc(disc, _angleOf(from), _angleOf(to)),
  ];
}

double _angleOf(int sample) => sample / _outlineSamples * 2 * math.pi;

bool _coveredByLaterDisc(int index, double angle) {
  final BloomDisc disc = openingDiscs[index];
  final Offset point = Offset(
    disc.cx + disc.r * math.cos(angle),
    disc.cy + disc.r * math.sin(angle),
  );
  for (int later = index + 1; later < openingDiscs.length; later++) {
    final BloomDisc front = openingDiscs[later];
    if ((point - Offset(front.cx, front.cy)).distance < front.r - _coverInset) {
      return true;
    }
  }
  return false;
}

const double _soilLine = 184.2;
const double _flowerClearance = 1;

OpeningPolyline _stemLine() {
  final List<Offset> kept = <Offset>[
    for (final Offset point in sampleOpeningPath(openingStemPath).points)
      if (point.dy < _soilLine && !_nearAnyDisc(point)) point,
  ];
  return OpeningPolyline(kept).reversed();
}

bool _nearAnyDisc(Offset point) => openingDiscs.any(
  (BloomDisc disc) =>
      (point - Offset(disc.cx, disc.cy)).distance < disc.r + _flowerClearance,
);

final OpeningPlan _movingPlan = _buildMovingPlan();
final OpeningPlan _stillPlan = _buildStillPlan();

List<OpeningPolyline> _orientedLines() {
  final List<OpeningPolyline> oriented = <OpeningPolyline>[];
  for (final _Line line in _lines) {
    final Offset? previousEnd = oriented.isEmpty ? null : oriented.last.last;
    final OpeningPolyline polyline = line.polyline;
    final bool farEndNearer = switch (line.start) {
      _Start.asSampled => false,
      _Start.nearerEnd =>
        previousEnd != null &&
            (previousEnd - polyline.last).distance <
                (previousEnd - polyline.first).distance,
    };
    oriented.add(farEndNearer ? polyline.reversed() : polyline);
  }
  return oriented;
}

OpeningPlan _buildMovingPlan() {
  final List<OpeningPolyline> oriented = _orientedLines();
  final List<OpeningStroke> strokes = <OpeningStroke>[];
  double start = _firstStrokeStart;
  for (int i = 0; i < _lines.length; i++) {
    final OpeningPolyline polyline = oriented[i];
    final double end =
        start + math.max(_shortestStroke, polyline.length / _penSpeed);
    strokes.add(
      OpeningStroke(
        ink: _lines[i].ink,
        points: polyline.points,
        length: polyline.length,
        start: start,
        end: end,
      ),
    );
    start =
        end +
        (_lines[i].ink == OpeningInk.tuft ? _liftAfterTuft : _liftAfterStroke);
  }

  final Map<OpeningInk, OpeningSpan> washes = <OpeningInk, OpeningSpan>{
    for (final OpeningInk part in _washedInks)
      part: _washAfter(_lastEndOf(strokes, part)),
  };
  final double windStart =
      washes.values.map((OpeningSpan wash) => wash.end).reduce(math.max) -
      _windBeforeLastWashEnd;
  final double windArrival = windStart + _windTravel;
  final double firstShed = windArrival + _shedAfterArrival;
  final Map<OpeningInk, double> sheds = <OpeningInk, double>{
    for (final MapEntry<OpeningInk, double> offset in _shedOffsets.entries)
      offset.key: firstShed + offset.value,
  };
  final double lastShed = sheds.values.reduce(math.max);
  final OpeningSpan reveal = OpeningSpan(
    lastShed + _revealStartAfterLastShed,
    lastShed + _revealEndAfterLastShed,
  );
  return OpeningPlan(
    still: false,
    strokes: List<OpeningStroke>.unmodifiable(strokes),
    washes: Map<OpeningInk, OpeningSpan>.unmodifiable(washes),
    windStart: windStart,
    gustStarts: List<double>.unmodifiable(<double>[
      for (final double offset in _gustOffsets) windStart + offset,
    ]),
    windArrival: windArrival,
    bend: OpeningSpan(windArrival - _bendLead, windArrival + _bendPeak),
    bendRelease: lastShed + _releaseAfterLastShed,
    sheds: Map<OpeningInk, double>.unmodifiable(sheds),
    reveal: reveal,
    total: reveal.end + _piecesAfterReveal,
  );
}

double _lastEndOf(List<OpeningStroke> strokes, OpeningInk part) => strokes
    .where((OpeningStroke stroke) => openingWashOwner(stroke.ink) == part)
    .map((OpeningStroke stroke) => stroke.end)
    .reduce(math.max);

OpeningSpan _washAfter(double penLeaves) {
  final double start = penLeaves + _washDelay;
  return OpeningSpan(start, start + _washLength);
}

OpeningPlan _buildStillPlan() {
  final List<OpeningPolyline> oriented = _orientedLines();
  return OpeningPlan(
    still: true,
    strokes: List<OpeningStroke>.unmodifiable(<OpeningStroke>[
      for (int i = 0; i < _lines.length; i++)
        OpeningStroke(
          ink: _lines[i].ink,
          points: oriented[i].points,
          length: oriented[i].length,
          start: 0,
          end: 0,
        ),
    ]),
    washes: Map<OpeningInk, OpeningSpan>.unmodifiable(<OpeningInk, OpeningSpan>{
      for (final OpeningInk part in _washedInks) part: const OpeningSpan(0, 0),
    }),
    windStart: double.infinity,
    gustStarts: const <double>[],
    windArrival: double.infinity,
    bend: const OpeningSpan(double.infinity, double.infinity),
    bendRelease: double.infinity,
    sheds: const <OpeningInk, double>{},
    reveal: _stillReveal,
    total: _stillReveal.end,
  );
}
