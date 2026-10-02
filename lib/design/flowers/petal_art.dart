import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PathMetric;

import 'package:flutter/rendering.dart';

import 'package:field_notes/domain/mood/flower_kind.dart';

import 'bloom_part.dart';
import 'flower_spec.dart';

const Size _driftBox = Size(10, 7);
const double _traceStep = 0.25;

const Map<FlowerKind, List<int>> _petalParts = <FlowerKind, List<int>>{
  FlowerKind.peony: <int>[0],
  FlowerKind.rose: <int>[0, 1],
  FlowerKind.sunflower: <int>[0],
  FlowerKind.chrysanthemum: <int>[0],
  FlowerKind.daffodil: <int>[0],
  FlowerKind.lavender: <int>[4],
  FlowerKind.aster: <int>[0],
  FlowerKind.poppy: <int>[0],
  FlowerKind.bleedingHeart: <int>[1, 2],
  FlowerKind.redSpiderLily: <int>[0, 6],
};

final Map<FlowerKind, PetalArt> _arts = <FlowerKind, PetalArt>{
  for (final MapEntry<FlowerKind, List<int>> cut in _petalParts.entries)
    cut.key: _cut(flowerSpecFor(cut.key), cut.value),
};

PetalArt? petalArtFor(FlowerKind kind) => _arts[kind];

class PetalPiece {
  const PetalPiece._({
    required this.path,
    required this.fill,
    required this.outline,
    required this.outlineWidth,
    required this.strokeCap,
    required this.strokeJoin,
  });

  final Path path;
  final Color? fill;
  final Color? outline;
  final double outlineWidth;
  final StrokeCap strokeCap;
  final StrokeJoin strokeJoin;

  PetalPiece _transformed(Float64List matrix, double scale) => PetalPiece._(
    path: path.transform(matrix),
    fill: fill,
    outline: outline,
    outlineWidth: outlineWidth * scale,
    strokeCap: strokeCap,
    strokeJoin: strokeJoin,
  );
}

class PetalArt {
  const PetalArt._({
    required this.kind,
    required this.pieces,
    required this.size,
  });

  final FlowerKind kind;
  final List<PetalPiece> pieces;
  final Size size;

  void paint(Canvas canvas, {double opacity = 1}) {
    for (final PetalPiece piece in pieces) {
      final Color? fill = piece.fill;
      if (fill != null) {
        canvas.drawPath(
          piece.path,
          Paint()
            ..color = fill.withValues(alpha: fill.a * opacity)
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );
      }
      final Color? outline = piece.outline;
      if (outline != null) {
        canvas.drawPath(
          piece.path,
          Paint()
            ..color = outline.withValues(alpha: outline.a * opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = piece.outlineWidth
            ..strokeCap = piece.strokeCap
            ..strokeJoin = piece.strokeJoin
            ..isAntiAlias = true,
        );
      }
    }
  }
}

class PetalPainter extends CustomPainter {
  const PetalPainter(this.art);

  final PetalArt art;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = math.min(
      size.width / art.size.width,
      size.height / art.size.height,
    );
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale);
    art.paint(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PetalPainter oldDelegate) => oldDelegate.art != art;
}

PetalArt _cut(FlowerSpec spec, List<int> indices) {
  final List<BloomPart> parts = spec.parts!;
  final List<PetalPiece> drawn = <PetalPiece>[
    for (final int index in indices) _piece(parts[index], spec),
  ];
  final Rect bounds = _bounds(drawn);
  final Size box = bounds.height > bounds.width ? _driftBox.flipped : _driftBox;
  final double scale = math.min(
    box.width / bounds.width,
    box.height / bounds.height,
  );
  final Float64List fit =
      (Matrix4.diagonal3Values(scale, scale, 1)..setTranslationRaw(
            -bounds.center.dx * scale,
            -bounds.center.dy * scale,
            0,
          ))
          .storage;
  return PetalArt._(
    kind: spec.kind,
    pieces: List<PetalPiece>.unmodifiable(<PetalPiece>[
      for (final PetalPiece piece in drawn) piece._transformed(fit, scale),
    ]),
    size: bounds.size * scale,
  );
}

PetalPiece _piece(BloomPart part, FlowerSpec spec) {
  final double width = part.strokeWidth ?? spec.strokeWidth;
  return PetalPiece._(
    path: _outline(part),
    fill: part.fill,
    outline: width == 0 ? null : part.strokeColor ?? spec.strokeColor,
    outlineWidth: width,
    strokeCap: part.strokeCap,
    strokeJoin: part.strokeJoin,
  );
}

Path _outline(BloomPart part) => switch (part) {
  BloomDisc() =>
    Path()..addOval(
      Rect.fromCircle(center: Offset(part.cx, part.cy), radius: part.r),
    ),
  BloomOval() => _oval(
    part.cx,
    part.cy,
    part.rx,
    part.ry,
    part.rotationDeg,
    part.pivotX,
    part.pivotY,
  ),
  BloomOvalRing() => _oval(
    part.cx,
    part.cy,
    part.rx,
    part.ry,
    part.startDeg,
    part.pivotX,
    part.pivotY,
  ),
  BloomShape() => _shape(part),
};

Path _oval(
  double cx,
  double cy,
  double rx,
  double ry,
  double rotationDeg,
  double pivotX,
  double pivotY,
) {
  final Path oval = Path()
    ..addOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
    );
  if (rotationDeg == 0) {
    return oval;
  }
  final Matrix4 turn = Matrix4.translationValues(pivotX, pivotY, 0)
    ..multiply(Matrix4.rotationZ(rotationDeg * math.pi / 180))
    ..multiply(Matrix4.translationValues(-pivotX, -pivotY, 0));
  return oval.transform(turn.storage);
}

Path _shape(BloomShape shape) {
  final Path path = Path();
  for (final BloomCmd cmd in shape.commands) {
    switch (cmd) {
      case BloomMoveTo():
        path.moveTo(cmd.x, cmd.y);
      case BloomLineTo():
        path.lineTo(cmd.x, cmd.y);
      case BloomQuadTo():
        path.quadraticBezierTo(cmd.cx, cmd.cy, cmd.x, cmd.y);
      case BloomCubicTo():
        path.cubicTo(cmd.c1x, cmd.c1y, cmd.c2x, cmd.c2y, cmd.x, cmd.y);
      case BloomArcTo():
        path.arcToPoint(
          Offset(cmd.x, cmd.y),
          radius: Radius.elliptical(cmd.rx, cmd.ry),
          largeArc: cmd.largeArc,
          clockwise: cmd.clockwise,
        );
    }
  }
  if (shape.close) {
    path.close();
  }
  return path;
}

Rect _bounds(List<PetalPiece> pieces) => pieces
    .map(
      (PetalPiece piece) => _traced(piece.path).inflate(piece.outlineWidth / 2),
    )
    .reduce((Rect box, Rect next) => box.expandToInclude(next));

Rect _traced(Path path) {
  final List<Offset> points = <Offset>[
    for (final PathMetric metric in path.computeMetrics())
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
