import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';

import 'package:field_notes/domain/mood/flower_kind.dart';

const Size rootArtViewBox = Size(200, 120);

const Duration _strokeLead = Duration(milliseconds: 250);
const Duration _strokeStagger = Duration(milliseconds: 90);
const Duration _popStagger = Duration(milliseconds: 100);
const Duration _popLength = Duration(milliseconds: 550);
const Cubic _drawCurve = Cubic(0.4, 0.1, 0.3, 1);
const Cubic _popCurve = Cubic(0.2, 0.9, 0.3, 1.2);
const double _popFrom = 0.6;
const double _popFadeShare = 0.6;
const double _strokeOpacity = 0.88;

const List<Color> _rootShades = <Color>[
  Color(0xFFE8D3AD),
  Color(0xFFDCC39A),
  Color(0xFFD6BC92),
  Color(0xFFCDB386),
];
const Color _bleedingHeartRoot = Color(0xFFE8D2A8);
const Color _tuberFill = Color(0xFFE6CDA3);
const Color _tuberOutline = Color(0xFFB39468);
const double _tuberOutlineWidth = 1.2;

const List<int> _peonyAngles = <int>[-58, -30, -4, 26, 54];
const List<int> _sunflowerSideRoots = <int>[14, 28, 42, 56, 70, 84, 98];
const List<int> _sunflowerHairRoots = <int>[20, 48, 76, 104];
const List<(int, int)> _asterTufts = <(int, int)>[
  (48, 13),
  (68, 10),
  (132, 10),
  (152, 11),
];

enum RootMode {
  open(
    start: Duration(milliseconds: 1200),
    stroke: Duration(milliseconds: 1200),
  ),
  grow(
    start: Duration(milliseconds: 150),
    stroke: Duration(milliseconds: 1100),
  ),
  still(start: Duration.zero, stroke: Duration.zero);

  const RootMode({required this.start, required this.stroke});

  final Duration start;
  final Duration stroke;
}

final Map<FlowerKind, RootDrawing> _drawings = <FlowerKind, RootDrawing>{
  for (final FlowerKind kind in FlowerKind.values)
    if (_drawingFor(kind) case final RootDrawing drawing) kind: drawing,
};

RootDrawing rootDrawingFor(FlowerKind kind) =>
    _drawings[kind] ?? _drawings[FlowerKind.peony]!;

class RootStroke {
  const RootStroke._({
    required this.path,
    required this.width,
    required this.color,
    required this.contours,
    required this.length,
  });

  factory RootStroke._traced(String data, double width, Color color) {
    final Path path = _svgPath(data);
    final List<PathMetric> contours = List<PathMetric>.unmodifiable(
      path.computeMetrics(),
    );
    return RootStroke._(
      path: path,
      width: width,
      color: color,
      contours: contours,
      length: contours.fold<double>(
        0,
        (double sum, PathMetric contour) => sum + contour.length,
      ),
    );
  }

  final Path path;
  final double width;
  final Color color;
  final List<PathMetric> contours;
  final double length;

  Path drawnTo(double drawn) {
    final double reach = length * drawn;
    final Path drawnPath = Path();
    for (final PathMetric contour in contours) {
      drawnPath.addPath(
        contour.extractPath(0, math.min(contour.length, reach)),
        Offset.zero,
      );
    }
    return drawnPath;
  }
}

class RootBulbPiece {
  RootBulbPiece._(
    String data, {
    required this.outline,
    required this.width,
    this.fill,
  }) : path = _svgPath(data);

  final Path path;
  final Color outline;
  final double width;
  final Color? fill;
}

class RootBulb {
  RootBulb._(List<RootBulbPiece> pieces)
    : pieces = List<RootBulbPiece>.unmodifiable(pieces),
      bounds = pieces
          .map((RootBulbPiece piece) => piece.path.getBounds())
          .reduce((Rect box, Rect next) => box.expandToInclude(next));

  final List<RootBulbPiece> pieces;
  final Rect bounds;

  Offset get origin => Offset(bounds.center.dx, bounds.top);

