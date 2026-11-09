import 'package:field_notes/features/capture/immersive/let_go_panel.dart';
import 'package:field_notes/features/capture/immersive/recorder_surface.dart';
import 'package:field_notes/features/capture/video/camera_picker.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/features/capture/video/video_shutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

const String _readyWords = 'Tap when you’re ready.';
const String _countdownWords = 'Breathe in… recording starts in';
const String _recordingWords = 'I’m listening. Take your time.';
const String _armingHint = 'Getting the camera ready…';
const String _capHint = 'Auto-stops at 30:00.';
const Duration _midFade = Duration(milliseconds: 130);
const Duration _pastFade = Duration(milliseconds: 300);
const Duration _step = Duration(milliseconds: 50);
const int _stepsBeforeHint = 11;
const Size _phoneScreen = Size(412, 915);
const Size _desktopScreen = Size(1440, 900);
const Color _black = Color(0xFF000000);

Widget _sheet({
  required VideoRecorderPhase phase,
  bool asking = false,
  bool cameraOn = true,
  bool withDevices = false,
  bool reduceMotion = false,
  TargetPlatform platform = TargetPlatform.android,
  VoidCallback? onLetGo,
}) {
  return videoSheetHarness(
    Builder(
      builder: (BuildContext context) => Theme(
        data: Theme.of(context).copyWith(platform: platform),
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: VideoRecorderSheet(
            phase: phase,
            asking: asking,
            cameraOn: cameraOn,
            onStart: () {},
            onStop: () {},
            onLeave: () {},
            onKeepGoing: () {},
            onLetGo: onLetGo ?? () {},
            devices: withDevices ? fakeVideoDevices : const [],
            selectedDeviceId: withDevices ? fakeVideoDevices.first.id : null,
            onDeviceChanged: withDevices ? (String id) {} : null,
            onCameraChanged: withDevices ? (bool on) {} : null,
          ),
        ),
      ),
    ),
  );
}

void _useScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

bool _paintsBlack(Widget widget) {
  if (widget is ColoredBox) {
    return widget.color == _black;
  }
  if (widget is DecoratedBox) {
    final Decoration decoration = widget.decoration;
    return decoration is BoxDecoration && decoration.color == _black;
  }
  return false;
}

void _expectWarmStage() {
  expect(
    find.byWidgetPredicate(
      (Widget widget) =>
          widget is ColoredBox && widget.color == recorderStageColor,
    ),
    findsWidgets,
  );
  expect(find.byWidgetPredicate(_paintsBlack), findsNothing);
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
      _useScreen(tester, _phoneScreen);
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
      _expectMidway(find.byKey(videoFlipCameraKey), 'the flip button');
      expect(tester.getRect(microphone).right, closeTo(micRightBefore, 0.01));

      await tester.pump(_pastFade);

      expect(find.byKey(videoCameraKey), findsNothing);
      expect(find.byKey(videoFlipCameraKey), findsNothing);
    },
  );

  testWidgets(
    'the cap hint and the camera picker fade when the breath starts',
    (WidgetTester tester) async {
      _useScreen(tester, _desktopScreen);
      final Finder picker = find.byType(CameraPicker);
      final Finder capHint = find.text(_capHint);

      await _change(
        tester,
        _sheet(
          phase: VideoRecorderPhase.idle,
          withDevices: true,
          platform: TargetPlatform.macOS,
        ),
        _sheet(
          phase: VideoRecorderPhase.breathing,
          withDevices: true,
          platform: TargetPlatform.macOS,
        ),
      );
      await tester.pump(_midFade);

      _expectMidway(picker, 'the camera picker');
      _expectMidway(capHint, 'the cap hint');

      await tester.pump(_pastFade);

      expect(picker, findsNothing);
      expect(capHint, findsNothing);
    },
  );

  testWidgets('the status words ease down as the cap hint goes', (
    WidgetTester tester,
  ) async {
    _useScreen(tester, _phoneScreen);
    await tester.pumpWidget(_sheet(phase: VideoRecorderPhase.idle));
    await tester.pump(_pastFade);
    final double before = tester.getTopLeft(find.text(_readyWords).first).dy;

    await tester.pumpWidget(_sheet(phase: VideoRecorderPhase.breathing));
    await tester.pump(_midFade);
    final double during = tester
        .getTopLeft(find.text(_countdownWords).first)
        .dy;

    await tester.pump(_pastFade);
    final double after = tester.getTopLeft(find.text(_countdownWords).first).dy;

    expect(during, greaterThan(before));
    expect(during, lessThan(after));
  });

  testWidgets(
    'the microphone and camera buttons fade when the camera reopens',
    (WidgetTester tester) async {
      _useScreen(tester, _phoneScreen);
      final Finder microphone = _named('RecorderInputButton');

      await _change(
        tester,
        _sheet(phase: VideoRecorderPhase.idle, withDevices: true),
        _sheet(phase: VideoRecorderPhase.preparing, withDevices: true),
      );
      await tester.pump(_midFade);

      _expectMidway(microphone, 'the microphone');
      _expectMidway(find.byKey(videoCameraKey), 'the camera button');

      await tester.pump(_pastFade);

      expect(microphone, findsNothing);
      expect(find.byKey(videoCameraKey), findsNothing);
    },
  );

  testWidgets('the microphone fades when the take starts saving', (
    WidgetTester tester,
  ) async {
    final Finder microphone = _named('RecorderInputButton');

    await _change(
      tester,
      _sheet(phase: VideoRecorderPhase.recording),
      _sheet(phase: VideoRecorderPhase.saving),
    );
    await tester.pump(_midFade);

    _expectMidway(microphone, 'the microphone');

    await tester.pump(_pastFade);

    expect(microphone, findsNothing);
  });

  testWidgets('an answer that is fading away cannot be pressed', (
    WidgetTester tester,
  ) async {
    int letGoes = 0;
    void letGo() => letGoes += 1;

    await _change(
      tester,
      _sheet(phase: VideoRecorderPhase.recording, asking: true, onLetGo: letGo),
      _sheet(phase: VideoRecorderPhase.recording, onLetGo: letGo),
    );
    await tester.pump(_midFade);

    await tester.tap(find.text(letGoConfirmLabel), warnIfMissed: false);
    await tester.pump();

    expect(letGoes, 0);
  });

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
    _expectWarmStage();

    await tester.pumpWidget(_sheet(phase: VideoRecorderPhase.saving));
    await tester.pump(_pastFade);

    expect(placeholder, findsNothing);
    _expectWarmStage();
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
