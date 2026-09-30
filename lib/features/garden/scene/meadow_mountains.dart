import 'dart:math' as math;
import 'dart:ui';

import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/scene/meadow_water.dart';

enum MeadowRole {
  m0,
  m0b,
  m1t,
  m1b,
  r1,
  r2,
  snow,
  lit,
  shade,
  m1d,
  rS,
  rL,
  scr,
  fo1,
  fo2,
  fo3,
  wf,
  wfHi,
  fog,
  lkHi,
}

enum MeadowVerb { move, line, quad, cubic, close }

class MeadowSegment {
  const MeadowSegment.move(this.to)
    : verb = MeadowVerb.move,
      control1 = null,
      control2 = null;

  const MeadowSegment.line(this.to)
    : verb = MeadowVerb.line,
      control1 = null,
      control2 = null;

  const MeadowSegment.quad(Offset control, this.to)
    : verb = MeadowVerb.quad,
      control1 = control,
      control2 = null;

  const MeadowSegment.cubic(Offset first, Offset second, this.to)
    : verb = MeadowVerb.cubic,
      control1 = first,
      control2 = second;

  const MeadowSegment.close()
    : verb = MeadowVerb.close,
      to = Offset.zero,
      control1 = null,
      control2 = null;

  final MeadowVerb verb;
  final Offset to;
  final Offset? control1;
  final Offset? control2;
}

sealed class MeadowGeometry {
  const MeadowGeometry();
}

class MeadowOutline extends MeadowGeometry {
  const MeadowOutline(this.segments);

  factory MeadowOutline.polygon(List<Offset> points) =>
      MeadowOutline(List<MeadowSegment>.unmodifiable(meadowPolygon(points)));

  factory MeadowOutline.polyline(List<Offset> points) =>
      MeadowOutline(List<MeadowSegment>.unmodifiable(meadowPolyline(points)));

  final List<MeadowSegment> segments;
}

List<MeadowSegment> meadowPolyline(List<Offset> points) => <MeadowSegment>[
  MeadowSegment.move(points.first),
  for (final Offset point in points.skip(1)) MeadowSegment.line(point),
];

List<MeadowSegment> meadowPolygon(List<Offset> points) => <MeadowSegment>[
  ...meadowPolyline(points),
  const MeadowSegment.close(),
];

class MeadowEllipse extends MeadowGeometry {
  const MeadowEllipse({
    required this.centre,
    required this.radiusX,
    required this.radiusY,
    this.rotation = 0,
  });

  final Offset centre;
  final double radiusX;
  final double radiusY;
  final double rotation;
}

class MeadowShape {
  const MeadowShape.fill(
    this.geometry, {
    this.role,
    this.colour,
    this.opacity = 1,
  }) : assert((role == null) != (colour == null)),
       strokeWidth = null,
       dash = const <double>[],
       rounded = false;

  const MeadowShape.stroke(
    this.geometry, {
    required double width,
    this.role,
    this.colour,
    this.opacity = 1,
    this.dash = const <double>[],
    this.rounded = false,
  }) : assert((role == null) != (colour == null)),
       strokeWidth = width;

  final MeadowGeometry geometry;
  final MeadowRole? role;
  final Color? colour;
  final double opacity;
  final double? strokeWidth;
  final List<double> dash;
  final bool rounded;

  bool get isStroke => strokeWidth != null;
}

class MeadowShapeGroup {
  const MeadowShapeGroup({required this.shapes, this.opacity = 1, this.clip});

  final List<MeadowShape> shapes;
  final double opacity;
  final List<Offset>? clip;
}

class MeadowRgb {
  const MeadowRgb(this.red, this.green, this.blue);

  final double red;
  final double green;
  final double blue;

  MeadowRgb mix(MeadowRgb other, double k) => MeadowRgb(
    red + (other.red - red) * k,
    green + (other.green - green) * k,
    blue + (other.blue - blue) * k,
  );

  MeadowRgb scale(double k) => MeadowRgb(red * k, green * k, blue * k);

  Color toColour() =>
      Color.fromARGB(255, _channel(red), _channel(green), _channel(blue));

  static int _channel(double v) => v.clamp(0.0, 255.0).round();

  @override
  bool operator ==(Object other) =>
      other is MeadowRgb &&
      other.red == red &&
      other.green == green &&
      other.blue == blue;

  @override
  int get hashCode => Object.hash(red, green, blue);

  @override
  String toString() => 'MeadowRgb($red, $green, $blue)';
}

const int _ridgePoints = 129;
const double _ridgeLeft = -20;
const double _ridgeSpan = 1440;
const double _rangeFloor = 350;
const double _massifGradientBottom = 330;