  Rect get layerBounds => bounds.inflate(
    pieces.map((RootBulbPiece piece) => piece.width).reduce(math.max),
  );
}

class RootTuber {
  const RootTuber._({
    required this.centre,
    required this.radii,
    required this.rotationDeg,
  });

  final Offset centre;
  final Size radii;
  final double rotationDeg;

  Rect get oval => Rect.fromCenter(
    center: Offset.zero,
    width: radii.width * 2,
    height: radii.height * 2,
  );
}

class RootFrame {
  const RootFrame._({
    required this.strokes,
    required this.bulb,
    required this.tubers,
  });

  final List<double> strokes;
  final double bulb;
  final List<double> tubers;

  Iterable<double> get _all => <double>[...strokes, bulb, ...tubers];

  bool get isComplete => _all.every((double value) => value >= 1);

  bool get isBlank => _all.every((double value) => value <= 0);
}

class RootDrawing {
  RootDrawing._({
    required this.kind,
    required List<RootStroke> strokes,
    this.bulb,
    List<RootTuber> tubers = const <RootTuber>[],
  }) : strokes = List<RootStroke>.unmodifiable(strokes),
       tubers = List<RootTuber>.unmodifiable(tubers);

  final FlowerKind kind;
  final List<RootStroke> strokes;
  final RootBulb? bulb;
  final List<RootTuber> tubers;

  Duration lengthOf(RootMode mode) {
    if (mode == RootMode.still) {
      return Duration.zero;
    }
    final Duration drawn =
        mode.start +
        _strokeLead +
        _strokeStagger * (strokes.length - 1) +
        mode.stroke;
    final Duration popped =
        mode.start + _popStagger * tubers.length + _popLength;
    return drawn > popped ? drawn : popped;
  }

  RootFrame frameAt(RootMode mode, Duration elapsed) {
    if (mode == RootMode.still) {
      return RootFrame._(
        strokes: List<double>.unmodifiable(
          List<double>.filled(strokes.length, 1),
        ),
        bulb: 1,
        tubers: List<double>.unmodifiable(
          List<double>.filled(tubers.length, 1),
        ),
      );
    }
    return RootFrame._(
      strokes: List<double>.unmodifiable(<double>[
        for (int index = 0; index < strokes.length; index++)
          _drawCurve.transform(
            _phase(
              elapsed,
              mode.start + _strokeLead + _strokeStagger * index,
              mode.stroke,
            ),
          ),
      ]),
      bulb: _phase(elapsed, mode.start, _popLength),
      tubers: List<double>.unmodifiable(<double>[
        for (int index = 0; index < tubers.length; index++)
          _phase(elapsed, mode.start + _popStagger * (index + 1), _popLength),
      ]),
    );
  }
}

class RootPainter extends CustomPainter {
  RootPainter({required this.drawing, required this.mode, required this.clock})
    : super(repaint: clock);

  final RootDrawing drawing;
  final RootMode mode;
  final Animation<double> clock;

  RootFrame get frame =>
      drawing.frameAt(mode, drawing.lengthOf(mode) * clock.value);

  @override
  void paint(Canvas canvas, Size size) {
    final RootFrame shown = frame;
    if (shown.isBlank) {
      return;
    }
    final double scale = math.min(
      size.width / rootArtViewBox.width,
      size.height / rootArtViewBox.height,
    );
    canvas
      ..save()
      ..translate((size.width - rootArtViewBox.width * scale) / 2, 0)
      ..scale(scale);
    final RootBulb? bulb = drawing.bulb;
    if (bulb != null) {
      _paintBulb(canvas, bulb, shown.bulb);
    }
    for (int index = 0; index < drawing.strokes.length; index++) {
      _paintStroke(canvas, drawing.strokes[index], shown.strokes[index]);
    }
    for (int index = 0; index < drawing.tubers.length; index++) {
      _paintTuber(canvas, drawing.tubers[index], shown.tubers[index]);
    }
    canvas.restore();
  }

