import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/features/capture/video/video_shutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

const String _readyWords = 'Tap when you’re ready.';
const String _countdownWords = 'Breathe in… recording starts in';
const String _recordingWords = 'I’m listening. Take your time.';
const String _armingHint = 'Getting the camera ready…';
const Duration _midFade = Duration(milliseconds: 130);
const Duration _pastFade = Duration(milliseconds: 300);
const Duration _step = Duration(milliseconds: 50);
const int _stepsBeforeHint = 11;
const Size _phoneScreen = Size(412, 915);

Widget _sheet({
  required VideoRecorderPhase phase,
  bool asking = false,
  bool cameraOn = true,
  bool withDevices = false,
  bool reduceMotion = false,
}) {
  return videoSheetHarness(
    Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: VideoRecorderSheet(
          phase: phase,
          asking: asking,
          cameraOn: cameraOn,
          onStart: () {},
          onStop: () {},
          onLeave: () {},
          onKeepGoing: () {},
          onLetGo: () {},
          devices: withDevices ? fakeVideoDevices : const [],
          selectedDeviceId: withDevices ? fakeVideoDevices.first.id : null,
          onDeviceChanged: withDevices ? (String id) {} : null,
          onCameraChanged: withDevices ? (bool on) {} : null,
        ),
      ),
    ),
  );
}

Finder _named(String typeName) => find.byWidgetPredicate(
  (Widget widget) => widget.runtimeType.toString() == typeName,
);