class MeadowRange {
  const MeadowRange({
    required this.heights,
    required this.top,
    required this.bottom,
    required this.ridge,
    required this.peaks,
    required this.topRole,
    required this.bottomRole,
    required this.gradientTop,
    required this.gradientBottom,
  });

  final List<double> heights;
  final double top;
  final double bottom;
  final List<Offset> ridge;
  final List<int> peaks;
  final MeadowRole topRole;
  final MeadowRole bottomRole;
  final double gradientTop;
  final double gradientBottom;

  List<Offset> get outline => List<Offset>.unmodifiable(<Offset>[
    const Offset(_ridgeLeft, _rangeFloor),
    ...ridge,
    const Offset(_ridgeLeft + _ridgeSpan, _rangeFloor),
  ]);

  double ridgeAt(double x) {
    final double t = (x - _ridgeLeft) / _ridgeSpan * (_ridgePoints - 1);
    final int i = t.floor().clamp(0, _ridgePoints - 2);
    final double k = t - i;
    return ridge[i].dy + (ridge[i + 1].dy - ridge[i].dy) * k;
  }
}

class MeadowFacets {
  const MeadowFacets({
    required this.left,
    required this.right,
    required this.litTop,
    required this.litBottom,
    required this.shadeTop,
    required this.shadeBottom,
  });

  final List<MeadowOutline> left;
  final List<MeadowOutline> right;
  final double litTop;
  final double litBottom;
  final double shadeTop;
  final double shadeBottom;
}

class MeadowStreak {
  const MeadowStreak({
    required this.shape,
    required this.period,
    required this.phase,
  });

  final MeadowShape shape;
  final double period;
  final double phase;
}

class MeadowFall {
  const MeadowFall({
    required this.x,
    required this.top,
    required this.bend,
    required this.base,
    required this.bendShift,
    required this.footShift,
    required this.width,
    required this.centreLine,
    required this.gorge,
    required this.sheet,
    required this.streaks,
    required this.pool,
    required this.bounds,
    required this.mist,
  });

  final double x;
  final double top;
  final double bend;
  final double base;
  final double bendShift;
  final double footShift;
  final double width;
  final List<Offset> centreLine;
  final List<MeadowShape> gorge;
  final List<MeadowShape> sheet;
  final List<MeadowStreak> streaks;
  final MeadowShape pool;
  final Rect bounds;
  final Rect mist;
}

class MeadowFogBand {
  const MeadowFogBand({required this.rect, required this.strength});

  static const List<double> stops = <double>[0, 0.62, 1];
  static const List<double> opacities = <double>[0, 0.8, 0.9];

  final Rect rect;
  final double strength;
}

double _skirt(MeadowRange massif, List<double> phases, double x) => math.max(
  massif.ridgeAt(x) + 22,
  326 -
      (40 +
          20 * math.sin(x / 150 + phases[0]) +
          11 * math.sin(x / 47 + phases[1]) +
          6 * math.sin(x / 19 + phases[2])),
);

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _smooth(double t) => t * t * (3 - 2 * t);

List<MeadowSegment> _spike(double x, double base, double height, double w) =>
    meadowPolygon(<Offset>[
      Offset(x - w / 2, base),
      Offset(x, base - height),
      Offset(x + w / 2, base),
    ]);

class MeadowMountains {
  const MeadowMountains({
    required this.far,
    required this.high,
    required this.massif,
    required this.highFacets,
    required this.massifFacets,
    required this.snowfield,
    required this.highGullies,
    required this.strata,
    required this.scree,
    required this.couloirs,
    required this.massifGullies,
    required this.skirtPhases,
    required this.skirtLine,
    required this.skirt,
    required this.falls,
    required this.fogBands,
  });

