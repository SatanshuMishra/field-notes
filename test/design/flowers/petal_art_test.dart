import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/domain/mood/mood.dart';

const int _rimRgb = 0xFFF9EE;
const double _rimAlpha = 0.6;
const double _baseAlpha = 0.55;
const double _alphaTolerance = 1 / 255;
const double _renderScale = 20;
const double _renderMargin = 1;
const double _nearBase = 0.05;
const double _nearTip = 0.9;
const int _channelTolerance = 3;
const double _baseAlphaCeiling = 0.8;
const double _scanStep = 0.02;
const int _scanReach = 800;

typedef _Draw = ({Path path, Paint paint});

typedef _Pixel = ({int r, int g, int b, int a});

typedef _Render = ({ByteData bytes, int width, Rect bounds});

List<_Draw> _draws(PetalArt art, {bool alternate = false, Size? size}) {
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  art.paint(canvas, alternate: alternate, size: size);
  return <_Draw>[
    for (final RecordedInvocation call in canvas.invocations)
      if (call.invocation.memberName == #drawPath)
        (
          path: call.invocation.positionalArguments[0] as Path,
          paint: call.invocation.positionalArguments[1] as Paint,
        ),
  ];
}

double _scaleOf(PetalArt art, Size size) {
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  art.paint(canvas, size: size);
  return canvas.invocations
          .firstWhere(
            (RecordedInvocation call) => call.invocation.memberName == #scale,
          )
          .invocation
          .positionalArguments[0]
      as double;
}

List<PetalShade> _shadesOf(PetalArt art) => <PetalShade>[
  for (final PetalPiece piece in art.pieces)
    if (piece.shade case final PetalShade shade) shade,
];

List<int> _shadedDraws(List<_Draw> draws) => <int>[
  for (final (int index, _Draw draw) in draws.indexed)
    if (draw.paint.shader != null) index,
];

int _rgb(Color colour) => colour.toARGB32() & 0xFFFFFF;

int _channel(double value) => (value * 255).round();

String _signature(Path path) {
  final Rect bounds = path.getBounds();
  final double length = path.computeMetrics().fold<double>(
    0,
    (double total, ui.PathMetric metric) => total + metric.length,
  );
  return <double>[
    bounds.left,
    bounds.top,
    bounds.right,
    bounds.bottom,
    length,
  ].map((double value) => value.toStringAsFixed(3)).join(',');
}

Offset _inside(Path path, PetalShade shade, double share) {
  final Offset along = Offset.lerp(shade.from, shade.to, share)!;
  final Offset axis = shade.to - shade.from;
  final Offset across = Offset(-axis.dy, axis.dx) / axis.distance;
  final List<int> hits = <int>[
    for (int step = -_scanReach; step <= _scanReach; step++)
      if (path.contains(along + across * (step * _scanStep))) step,
  ];
  expect(hits, isNotEmpty, reason: 'no fill across the shade at $share');
  final List<({int from, int to})> runs = <({int from, int to})>[
    for (final (int index, int step) in hits.indexed)
      if (index == 0 || hits[index - 1] != step - 1)
        (from: step, to: _runEnd(hits, index)),
  ];
  final ({int from, int to}) widest = runs.reduce(
    (({int from, int to}) best, ({int from, int to}) run) =>
        run.to - run.from > best.to - best.from ? run : best,
  );
  final Offset middle =
      along + across * ((widest.from + widest.to) / 2 * _scanStep);
  expect(path.contains(middle), isTrue);
  return middle;
}

int _runEnd(List<int> hits, int start) {
  int end = start;
  while (end + 1 < hits.length && hits[end + 1] == hits[end] + 1) {
    end++;
  }
  return hits[end];
}

Future<_Render> _render(_Draw draw) async {
  final Rect bounds = draw.path.getBounds().inflate(_renderMargin);
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..scale(_renderScale)
    ..translate(-bounds.left, -bounds.top)
    ..drawPath(draw.path, draw.paint);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(
    (bounds.width * _renderScale).ceil(),
    (bounds.height * _renderScale).ceil(),
  );
  final ByteData bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  ))!;
  final int width = image.width;
  picture.dispose();
  image.dispose();
  return (bytes: bytes, width: width, bounds: bounds);
}

