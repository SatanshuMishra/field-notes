import 'dart:math' as math;
import 'dart:ui' as ui show Gradient, PathMetric;

import 'package:flutter/rendering.dart';

import 'package:field_notes/domain/mood/flower_kind.dart';

const double _viewPadding = 1.5;
const double _baseAlpha = 0.55;
const double _shadeTurn = 0.3;
const double _veinAlpha = 0x99 / 0xFF;
const double _rimWidth = 2.4;
const double _outlineWidth = 1;
const double _stemRimWidth = 2.6;
const double _stemWidth = 1.1;
const double _floretRimWidth = 2.2;
const double _floretOutlineWidth = 0.8;
const double _traceStep = 0.05;

const Color _rim = Color.fromRGBO(255, 249, 238, 0.6);
const Color _light = Color.fromRGBO(255, 255, 255, 0.75);
const Color _stem = Color(0xFF6F7F4A);
const Color _spot = Color(0xFF2E1C18);

final RegExp _pathToken = RegExp(r'[MLCQZmlcqz]|-?(?:\d+\.?\d*|\.\d+)');
final RegExp _pathCommand = RegExp(r'^[MLCQZmlcqz]$');

enum PetalScreen {
  wide(1.25),
  narrow(1.05);

  const PetalScreen(this.scale);

  final double scale;
}

enum _Ink { vein, light }

class _Oval {
  const _Oval(this.cx, this.cy, this.rx, this.ry, {this.turnDeg = 0});

  final double cx;
  final double cy;
  final double rx;
  final double ry;
  final double turnDeg;

  Matrix4 get _turn => Matrix4.translationValues(cx, cy, 0)
    ..multiply(Matrix4.rotationZ(turnDeg * math.pi / 180))
    ..multiply(Matrix4.translationValues(-cx, -cy, 0));

  Path get path {
    final Path oval = Path()
      ..addOval(
        Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      );
    return turnDeg == 0 ? oval : oval.transform(_turn.storage);
  }

  Offset get base => MatrixUtils.transformPoint(_turn, Offset(cx, cy + ry));

  Offset get tip => MatrixUtils.transformPoint(_turn, Offset(cx, cy - ry));
}

sealed class _Mark {
  const _Mark();
}

final class _Line extends _Mark {
  const _Line(this.data, this.ink, this.width, {this.opacity = 1});

  final String data;
  final _Ink ink;
  final double width;
  final double opacity;
}

final class _Spot extends _Mark {
  const _Spot(this.oval, this.colour, {required this.opacity});

  final _Oval oval;
  final Color colour;
  final double opacity;
}

class _Design {
  const _Design({
    required this.outline,
    required this.size,
    required this.view,
    required this.fill,
    required this.alternate,
    required this.ink,
    this.marks = const <_Mark>[],
    this.florets = const <_Oval>[],
  });

  final String outline;
  final Size size;
  final Size view;
  final Color fill;
  final Color alternate;
  final Color ink;
  final List<_Mark> marks;
  final List<_Oval> florets;
}