  void _paintStroke(Canvas canvas, RootStroke stroke, double drawn) {
    if (drawn <= 0) {
      return;
    }
    final Paint paint = Paint()
      ..color = stroke.color.withValues(alpha: stroke.color.a * _strokeOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.drawPath(drawn >= 1 ? stroke.path : stroke.drawnTo(drawn), paint);
  }

  void _paintBulb(Canvas canvas, RootBulb bulb, double popped) {
    if (popped <= 0) {
      return;
    }
    final double opacity = _popOpacity(popped);
    final double scale = _popScale(popped);
    canvas
      ..save()
      ..translate(bulb.origin.dx, bulb.origin.dy)
      ..scale(scale)
      ..translate(-bulb.origin.dx, -bulb.origin.dy);
    if (opacity < 1) {
      canvas.saveLayer(bulb.layerBounds, _layer(opacity));
    }
    for (final RootBulbPiece piece in bulb.pieces) {
      final Color? fill = piece.fill;
      if (fill != null) {
        canvas.drawPath(
          piece.path,
          Paint()
            ..color = fill
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );
      }
      canvas.drawPath(
        piece.path,
        Paint()
          ..color = piece.outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = piece.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true,
      );
    }
    if (opacity < 1) {
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintTuber(Canvas canvas, RootTuber tuber, double popped) {
    if (popped <= 0) {
      return;
    }
    final double opacity = _popOpacity(popped);
    final double scale = _popScale(popped);
    final Rect oval = tuber.oval;
    canvas
      ..save()
      ..translate(tuber.centre.dx, tuber.centre.dy)
      ..rotate(tuber.rotationDeg * math.pi / 180)
      ..translate(0, oval.top)
      ..scale(scale)
      ..translate(0, -oval.top);
    if (opacity < 1) {
      canvas.saveLayer(oval.inflate(_tuberOutlineWidth), _layer(opacity));
    }
    canvas
      ..drawOval(
        oval,
        Paint()
          ..color = _tuberFill
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      )
      ..drawOval(
        oval,
        Paint()
          ..color = _tuberOutline
          ..style = PaintingStyle.stroke
          ..strokeWidth = _tuberOutlineWidth
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true,
      );
    if (opacity < 1) {
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(RootPainter oldDelegate) =>
      oldDelegate.drawing != drawing ||
      oldDelegate.mode != mode ||
      oldDelegate.clock != clock;
}

class RootArt extends StatefulWidget {
  const RootArt({super.key, required this.kind, this.mode = RootMode.still});

  final FlowerKind kind;
  final RootMode mode;

  @override
  State<RootArt> createState() => _RootArtState();
}

class _RootArtState extends State<RootArt> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this);
  bool _still = false;
  bool _started = false;

  RootDrawing get _drawing => rootDrawingFor(widget.kind);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_started) {
      _started = true;
      _start();
    } else if (_still && _clock.isAnimating) {
      _clock.value = 1;
    }
  }

  @override
  void didUpdateWidget(RootArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind || oldWidget.mode != widget.mode) {
      _start();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _start() {
    final Duration length = _drawing.lengthOf(widget.mode);
    if (_still || length == Duration.zero) {
      _clock.value = 1;
      return;
    }
    _clock
      ..duration = length
      ..forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: rootArtViewBox,
        painter: RootPainter(
          drawing: _drawing,
          mode: widget.mode,
          clock: _clock,
        ),
      ),
    );
  }
}

double _phase(Duration elapsed, Duration delay, Duration length) =>
    ((elapsed - delay).inMicroseconds / length.inMicroseconds).clamp(0.0, 1.0);

double _popScale(double popped) =>
    _popFrom + (1 - _popFrom) * _popCurve.transform(popped);

double _popOpacity(double popped) =>
    _popCurve.transform(math.min(1.0, popped / _popFadeShare)).clamp(0.0, 1.0);

Paint _layer(double opacity) =>
    Paint()..color = Color.fromRGBO(0, 0, 0, opacity);

String _fixed(double value) => value.toStringAsFixed(1);