_Pixel _pixelAt(_Render render, Offset point) {
  final int x = ((point.dx - render.bounds.left) * _renderScale).floor();
  final int y = ((point.dy - render.bounds.top) * _renderScale).floor();
  final int at = (y * render.width + x) * 4;
  return (
    r: render.bytes.getUint8(at),
    g: render.bytes.getUint8(at + 1),
    b: render.bytes.getUint8(at + 2),
    a: render.bytes.getUint8(at + 3),
  );
}

double _distance(_Pixel pixel, Color colour) => math.sqrt(
  math.pow(pixel.r - _channel(colour.r), 2) +
      math.pow(pixel.g - _channel(colour.g), 2) +
      math.pow(pixel.b - _channel(colour.b), 2),
);

Future<void> _expectShadedFromBaseToTip(
  WidgetTester tester,
  _Draw fill,
  PetalShade shade,
  Color tip, {
  required String reason,
}) async {
  final Offset nearBase = _inside(fill.path, shade, _nearBase);
  final Offset nearTip = _inside(fill.path, shade, _nearTip);
  final _Render render = (await tester.runAsync(() => _render(fill)))!;
  final _Pixel atTip = _pixelAt(render, nearTip);
  expect(
    atTip.a,
    greaterThanOrEqualTo(255 - _channelTolerance),
    reason: reason,
  );
  expect(
    <int>[atTip.r, atTip.g, atTip.b],
    <Matcher>[
      closeTo(_channel(tip.r), _channelTolerance),
      closeTo(_channel(tip.g), _channelTolerance),
      closeTo(_channel(tip.b), _channelTolerance),
    ],
    reason: '$reason at the tip',
  );
  final _Pixel atBase = _pixelAt(render, nearBase);
  expect(
    atBase.a,
    inInclusiveRange(
      _channel(_baseAlpha) - _channelTolerance,
      _channel(_baseAlphaCeiling),
    ),
    reason: '$reason at the base',
  );
  expect(
    _distance(atBase, shade.base),
    lessThan(_distance(atBase, tip)),
    reason: '$reason at the base',
  );
}