  static MeadowMountains build(MeadowRandom random, MeadowWater water) {
    final double farTop = random.between(100, 135);
    final MeadowRange far = _range(
      random,
      rough: 0.6,
      top: farTop,
      bottom: 246,
      power: 1.1,
      topRole: MeadowRole.m0,
      bottomRole: MeadowRole.m0b,
      gradientBottom: 246,
    );
    final double highTop = random.between(48, 86);
    final MeadowRange high = _range(
      random,
      rough: 0.55,
      top: highTop,
      bottom: 258,
      power: 1.5,
      topRole: MeadowRole.m1t,
      bottomRole: MeadowRole.m1b,
      gradientBottom: 258,
    );
    final double massifTop = random.between(96, 132);
    final MeadowRange massif = _range(
      random,
      rough: 0.52,
      top: massifTop,
      bottom: 288,
      power: 1.15,
      topRole: MeadowRole.r1,
      bottomRole: MeadowRole.r2,
      gradientBottom: _massifGradientBottom,
    );
    final MeadowFacets highFacets = _facets(
      random,
      high,
      litReach: 0.7,
      shadeReach: 0.75,
    );
    final MeadowFacets massifFacets = _facets(
      random,
      massif,
      litReach: 0.9,
      shadeReach: 0.95,
    );

    final double snowLine =
        high.top + (high.bottom - high.top) * random.between(0.2, 0.3);
    final double snowPhase1 = random.between(0, 6);
    final double snowPhase2 = random.between(0, 6);
    final List<Offset> jag = <Offset>[
      for (double x = 1420; x >= -20; x -= 12)
        Offset(
          x,
          snowLine +
              10 * math.sin(x / 61 + snowPhase1) +
              6 * math.sin(x / 23 + snowPhase2) +
              (random.next() < 0.2 ? random.between(8, 26) : 0),
        ),
    ];
    final MeadowShapeGroup snowfield = MeadowShapeGroup(
      shapes: List<MeadowShape>.unmodifiable(<MeadowShape>[
        MeadowShape.fill(
          MeadowOutline.polygon(<Offset>[
            const Offset(-20, 0),
            const Offset(1420, 0),
            ...jag,
          ]),
          role: MeadowRole.snow,
        ),
      ]),
      clip: high.outline,
    );

    final List<double> skirtPhases = List<double>.unmodifiable(<double>[
      for (int i = 0; i < 3; i++) random.between(0, 6),
    ]);
    double skirtAt(double x) => _skirt(massif, skirtPhases, x);

    final double tiltSign = random.next() < 0.5 ? -1 : 1;
    final double tilt = math.tan(
      tiltSign * random.between(10, 22) * math.pi / 180,
    );
    final double spacing = random.between(7, 11);
    final List<MeadowShape> strata = <MeadowShape>[];
    for (int k = -70; k < 90; k++) {
      final double y0 = 100 + k * spacing + random.between(-2, 2);
      final List<Offset> points = <Offset>[
        Offset(-40, y0 - tilt * 740),
        for (double x = -40; x <= 1440; x += 80)
          Offset(x, y0 + tilt * (x - 700) + 3 * math.sin(x / 97 + k)),
      ];
      final List<double> dash = List<double>.unmodifiable(<double>[
        random.between(40, 220),
        random.between(20, 120),
        random.between(30, 160),
        random.between(10, 90),
      ]);
      if (k % 3 == 0) {
        strata.add(
          MeadowShape.stroke(
            MeadowOutline.polyline(points),
            role: MeadowRole.rL,
            width: random.between(1.6, 3.2),
            opacity: 0.2,
            dash: dash,
          ),
        );
      } else if (random.next() < 0.65) {
        strata.add(
          MeadowShape.stroke(
            MeadowOutline.polyline(points),
            role: MeadowRole.rS,
            width: random.between(1, 2),
            opacity: 0.3,
            dash: dash,
          ),
        );
      }
    }

    final List<MeadowShape> couloirs = <MeadowShape>[];
    final List<Offset> crest = massif.ridge;
    for (final int i in massif.peaks) {
      final Offset peak = crest[i];
      if (peak.dy > massif.top + (massif.bottom - massif.top) * 0.55) {
        continue;
      }
      final int count = 2 + (random.next() * 3).floor();
      for (int j = 0; j < count; j++) {
        final double x0 = peak.dx + random.between(-40, 40);
        final double y0 = massif.ridgeAt(x0) + random.between(2, 8);
        final double length = random.between(18, 58);
        final double w = random.between(1.6, 4.2);
        final double dx = random.between(-8, 8);
        couloirs.add(
          MeadowShape.fill(
            MeadowOutline(
              List<MeadowSegment>.unmodifiable(<MeadowSegment>[
                MeadowSegment.move(Offset(x0 - w, y0)),
                MeadowSegment.quad(
                  Offset(x0 + dx * 0.5, y0 + length * 0.6),
                  Offset(x0 + dx, y0 + length),
                ),
                MeadowSegment.quad(
                  Offset(x0 + dx * 0.5 + w * 0.3, y0 + length * 0.5),
                  Offset(x0 + w, y0),
                ),
                const MeadowSegment.close(),
              ]),
            ),
            role: MeadowRole.snow,
            opacity: 0.9,
          ),
        );
      }
      final int from = math.max(0, i - 2);
      final int to = math.min(_ridgePoints - 1, i + 2);
      couloirs.add(
        MeadowShape.fill(
          MeadowOutline.polygon(<Offset>[
            ...crest.sublist(from, math.min(_ridgePoints - 1, i + 3)),
            Offset(crest[to].dx, peak.dy + 10),
            Offset(crest[from].dx, peak.dy + 9),
          ]),
          role: MeadowRole.snow,
          opacity: 0.85,
        ),
      );
    }

    final List<MeadowShape> scree = <MeadowShape>[];
    for (int i = 0; i < 14; i++) {
      final double x = random.between(0, 1400);
      final double b = skirtAt(x) + 3;
      final double height = random.between(22, 58);
      final double w = random.between(26, 70);
      if (b - height < massif.ridgeAt(x) + 8) {
        continue;
      }
      scree.add(
        MeadowShape.fill(
          MeadowOutline(
            List<MeadowSegment>.unmodifiable(<MeadowSegment>[
              MeadowSegment.move(Offset(x - w / 2, b)),
              MeadowSegment.quad(
                Offset(x - w * 0.12, b - height * 0.55),
                Offset(x, b - height),
              ),
              MeadowSegment.quad(
                Offset(x + w * 0.12, b - height * 0.55),
                Offset(x + w / 2, b),
              ),
              const MeadowSegment.close(),
            ]),
          ),
          role: MeadowRole.scr,
        ),
      );
    }

    final List<Offset> skirtLine = List<Offset>.unmodifiable(<Offset>[
      for (double x = -20; x <= 1420; x += 8) Offset(x, skirtAt(x)),
    ]);
    final List<MeadowSegment> spikesA = <MeadowSegment>[];
    final List<MeadowSegment> spikesB = <MeadowSegment>[];
    for (double x = -10; x < 1410; x += random.between(3.2, 5.6)) {
      final double b = skirtAt(x) + random.between(1, 5);
      final double height = random.between(6, 13);
      final double w = height * random.between(0.38, 0.5);
      final List<MeadowSegment> spike = _spike(x, b, height, w);
      if (random.next() < 0.55) {
        spikesA.addAll(spike);
      } else {
        spikesB.addAll(spike);
      }
    }
    final List<MeadowSegment> rows = <MeadowSegment>[];
    for (double y = 0; y < 46; y += 5.5) {
      for (double x = -10; x < 1410; x += random.between(6, 11)) {
        final double b = skirtAt(x) + 8 + y + random.between(-2, 2);
        if (b > 346) {
          continue;
        }
        final double height = random.between(6, 11) * (1 + y / 60);
        rows.addAll(_spike(x, b, height, height * 0.46));
      }
    }
    final List<MeadowShape> skirt = List<MeadowShape>.unmodifiable(
      <MeadowShape>[
        MeadowShape.fill(
          MeadowOutline.polygon(<Offset>[
            const Offset(-20, _rangeFloor),
            ...skirtLine,
            const Offset(1420, _rangeFloor),
          ]),
          role: MeadowRole.fo1,
        ),
        MeadowShape.fill(
          MeadowOutline(List<MeadowSegment>.unmodifiable(spikesA)),
          role: MeadowRole.fo1,
        ),
        MeadowShape.fill(
          MeadowOutline(List<MeadowSegment>.unmodifiable(spikesB)),
          role: MeadowRole.fo2,
        ),
        MeadowShape.fill(
          MeadowOutline(List<MeadowSegment>.unmodifiable(rows)),
          role: MeadowRole.fo3,
          opacity: 0.75,
        ),
      ],
    );

    final List<_FallSite> sites = _fallSites(
      random,
      water: water,
      massif: massif,
      skirtAt: skirtAt,
    );
    final List<List<MeadowShape>> gorges = <List<MeadowShape>>[
      for (final _FallSite site in sites) _gorge(random, site),
    ];
    final MeadowShape highGullies = _gullies(random, high, MeadowRole.m1d, 0.4);
    final MeadowShape massifGullies = _gullies(
      random,
      massif,
      MeadowRole.rS,
      0.35,
    );

    return MeadowMountains(
      far: far,
      high: high,
      massif: massif,
      highFacets: highFacets,
      massifFacets: massifFacets,
      snowfield: snowfield,
      highGullies: highGullies,
      strata: MeadowShapeGroup(
        shapes: List<MeadowShape>.unmodifiable(strata),
        clip: massif.outline,
      ),
      scree: MeadowShapeGroup(
        shapes: List<MeadowShape>.unmodifiable(scree),
        opacity: 0.7,
      ),
      couloirs: List<MeadowShape>.unmodifiable(couloirs),
      massifGullies: massifGullies,
      skirtPhases: skirtPhases,
      skirtLine: skirtLine,
      skirt: skirt,
      falls: List<MeadowFall>.unmodifiable(<MeadowFall>[
        for (int i = 0; i < sites.length; i++) _fall(sites[i], gorges[i]),
      ]),
      fogBands: List<MeadowFogBand>.unmodifiable(<MeadowFogBand>[
        MeadowFogBand(
          rect: Rect.fromLTWH(-20, far.bottom - 70, 1440, 80),
          strength: 1,
        ),
        MeadowFogBand(
          rect: Rect.fromLTWH(-20, high.bottom - 60, 1440, 70),
          strength: 0.6,
        ),
        const MeadowFogBand(
          rect: Rect.fromLTWH(-20, 296, 1440, 36),
          strength: 0.7,
        ),
      ]),
    );
  }

