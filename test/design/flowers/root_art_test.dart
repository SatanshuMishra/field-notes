import 'dart:ui' show PathMetric;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/domain/mood/flower_kind.dart';

const Size _phoneSurface = Size(384, 832);
const Size _phoneRoots = Size(180, 160);
const Size _desktopRoots = Size(200, 90);

const Map<FlowerKind, int> _strokeCounts = <FlowerKind, int>{
  FlowerKind.peony: 10,
  FlowerKind.rose: 6,
  FlowerKind.sunflower: 12,
  FlowerKind.chrysanthemum: 13,
  FlowerKind.daffodil: 9,
  FlowerKind.lavender: 10,
  FlowerKind.aster: 15,
  FlowerKind.poppy: 4,
  FlowerKind.bleedingHeart: 5,
  FlowerKind.redSpiderLily: 6,
};

const List<int> _rootShades = <int>[
  0xFFE8D3AD,
  0xFFE8D3AD,
  0xFFDCC39A,
  0xFFDCC39A,
  0xFFD6BC92,
  0xFFD6BC92,
];
const int _deepShade = 0xFFCDB386;
const int _bleedingHeartRoot = 0xFFE8D2A8;

typedef _Drawn = ({int paths, int ovals});

String _point(Offset point) =>
    '${point.dx.toStringAsFixed(2)},${point.dy.toStringAsFixed(2)}';

String _shapeOf(RootStroke stroke) => <String>[
  for (final PathMetric contour in stroke.path.computeMetrics())
    <Offset>[
      contour.getTangentForOffset(0)!.position,
      contour.getTangentForOffset(contour.length / 2)!.position,
      contour.getTangentForOffset(contour.length)!.position,
    ].map(_point).join(' '),
].join(' | ');

int _shadeAt(FlowerKind kind, int index) {
  if (kind == FlowerKind.bleedingHeart) {
    return _bleedingHeartRoot;
  }
  return index < _rootShades.length ? _rootShades[index] : _deepShade;
}

_Drawn _complete(RootDrawing drawing) => (
  paths:
      drawing.strokes.length +
      (drawing.bulb?.pieces ?? const <RootBulbPiece>[]).fold<int>(
        0,
        (int count, RootBulbPiece piece) =>
            count + (piece.fill == null ? 1 : 2),
      ),
  ovals: drawing.tubers.length * 2,
);

TestRecordingCanvas _record(
  RootDrawing drawing,
  RootMode mode,
  double clock,
  Size box,
) {
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  RootPainter(
    drawing: drawing,
    mode: mode,
    clock: AlwaysStoppedAnimation<double>(clock),
  ).paint(canvas, box);
  return canvas;
}

_Drawn _countDrawn(TestRecordingCanvas canvas) => (
  paths: canvas.invocations
      .where(
        (RecordedInvocation call) => call.invocation.memberName == #drawPath,
      )
      .length,
  ovals: canvas.invocations
      .where(
        (RecordedInvocation call) => call.invocation.memberName == #drawOval,
      )
      .length,
);

List<Object?> _firstCall(TestRecordingCanvas canvas, Symbol method) => canvas
    .invocations
    .firstWhere(
      (RecordedInvocation call) => call.invocation.memberName == method,
    )
    .invocation
    .positionalArguments;

Future<void> _show(
  WidgetTester tester,
  RootArt art, {
  Size box = _phoneRoots,
  bool reduceMotion = false,
}) => tester.pumpWidget(
  MediaQuery(
    data: MediaQueryData.fromView(tester.view)
        .copyWith(disableAnimations: reduceMotion),
    child: Center(
      child: SizedBox.fromSize(size: box, child: art),
    ),
  ),
);