double _rounded(double value) => double.parse(_fixed(value));

RootDrawing? _drawingFor(FlowerKind kind) => switch (kind) {
  FlowerKind.peony => RootDrawing._(
    kind: kind,
    strokes: _shaded(<(String, double)>[
      for (int index = 0; index < _peonyAngles.length; index++)
        ..._peonyRoots(index),
    ]),
    tubers: <RootTuber>[
      for (int index = 0; index < _peonyAngles.length; index++)
        _peonyTuber(index),
    ],
  ),
  FlowerKind.rose => RootDrawing._(
    kind: kind,
    strokes: _shaded(const <(String, double)>[
      ('M100 2 C 101 30 96 60 99 104', 3),
      ('M100 22 C 86 30 72 36 58 50', 1.6),
      ('M99 44 C 114 52 128 60 142 76', 1.5),
      ('M98 68 C 88 76 80 86 72 98', 1.1),
      ('M66 42 l-6 -6 M128 66 l7 -3 M80 88 l-7 2', 1),
      ('M100 86 C 108 92 112 100 118 110', 1),
    ]),
  ),
  FlowerKind.sunflower => RootDrawing._(
    kind: kind,
    strokes: _shaded(<(String, double)>[
      ('M100 2 C 99 40 102 80 100 118', 3.6),
      for (int index = 0; index < _sunflowerSideRoots.length; index++)
        (
          'M100 ${_sunflowerSideRoots[index]} '
              'q ${index.isOdd ? 16 : -16} 4 ${index.isOdd ? 28 : -28} 12',
          0.9,
        ),
      for (int index = 0; index < _sunflowerHairRoots.length; index++)
        (
          'M100 ${_sunflowerHairRoots[index]} '
              'q ${index.isOdd ? -12 : 12} 3 ${index.isOdd ? -20 : 20} 8',
          0.8,
        ),
    ]),
  ),
  FlowerKind.chrysanthemum => RootDrawing._(
    kind: kind,
    strokes: _shaded(<(String, double)>[
      for (int index = 0; index < 13; index++) _chrysanthemumRoot(index),
    ]),
  ),
  FlowerKind.daffodil => RootDrawing._(
    kind: kind,
    strokes: _shaded(<(String, double)>[
      for (int index = 0; index < 9; index++) _daffodilRoot(index),
    ]),
    bulb: RootBulb._(<RootBulbPiece>[
      RootBulbPiece._(
        'M100 3 C 108 6 116 14 116 22 C 116 29 109 32 100 32 '
        'C 91 32 84 29 84 22 C 84 14 92 6 100 3 Z',
        outline: const Color(0xFFB89A6E),
        width: 1.3,
        fill: const Color(0xFFEFE0BF),
      ),
      RootBulbPiece._(
        'M86 31 L114 31',
        outline: const Color(0xFFA8875A),
        width: 2.2,
      ),
      RootBulbPiece._(
        'M94 10 C 96 18 96 24 95 30 M106 10 C 104 18 104 24 105 30',
        outline: const Color(0xFFD6BF94),
        width: 1,
      ),
    ]),
  ),
  FlowerKind.lavender => RootDrawing._(
    kind: kind,
    strokes: _shaded(const <(String, double)>[
      ('M100 2 C 98 12 90 20 80 28', 1.9),
      ('M100 2 C 102 12 110 20 120 28', 1.9),
      ('M80 28 C 70 36 58 42 44 46', 1.3),
      ('M80 28 C 78 42 72 56 64 70', 1.3),
      ('M120 28 C 130 36 142 42 156 46', 1.3),
      ('M120 28 C 122 42 128 56 136 70', 1.3),
      ('M58 42 C 54 50 50 54 44 58', 0.9),
      ('M142 42 C 146 50 150 54 156 58', 0.9),
      ('M68 62 C 62 66 58 72 54 80', 0.9),
      ('M132 62 C 138 66 142 72 146 80', 0.9),
    ]),
  ),
  FlowerKind.aster => RootDrawing._(
    kind: kind,
    strokes: _shaded(<(String, double)>[
      ('M100 6 C 82 10 62 8 40 14', 2.6),
      ('M100 6 C 118 10 138 8 162 12', 2.6),
      ('M100 6 C 100 18 99 28 100 36', 1.4),
      for (final (int x, int y) in _asterTufts) ...<(String, double)>[
        ('M$x $y q -4 10 -7 20', 0.9),
        ('M$x $y q 1 11 0 22', 0.9),
        ('M$x $y q 5 9 8 18', 0.9),
      ],
    ]),
  ),
  FlowerKind.poppy => RootDrawing._(
    kind: kind,
    strokes: _shaded(const <(String, double)>[
      ('M100 2 C 104 22 96 42 101 62 C 105 80 97 98 100 118', 1.7),
      ('M101 30 q 8 4 14 12', 0.7),
      ('M99 56 q -8 4 -13 12', 0.7),
      ('M101 84 q 7 5 11 12', 0.7),
    ]),
  ),
  FlowerKind.bleedingHeart => RootDrawing._(
    kind: kind,
    strokes: _coloured(const <(String, double)>[
      ('M100 3 C 88 14 74 22 64 40 C 58 52 60 62 56 70', 3.2),
      ('M100 3 C 96 22 92 40 94 62', 3.2),
      ('M100 3 C 110 18 124 26 132 44 C 136 54 134 62 138 70', 3.2),
      ('M100 3 C 106 22 114 36 112 54', 2.6),
      ('M64 40 q -10 4 -16 2 M132 44 q 10 2 16 -2', 1),
    ], _bleedingHeartRoot),
  ),
  FlowerKind.redSpiderLily => RootDrawing._(
    kind: kind,
    strokes: _shaded(<(String, double)>[
      for (int index = 0; index < 6; index++) _redSpiderLilyRoot(index),
    ]),
    bulb: RootBulb._(<RootBulbPiece>[
      RootBulbPiece._(
        'M100 2 C 109 6 114 16 113 24 C 112 31 107 34 100 34 '
        'C 93 34 88 31 87 24 C 86 16 91 6 100 2 Z',
        outline: const Color(0xFF8A5A42),
        width: 1.3,
        fill: const Color(0xFFC99A7A),
      ),
      RootBulbPiece._(
        'M93 8 C 95 18 95 26 94 33 M107 8 C 105 18 105 26 106 33',
        outline: const Color(0xFFA87458),
        width: 1,
      ),
      RootBulbPiece._(
        'M89 33 L111 33',
        outline: const Color(0xFF7A4A34),
        width: 2.2,
      ),
    ]),
  ),
  FlowerKind.wiltingRose || FlowerKind.thistle => null,
};

