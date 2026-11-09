import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/features/capture/video/video_shutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

const Duration _midFade = Duration(milliseconds: 130);
const Duration _pastFade = Duration(milliseconds: 300);
const Duration _halfBreath = Duration(milliseconds: 1500);

Widget _sheet({
  required VideoRecorderPhase phase,
  bool supportsPause = false,
  VoidCallback? onStart,
  VoidCallback? onPause,
  VoidCallback? onResume,
  bool reduceMotion = false,
}) {
  return videoSheetHarness(
    Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: VideoRecorderSheet(
          phase: phase,
          supportsPause: supportsPause,
          onStart: onStart ?? () {},
          onStop: () {},
          onLeave: () {},
          onPause: onPause,
          onResume: onResume,
        ),
      ),
    ),
  );
}

Finder _form(VideoShutterForm form) => find.byKey(videoShutterFormKey(form));

void _expectOnlyForm(VideoShutterForm shown) {
  for (final VideoShutterForm form in VideoShutterForm.values) {
    expect(
      _form(form),
      form == shown ? findsOneWidget : findsNothing,
      reason: '${form.name} while ${shown.name} should show',
    );
  }
}

double _fadeOf(WidgetTester tester, Finder finder) {
  final Element element = tester.element(finder);
  double product = _ownFade(element.widget);
  element.visitAncestorElements((Element ancestor) {
    product *= _ownFade(ancestor.widget);
    return true;
  });
  return product;
}

double _ownFade(Widget widget) {
  if (widget is Opacity) {
    return widget.opacity;
  }
  if (widget is FadeTransition) {
    return widget.opacity.value;
  }
  return 1;
}

double _shutterOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find
          .descendant(
            of: find.byKey(videoShutterKey),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

void _expectMidway(WidgetTester tester, Finder finder, String what) {
  expect(finder, findsOneWidget, reason: what);
  final double fade = _fadeOf(tester, finder);
  expect(fade, greaterThan(0), reason: what);
  expect(fade, lessThan(1), reason: what);
}

void main() {
  testWidgets('the shutter shows the ready form while idle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_sheet(phase: VideoRecorderPhase.idle));
    await tester.pump();

    _expectOnlyForm(VideoShutterForm.ready);
  });

  testWidgets(
    'the shutter shows the countdown form during the breath and while arming',
    (WidgetTester tester) async {
      await tester.pumpWidget(_sheet(phase: VideoRecorderPhase.breathing));
      await tester.pump(_pastFade);

      _expectOnlyForm(VideoShutterForm.countdown);

      await tester.pumpWidget(_sheet(phase: VideoRecorderPhase.arming));
      await tester.pump(_pastFade);

      _expectOnlyForm(VideoShutterForm.countdown);
    },
  );

  testWidgets(
    'the shutter shows the pause form while recording with pause available and the stop form without it',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _sheet(
          phase: VideoRecorderPhase.recording,
          supportsPause: true,
          onPause: () {},
        ),
      );
      await tester.pump();

      _expectOnlyForm(VideoShutterForm.pause);
      expect(
        tester
            .widget<IconStickerGlyphIcon>(
              find.descendant(
                of: _form(VideoShutterForm.pause),
                matching: find.byType(IconStickerGlyphIcon),
              ),
            )
            .glyph,
        IconStickerGlyph.pause,
      );

      await tester.pumpWidget(_sheet(phase: VideoRecorderPhase.recording));
      await tester.pump(_pastFade);

      _expectOnlyForm(VideoShutterForm.stop);
    },
  );

  testWidgets('the shutter shows the resume form while paused', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _sheet(
        phase: VideoRecorderPhase.paused,
        supportsPause: true,
        onResume: () {},
      ),
    );
    await tester.pump();

    _expectOnlyForm(VideoShutterForm.resume);
  });

  testWidgets(
    'the countdown ring has filled half way after half of the breath',
    (WidgetTester tester) async {
      await tester.pumpWidget(_sheet(phase: VideoRecorderPhase.idle));
      await tester.pump();
      await tester.pumpWidget(_sheet(phase: VideoRecorderPhase.breathing));
      await tester.pump(_halfBreath);

      final Iterable<VideoCountdownRingPainter> rings = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: _form(VideoShutterForm.countdown),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((CustomPaint paint) => paint.painter)
          .whereType<VideoCountdownRingPainter>();

      expect(rings, hasLength(1));
      expect(rings.single.fraction, inInclusiveRange(0.45, 0.55));
    },
  );

  testWidgets(
    'the shutter stays at full strength while arming and ignores presses',
    (WidgetTester tester) async {
      int starts = 0;

      await tester.pumpWidget(
        _sheet(phase: VideoRecorderPhase.arming, onStart: () => starts += 1),
      );
      await tester.pump(_pastFade);

      expect(
        _fadeOf(tester, _form(VideoShutterForm.countdown)),
        closeTo(1, 1e-9),
      );

      await tester.tap(find.byKey(videoShutterKey), warnIfMissed: false);
      await tester.pump();

      expect(starts, 0);
    },
  );

  testWidgets('the shutter dims gradually when the take pauses', (
    WidgetTester tester,
  ) async {
    Widget sheet(VideoRecorderPhase phase) => _sheet(
      phase: phase,
      supportsPause: true,
      onPause: () {},
      onResume: () {},
    );

    await tester.pumpWidget(sheet(VideoRecorderPhase.recording));
    await tester.pump(_pastFade);
    expect(_shutterOpacity(tester), closeTo(1, 1e-9));

    await tester.pumpWidget(sheet(VideoRecorderPhase.paused));
    await tester.pump(_midFade);

    expect(_shutterOpacity(tester), greaterThan(videoPausedShutterOpacity));
    expect(_shutterOpacity(tester), lessThan(1));

    await tester.pump(_pastFade);

    expect(_shutterOpacity(tester), closeTo(videoPausedShutterOpacity, 1e-9));
  });

  testWidgets('old and new shutter forms overlap while the phase changes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_sheet(phase: VideoRecorderPhase.idle));
    await tester.pump();
    await tester.pumpWidget(_sheet(phase: VideoRecorderPhase.breathing));
    await tester.pump(_midFade);

    _expectMidway(tester, _form(VideoShutterForm.ready), 'the ready form');
    _expectMidway(
      tester,
      _form(VideoShutterForm.countdown),
      'the countdown form',
    );

    await tester.pump(_pastFade);

    _expectOnlyForm(VideoShutterForm.countdown);
  });

  testWidgets('with reduced motion the shutter form changes at once', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _sheet(phase: VideoRecorderPhase.idle, reduceMotion: true),
    );
    await tester.pump();
    await tester.pumpWidget(
      _sheet(phase: VideoRecorderPhase.breathing, reduceMotion: true),
    );
    await tester.pump();

    _expectOnlyForm(VideoShutterForm.countdown);
  });
}
