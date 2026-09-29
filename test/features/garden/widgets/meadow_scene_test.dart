import 'package:field_notes/design/flowers/garden_art_colors.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/model/garden_data.dart';
import 'package:field_notes/features/garden/model/meadow_layout.dart';
import 'package:field_notes/features/garden/paint/meadow_painter.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:field_notes/features/garden/widgets/meadow_scene.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final SkyScene _noon = skySceneAt(
  DateTime.utc(2026, 9, 28, 18),
  53.55,
  -113.4667,
);
final SkyScene _dusk = skySceneAt(
  DateTime.utc(2026, 9, 29, 1),
  53.55,
  -113.4667,
);
final SkyScene _midnight = skySceneAt(
  DateTime.utc(2026, 9, 29, 6),
  53.55,
  -113.4667,
);

List<GardenBloomData> _blooms(int n) => List<GardenBloomData>.generate(
  n,
  (int i) => GardenBloomData(
    date: '2026-02-${(i + 1).toString().padLeft(2, '0')}',
    mood: moodOrder[i % moodOrder.length],
  ),
);

Widget _host(
  Widget child, {
  bool disableAnimations = false,
  Size size = const Size(400, 300),
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Center(
      child: SizedBox(width: size.width, height: size.height, child: child),
    ),
  ),
);

MeadowPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(MeadowScene),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as MeadowPainter;

TestRecordingCanvas _record(WidgetTester tester, Size size) {
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  _painter(tester).paint(canvas, size);
  return canvas;
}

int _count(
  TestRecordingCanvas canvas,
  Symbol method,
  int paintIndex,
  Color colour,
) => canvas.invocations.where((RecordedInvocation call) {
  if (call.invocation.memberName != method) {
    return false;
  }
  final Paint paint = call.invocation.positionalArguments[paintIndex] as Paint;
  return paint.color.toARGB32() & 0xFFFFFF == colour.toARGB32() & 0xFFFFFF &&
      paint.maskFilter == null &&
      paint.style == PaintingStyle.fill;
}).length;

void main() {
  testWidgets('one ticker drives all garden motion', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(MeadowScene(blooms: _blooms(6), sky: _noon, seed: 2026)),
    );
    final MeadowPainter painter = _painter(tester);
    expect(painter.animate, isTrue);
    expect(tester.binding.transientCallbackCount, 1);

    final double before = painter.elapsedSeconds;
    final TestRecordingCanvas first = _record(tester, const Size(400, 300));
    await tester.pump(const Duration(milliseconds: 700));
    expect(_painter(tester), same(painter));
    expect(painter.elapsedSeconds, greaterThan(before));
    expect(tester.binding.transientCallbackCount, 1);

    final TestRecordingCanvas second = _record(tester, const Size(400, 300));
    List<String> rotations(TestRecordingCanvas canvas) => <String>[
      for (final RecordedInvocation call in canvas.invocations)
        if (call.invocation.memberName == #rotate)
          '${call.invocation.positionalArguments.first}',
    ];
    expect(rotations(second), isNotEmpty);
    expect(rotations(second), isNot(rotations(first)));

    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('animation frames reuse one meadow layout', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(MeadowScene(blooms: _blooms(20), sky: _noon, seed: 2026)),
    );
    final MeadowLayout layout = _painter(tester).layout;
    expect(layout.size, const Size(400, 300));
    expect(layout.plants, hasLength(20));

    for (int frame = 0; frame < 60; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(_painter(tester).layout, same(layout));
    }

    await tester.pumpWidget(
      _host(MeadowScene(blooms: _blooms(20), sky: _dusk, seed: 2026)),
    );
    expect(_painter(tester).sky, _dusk);
    expect(_painter(tester).layout, same(layout));

    await tester.pumpWidget(
      _host(
        MeadowScene(blooms: _blooms(20), sky: _dusk, seed: 2026),
        size: const Size(520, 300),
      ),
    );
    final MeadowLayout resized = _painter(tester).layout;
    expect(resized, isNot(same(layout)));
    expect(resized.size, const Size(520, 300));

    await tester.pump(const Duration(milliseconds: 16));
    expect(_painter(tester).layout, same(resized));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion schedules no frames once settled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        MeadowScene(blooms: _blooms(6), sky: _midnight, seed: 2026),
        disableAnimations: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(_painter(tester).animate, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pumpWidget(
      _host(MeadowScene(blooms: _blooms(6), sky: _midnight, seed: 2026)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pumpWidget(
      _host(
        MeadowScene(blooms: _blooms(6), sky: _midnight, seed: 2026),
        disableAnimations: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(_painter(tester).animate, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(
      _host(MeadowScene(blooms: _blooms(141), sky: _midnight, seed: 2026)),
    );
    await tester.pumpAndSettle();
    expect(_painter(tester).animate, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a hidden garden or a paused app schedules no frames', (
    WidgetTester tester,
  ) async {
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    Widget scene({required bool shown}) => _host(
      TickerMode(
        enabled: shown,
        child: MeadowScene(blooms: _blooms(6), sky: _noon, seed: 2026),
      ),
    );

    await tester.pumpWidget(scene(shown: false));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(scene(shown: true));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the sky draws at most 34 stars, 9 fireflies and 3 insects', (
    WidgetTester tester,
  ) async {
    for (final (Size size, bool compact, int insects) in <(Size, bool, int)>[
      (const Size(1000, 452), false, 3),
      (const Size(380, 320), true, 2),
    ]) {
      await tester.pumpWidget(
        _host(
          MeadowScene(
            blooms: _blooms(28),
            sky: _midnight,
            seed: 2026,
            compact: compact,
          ),
          size: size,
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      final TestRecordingCanvas night = _record(tester, size);
      final int stars = _count(night, #drawCircle, 2, GardenArtColors.star);
      final int fireflies = _count(
        night,
        #drawCircle,
        2,
        GardenArtColors.firefly,
      );
      expect(stars, lessThanOrEqualTo(34));
      expect(stars, 34);
      expect(fireflies, lessThanOrEqualTo(9));
      expect(fireflies, 9);

      await tester.pumpWidget(
        _host(
          MeadowScene(
            blooms: _blooms(28),
            sky: _noon,
            seed: 2026,
            compact: compact,
          ),
          size: size,
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      final TestRecordingCanvas day = _record(tester, size);
      final int flying =
          _count(day, #drawOval, 1, GardenArtColors.insectBody) +
          _count(day, #drawOval, 1, GardenArtColors.beeBody);
      expect(flying, lessThanOrEqualTo(3));
      expect(flying, insects);
      expect(_count(day, #drawCircle, 2, GardenArtColors.star), 0);
      expect(_count(day, #drawCircle, 2, GardenArtColors.firefly), 0);
    }

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('describes the meadow inside a RepaintBoundary', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        MeadowScene(
          blooms: _blooms(6),
          sprouts: const <String>['2026-02-20'],
          sky: _noon,
          seed: 1,
        ),
        disableAnimations: true,
      ),
    );

    expect(
      find.bySemanticsLabel('Garden meadow with 6 blooms and 1 sprout'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(MeadowScene),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
    handle.dispose();
  });

  testWidgets('an empty meadow still lays out sky and grass', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        MeadowScene(blooms: const <GardenBloomData>[], sky: _noon, seed: 2026),
        disableAnimations: true,
      ),
    );

    final MeadowLayout layout = _painter(tester).layout;
    expect(layout.plants, isEmpty);
    expect(layout.tufts, hasLength(14));
    expect(tester.takeException(), isNull);
  });
}