const Map<FlowerKind, _Design> _designs = <FlowerKind, _Design>{
  FlowerKind.peony: _Design(
    outline:
        'M12 23 C 7 21 2 16 2 10 C 2 6 4 3 7 3 C 8 1.5 10 2 11 3 '
        'C 12.5 1.5 14.5 1.8 15.5 3.2 C 17 2.5 19.5 3.5 20.5 5.5 '
        'C 22 8 22 12 20 16 C 18 20 15 22 12 23 Z',
    marks: <_Mark>[
      _Line(
        'M12 22 L12 8 M12 22 C 10 17 7 12 5 8 M12 22 C 14 17 17 12 19 8',
        _Ink.vein,
        0.6,
      ),
    ],
    size: Size(16, 16),
    view: Size(24, 24),
    fill: Color(0xFFF2A2B0),
    alternate: Color(0xFFEA8A9E),
    ink: Color(0xFF8A4A4A),
  ),
  FlowerKind.rose: _Design(
    outline:
        'M12 22 C 6 21 2 16 2 11 C 2 6 6 3 12 3 C 18 3 22 6 22 11 '
        'C 22 16 18 21 12 22 Z',
    marks: <_Mark>[
      _Line('M3.5 9 C 7 5.6 17 5.6 20.5 9', _Ink.light, 1.4, opacity: 0.7),
      _Line('M12 21 C 11.5 17 11.5 14 12 11', _Ink.vein, 0.6),
    ],
    size: Size(15, 14),
    view: Size(24, 24),
    fill: Color(0xFFD65A6A),
    alternate: Color(0xFFC84A5C),
    ink: Color(0xFF6D2532),
  ),
  FlowerKind.sunflower: _Design(
    outline:
        'M6 29 C 3 24 1.5 16 2 9 C 2.5 5 4 2 6 1 C 8 2 9.5 5 10 9 '
        'C 10.5 16 9 24 6 29 Z',
    marks: <_Mark>[
      _Line(
        'M6 27 L6 4 M4.4 24 C 3.8 18 3.9 12 4.6 7 '
        'M7.6 24 C 8.2 18 8.1 12 7.4 7',
        _Ink.vein,
        0.55,
      ),
    ],
    size: Size(10, 23),
    view: Size(12, 30),
    fill: Color(0xFFF2BD3A),
    alternate: Color(0xFFE9A92A),
    ink: Color(0xFF8A5A1A),
  ),
  FlowerKind.chrysanthemum: _Design(
    outline:
        'M5 29 C 3.6 22 2.6 14 2.4 8 C 2.2 4 3.2 1.5 5 1.5 '
        'C 6.8 1.5 7.8 4 7.6 8 C 7.4 14 6.4 22 5 29 Z',
    marks: <_Mark>[
      _Line('M5 27 C 4.7 20 4.6 12 5 5', _Ink.vein, 0.6),
      _Line('M3.4 6 C 3.8 3.6 6.2 3.6 6.6 6', _Ink.light, 0.9, opacity: 0.7),
    ],
    size: Size(8, 22),
    view: Size(10, 30),
    fill: Color(0xFFE08A35),
    alternate: Color(0xFFEBA455),
    ink: Color(0xFF8F5414),
  ),
  FlowerKind.daffodil: _Design(
    outline:
        'M10 27 C 5 24 2 17 2.5 11 C 3 6 6 2.5 10 1 C 14 2.5 17 6 17.5 11 '
        'C 18 17 15 24 10 27 Z',
    marks: <_Mark>[
      _Line('M10 25 L10 4', _Ink.vein, 0.7),
      _Line(
        'M10 25 C 7 20 5.5 15 5.5 10 M10 25 C 13 20 14.5 15 14.5 10',
        _Ink.vein,
        0.5,
      ),
    ],
    size: Size(13, 18),
    view: Size(20, 28),
    fill: Color(0xFFF2CF4A),
    alternate: Color(0xFFF6DC6E),
    ink: Color(0xFFA37A12),
  ),
  FlowerKind.lavender: _Design(
    outline: 'M7 25 C 7.4 18 7.2 10 7 4',
    florets: <_Oval>[
      _Oval(7, 4, 2.6, 3.4),
      _Oval(4.6, 9, 2.5, 3.2, turnDeg: -25),
      _Oval(9.4, 12, 2.5, 3.2, turnDeg: 25),
      _Oval(4.8, 15.6, 2.3, 3, turnDeg: -25),
      _Oval(9.2, 19, 2.1, 2.8, turnDeg: 25),
    ],
    size: Size(10, 19),
    view: Size(14, 27),
    fill: Color(0xFF8F78C4),
    alternate: Color(0xFFA693D2),
    ink: Color(0xFF4E3F78),
  ),
  FlowerKind.aster: _Design(
    outline:
        'M5 29 C 4 22 3 12 3 5 C 3 3 3.8 1.5 4.4 1.2 L5 2.4 L5.6 1.2 '
        'C 6.2 1.5 7 3 7 5 C 7 12 6 22 5 29 Z',
    marks: <_Mark>[_Line('M5 27 L5 5', _Ink.vein, 0.55)],
    size: Size(7, 21),
    view: Size(10, 30),
    fill: Color(0xFF9F86D0),
    alternate: Color(0xFFB39FDC),
    ink: Color(0xFF5A4888),
  ),
  FlowerKind.poppy: _Design(
    outline:
        'M13 21 C 8 20 2 16 1.5 10 C 1 5 4 2 8 2.5 C 10 1 13 1.5 14 2.5 '
        'C 16 1 19.5 1.5 21 3 C 24 5 25 9 24 13 C 22.5 17.5 18 20 13 21 Z',
    marks: <_Mark>[
      _Spot(_Oval(13, 17.6, 4.2, 2.6), _spot, opacity: 0.8),
      _Line(
        'M13 15 C 10 11 7 8 5 6 M13 15 C 13 11 13 7 13 4.5 '
        'M13 15 C 16 11 19 8 21 6',
        _Ink.vein,
        0.55,
      ),
    ],
    size: Size(18, 15),
    view: Size(26, 22),
    fill: Color(0xFFE5543F),
    alternate: Color(0xFFEC6A52),
    ink: Color(0xFF7D2A24),
  ),
  FlowerKind.bleedingHeart: _Design(
    outline:
        'M9 1.5 C 13 3 16 8 16 13 C 16 17.6 13.4 20.6 11.4 21.6 '
        'C 12.8 22.8 14.2 23.8 15.4 25.4 C 12.6 25.6 10.4 24.6 9 23.4 '
        'C 7.6 24.6 5.4 25.6 2.6 25.4 C 3.8 23.8 5.2 22.8 6.6 21.6 '
        'C 4.6 20.6 2 17.6 2 13 C 2 8 5 3 9 1.5 Z',
    marks: <_Mark>[
      _Line('M9 21 C 8.6 15 8.6 9 9 4', _Ink.vein, 0.6),
      _Line('M5 9 C 6 6 7.4 4.4 9 3.6', _Ink.light, 1.2, opacity: 0.6),
    ],
    size: Size(12, 17),
    view: Size(18, 27),
    fill: Color(0xFFE8789A),
    alternate: Color(0xFFF08FAE),
    ink: Color(0xFF9A3F5C),
  ),
  FlowerKind.redSpiderLily: _Design(
    outline:
        'M3 29 C 2 22 3 14 5.5 8.5 C 7 5 9 2.5 11 1 C 11.5 4 10.5 7 9.5 10 '
        'C 8 15 7 22 6.5 29 Z',
    marks: <_Mark>[
      _Line(
        'M4.8 27 C 4.8 21 5.4 15 6.8 10.6 C 7.8 7.4 9 5 10.2 3.4',
        _Ink.vein,
        0.55,
      ),
    ],
    size: Size(9, 22),
    view: Size(12, 30),
    fill: Color(0xFFDC3A2C),
    alternate: Color(0xFFE8523F),
    ink: Color(0xFF7D1A12),
  ),
};