List<RootStroke> _shaded(List<(String, double)> lines) => <RootStroke>[
  for (int index = 0; index < lines.length; index++)
    RootStroke._traced(
      lines[index].$1,
      lines[index].$2,
      _rootShades[math.min(3, index ~/ 2)],
    ),
];

List<RootStroke> _coloured(List<(String, double)> lines, Color color) =>
    <RootStroke>[
      for (final (String data, double width) in lines)
        RootStroke._traced(data, width, color),
    ];

({double sx, double cy, int reach, int length}) _peonyAim(int index) {
  final double turn = _peonyAngles[index] * math.pi / 180;
  return (
    sx: math.sin(turn),
    cy: math.cos(turn),
    reach: 10 + (index % 2) * 4,
    length: 13 + (index % 3) * 2,
  );
}

List<(String, double)> _peonyRoots(int index) {
  final (:double sx, :double cy, :int reach, :int length) = _peonyAim(index);
  final double tailX = 100 + sx * (reach + length * 2);
  final double tailY = 3 + cy * (reach + length * 2);
  return <(String, double)>[
    ('M100 3 L${_fixed(100 + sx * reach)} ${_fixed(3 + cy * reach)}', 1.6),
    (
      'M${_fixed(tailX)} ${_fixed(tailY)} '
          'q ${_fixed(sx * 8 + 3)} ${_fixed(cy * 8)} '
          '${_fixed(sx * 14)} ${_fixed(cy * 16)}',
      0.8,
    ),
  ];
}