  final MeadowRange far;
  final MeadowRange high;
  final MeadowRange massif;
  final MeadowFacets highFacets;
  final MeadowFacets massifFacets;
  final MeadowShapeGroup snowfield;
  final MeadowShape highGullies;
  final MeadowShapeGroup strata;
  final MeadowShapeGroup scree;
  final List<MeadowShape> couloirs;
  final MeadowShape massifGullies;
  final List<double> skirtPhases;
  final List<Offset> skirtLine;
  final List<MeadowShape> skirt;
  final List<MeadowFall> falls;
  final List<MeadowFogBand> fogBands;

  double skirtAt(double x) => _skirt(massif, skirtPhases, x);
}

List<double> _displace(MeadowRandom random, double rough) {
  List<double> heights = <double>[random.next(), random.next()];
  double amplitude = 1;
  while (heights.length < _ridgePoints) {
    final List<double> previous = heights;
    heights = <double>[
      for (int i = 0; i < previous.length - 1; i++) ...<double>[
        previous[i],
        (previous[i] + previous[i + 1]) / 2 + (random.next() - 0.5) * amplitude,
      ],
      previous.last,
    ];
    amplitude *= rough;
  }
  final double low = heights.reduce(math.min);
  final double peak = heights.reduce(math.max);
  return <double>[for (final double v in heights) (v - low) / (peak - low)];
}