final Map<FlowerKind, PetalArt> _arts = <FlowerKind, PetalArt>{
  for (final MapEntry<FlowerKind, _Design> design in _designs.entries)
    design.key: _draw(design.key, design.value),
};

PetalArt? petalArtFor(FlowerKind kind) => _arts[kind];

class PetalShade {
  PetalShade._({
    required this.base,
    required this.tip,
    required this.alternateTip,
    required this.from,
    required this.to,
  }) : shader = _gradient(from, to, base, tip),
       alternateShader = _gradient(from, to, base, alternateTip);

  final Color base;
  final Color tip;
  final Color alternateTip;
  final Offset from;
  final Offset to;
  final Shader shader;
  final Shader alternateShader;

  Shader shaderFor({required bool alternate}) =>
      alternate ? alternateShader : shader;
}

class PetalPiece {
  const PetalPiece._({
    required this.path,
    this.fill,
    this.shade,
    this.outline,
    this.outlineWidth = 0,
    this.strokeCap = StrokeCap.butt,
    this.strokeJoin = StrokeJoin.miter,
  });

  final Path path;
  final Color? fill;
  final PetalShade? shade;
  final Color? outline;
  final double outlineWidth;
  final StrokeCap strokeCap;
  final StrokeJoin strokeJoin;