RootTuber _peonyTuber(int index) {
  final (:double sx, :double cy, :int reach, :int length) = _peonyAim(index);
  return RootTuber._(
    centre: Offset(
      _rounded(100 + sx * (reach + length)),
      _rounded(3 + cy * (reach + length)),
    ),
    radii: Size(5.5 + (index % 2), length.toDouble()),
    rotationDeg: _rounded(-_peonyAngles[index].toDouble()),
  );
}

(String, double) _chrysanthemumRoot(int index) {
  final double turn = (-70 + index * 140 / 12) * math.pi / 180;
  final int reach = 34 + ((index * 37) % 14);
  final double x = 100 + math.sin(turn) * reach * 1.5;
  final double y = 4 + math.cos(turn) * reach;
  final double bendX =
      100 + math.sin(turn) * reach * 0.7 + (index.isOdd ? 4 : -4);
  final double bendY = 4 + math.cos(turn) * reach * 0.5;
  return (
    'M100 3 Q ${_fixed(bendX)} ${_fixed(bendY)} ${_fixed(x)} ${_fixed(y)}',
    index % 3 == 0 ? 1.2 : 0.9,
  );
}

(String, double) _daffodilRoot(int index) {
  final double x = 82 + index * 4.5;
  final int endX = 64 + index * 9;
  return (
    'M${_fixed(x)} 32 C ${_fixed(x + (index.isOdd ? 3 : -3))} 52 '
        '${_fixed((x + endX) / 2)} 66 ${_fixed(endX.toDouble())} '
        '${80 + (index % 3) * 6}',
    1,
  );
}

(String, double) _redSpiderLilyRoot(int index) {
  final double x = 88 + index * 4.8;
  final int endX = 70 + index * 12;
  return (
    'M${_fixed(x)} 34 C ${_fixed(x)} 54 '
        '${_fixed((x + endX) / 2)} 70 ${_fixed(endX.toDouble())} '
        '${92 + (index % 2) * 8}',
    1.3,
  );
}

final RegExp _pathCommand = RegExp(r'([MLQCZmlqcz])([^MLQCZmlqcz]*)');
final RegExp _pathNumber = RegExp(r'-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?');

Path _svgPath(String data) {
  final Path path = Path();
  ({Offset pen, Offset start}) cursor = (pen: Offset.zero, start: Offset.zero);
  for (final RegExpMatch segment in _pathCommand.allMatches(data)) {
    final String letter = segment[1]!;
    final String command = letter.toUpperCase();
    final bool relative = letter != command;
    if (command == 'Z') {
      path.close();
      cursor = (pen: cursor.start, start: cursor.start);
      continue;
    }
    final List<double> values = <double>[
      for (final RegExpMatch number in _pathNumber.allMatches(segment[2]!))
        double.parse(number[0]!),
    ];
    final int arity = switch (command) {
      'C' => 6,
      'Q' => 4,
      _ => 2,
    };
    for (int at = 0; at + arity <= values.length; at += arity) {
      final Offset origin = relative ? cursor.pen : Offset.zero;
      final List<Offset> points = <Offset>[
        for (int index = at; index < at + arity; index += 2)
          origin + Offset(values[index], values[index + 1]),
      ];
      final Offset end = points.last;
      final String step = command == 'M' && at > 0 ? 'L' : command;
      switch (step) {
        case 'M':
          path.moveTo(end.dx, end.dy);
        case 'L':
          path.lineTo(end.dx, end.dy);
        case 'Q':
          path.quadraticBezierTo(points[0].dx, points[0].dy, end.dx, end.dy);
        case 'C':
          path.cubicTo(
            points[0].dx,
            points[0].dy,
            points[1].dx,
            points[1].dy,
            end.dx,
            end.dy,
          );
      }
      cursor = (pen: end, start: step == 'M' ? end : cursor.start);
    }
  }
  return path;
}
