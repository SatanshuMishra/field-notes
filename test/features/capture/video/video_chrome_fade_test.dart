import 'package:field_notes/features/capture/audio/microphone_hearing.dart';
import 'package:field_notes/features/capture/immersive/recorder_chrome.dart';
import 'package:field_notes/features/capture/immersive/recorder_shortcuts.dart';
import 'package:field_notes/features/capture/immersive/reflection_prompt.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

const String _recordingWords = 'I’m listening. Take your time.';
const String _sixtyFiveSeconds = '1:05';
const String _nudge = 'Still there? Take your time.';
const String _takeError = 'The take could not be saved.';
const Size _phoneScreen = Size(412, 915);
const Size _desktopScreen = Size(1440, 900);
const Duration _fade = Duration(milliseconds: 300);
const Duration _beforeFade = Duration(milliseconds: 400);
const Duration _midFade = Duration(milliseconds: 130);
const Duration _longWait = Duration(milliseconds: 9700);
const Duration _justBeforeHide = Duration(milliseconds: 2500);
const Duration _heldAfterInput = Duration(milliseconds: 2200);
const Duration _acrossHide = Duration(milliseconds: 200);

void _useScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app(
  Widget sheet, {
  TargetPlatform platform = TargetPlatform.android,
  bool reduceMotion = false,
  bool accessibleNavigation = false,
}) {
  return ProviderScope(
    overrides: [reflectionPromptsOff()],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(platform: platform),
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            accessibleNavigation: accessibleNavigation,
          ),
          child: Scaffold(body: Center(child: sheet)),
        ),
      ),
    ),
  );
}

VideoRecorderSheet _sheet({
  required VideoRecorderPhase phase,
  bool supportsPause = false,
  VoidCallback? onPause,
  bool asking = false,
  bool cameraOn = true,
  Duration elapsed = Duration.zero,
  String? nudgeMessage,
  String? errorMessage,
  MicrophoneHearing hearing = MicrophoneHearing.hearing,
  FakeVideoRecorder? controls,
}) {
  final FakeVideoRecorder? camera = controls;
  return VideoRecorderSheet(
    phase: phase,
    supportsPause: supportsPause,
    onStart: () {},
    onStop: () {},
    onLeave: () {},
    onPause: onPause,
    onResume: () {},
    onKeepGoing: () {},
    onLetGo: () {},
    asking: asking,
    cameraOn: cameraOn,
    elapsed: elapsed,
    nudgeMessage: nudgeMessage,
    errorMessage: errorMessage,
    hearing: hearing,
    controls: camera,
    preview: camera?.openSession(fakeVideoDevices.first.id),
    devices: camera == null ? const [] : fakeVideoDevices,
    selectedDeviceId: camera == null ? null : fakeVideoDevices.first.id,
  );
}

Finder _named(String typeName) => find.byWidgetPredicate(
  (Widget widget) => widget.runtimeType.toString() == typeName,
);

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

void _expectFade(
  WidgetTester tester,
  Finder finder,
  double expected,
  String what,
) {
  expect(finder, findsOneWidget, reason: '$what is missing');
  expect(_fadeOf(tester, finder), closeTo(expected, 1e-9), reason: what);
}

Future<void> _pastHold(WidgetTester tester) async {
  await tester.pump(recorderChromeHold + _beforeFade);
  await tester.pump(_fade);
}

Future<void> _longHold(WidgetTester tester) async {
  await tester.pump(_longWait);
  await tester.pump(_fade);
}

Future<void> _afterInput(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(_fade);
}

Offset _middleOf(WidgetTester tester) =>
    tester.getCenter(find.byType(VideoRecorderSheet));