MeadowRange _range(
  MeadowRandom random, {
  required double rough,
  required double top,
  required double bottom,
  required double power,
  required MeadowRole topRole,
  required MeadowRole bottomRole,
  required double gradientBottom,
}) {
  final List<double> heights = List<double>.unmodifiable(
    _displace(random, rough).map((double v) => math.pow(v, power).toDouble()),
  );
  return MeadowRange(
    heights: heights,
    top: top,
    bottom: bottom,
    ridge: List<Offset>.unmodifiable(<Offset>[
      for (int i = 0; i < heights.length; i++)
        Offset(
          _ridgeLeft + i * _ridgeSpan / (_ridgePoints - 1),
          bottom - heights[i] * (bottom - top),
        ),
    ]),
    peaks: List<int>.unmodifiable(_peaks(heights)),
    topRole: topRole,
    bottomRole: bottomRole,
    gradientTop: top,
    gradientBottom: gradientBottom,
  );
}

bool _isPeak(List<double> heights, int i) {
  if (heights[i] <= 0.3) {
    return false;
  }
  final int last = math.min(heights.length - 1, i + 6);
  for (int j = math.max(0, i - 6); j <= last; j++) {
    if (heights[j] > heights[i]) {
      return false;
    }
  }
  return true;
}

List<int> _peaks(List<double> heights) => <int>[
  for (int i = 3; i < heights.length - 3; i++)
    if (_isPeak(heights, i)) i,
];

MeadowFacets _facets(
  MeadowRandom random,
  MeadowRange range, {
  required double litReach,
  required double shadeReach,
}) {
  final List<Offset> crest = range.ridge;
  final List<int> peaks = range.peaks;
  final List<MeadowOutline> left = <MeadowOutline>[];
  final List<MeadowOutline> right = <MeadowOutline>[];
  for (int k = 0; k < peaks.length; k++) {
    final int i = peaks[k];
    final int lo = k > 0 ? peaks[k - 1] : 0;
    final int hi = k < peaks.length - 1 ? peaks[k + 1] : crest.length - 1;
    int valleyLeft = lo;
    for (int j = lo; j <= i; j++) {
      if (crest[j].dy > crest[valleyLeft].dy) {
        valleyLeft = j;
      }
    }
    int valleyRight = hi;
    for (int j = i; j <= hi; j++) {
      if (crest[j].dy > crest[valleyRight].dy) {
        valleyRight = j;
      }
    }
    final Offset foot = Offset(
      crest[i].dx + random.between(-70, 70),
      range.bottom + 40,
    );
    left.add(
      MeadowOutline.polygon(<Offset>[
        ...crest.sublist(valleyLeft, i + 1),
        foot,
      ]),
    );
    right.add(
      MeadowOutline.polygon(<Offset>[
        ...crest.sublist(i, valleyRight + 1),
        foot,
      ]),
    );
  }
  final double height = range.bottom - range.top;
  return MeadowFacets(
    left: List<MeadowOutline>.unmodifiable(left),
    right: List<MeadowOutline>.unmodifiable(right),
    litTop: range.top,
    litBottom: range.top + height * litReach,
    shadeTop: range.top,
    shadeBottom: range.top + height * shadeReach,
  );
}