RootPainter _painterIn(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(RootArt),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as RootPainter;

void main() {
  testWidgets('every flower has distinct roots that draw in or show still', (
    WidgetTester tester,
  ) async {
    tester.view
      ..physicalSize = _phoneSurface
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(top: 34, bottom: 24)
      ..viewPadding = const FakeViewPadding(top: 34, bottom: 24);
    addTearDown(tester.view.reset);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final List<FlowerKind> flowers = FlowerKind.values
        .where((FlowerKind kind) => !kind.ambientOnly)
        .toList();
    expect(flowers, hasLength(10));

    final Map<FlowerKind, Set<String>> shapes = <FlowerKind, Set<String>>{};
    for (final FlowerKind kind in flowers) {
      final RootDrawing drawing = rootDrawingFor(kind);
      expect(drawing.kind, kind);
      expect(drawing.strokes, hasLength(_strokeCounts[kind]), reason: '$kind');
      for (int index = 0; index < drawing.strokes.length; index++) {
        final RootStroke stroke = drawing.strokes[index];
        expect(stroke.width, greaterThan(0), reason: '$kind stroke $index');
        expect(stroke.length, greaterThan(0), reason: '$kind stroke $index');
        expect(
          stroke.color.toARGB32(),
          _shadeAt(kind, index),
          reason: '$kind stroke $index',
        );
      }
      shapes[kind] = drawing.strokes.map(_shapeOf).toSet();
    }
    for (int first = 0; first < flowers.length; first++) {
      for (int second = first + 1; second < flowers.length; second++) {
        expect(
          shapes[flowers[first]]!.intersection(shapes[flowers[second]]!),
          isEmpty,
          reason: '${flowers[first]} and ${flowers[second]} share a root',
        );
      }
    }
    expect(
      identical(
        rootDrawingFor(FlowerKind.thistle),
        rootDrawingFor(FlowerKind.peony),
      ),
      isTrue,
    );

    expect(
      <FlowerKind>[
        for (final FlowerKind kind in flowers)
          if (rootDrawingFor(kind).bulb != null) kind,
      ],
      <FlowerKind>[FlowerKind.daffodil, FlowerKind.redSpiderLily],
    );
    final RootBulb daffodilBulb = rootDrawingFor(FlowerKind.daffodil).bulb!;
    expect(daffodilBulb.origin.dx, closeTo(100, 1e-6));
    expect(daffodilBulb.origin.dy, closeTo(3, 1e-6));
    expect(daffodilBulb.pieces.first.fill!.toARGB32(), 0xFFEFE0BF);
    final RootBulb lilyBulb = rootDrawingFor(FlowerKind.redSpiderLily).bulb!;
    expect(lilyBulb.origin.dx, closeTo(100, 1e-6));
    expect(lilyBulb.origin.dy, closeTo(2, 1e-6));
    expect(lilyBulb.pieces.first.fill!.toARGB32(), 0xFFC99A7A);
    expect(
      <FlowerKind>[
        for (final FlowerKind kind in flowers)
          if (rootDrawingFor(kind).tubers.isNotEmpty) kind,
      ],
      <FlowerKind>[FlowerKind.peony],
    );
    expect(rootDrawingFor(FlowerKind.peony).tubers, hasLength(5));

    final RootDrawing sunflower = rootDrawingFor(FlowerKind.sunflower);
    final TestRecordingCanvas phoneFit = _record(
      sunflower,
      RootMode.still,
      0,
      _phoneRoots,
    );
    expect(_firstCall(phoneFit, #translate), <double>[0, 0]);
    expect(_firstCall(phoneFit, #scale).first, 0.9);
    final TestRecordingCanvas desktopFit = _record(
      sunflower,
      RootMode.still,
      0,
      _desktopRoots,
    );
    expect(_firstCall(desktopFit, #translate), <double>[25, 0]);
    expect(_firstCall(desktopFit, #scale).first, 0.75);

    for (final FlowerKind kind in flowers) {
      final RootDrawing drawing = rootDrawingFor(kind);
      final int strokes = drawing.strokes.length;
      expect(drawing.lengthOf(RootMode.still), Duration.zero);
      expect(
        drawing.lengthOf(RootMode.grow),
        Duration(milliseconds: 1500 + 90 * (strokes - 1)),
        reason: '$kind',
      );
      expect(
        drawing.lengthOf(RootMode.open),
        Duration(milliseconds: 2650 + 90 * (strokes - 1)),
        reason: '$kind',
      );
      expect(
        drawing.frameAt(RootMode.open, const Duration(milliseconds: 1200)),
        isA<RootFrame>().having(
          (RootFrame frame) => frame.isBlank,
          'isBlank',
          isTrue,
        ),
        reason: '$kind',
      );
      expect(
        drawing
            .frameAt(RootMode.open, const Duration(milliseconds: 1450))
            .strokes,
        everyElement(0),
        reason: '$kind',
      );
      expect(
        drawing
            .frameAt(RootMode.open, const Duration(milliseconds: 1500))
            .strokes
            .first,
        greaterThan(0),
        reason: '$kind',
      );
      expect(
        drawing
            .frameAt(RootMode.grow, const Duration(milliseconds: 150))
            .isBlank,
        isTrue,
        reason: '$kind',
      );
      expect(
        drawing
            .frameAt(RootMode.grow, const Duration(milliseconds: 400))
            .strokes,
        everyElement(0),
        reason: '$kind',
      );
      expect(
        drawing.frameAt(RootMode.grow, drawing.lengthOf(RootMode.grow)),
        isA<RootFrame>().having(
          (RootFrame frame) => frame.isComplete,
          'isComplete',
          isTrue,
        ),
        reason: '$kind',
      );
      expect(
        _countDrawn(_record(drawing, RootMode.still, 0, _phoneRoots)),
        _complete(drawing),
        reason: '$kind',
      );
    }

    for (final FlowerKind kind in flowers) {
      final RootDrawing drawing = rootDrawingFor(kind);
      await _show(
        tester,
        RootArt(key: ValueKey<String>('still $kind'), kind: kind),
      );
      expect(tester.hasRunningAnimations, isFalse, reason: '$kind');
      expect(_painterIn(tester).frame.isComplete, isTrue, reason: '$kind');
      expect(
        find.byType(RootArt),
        paintsExactlyCountTimes(#drawPath, _complete(drawing).paths),
        reason: '$kind',
      );
      expect(
        find.byType(RootArt),
        paintsExactlyCountTimes(#drawOval, _complete(drawing).ovals),
        reason: '$kind',
      );
    }

    for (final FlowerKind kind in flowers) {
      final RootDrawing drawing = rootDrawingFor(kind);
      final Duration length = drawing.lengthOf(RootMode.grow);
      await _show(
        tester,
        RootArt(
          key: ValueKey<String>('grow $kind'),
          kind: kind,
          mode: RootMode.grow,
        ),
      );
      expect(tester.hasRunningAnimations, isTrue, reason: '$kind');
      expect(_painterIn(tester).frame.isBlank, isTrue, reason: '$kind');
      expect(find.byType(RootArt), paintsExactlyCountTimes(#drawPath, 0));
      expect(find.byType(RootArt), paintsExactlyCountTimes(#drawOval, 0));

      await tester.pump(length ~/ 2);
      final RootFrame midway = _painterIn(tester).frame;
      expect(midway.isBlank, isFalse, reason: '$kind');
      expect(midway.isComplete, isFalse, reason: '$kind');
      expect(
        midway.strokes.where((double drawn) => drawn > 0 && drawn < 1),
        isNotEmpty,
        reason: '$kind',
      );
      expect(
        find.byType(RootArt),
        paintsExactlyCountTimes(
          #drawPath,
          midway.strokes.where((double drawn) => drawn > 0).length +
              _complete(drawing).paths -
              drawing.strokes.length,
        ),
        reason: '$kind',
      );

      await tester.pump(length - length ~/ 2);
      expect(_painterIn(tester).frame.isComplete, isTrue, reason: '$kind');
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.hasRunningAnimations, isFalse, reason: '$kind');
      expect(
        find.byType(RootArt),
        paintsExactlyCountTimes(#drawPath, _complete(drawing).paths),
        reason: '$kind',
      );
      expect(
        find.byType(RootArt),
        paintsExactlyCountTimes(#drawOval, _complete(drawing).ovals),
        reason: '$kind',
      );
    }

    await _show(
      tester,
      const RootArt(
        key: ValueKey<String>('open peony'),
        kind: FlowerKind.peony,
      ),
    );
    await _show(
      tester,
      const RootArt(
        key: ValueKey<String>('open peony'),
        kind: FlowerKind.peony,
        mode: RootMode.open,
      ),
    );
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(_painterIn(tester).frame.isBlank, isTrue);
    await tester.pump(
      rootDrawingFor(FlowerKind.peony).lengthOf(RootMode.open) -
          const Duration(milliseconds: 1200),
    );
    await tester.pump(const Duration(milliseconds: 1));
    expect(_painterIn(tester).frame.isComplete, isTrue);
    expect(tester.hasRunningAnimations, isFalse);

    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await _show(
      tester,
      const RootArt(
        key: ValueKey<String>('reduced daffodil'),
        kind: FlowerKind.daffodil,
        mode: RootMode.open,
      ),
      box: _desktopRoots,
      reduceMotion: true,
    );
    expect(tester.hasRunningAnimations, isFalse);
    expect(_painterIn(tester).frame.isComplete, isTrue);
    expect(
      find.byType(RootArt),
      paintsExactlyCountTimes(
        #drawPath,
        _complete(rootDrawingFor(FlowerKind.daffodil)).paths,
      ),
    );
    expect(tester.getSize(find.byType(RootArt)), _desktopRoots);
    expect(
      find.descendant(
        of: find.byType(RootArt),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });
}