void main() {
  testWidgets('each flower has its own outlined, rimmed and shaded petal', (
    WidgetTester tester,
  ) async {
    final Set<String> outlines = <String>{};
    for (final Mood mood in moodOrder) {
      final FlowerKind kind = mood.flower;
      final String name = kind.name;
      final PetalArt? art = petalArtFor(kind);
      expect(art, isNotNull, reason: name);
      expect(art!.kind, kind, reason: name);

      final List<_Draw> draws = _draws(art);
      final List<PetalShade> shades = _shadesOf(art);
      final List<int> shaded = _shadedDraws(draws);
      expect(shaded, isNotEmpty, reason: name);
      expect(shaded, hasLength(shades.length), reason: name);
      outlines.add(
        shaded.map((int index) => _signature(draws[index].path)).join('|'),
      );

      for (final (int order, int index) in shaded.indexed) {
        final String reason = '$name shaded piece $order';
        final _Draw fill = draws[index];
        final PetalShade shade = shades[order];
        expect(fill.paint.style, PaintingStyle.fill, reason: reason);
        expect(
          identical(fill.paint.shader, shade.shader),
          isTrue,
          reason: reason,
        );
        expect(shade.from.dy, greaterThan(shade.to.dy), reason: reason);
        expect(shade.base.a, closeTo(_baseAlpha, _alphaTolerance));

        final _Draw outline = draws[index + 1];
        expect(identical(outline.path, fill.path), isTrue, reason: reason);
        expect(outline.paint.style, PaintingStyle.stroke, reason: reason);
        expect(outline.paint.color.a, 1, reason: reason);
        expect(_rgb(outline.paint.color), _rgb(shade.base), reason: reason);
        for (final Color tip in <Color>[shade.tip, shade.alternateTip]) {
          expect(
            outline.paint.color.computeLuminance(),
            lessThan(tip.computeLuminance()),
            reason: '$reason outline is darker than its fill',
          );
        }

        final List<_Draw> rims = <_Draw>[
          for (final _Draw draw in draws.take(index))
            if (identical(draw.path, fill.path) &&
                draw.paint.style == PaintingStyle.stroke &&
                _rgb(draw.paint.color) == _rimRgb)
              draw,
        ];
        expect(rims, hasLength(1), reason: '$reason cream rim');
        expect(
          rims.single.paint.color.a,
          closeTo(_rimAlpha, _alphaTolerance),
          reason: '$reason cream rim',
        );
        expect(
          rims.single.paint.strokeWidth,
          greaterThan(outline.paint.strokeWidth),
          reason: '$reason cream rim',
        );

        await _expectShadedFromBaseToTip(
          tester,
          fill,
          shade,
          shade.tip,
          reason: reason,
        );
      }
    }
    expect(outlines, hasLength(moodOrder.length));

    final PetalArt peony = petalArtFor(FlowerKind.peony)!;
    final Size wide = peony.sizeOn(PetalScreen.wide);
    final Size narrow = peony.sizeOn(PetalScreen.narrow);
    expect(wide, const Size(20, 20));
    expect(narrow, const Size(17, 17));
    expect(
      _scaleOf(peony, narrow) / _scaleOf(peony, wide),
      closeTo(17 / 20, 1e-9),
    );

    for (final FlowerKind kind in FlowerKind.values) {
      if (!moodOrder.any((Mood mood) => mood.flower == kind)) {
        expect(petalArtFor(kind), isNull, reason: kind.name);
      }
    }
  });

  testWidgets(
    'every other petal takes its alternate fill and sizes stay whole',
    (WidgetTester tester) async {
      for (final Mood mood in moodOrder) {
        final String name = mood.flower.name;
        final PetalArt art = petalArtFor(mood.flower)!;
        final List<_Draw> primary = _draws(art);
        final List<_Draw> alternate = _draws(art, alternate: true);
        final List<PetalShade> shades = _shadesOf(art);
        expect(alternate, hasLength(primary.length), reason: name);

        final List<int> shaded = _shadedDraws(alternate);
        expect(shaded, _shadedDraws(primary), reason: name);
        for (final (int order, int index) in shaded.indexed) {
          final PetalShade shade = shades[order];
          expect(
            _rgb(shade.alternateTip),
            isNot(_rgb(shade.tip)),
            reason: name,
          );
          expect(
            identical(alternate[index].paint.shader, shade.alternateShader),
            isTrue,
            reason: name,
          );
          await _expectShadedFromBaseToTip(
            tester,
            alternate[index],
            shade,
            shade.alternateTip,
            reason: '$name alternate shaded piece $order',
          );
        }
        for (int index = 0; index < primary.length; index++) {
          if (shaded.contains(index)) {
            continue;
          }
          expect(
            alternate[index].paint.color.toARGB32(),
            primary[index].paint.color.toARGB32(),
            reason: '$name draw $index',
          );
        }

        final Size wide = art.sizeOn(PetalScreen.wide);
        final Size narrow = art.sizeOn(PetalScreen.narrow);
        for (final double side in <double>[
          wide.width,
          wide.height,
          narrow.width,
          narrow.height,
        ]) {
          expect(side, side.roundToDouble(), reason: name);
        }
        expect(narrow.width, lessThanOrEqualTo(wide.width), reason: name);
        expect(narrow.height, lessThan(wide.height), reason: name);
        expect(
          wide,
          Size(
            (art.size.width * 1.25).roundToDouble(),
            (art.size.height * 1.25).roundToDouble(),
          ),
          reason: name,
        );
        expect(
          narrow,
          Size(
            (art.size.width * 1.05).roundToDouble(),
            (art.size.height * 1.05).roundToDouble(),
          ),
          reason: name,
        );
      }
    },
  );
}