MeadowShape _gullies(
  MeadowRandom random,
  MeadowRange range,
  MeadowRole role,
  double opacity,
) {
  final List<MeadowSegment> segments = <MeadowSegment>[];
  for (int i = 0; i < range.ridge.length; i++) {
    if (random.next() > 0.4 || i.isOdd) {
      continue;
    }
    final Offset q = range.ridge[i];
    final double length =
        random.between(10, 50) *
        (range.bottom - q.dy) /
        (range.bottom - range.top + 1);
    if (length < 5) {
      continue;
    }
    final Offset start = Offset(q.dx, q.dy + 1.5);
    final double bend = random.between(-4, 4);
    final double reach = random.between(-7, 7);
    segments
      ..add(MeadowSegment.move(start))
      ..add(
        MeadowSegment.quad(
          start + Offset(bend, length * 0.5),
          start + Offset(reach, length),
        ),
      );
  }
  return MeadowShape.stroke(
    MeadowOutline(List<MeadowSegment>.unmodifiable(segments)),
    role: role,
    width: 0.9,
    opacity: opacity,
    rounded: true,
  );
}

class _FallSite {
  _FallSite({
    required this.x,
    required this.top,
    required this.bend,
    required this.base,
    required this.bendShift,
    required this.footShift,
    required this.width,
    required this.ridge,
  }) : centreLine = List<Offset>.unmodifiable(<Offset>[
         for (int i = 0; i <= 24; i++)
           _fallCentre(
             i / 24,
             x: x,
             top: top,
             bend: bend,
             base: base,
             bendShift: bendShift,
             footShift: footShift,
           ),
       ]);

  final double x;
  final double top;
  final double bend;
  final double base;
  final double bendShift;
  final double footShift;
  final double width;
  final double ridge;
  final List<Offset> centreLine;
}

Offset _fallCentre(
  double along, {
  required double x,
  required double top,
  required double bend,
  required double base,
  required double bendShift,
  required double footShift,
}) {
  final bool upper = along < 0.5;
  final double t = upper ? along * 2 : (along - 0.5) * 2;
  return Offset(
    upper
        ? x + bendShift * _smooth(t)
        : x + bendShift + (footShift - bendShift) * _smooth(t),
    upper ? _lerp(top, bend, t) : _lerp(bend, base, t),
  );
}

List<_FallSite> _fallSites(
  MeadowRandom random, {
  required MeadowWater water,
  required MeadowRange massif,
  required double Function(double x) skirtAt,
}) {
  final int count = 1 + (random.next() < 0.4 ? 1 : 0);
  final List<_FallSite> sites = <_FallSite>[];
  for (int i = 0; i < count; i++) {
    double? chosen;
    double? fallback;
    double fallbackGap = double.negativeInfinity;
    for (int tries = 0; chosen == null && tries < 30; tries++) {
      final double candidate = random.between(
        math.max(water.lakeLeftX + 90, 230),
        math.min(water.lakeRightX - 90, 1170),
      );
      final double gap = skirtAt(candidate) - massif.ridgeAt(candidate);
      final bool apart = sites.every(
        (_FallSite site) => (site.x - candidate).abs() > 260,
      );
      final bool overLake = water.lakeTopAt(candidate) < 400;
      if (apart && overLake && gap > (tries < 22 ? 85 : 50)) {
        chosen = candidate;
      } else if (apart && overLake && gap > fallbackGap) {
        fallback = candidate;
        fallbackGap = gap;
      }
    }
    final double? site = chosen ?? (i == 0 ? fallback : null);
    if (site == null) {
      continue;
    }
    final double x = site;
    final double ridge = massif.ridgeAt(x);
    final double base = water.lakeTopAt(x) + 1;
    final double top = ridge + (skirtAt(x) - ridge) * random.between(0.36, 0.5);
    final double bend = _lerp(top, base, random.between(0.38, 0.52));
    final double bendShift = random.between(-6, 6);
    final double footShift = bendShift + random.between(-5, 5);
    final double width = i > 0
        ? random.between(2.6, 3.6)
        : random.between(4.2, 6);
    sites.add(
      _FallSite(
        x: x,
        top: top,
        bend: bend,
        base: base,
        bendShift: bendShift,
        footShift: footShift,
        width: width,
        ridge: ridge,
      ),
    );
  }
  return sites;
}