double _fadeOf(Element element) {
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

void _expectMidway(Finder finder, String what) {
  final List<Element> found = finder.evaluate().toList();
  expect(found, isNotEmpty, reason: '$what is missing');
  for (final Element element in found) {
    final double fade = _fadeOf(element);
    expect(fade, greaterThan(0), reason: what);
    expect(fade, lessThan(1), reason: what);
  }
}

Future<void> _change(
  WidgetTester tester,
  Widget from,
  Widget to, {
  Duration settle = _pastFade,
}) async {
  await tester.pumpWidget(from);
  await tester.pump(settle);
  await tester.pumpWidget(to);
}

void main() {
  testWidgets('the status words cross-fade from ready to countdown', (
    WidgetTester tester,
  ) async {
    await _change(
      tester,
      _sheet(phase: VideoRecorderPhase.idle),
      _sheet(phase: VideoRecorderPhase.breathing),
    );
    expect(find.byKey(videoShutterFormKey(VideoShutterForm.ready)), findsOne);
    await tester.pump(_midFade);

    _expectMidway(find.text(_readyWords), 'the ready words');
    _expectMidway(find.text(_countdownWords), 'the countdown words');
  });

  testWidgets('the status words cross-fade from countdown to recording', (
    WidgetTester tester,
  ) async {
    await _change(
      tester,
      _sheet(phase: VideoRecorderPhase.breathing),
      _sheet(phase: VideoRecorderPhase.recording),
    );
    expect(
      find.byKey(videoShutterFormKey(VideoShutterForm.countdown)),
      findsOne,
    );
    await tester.pump(_midFade);

    _expectMidway(find.text(_countdownWords), 'the countdown words');
    _expectMidway(find.text(_recordingWords), 'the recording words');
  });

  testWidgets('let go and keep fade in when the take starts', (
    WidgetTester tester,
  ) async {
    await _change(
      tester,
      _sheet(phase: VideoRecorderPhase.breathing),
      _sheet(phase: VideoRecorderPhase.recording),
    );
    await tester.pump(_midFade);

    _expectMidway(find.byKey(videoDiscardCircleKey), 'Let go');
    _expectMidway(find.byKey(videoSaveCircleKey), 'Keep');
  });

  testWidgets(
    'the camera and flip buttons fade away when the breath starts without moving the microphone',
    (WidgetTester tester) async {
      tester.view.physicalSize = _phoneScreen;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final Finder microphone = _named('RecorderInputButton');

      await tester.pumpWidget(
        _sheet(phase: VideoRecorderPhase.idle, withDevices: true),
      );
      await tester.pump(_pastFade);
      expect(find.byKey(videoCameraKey), findsOneWidget);
      expect(microphone, findsOneWidget);
      final double micRightBefore = tester.getRect(microphone).right;

      await tester.pumpWidget(
        _sheet(phase: VideoRecorderPhase.breathing, withDevices: true),
      );
      await tester.pump(_midFade);

      _expectMidway(find.byKey(videoCameraKey), 'the camera button');
      expect(tester.getRect(microphone).right, closeTo(micRightBefore, 0.01));

      await tester.pump(_pastFade);

      expect(find.byKey(videoCameraKey), findsNothing);
    },
  );

  testWidgets('the breathing glow fades out when the breath ends', (
    WidgetTester tester,
  ) async {
    final Finder glow = _named('BreathingGlow');
    await _change(
      tester,
      _sheet(phase: VideoRecorderPhase.breathing),
      _sheet(phase: VideoRecorderPhase.recording),
    );
    await tester.pump(_midFade);

    _expectMidway(glow, 'the breathing glow');

    await tester.pump(_pastFade);

    expect(glow, findsNothing);
  });

  testWidgets('with reduced motion the status words change at once', (
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

    expect(find.text(_readyWords), findsNothing);
    expect(find.text(_countdownWords), findsWidgets);
  });

  testWidgets('the let go question cross-fades with the controls', (
    WidgetTester tester,
  ) async {
    await _change(
      tester,
      _sheet(phase: VideoRecorderPhase.recording),
      _sheet(phase: VideoRecorderPhase.recording, asking: true),
    );
    await tester.pump(_midFade);

    _expectMidway(find.byKey(videoKeepGoingKey), 'the keep going answer');
    _expectMidway(find.byKey(videoShutterKey), 'the shutter');
  });

  testWidgets('no placeholder shows while the picture is absent', (
    WidgetTester tester,
  ) async {
    final Finder placeholder = _named('CrossHatchPlaceholder');

    await tester.pumpWidget(_sheet(phase: VideoRecorderPhase.preparing));
    await tester.pump();

    expect(placeholder, findsNothing);

    await tester.pumpWidget(_sheet(phase: VideoRecorderPhase.saving));
    await tester.pump(_pastFade);

    expect(placeholder, findsNothing);
  });

  testWidgets(
    'arming shows no getting ready words for the first 600 milliseconds',
    (WidgetTester tester) async {
      await _change(
        tester,
        _sheet(phase: VideoRecorderPhase.breathing),
        _sheet(phase: VideoRecorderPhase.arming),
      );

      for (int step = 0; step < _stepsBeforeHint; step += 1) {
        await tester.pump(_step);
        expect(
          find.text(_armingHint),
          findsNothing,
          reason: 'at ${(step + 1) * _step.inMilliseconds} ms',
        );
        expect(
          find.text(_countdownWords),
          findsWidgets,
          reason: 'at ${(step + 1) * _step.inMilliseconds} ms',
        );
      }
    },
  );

  testWidgets(
    'a slow start shows the getting ready words after 600 milliseconds',
    (WidgetTester tester) async {
      await _change(
        tester,
        _sheet(phase: VideoRecorderPhase.breathing),
        _sheet(phase: VideoRecorderPhase.arming),
      );

      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(_pastFade);

      expect(find.text(_armingHint), findsWidgets);
    },
  );

  testWidgets(
    'opening the camera shows no getting ready words for the first 600 milliseconds',
    (WidgetTester tester) async {
      await tester.pumpWidget(_sheet(phase: VideoRecorderPhase.preparing));

      for (int step = 0; step < _stepsBeforeHint; step += 1) {
        await tester.pump(_step);
        expect(
          find.text(_armingHint),
          findsNothing,
          reason: 'at ${(step + 1) * _step.inMilliseconds} ms',
        );
      }

      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(_armingHint), findsWidgets);
    },
  );
}