  void _paint(Canvas canvas, double opacity, bool alternate) {
    final Color? fill = this.fill;
    if (fill != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = fill.withValues(alpha: fill.a * opacity)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }
    final PetalShade? shade = this.shade;
    if (shade != null) {
      canvas.drawPath(
        path,
        Paint()
          ..shader = shade.shaderFor(alternate: alternate)
          ..color = shade.base.withValues(alpha: opacity)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }
    final Color? outline = this.outline;
    if (outline != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = outline.withValues(alpha: outline.a * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = outlineWidth
          ..strokeCap = strokeCap
          ..strokeJoin = strokeJoin
          ..isAntiAlias = true,
      );
    }
  }
}

class PetalArt {
  const PetalArt._({
    required this.kind,
    required this.pieces,
    required this.size,
    required this._view,
  });

  final FlowerKind kind;
  final List<PetalPiece> pieces;
  final Size size;
  final Size _view;

  Size sizeOn(PetalScreen screen) => Size(
    (size.width * screen.scale).roundToDouble(),
    (size.height * screen.scale).roundToDouble(),
  );

  void paint(
    Canvas canvas, {
    double opacity = 1,
    Size? size,
    bool alternate = false,
  }) {
    final Size box = size ?? this.size;
    canvas
      ..save()
      ..scale(math.min(box.width / _view.width, box.height / _view.height));
    for (final PetalPiece piece in pieces) {
      piece._paint(canvas, opacity, alternate);
    }
    canvas.restore();
  }
}

class PetalPainter extends CustomPainter {
  const PetalPainter(this.art, {this.alternate = false});

  final PetalArt art;
  final bool alternate;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2);
    art.paint(canvas, size: size, alternate: alternate);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PetalPainter oldDelegate) =>
      oldDelegate.art != art || oldDelegate.alternate != alternate;
}

PetalArt _draw(FlowerKind kind, _Design design) {
  final Offset centre = design.view.center(Offset.zero);
  final Path outline = _parse(design.outline).shift(-centre);
  final List<PetalPiece> pieces = design.florets.isEmpty
      ? _petal(design, outline, centre)
      : _sprig(design, outline, centre);
  return PetalArt._(
    kind: kind,
    pieces: List<PetalPiece>.unmodifiable(pieces),
    size: design.size,
    view: Size(
      design.view.width + _viewPadding * 2,
      design.view.height + _viewPadding * 2,
    ),
  );
}

List<PetalPiece> _petal(_Design design, Path outline, Offset centre) {
  final Rect bounds = _traced(outline);
  return <PetalPiece>[
    PetalPiece._(
      path: outline,
      outline: _rim,
      outlineWidth: _rimWidth,
      strokeJoin: StrokeJoin.round,
    ),
    PetalPiece._(
      path: outline,
      shade: _shade(
        design,
        Offset(bounds.center.dx, bounds.bottom),
        Offset(bounds.center.dx, bounds.top),
      ),
      outline: design.ink,
      outlineWidth: _outlineWidth,
      strokeJoin: StrokeJoin.round,
    ),
    for (final _Mark mark in design.marks) _marked(mark, design.ink, centre),
  ];
}

