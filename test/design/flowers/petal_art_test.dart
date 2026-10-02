import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/flowers/bloom_part.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/domain/mood/mood.dart';

const Size _sheetBox = Size(120, 84);
const double _driftLong = 10;
const double _driftShort = 7;
const double _tolerance = 1e-6;

typedef _Colours = ({int? fill, int? outline});

typedef _Drawn = ({
  Path path,
  Color? fill,
  Color? outline,
  double outlineWidth,
});

List<_Drawn> _drawnPieces(PetalArt art) {
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  PetalPainter(art).paint(canvas, _sheetBox);
  final List<_Drawn> pieces = <_Drawn>[];
  for (final RecordedInvocation call in canvas.invocations) {
    if (call.invocation.memberName != #drawPath) {
      continue;
    }
    final Path path = call.invocation.positionalArguments[0] as Path;
    final Paint paint = call.invocation.positionalArguments[1] as Paint;
    final bool stroke = paint.style == PaintingStyle.stroke;
    final _Drawn? same = pieces.isNotEmpty && identical(pieces.last.path, path)
        ? pieces.removeLast()
        : null;
    pieces.add((
      path: path,
      fill: stroke ? same?.fill : paint.color,
      outline: stroke ? paint.color : same?.outline,
      outlineWidth: stroke ? paint.strokeWidth : same?.outlineWidth ?? 0,
    ));
  }
  return pieces;
}

_Colours _coloursOf(_Drawn piece) =>
    (fill: piece.fill?.toARGB32(), outline: piece.outline?.toARGB32());

Set<_Colours> _partColours(FlowerSpec spec) => <_Colours>{
  for (final BloomPart part in spec.parts!)
    (
      fill: part.fill?.toARGB32(),
      outline: (part.strokeWidth ?? spec.strokeWidth) == 0
          ? null
          : (part.strokeColor ?? spec.strokeColor).toARGB32(),
    ),
};

void main() {
  test("each mood's flower has a petal drawn from its own art", () {
    for (final Mood mood in moodOrder) {
      final FlowerKind kind = mood.flower;
      final PetalArt? art = petalArtFor(kind);
      expect(art, isNotNull, reason: kind.name);
      expect(art!.kind, kind, reason: kind.name);

      final List<_Drawn> pieces = _drawnPieces(art);
      expect(pieces, isNotEmpty, reason: kind.name);
      expect(pieces.length, art.pieces.length, reason: kind.name);
      final Set<_Colours> partColours = _partColours(flowerSpecFor(kind));
      for (final _Drawn piece in pieces) {
        expect(
          piece.fill != null || piece.outline != null,
          isTrue,
          reason: kind.name,
        );
        expect(piece.path.getBounds().isEmpty, isFalse, reason: kind.name);
        expect(_coloursOf(piece), isIn(partColours), reason: kind.name);
        if (piece.outline != null) {
          expect(piece.outlineWidth, greaterThan(0), reason: kind.name);
        }
      }

      final double long = math.max(art.size.width, art.size.height);
      final double short = math.min(art.size.width, art.size.height);
      expect(
        long,
        lessThanOrEqualTo(_driftLong + _tolerance),
        reason: kind.name,
      );
      expect(
        short,
        lessThanOrEqualTo(_driftShort + _tolerance),
        reason: kind.name,
      );
      expect(
        long >= _driftLong - _tolerance || short >= _driftShort - _tolerance,
        isTrue,
        reason: kind.name,
      );
    }

    for (final FlowerKind kind in FlowerKind.values) {
      if (!moodOrder.any((Mood mood) => mood.flower == kind)) {
        expect(petalArtFor(kind), isNull, reason: kind.name);
      }
    }
    expect(petalArtFor(FlowerKind.wiltingRose), isNull);
    expect(petalArtFor(FlowerKind.thistle), isNull);
  });
}