List<MeadowShape> _gorge(MeadowRandom random, _FallSite site) {
  final double x = site.x;
  final double y = site.top;
  final double w = site.width;
  final List<Offset> line = site.centreLine;
  final List<Offset> wallLeft = <Offset>[
    for (int i = 0; i < line.length; i++)
      Offset(line[i].dx - w * (1 + 0.9 * i / 24), line[i].dy),
  ];
  final List<Offset> wallRight = <Offset>[
    for (int i = 0; i < line.length; i++)
      Offset(line[i].dx + w * (1 + 0.9 * i / 24), line[i].dy),
  ];
  final double cut = math.max(10, math.min(64, (y - site.ridge) * 0.85));
  final double cleft = w * random.between(1.9, 2.6);
  final double skew = random.between(-0.4, 0.4) * cleft;
  final Offset joint = Offset(x + skew * 0.2, y - cut * 0.22);
  final Offset beforeJoint = Offset(x - w * 0.7, y - cut * 0.4);
  final Offset leftRock = Offset(x - w * 2, y + 2.5);
  final Offset leftRockTip = leftRock + Offset(w * 1.3, -w * 0.3);
  final Offset rightRock = Offset(x + w * 2.1, y + 3);
  final Offset rightRockTip = rightRock + Offset(-w * 1.4, -w * 0.2);
  return List<MeadowShape>.unmodifiable(<MeadowShape>[
    MeadowShape.fill(
      MeadowOutline.polygon(<Offset>[...wallLeft, ...wallRight.reversed]),
      role: MeadowRole.rS,
      opacity: 0.38,
    ),
    MeadowShape.fill(
      MeadowOutline(
        List<MeadowSegment>.unmodifiable(<MeadowSegment>[
          MeadowSegment.move(Offset(x - cleft + skew, y - cut)),
          MeadowSegment.cubic(
            Offset(x - cleft * 0.55, y - cut * 0.5),
            Offset(x - w * 1.1, y - 2),
            Offset(x - w * 0.6, y + 1),
          ),
          MeadowSegment.line(Offset(x + w * 0.6, y + 1)),
          MeadowSegment.cubic(
            Offset(x + w * 1.1, y - 2),
            Offset(x + cleft * 0.55, y - cut * 0.5),
            Offset(x + cleft + skew, y - cut),
          ),
          const MeadowSegment.close(),
        ]),
      ),
      role: MeadowRole.rS,
      opacity: 0.42,
    ),
    MeadowShape.fill(
      MeadowOutline(
        List<MeadowSegment>.unmodifiable(<MeadowSegment>[
          MeadowSegment.move(Offset(x + skew - cleft * 0.6, y - cut - 2)),
          MeadowSegment.quad(
            Offset(x + skew - cleft * 0.1, y - cut * 0.8),
            Offset(x + skew * 0.6, y - cut * 0.58),
          ),
          MeadowSegment.quad(
            Offset(x + skew + cleft * 0.2, y - cut * 0.85),
            Offset(x + skew + cleft * 0.5, y - cut - 2),
          ),
          const MeadowSegment.close(),
        ]),
      ),
      role: MeadowRole.snow,
      opacity: 0.75,
    ),
    MeadowShape.stroke(
      MeadowOutline(
        List<MeadowSegment>.unmodifiable(<MeadowSegment>[
          MeadowSegment.move(Offset(x + skew, y - cut + 2)),
          MeadowSegment.cubic(
            Offset(x + skew * 0.6 + w * 0.8, y - cut * 0.7),
            beforeJoint,
            joint,
          ),
          MeadowSegment.cubic(
            joint * 2 - beforeJoint,
            Offset(x, y - 3),
            Offset(x, y),
          ),
        ]),
      ),
      role: MeadowRole.wf,
      width: w * 0.36,
      opacity: 0.85,
      rounded: true,
    ),
    MeadowShape.fill(
      MeadowOutline(
        List<MeadowSegment>.unmodifiable(<MeadowSegment>[
          MeadowSegment.move(leftRock),
          MeadowSegment.quad(leftRock + Offset(w * 0.5, -w * 1.4), leftRockTip),
          MeadowSegment.quad(
            leftRockTip + Offset(-0.1 * w, w * 0.8),
            leftRockTip + Offset(-w * 1.3, w * 0.3),
          ),
          const MeadowSegment.close(),
        ]),
      ),
      role: MeadowRole.rS,
      opacity: 0.3,
    ),
    MeadowShape.fill(
      MeadowOutline(
        List<MeadowSegment>.unmodifiable(<MeadowSegment>[
          MeadowSegment.move(rightRock),
          MeadowSegment.quad(
            rightRock + Offset(-w * 0.6, -w * 1.2),
            rightRockTip,
          ),
          MeadowSegment.quad(
            rightRockTip + Offset(0, w * 0.8),
            rightRockTip + Offset(w * 1.4, w * 0.2),
          ),
          const MeadowSegment.close(),
        ]),
      ),
      role: MeadowRole.rS,
      opacity: 0.26,
    ),
  ]);
}

