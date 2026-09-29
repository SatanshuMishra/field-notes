import 'dart:ui';

import 'package:field_notes/design/flowers/garden_art_colors.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/model/garden_data.dart';
import 'package:field_notes/features/garden/model/garden_insect.dart';
import 'package:field_notes/features/garden/model/meadow_layout.dart';
import 'package:field_notes/features/garden/paint/meadow_painter.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _card = Size(1000, 452);

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

final List<GardenBloomData> _blooms = <GardenBloomData>[
  for (int i = 0; i < 12; i++)
    GardenBloomData(
      date: '2026-03-${(i + 1).toString().padLeft(2, '0')}',
      mood: moodOrder[i % moodOrder.length],
    ),
];

MeadowLayout _layout({bool compact = false, Size size = _card}) =>
    layoutMeadowByDepth(
      blooms: _blooms,
      sprouts: const <String>['2026-03-20'],
      size: size,
      seed: 2026,
      compact: compact,
    );

final List<SkyStar> _stars = skyStarsFor(2026);
final List<GardenFirefly> _fireflies = gardenFirefliesFor(2026);

MeadowPainter _painter({
  required SkyScene sky,
  MeadowLayout? layout,
  bool compact = false,
  bool animate = true,
  ValueListenable<Duration>? clock,
}) => MeadowPainter(
  layout: layout ?? _layout(compact: compact),
  sky: sky,
  compact: compact,
  stars: _stars,
  fireflies: _fireflies,
  insects: gardenInsectsFor(compact: compact),
  animate: animate,
  clock: clock,
);

List<Paint> _paintsOf(TestRecordingCanvas canvas, Symbol method, int index) =>
    <Paint>[
      for (final RecordedInvocation call in canvas.invocations)
        if (call.invocation.memberName == method)
          call.invocation.positionalArguments[index] as Paint,
    ];

bool _sameRgb(Color a, Color b) =>
    a.toARGB32() & 0xFFFFFF == b.toARGB32() & 0xFFFFFF;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('paints noon, dusk and midnight on desktop and phone', () {
    for (final SkyScene sky in <SkyScene>[_noon, _dusk, _midnight]) {
      for (final bool compact in <bool>[false, true]) {
        final PictureRecorder recorder = PictureRecorder();
        expect(
          () => _painter(
            sky: sky,
            compact: compact,
            clock: ValueNotifier<Duration>(const Duration(seconds: 3)),
          ).paint(Canvas(recorder), compact ? const Size(380, 320) : _card),
          returnsNormally,
        );
        recorder.endRecording().dispose();
      }
    }
  });

  test(
    'a still frame hides fireflies and insects and keeps plants upright',
    () {
      final TestRecordingCanvas moving = TestRecordingCanvas();
      _painter(
        sky: _midnight,
        clock: ValueNotifier<Duration>(const Duration(seconds: 2)),
      ).paint(moving, _card);
      final TestRecordingCanvas still = TestRecordingCanvas();
      _painter(
        sky: _midnight,
        animate: false,
        clock: ValueNotifier<Duration>(const Duration(seconds: 2)),
      ).paint(still, _card);

      bool firefly(Paint paint) =>
          _sameRgb(paint.color, GardenArtColors.firefly) &&
          paint.maskFilter == null;
      expect(_paintsOf(moving, #drawCircle, 2).where(firefly), hasLength(9));
      expect(_paintsOf(still, #drawCircle, 2).where(firefly), isEmpty);
      expect(
        still.invocations.where(
          (RecordedInvocation call) => call.invocation.memberName == #rotate,
        ),
        isEmpty,
      );
    },
  );

  test('the sun hides behind the meadow and the night multiplies over it', () {
    final TestRecordingCanvas canvas = TestRecordingCanvas();
    _painter(sky: _midnight).paint(canvas, _card);
    final List<Symbol> calls = <Symbol>[
      for (final RecordedInvocation call in canvas.invocations)
        call.invocation.memberName,
    ];
    final int lastPicture = calls.lastIndexOf(#drawPicture);
    final int multiply = canvas.invocations.indexWhere(
      (RecordedInvocation call) =>
          call.invocation.memberName == #drawRect &&
          (call.invocation.positionalArguments[1] as Paint).blendMode ==
              BlendMode.multiply,
    );
    expect(lastPicture, greaterThan(0));
    expect(multiply, greaterThan(lastPicture));
  });

  test(
    'repaints for a new sky, motion or layout but not for the same inputs',
    () {
      final MeadowLayout layout = _layout();
      final ValueNotifier<Duration> clock = ValueNotifier<Duration>(
        Duration.zero,
      );
      final MeadowPainter a = _painter(
        sky: _noon,
        layout: layout,
        clock: clock,
      );
      final MeadowPainter same = _painter(
        sky: _noon,
        layout: layout,
        clock: clock,
      );
      expect(a.shouldRepaint(same), isFalse);
      expect(
        a.shouldRepaint(_painter(sky: _dusk, layout: layout, clock: clock)),
        isTrue,
      );
      expect(
        a.shouldRepaint(
          _painter(sky: _noon, layout: layout, clock: clock, animate: false),
        ),
        isTrue,
      );
      expect(
        a.shouldRepaint(
          _painter(
            sky: _noon,
            layout: _layout(size: const Size(900, 452)),
            clock: clock,
          ),
        ),
        isTrue,
      );
    },
  );

  test('reads elapsed time from its clock only while animating', () {
    final ValueNotifier<Duration> clock = ValueNotifier<Duration>(
      const Duration(milliseconds: 1500),
    );
    expect(_painter(sky: _noon, clock: clock).elapsedSeconds, 1.5);
    expect(
      _painter(sky: _noon, clock: clock, animate: false).elapsedSeconds,
      0,
    );
  });

  test('stars are seeded into the top band of the sky', () {
    final List<SkyStar> stars = skyStarsFor(2026);
    expect(stars, hasLength(34));
    for (final SkyStar star in stars) {
      expect(star.x, inInclusiveRange(0, 1));
      expect(star.y, inInclusiveRange(0, 0.9));
      expect(star.size, inInclusiveRange(0.8, 2.6));
      expect(star.period, inInclusiveRange(2, 5));
    }
    expect(
      skyStarsFor(2026).map((SkyStar s) => s.x),
      stars.map((SkyStar s) => s.x),
    );
  });

  test('paints an empty meadow without throwing', () {
    final PictureRecorder recorder = PictureRecorder();
    expect(
      () => _painter(
        sky: _noon,
        layout: layoutMeadowByDepth(
          blooms: const <GardenBloomData>[],
          size: _card,
          seed: 1,
        ),
      ).paint(Canvas(recorder), _card),
      returnsNormally,
    );
    recorder.endRecording().dispose();
  });
}