List<PetalPiece> _sprig(_Design design, Path stem, Offset centre) {
  final List<({Path path, PetalShade shade})> florets =
      <({Path path, PetalShade shade})>[
        for (final _Oval floret in design.florets)
          (
            path: floret.path.shift(-centre),
            shade: _shade(design, floret.base - centre, floret.tip - centre),
          ),
      ];
  return <PetalPiece>[
    for (final ({Path path, PetalShade shade}) floret in florets)
      PetalPiece._(
        path: floret.path,
        fill: _rim,
        outline: _rim,
        outlineWidth: _floretRimWidth,
      ),
    PetalPiece._(
      path: stem,
      outline: _rim,
      outlineWidth: _stemRimWidth,
      strokeCap: StrokeCap.round,
    ),
    PetalPiece._(
      path: stem,
      outline: _stem,
      outlineWidth: _stemWidth,
      strokeCap: StrokeCap.round,
    ),
    for (final ({Path path, PetalShade shade}) floret in florets)
      PetalPiece._(
        path: floret.path,
        shade: floret.shade,
        outline: design.ink,
        outlineWidth: _floretOutlineWidth,
      ),
  ];
}

PetalShade _shade(_Design design, Offset from, Offset to) => PetalShade._(
  base: design.ink.withValues(alpha: _baseAlpha),
  tip: design.fill,
  alternateTip: design.alternate,
  from: from,
  to: to,
);

Shader _gradient(Offset from, Offset to, Color base, Color tip) =>
    ui.Gradient.linear(
      from,
      to,
      <Color>[base, tip, tip],
      const <double>[0, _shadeTurn, 1],
    );

PetalPiece _marked(_Mark mark, Color ink, Offset centre) => switch (mark) {
  _Line() => PetalPiece._(
    path: _parse(mark.data).shift(-centre),
    outline: _lineColour(mark, ink),
    outlineWidth: mark.width,
  ),
  _Spot() => PetalPiece._(
    path: mark.oval.path.shift(-centre),
    fill: mark.colour.withValues(alpha: mark.colour.a * mark.opacity),
  ),
};

Color _lineColour(_Line line, Color ink) {
  final Color colour = switch (line.ink) {
    _Ink.vein => ink.withValues(alpha: _veinAlpha),
    _Ink.light => _light,
  };
  return colour.withValues(alpha: colour.a * line.opacity);
}

Path _parse(String data) {
  final List<String> tokens = <String>[
    for (final Match token in _pathToken.allMatches(data)) token[0]!,
  ];
  final Path path = Path();
  int at = 0;
  String command = '';
  Offset pen = Offset.zero;
  Offset start = Offset.zero;
  Offset next() {
    final Offset point = Offset(
      double.parse(tokens[at]),
      double.parse(tokens[at + 1]),
    );
    at += 2;
    return command == command.toLowerCase() ? pen + point : point;
  }

  while (at < tokens.length) {
    if (_pathCommand.hasMatch(tokens[at])) {
      command = tokens[at];
      at++;
    }
    switch (command.toUpperCase()) {
      case 'M':
        pen = start = next();
        path.moveTo(pen.dx, pen.dy);
        command = command == 'M' ? 'L' : 'l';
      case 'L':
        pen = next();
        path.lineTo(pen.dx, pen.dy);
      case 'Q':
        final Offset control = next();
        final Offset end = next();
        path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
        pen = end;
      case 'C':
        final Offset first = next();
        final Offset second = next();
        final Offset end = next();
        path.cubicTo(first.dx, first.dy, second.dx, second.dy, end.dx, end.dy);
        pen = end;
      case 'Z':
        path.close();
        pen = start;
        command = '';
      default:
        throw FormatException('Unsupported petal path data', data, at);
    }
  }
  return path;
}

Rect _traced(Path path) {
  final List<Offset> points = <Offset>[
    for (final ui.PathMetric metric in path.computeMetrics())
      for (
        int step = 0, steps = math.max(1, (metric.length / _traceStep).ceil());
        step <= steps;
        step++
      )
        metric.getTangentForOffset(metric.length * step / steps)!.position,
  ];
  return points.fold<Rect>(
    Rect.fromPoints(points.first, points.first),
    (Rect box, Offset point) =>
        box.expandToInclude(Rect.fromPoints(point, point)),
  );
}