MeadowFall _fall(_FallSite site, List<MeadowShape> gorge) {
  final double w = site.width;
  final List<Offset> line = site.centreLine;
  double sheetWidth(double along) =>
      w * (0.26 + 0.55 * along + 0.18 * math.exp(-along * 18));
  final List<double> along = <double>[
    for (int i = 0; i < line.length; i++) i / 24,
  ];
  final List<Offset> sheetLeft = <Offset>[
    for (int i = 0; i < line.length; i++)
      Offset(line[i].dx - sheetWidth(along[i]), line[i].dy),
  ];
  final List<Offset> sheetRight = <Offset>[
    for (int i = 0; i < line.length; i++)
      Offset(
        line[i].dx + sheetWidth(along[i]) * (1 + 0.1 * math.sin(along[i] * 9)),
        line[i].dy,
      ),
  ];
  final List<Offset> glossLeft = <Offset>[
    for (int i = 0; i < line.length; i++)
      Offset(sheetLeft[i].dx + sheetWidth(along[i]) * 0.35, sheetLeft[i].dy),
  ];
  final List<Offset> glossRight = <Offset>[
    for (int i = 0; i < line.length; i++)
      Offset(sheetRight[i].dx - sheetWidth(along[i]) * 0.5, sheetRight[i].dy),
  ];
  final double left = <double>[
    site.x,
    site.x + site.bendShift,
    site.x + site.footShift,
  ].reduce(math.min);
  final double right = <double>[
    site.x,
    site.x + site.bendShift,
    site.x + site.footShift,
  ].reduce(math.max);
  return MeadowFall(
    x: site.x,
    top: site.top,
    bend: site.bend,
    base: site.base,
    bendShift: site.bendShift,
    footShift: site.footShift,
    width: w,
    centreLine: line,
    gorge: gorge,
    sheet: List<MeadowShape>.unmodifiable(<MeadowShape>[
      MeadowShape.fill(
        MeadowOutline.polygon(<Offset>[...sheetLeft, ...sheetRight.reversed]),
        role: MeadowRole.wf,
        opacity: 0.9,
      ),
      MeadowShape.fill(
        MeadowOutline.polygon(<Offset>[...glossLeft, ...glossRight.reversed]),
        role: MeadowRole.wfHi,
        opacity: 0.45,
      ),
      MeadowShape.fill(
        MeadowEllipse(
          centre: Offset(site.x, site.top + 2),
          radiusX: w * 0.55,
          radiusY: w * 0.8,
        ),
        role: MeadowRole.wfHi,
        opacity: 0.5,
      ),
    ]),
    streaks: List<MeadowStreak>.unmodifiable(<MeadowStreak>[
      MeadowStreak(
        shape: MeadowShape.stroke(
          MeadowOutline.polyline(line),
          role: MeadowRole.wfHi,
          width: w * 0.38,
          dash: const <double>[5, 9],
          rounded: true,
        ),
        period: 1.1,
        phase: 0,
      ),
      MeadowStreak(
        shape: MeadowShape.stroke(
          MeadowOutline.polyline(line),
          role: MeadowRole.wfHi,
          width: w * 0.25,
          opacity: 0.8,
          dash: const <double>[3, 13],
          rounded: true,
        ),
        period: 0.8,
        phase: 0.3,
      ),
    ]),
    pool: MeadowShape.fill(
      MeadowEllipse(
        centre: Offset(site.x + site.footShift, site.base + 1),
        radiusX: w * 3.2,
        radiusY: w * 0.7,
      ),
      role: MeadowRole.wfHi,
      opacity: 0.85,
    ),
    bounds: Rect.fromLTRB(left - 24, site.top - 6, right + 24, site.base + 10),
    mist: Rect.fromLTWH(site.x + site.footShift - 60, site.base - 34, 120, 46),
  );
}