void main() {
  testWidgets(
    'a few seconds into a take only the microphone and the recording indicator remain',
    (WidgetTester tester) async {
      _useScreen(tester, _phoneScreen);
      await tester.pumpWidget(
        _app(_sheet(phase: VideoRecorderPhase.recording)),
      );
      await _pastHold(tester);

      _expectFade(tester, find.byKey(videoShutterKey), 0, 'the shutter');
      _expectFade(tester, find.byKey(videoCloseKey), 0, 'the close button');
      _expectFade(tester, find.byKey(videoDiscardCircleKey), 0, 'Let go');
      _expectFade(tester, find.byKey(videoSaveCircleKey), 0, 'Keep');
      _expectFade(tester, find.text(_recordingWords), 0, 'the status words');
      _expectFade(tester, _named('RecorderInputButton'), 1, 'the microphone');
      _expectFade(
        tester,
        find.byKey(videoTakeIndicatorKey),
        1,
        'the recording indicator',
      );
    },
  );

  testWidgets(
    'the recording indicator shows the elapsed time while the controls are hidden',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _app(
          _sheet(
            phase: VideoRecorderPhase.recording,
            elapsed: const Duration(seconds: 65),
          ),
        ),
      );
      await _pastHold(tester);

      expect(
        find.descendant(
          of: find.byKey(videoTakeIndicatorKey),
          matching: find.text(_sixtyFiveSeconds),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('the controls fade rather than cut', (WidgetTester tester) async {
    await tester.pumpWidget(_app(_sheet(phase: VideoRecorderPhase.recording)));
    await tester.pump(_justBeforeHide);

    _expectFade(tester, find.byKey(videoShutterKey), 1, 'the shutter');

    await tester.pump(_acrossHide);
    await tester.pump(_midFade);

    final double fade = _fadeOf(tester, find.byKey(videoShutterKey));
    expect(fade, greaterThan(0));
    expect(fade, lessThan(1));
  });

  testWidgets('the controls hide a hold after the breath becomes a take', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_sheet(phase: VideoRecorderPhase.breathing)));
    await tester.pump(_fade);

    await tester.pumpWidget(_app(_sheet(phase: VideoRecorderPhase.recording)));
    await _pastHold(tester);

    _expectFade(tester, find.byKey(videoShutterKey), 0, 'the shutter');
  });

  testWidgets('resuming a paused take starts a new hold', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_sheet(phase: VideoRecorderPhase.paused)));
    await _longHold(tester);

    await tester.pumpWidget(_app(_sheet(phase: VideoRecorderPhase.recording)));
    await tester.pump(_justBeforeHide);

    _expectFade(tester, find.byKey(videoShutterKey), 1, 'the shutter');

    await tester.pump(_acrossHide);
    await tester.pump(_fade);

    _expectFade(tester, find.byKey(videoShutterKey), 0, 'the shutter');
  });

  testWidgets('answering the let go question starts a new hold', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_sheet(phase: VideoRecorderPhase.recording, asking: true)),
    );
    await _longHold(tester);

    await tester.pumpWidget(_app(_sheet(phase: VideoRecorderPhase.recording)));
    await tester.pump(_midFade);
    await tester.pump(_justBeforeHide);

    _expectFade(tester, find.byKey(videoShutterKey), 1, 'the shutter');

    await tester.pump(_acrossHide);
    await tester.pump(_fade);

    _expectFade(tester, find.byKey(videoShutterKey), 0, 'the shutter');
  });

  testWidgets('the controls come back as a fade after an input', (
    WidgetTester tester,
  ) async {
    _useScreen(tester, _phoneScreen);
    await tester.pumpWidget(_app(_sheet(phase: VideoRecorderPhase.recording)));
    await _pastHold(tester);

    await tester.tapAt(_middleOf(tester));
    await tester.pump();
    await tester.pump(_midFade);

    final double fade = _fadeOf(tester, find.byKey(videoShutterKey));
    expect(fade, greaterThan(0));
    expect(fade, lessThan(1));
  });

  testWidgets('with reduced motion the controls come back at once', (
    WidgetTester tester,
  ) async {
    _useScreen(tester, _phoneScreen);
    await tester.pumpWidget(
      _app(_sheet(phase: VideoRecorderPhase.recording), reduceMotion: true),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    _expectFade(tester, find.byKey(videoShutterKey), 0, 'the shutter');

    await tester.tapAt(_middleOf(tester));
    await tester.pump();

    _expectFade(tester, find.byKey(videoShutterKey), 1, 'the shutter');
  });

  testWidgets('the recording indicator fades away when a hidden take pauses', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_sheet(phase: VideoRecorderPhase.recording)));
    await _pastHold(tester);
    _expectFade(
      tester,
      find.byKey(videoTakeIndicatorKey),
      1,
      'the recording indicator',
    );

    await tester.pumpWidget(_app(_sheet(phase: VideoRecorderPhase.paused)));
    await tester.pump(_midFade);

    final double fade = _fadeOf(tester, find.byKey(videoTakeIndicatorKey));
    expect(fade, greaterThan(0));
    expect(fade, lessThan(1));

    await tester.pump(_fade);

    expect(find.byKey(videoTakeIndicatorKey), findsNothing);
  });

  testWidgets('the camera off words fade with the controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_sheet(phase: VideoRecorderPhase.recording, cameraOn: false)),
    );
    await _pastHold(tester);

    _expectFade(
      tester,
      find.text(videoCameraOffMessage),
      0,
      'the camera off words',
    );
  });

  testWidgets(
    'once the controls are hidden nothing keeps the screen redrawing',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _app(
          _sheet(
            phase: VideoRecorderPhase.recording,
            controls: FakeVideoRecorder(),
          ),
        ),
      );
      await _pastHold(tester);
      await tester.pump(const Duration(milliseconds: 16));

      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );

  testWidgets('hidden controls cannot be pressed', (WidgetTester tester) async {
    int pauses = 0;
    await tester.pumpWidget(
      _app(
        _sheet(
          phase: VideoRecorderPhase.recording,
          supportsPause: true,
          onPause: () => pauses += 1,
        ),
      ),
    );
    await _pastHold(tester);
    expect(_fadeOf(tester, find.byKey(videoShutterKey)), closeTo(0, 1e-9));

    await tester.tap(find.byKey(videoShutterKey), warnIfMissed: false);
    await tester.pump();

    expect(pauses, 0);
  });

  testWidgets('nothing fades outside a take', (WidgetTester tester) async {
    await tester.pumpWidget(_app(_sheet(phase: VideoRecorderPhase.idle)));
    await _longHold(tester);

    _expectFade(tester, find.byKey(videoShutterKey), 1, 'the shutter');
    _expectFade(tester, find.byKey(videoCloseKey), 1, 'the close button');
    expect(find.byKey(videoTakeIndicatorKey), findsNothing);
  });

  testWidgets(
    'on a desktop the controls hide while the recorder holds its own keyboard focus',
    (WidgetTester tester) async {
      _useScreen(tester, _desktopScreen);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );

      await tester.pumpWidget(
        _app(
          _sheet(phase: VideoRecorderPhase.recording),
          platform: TargetPlatform.macOS,
        ),
      );
      await _pastHold(tester);

      final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
      expect(
        focused?.findAncestorWidgetOfExactType<RecorderShortcuts>(),
        isNotNull,
      );
      _expectFade(tester, find.byKey(videoShutterKey), 0, 'the shutter');
      _expectFade(
        tester,
        find.byKey(videoKeyboardHintKey),
        0,
        'the keyboard hint',
      );
      _expectFade(tester, find.byType(ReflectionPrompt), 0, 'the question');
    },
    semanticsEnabled: false,
  );

  testWidgets(
    'a tap on the picture brings the controls back without focusing',
    (WidgetTester tester) async {
      _useScreen(tester, _phoneScreen);
      final FakeVideoRecorder camera = FakeVideoRecorder();
      await tester.pumpWidget(
        _app(_sheet(phase: VideoRecorderPhase.recording, controls: camera)),
      );
      await _pastHold(tester);
      expect(_fadeOf(tester, find.byKey(videoShutterKey)), closeTo(0, 1e-9));

      await tester.tapAt(_middleOf(tester));
      await _afterInput(tester);

      _expectFade(tester, find.byKey(videoShutterKey), 1, 'the shutter');
      expect(camera.focusPoints, isEmpty);
    },
  );

  testWidgets('moving the mouse brings the controls back', (
    WidgetTester tester,
  ) async {
    _useScreen(tester, _desktopScreen);
    await tester.pumpWidget(
      _app(
        _sheet(phase: VideoRecorderPhase.recording),
        platform: TargetPlatform.macOS,
      ),
    );
    await _pastHold(tester);
    expect(_fadeOf(tester, find.byKey(videoShutterKey)), closeTo(0, 1e-9));

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(40, 40));
    await mouse.moveTo(_middleOf(tester));
    await _afterInput(tester);

    _expectFade(tester, find.byKey(videoShutterKey), 1, 'the shutter');
  }, semanticsEnabled: false);

  testWidgets('pressing a key brings the controls back', (
    WidgetTester tester,
  ) async {
    _useScreen(tester, _desktopScreen);
    await tester.pumpWidget(
      _app(
        _sheet(phase: VideoRecorderPhase.recording),
        platform: TargetPlatform.macOS,
      ),
    );
    await _pastHold(tester);
    expect(_fadeOf(tester, find.byKey(videoShutterKey)), closeTo(0, 1e-9));

    await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    await _afterInput(tester);

    _expectFade(tester, find.byKey(videoShutterKey), 1, 'the shutter');
  }, semanticsEnabled: false);

  testWidgets('the controls hide again a few seconds after the last touch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_sheet(phase: VideoRecorderPhase.recording)));
    await _pastHold(tester);

    await tester.tapAt(_middleOf(tester));
    await _afterInput(tester);
    expect(_fadeOf(tester, find.byKey(videoShutterKey)), closeTo(1, 1e-9));
    await tester.pump(_heldAfterInput);

    _expectFade(tester, find.byKey(videoShutterKey), 1, 'the shutter');

    await tester.pump(_acrossHide);
    await tester.pump(_fade);

    _expectFade(tester, find.byKey(videoShutterKey), 0, 'the shutter');
  });

  testWidgets('the controls stay while the take is paused', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_sheet(phase: VideoRecorderPhase.paused)));
    await _longHold(tester);

    expect(_fadeOf(tester, find.byKey(videoShutterKey)), greaterThan(0));
    expect(find.byKey(videoTakeIndicatorKey), findsNothing);
  });

  testWidgets('the controls stay while the let go question is open', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_sheet(phase: VideoRecorderPhase.recording, asking: true)),
    );
    await _longHold(tester);

    _expectFade(
      tester,
      find.byKey(videoKeepGoingKey),
      1,
      'the keep going answer',
    );
  });

  testWidgets('a nudge or an error brings the controls back for one hold', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_sheet(phase: VideoRecorderPhase.recording)));
    await _pastHold(tester);

    await tester.pumpWidget(
      _app(_sheet(phase: VideoRecorderPhase.recording, nudgeMessage: _nudge)),
    );
    await tester.pump(_fade);
    _expectFade(tester, find.text(_nudge), 1, 'the nudge');
    await _pastHold(tester);
    _expectFade(tester, find.text(_nudge), 0, 'the nudge');

    await tester.pumpWidget(
      _app(
        _sheet(phase: VideoRecorderPhase.recording, errorMessage: _takeError),
      ),
    );
    await tester.pump(_fade);
    _expectFade(tester, find.text(_takeError), 1, 'the take error');
    await _pastHold(tester);
    _expectFade(tester, find.text(_takeError), 0, 'the take error');
  });

  testWidgets('the controls stay while the microphone cannot be heard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _sheet(
          phase: VideoRecorderPhase.recording,
          hearing: MicrophoneHearing.cannotHear,
        ),
      ),
    );
    await _longHold(tester);

    _expectFade(tester, find.byKey(videoShutterKey), 1, 'the shutter');
  });

  testWidgets('the controls stay while the microphone is opening', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _sheet(
          phase: VideoRecorderPhase.recording,
          hearing: MicrophoneHearing.opening,
        ),
      ),
    );
    await _longHold(tester);

    _expectFade(tester, find.byKey(videoShutterKey), 1, 'the shutter');
  });

  testWidgets('the controls stay for a screen reader', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _sheet(phase: VideoRecorderPhase.recording),
        accessibleNavigation: true,
      ),
    );
    await _longHold(tester);

    _expectFade(tester, find.byKey(videoShutterKey), 1, 'the shutter');
  });

  testWidgets('the controls stay while a control has keyboard focus', (
    WidgetTester tester,
  ) async {
    _useScreen(tester, _desktopScreen);
    await tester.pumpWidget(
      _app(
        _sheet(phase: VideoRecorderPhase.recording),
        platform: TargetPlatform.macOS,
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await _longHold(tester);

    _expectFade(tester, find.byKey(videoShutterKey), 1, 'the shutter');
  }, semanticsEnabled: false);

  testWidgets('with reduced motion the controls hide at once', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_sheet(phase: VideoRecorderPhase.recording), reduceMotion: true),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    _expectFade(tester, find.byKey(videoShutterKey), 0, 'the shutter');
  });

  testWidgets('the controls stay while the microphone is lost', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _sheet(
          phase: VideoRecorderPhase.recording,
          hearing: MicrophoneHearing.lost,
        ),
      ),
    );
    await _longHold(tester);

    _expectFade(tester, find.byKey(videoShutterKey), 1, 'the shutter');
  });

  testWidgets('the controls stay for a desktop screen reader', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle reader = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _app(
          _sheet(phase: VideoRecorderPhase.recording),
          platform: TargetPlatform.macOS,
        ),
      );
      await _longHold(tester);

      _expectFade(tester, find.byKey(videoShutterKey), 1, 'the shutter');
    } finally {
      reader.dispose();
    }
  }, semanticsEnabled: false);
}
