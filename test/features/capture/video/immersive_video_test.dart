import 'dart:async';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:field_notes/features/capture/video/camera_picker.dart';
import 'package:field_notes/features/capture/video/video_composer.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder_provider.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/features/capture/video/video_timeline.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

enum _Layout { sidebar, bottomBar }

const Size _sidebarWindow = Size(1280, 800);
const Size _bottomBarWindow = Size(360, 740);
const String _date = '2026-09-28';
const String _openLabel = 'open';
const String _behindLabel = 'behind';
const String _preparing = 'Getting the camera ready…';
const String _saving = 'Saving your video…';
const String _capHint = 'Auto-stops at 30:00.';
const String _selfViewOffTitle = 'The camera is still recording.';
const String _selfViewOffMessage = 'You just won’t see yourself.';
const String _letGoToast = 'Let go · nothing was saved';
const String _savedToast = 'Video saved';
const Color _stage = Color(0xFF1C1713);
const Color _shutterCore = Color(0xFFDA7185);
const Duration _fade = Duration(milliseconds: 600);
const Duration _step = Duration(milliseconds: 50);
const Duration _midFade = Duration(milliseconds: 300);
const Duration _frame = Duration(milliseconds: 16);

class _Harness {
  _Harness({required this.layout});

  final _Layout layout;
  final List<String?> results = <String?>[];
  int behindTaps = 0;

  Size get window =>
      layout == _Layout.sidebar ? _sidebarWindow : _bottomBarWindow;

  TargetPlatform get platform =>
      layout == _Layout.sidebar ? TargetPlatform.macOS : TargetPlatform.android;
}

Future<_Harness> _pumpApp(
  WidgetTester tester, {
  required _Layout layout,
  required VideoRecorder recorder,
  FakeCaptureService? service,
  bool reflection = false,
}) async {
  final _Harness harness = _Harness(layout: layout);
  debugDefaultTargetPlatformOverride = harness.platform;
  tester.view.physicalSize = harness.window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        videoRecorderProvider.overrideWith((Ref ref) => recorder),
        captureServiceProvider.overrideWith(
          (Ref ref) => service ?? FakeCaptureService(),
        ),
        reflectionPromptsEnabledProvider.overrideWithValue(reflection),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: harness.platform),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return Stack(
                children: <Widget>[
                  Center(
                    child: TextButton(
                      onPressed: () => harness.behindTaps++,
                      child: const Text(_behindLabel),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: TextButton(
                      onPressed: () async => harness.results.add(
                        await showVideoComposer(context, _date),
                      ),
                      child: const Text(_openLabel),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
  return harness;
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text(_openLabel));
  await tester.pump();
  await tester.pump(_fade);
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 14; i++) {
    await tester.pump(_step);
  }
}

Future<void> _tapShutter(WidgetTester tester) async {
  await tester.tap(find.byKey(videoShutterKey));
  await tester.pump();
}

Future<void> _startNow(WidgetTester tester) async {
  await _tapShutter(tester);
  await _tapShutter(tester);
  await _settle(tester);
}

Future<void> _closeAll(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

VideoRecorderPhase _phase(WidgetTester tester) =>
    tester.widget<VideoRecorderSheet>(find.byType(VideoRecorderSheet)).phase;

Finder _inStatusLine(String text) => find.descendant(
  of: find.byType(RecorderStatusLine),
  matching: find.text(text),
);

Finder _inShutter(bool Function(BoxDecoration decoration) test) {
  return find.descendant(
    of: find.byKey(videoShutterKey),
    matching: find.byWidgetPredicate((Widget widget) {
      if (widget is! DecoratedBox) {
        return false;
      }
      final Decoration decoration = widget.decoration;
      return decoration is BoxDecoration && test(decoration);
    }),
  );
}

Finder _shutterDot() => _inShutter(
  (BoxDecoration decoration) =>
      decoration.color == _shutterCore && decoration.shape == BoxShape.circle,
);

Finder _shutterStopSquare() => _inShutter(
  (BoxDecoration decoration) =>
      decoration.color == _shutterCore &&
      decoration.shape == BoxShape.rectangle &&
      decoration.borderRadius != null,
);

String _statusText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(recorderStatusTextKey)).data!;

SemanticsNode _statusNode(WidgetTester tester) =>
    tester.getSemantics(find.byKey(recorderStatusTextKey));

double _recorderOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.byType(VideoRecorderSheet),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

Future<void> _expectToastOnceFadedOut(
  WidgetTester tester, {
  required _Harness harness,
  required String toast,
  required List<String?> delivered,
}) async {
  final String reason = '${harness.layout}';
  await tester.pump();
  await tester.pump(_midFade);

  expect(find.byType(VideoRecorderSheet), findsOneWidget, reason: reason);
  expect(_recorderOpacity(tester), inExclusiveRange(0, 1), reason: reason);
  expect(harness.results, delivered, reason: reason);
  expect(find.text(toast), findsNothing, reason: reason);

  await tester.pump(
    (harness.layout == _Layout.sidebar
            ? immersiveSidebarFade
            : immersiveBottomBarFade) -
        _midFade,
  );
  await tester.pump(_frame);
  await tester.pump();

  expect(find.byType(VideoRecorderSheet), findsNothing, reason: reason);
  expect(find.text(toast), findsOneWidget, reason: reason);
}

class _GatedListRecorder extends FakeVideoRecorder {
  _GatedListRecorder();

  final Completer<void> listGate = Completer<void>();

  @override
  Future<List<VideoCaptureDevice>> listDevices() async {
    await listGate.future;
    return super.listDevices();
  }
}

class _GatedStartRecorder extends FakeVideoRecorder {
  _GatedStartRecorder();

  final Completer<void> startGate = Completer<void>();

  @override
  Future<void> start() async {
    await super.start();
    await startGate.future;
  }
}

void main() {
  testWidgets(
    'the video recorder covers the whole window with the live preview in both layouts',
    (WidgetTester tester) async {
      for (final _Layout layout in _Layout.values) {
        final FakeVideoRecorder recorder = FakeVideoRecorder();
        final _Harness harness = await _pumpApp(
          tester,
          layout: layout,
          recorder: recorder,
        );
        final Offset behind = tester.getCenter(find.text(_behindLabel));
        await _open(tester);

        final Rect window = Offset.zero & harness.window;
        final Finder surface = find.byType(RecorderSurface);
        final Finder preview = fakeVideoPreview(deviceId: 'built-in-id');
        expect(surface, findsOneWidget, reason: '$layout');
        expect(tester.getRect(surface), window, reason: '$layout');
        expect(preview, findsOneWidget, reason: '$layout');
        expect(tester.getRect(preview), window, reason: '$layout');
        expect(
          find.descendant(of: surface, matching: preview),
          findsOneWidget,
          reason: '$layout',
        );
        expect(
          find.ancestor(
            of: find.byType(VideoRecorderSheet),
            matching: find.byType(ScaleTransition),
          ),
          findsNothing,
          reason: '$layout',
        );

        await tester.tapAt(behind);
        await tester.pump();
        expect(harness.behindTaps, 0, reason: '$layout');

        await tester.tap(find.byKey(videoCloseKey));
        await _settle(tester);
        expect(
          find.byType(VideoRecorderSheet),
          findsNothing,
          reason: '$layout',
        );
        expect(harness.results, <String?>[null], reason: '$layout');
        await _closeAll(tester);
      }
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'tapping the shutter breathes for 4 seconds before recording and a second tap skips the breath',
    (WidgetTester tester) async {
      final FakeVideoRecorder waiting = FakeVideoRecorder();
      await _pumpApp(tester, layout: _Layout.sidebar, recorder: waiting);
      await _open(tester);

      await _tapShutter(tester);
      expect(_phase(tester).name, 'breathing');
      expect(_inStatusLine(stageBreathingStatus), findsOneWidget);
      expect(waiting.startCalls, 0);

      await tester.pump(stageBreathDuration - const Duration(milliseconds: 1));
      expect(waiting.startCalls, 0);
      expect(_inStatusLine(stageBreathingStatus), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(waiting.startCalls, 1);
      expect(_phase(tester), VideoRecorderPhase.recording);
      expect(_inStatusLine(stageRecordingStatus), findsOneWidget);
      await _closeAll(tester);

      final FakeVideoRecorder skipping = FakeVideoRecorder();
      await _pumpApp(tester, layout: _Layout.sidebar, recorder: skipping);
      await _open(tester);
      await _tapShutter(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(skipping.startCalls, 0);
      expect(
        tester.getSemantics(find.byKey(videoShutterKey)),
        isSemantics(label: 'Skip the breath', isButton: true),
      );

      await _tapShutter(tester);
      await tester.pump();
      expect(skipping.startCalls, 1);
      expect(_phase(tester), VideoRecorderPhase.recording);

      await tester.pump(stageBreathDuration);
      expect(skipping.startCalls, 1);
      await _closeAll(tester);

      final FakeVideoRecorder leaving = FakeVideoRecorder();
      final _Harness harness = await _pumpApp(
        tester,
        layout: _Layout.sidebar,
        recorder: leaving,
      );
      await _open(tester);
      await _tapShutter(tester);
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byKey(videoCloseKey));
      await _settle(tester);
      expect(find.byType(VideoRecorderSheet), findsNothing);
      expect(harness.results, <String?>[null]);

      await tester.pump(stageBreathDuration);
      expect(leaving.startCalls, 0);
      expect(leaving.cancelCalls, 0);
      expect(leaving.releaseCalls, 1);
      await _closeAll(tester);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('video phases show their status text, dot and announcement', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final FakeVideoRecorder recorder = FakeVideoRecorder(supportsPause: true);
    final Completer<void> stopGate = Completer<void>();
    recorder.stopGate = stopGate;
    await _pumpApp(tester, layout: _Layout.sidebar, recorder: recorder);
    await _open(tester);

    final List<String> seen = <String>[];

    expect(_statusText(tester), '$stageIdleStatus$stageIdleSidebarTail');
    expect(
      _statusNode(tester),
      isSemantics(label: 'Ready to record', isLiveRegion: true),
    );
    expect(find.byKey(recorderStatusDotKey), findsNothing);
    expect(find.byKey(recorderTimerKey), findsNothing);
    expect(_shutterDot(), findsOneWidget);
    seen.add(_statusText(tester));

    await _tapShutter(tester);
    expect(_statusText(tester), stageBreathingStatus);
    expect(
      _statusNode(tester),
      isSemantics(label: 'Breathing before recording', isLiveRegion: true),
    );
    expect(find.byKey(recorderStatusDotKey), findsNothing);
    expect(find.byType(BreathingGlow), findsOneWidget);
    seen.add(_statusText(tester));

    await tester.pump(stageBreathDuration);
    await _settle(tester);
    expect(_phase(tester), VideoRecorderPhase.recording);
    expect(_statusText(tester), stageRecordingStatus);
    expect(
      _statusNode(tester),
      isSemantics(label: 'Recording', isLiveRegion: true),
    );
    expect(tester.widget(find.byKey(recorderStatusDotKey)), isA<Blink>());
    expect(find.byKey(recorderTimerKey), findsOneWidget);
    seen.add(_statusText(tester));

    await _tapShutter(tester);
    await _settle(tester);
    expect(_phase(tester), VideoRecorderPhase.paused);
    expect(_statusText(tester), stagePausedStatus);
    expect(
      _statusNode(tester),
      isSemantics(label: 'Paused', isLiveRegion: true),
    );
    expect(find.byKey(recorderStatusDotKey), findsOneWidget);
    expect(
      tester.widget(find.byKey(recorderStatusDotKey)),
      isNot(isA<Blink>()),
    );
    expect(find.byKey(recorderTimerKey), findsOneWidget);
    seen.add(_statusText(tester));

    await tester.tap(find.byKey(videoSaveCircleKey));
    await tester.pump();
    expect(_phase(tester), VideoRecorderPhase.saving);
    expect(_statusText(tester), _saving);
    expect(
      _statusNode(tester),
      isSemantics(label: 'Saving', isLiveRegion: true),
    );
    expect(find.byKey(recorderStatusDotKey), findsNothing);
    expect(find.byKey(recorderTimerKey), findsNothing);
    expect(
      tester.getSemantics(find.byKey(videoShutterKey)),
      isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
    );
    seen.add(_statusText(tester));

    expect(seen.toSet(), hasLength(5));

    stopGate.complete();
    await _settle(tester);
    expect(find.byType(VideoRecorderSheet), findsNothing);
    await _closeAll(tester);
    semantics.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'self-view starts on, hides only the preview, and starts on again next time',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final FakeVideoRecorder recorder = FakeVideoRecorder(supportsPause: true);
      await _pumpApp(tester, layout: _Layout.sidebar, recorder: recorder);
      await _open(tester);

      expect(find.text('Self-view on'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Self-view on')),
        isSemantics(label: 'Self-view', hasToggledState: true, isToggled: true),
      );
      expect(
        tester.getSemantics(find.text('Self-view on')).rect.height,
        greaterThanOrEqualTo(48),
      );
      expect(fakeVideoPreview(), findsOneWidget);

      await _startNow(tester);
      expect(_phase(tester), VideoRecorderPhase.recording);

      await tester.tap(find.text('Self-view on'));
      await tester.pump();

      expect(find.text('Self-view off'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Self-view off')),
        isSemantics(
          label: 'Self-view',
          hasToggledState: true,
          isToggled: false,
        ),
      );
      expect(fakeVideoPreview(), findsNothing);
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget.key ==
              const ValueKey<String>('fake-video-preview-built-in-id'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(find.text(_selfViewOffTitle), findsOneWidget);
      expect(find.text(_selfViewOffMessage), findsOneWidget);
      expect(find.byType(BreathingGlow), findsOneWidget);
      expect(_phase(tester), VideoRecorderPhase.recording);
      expect(recorder.startCalls, 1);
      expect(recorder.pauseCalls, 0);
      expect(recorder.stopCalls, 0);
      expect(recorder.cancelCalls, 0);
      expect(recorder.previewDeviceIds.last, 'built-in-id');

      await tester.tap(find.text('Self-view off'));
      await tester.pump();
      expect(find.text('Self-view on'), findsOneWidget);
      expect(fakeVideoPreview(), findsOneWidget);
      expect(find.text(_selfViewOffTitle), findsNothing);

      await tester.tap(find.text('Self-view on'));
      await tester.pump();
      expect(find.text('Self-view off'), findsOneWidget);

      await tester.tap(find.byKey(videoCloseKey));
      await _settle(tester);
      await tester.tap(find.byKey(videoDiscardConfirmKey));
      await _settle(tester);
      expect(find.byType(VideoRecorderSheet), findsNothing);

      await _open(tester);
      expect(find.text('Self-view on'), findsOneWidget);
      expect(find.text('Self-view off'), findsNothing);
      expect(fakeVideoPreview(), findsOneWidget);
      await _closeAll(tester);

      await _pumpApp(
        tester,
        layout: _Layout.bottomBar,
        recorder: FakeVideoRecorder(),
      );
      await _open(tester);
      expect(find.text('Mirror on'), findsOneWidget);
      await tester.tap(find.text('Mirror on'));
      await tester.pump();
      expect(find.text('Mirror off'), findsOneWidget);
      expect(fakeVideoPreview(), findsNothing);
      expect(find.text(_selfViewOffTitle), findsOneWidget);
      await _closeAll(tester);
      semantics.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('a recorder that cannot pause shows Stop and keep and saves', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final FakeVideoRecorder recorder = FakeVideoRecorder();
    final FakeCaptureService service = FakeCaptureService();
    final _Harness harness = await _pumpApp(
      tester,
      layout: _Layout.sidebar,
      recorder: recorder,
      service: service,
    );
    await _open(tester);
    await _startNow(tester);

    expect(_phase(tester), VideoRecorderPhase.recording);
    expect(
      tester.getSemantics(find.byKey(videoShutterKey)),
      isSemantics(label: 'Stop and keep', isButton: true),
    );
    expect(_shutterStopSquare(), findsOneWidget);
    expect(_shutterDot(), findsNothing);

    await _tapShutter(tester);
    await _settle(tester);

    expect(recorder.pauseCalls, 0);
    expect(recorder.stopCalls, 1);
    expect(service.requests, hasLength(1));
    expect(harness.results, <String?>['entry-1']);
    expect(find.byType(VideoRecorderSheet), findsNothing);
    expect(find.text(_savedToast), findsOneWidget);
    await _closeAll(tester);
    semantics.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'Space pauses a pausing recorder and does nothing on a non-pausing one',
    (WidgetTester tester) async {
      final FakeVideoRecorder pausing = FakeVideoRecorder(supportsPause: true);
      await _pumpApp(tester, layout: _Layout.sidebar, recorder: pausing);
      await _open(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(_inStatusLine(stageBreathingStatus), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await _settle(tester);
      expect(_phase(tester), VideoRecorderPhase.recording);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await _settle(tester);
      expect(pausing.pauseCalls, 1);
      expect(_phase(tester), VideoRecorderPhase.paused);
      expect(_inStatusLine(stagePausedStatus), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await _settle(tester);
      expect(pausing.resumeCalls, 1);
      expect(_phase(tester), VideoRecorderPhase.recording);
      await _closeAll(tester);

      final FakeVideoRecorder steady = FakeVideoRecorder();
      await _pumpApp(tester, layout: _Layout.sidebar, recorder: steady);
      await _open(tester);
      await _startNow(tester);
      expect(_phase(tester), VideoRecorderPhase.recording);

      for (int i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await _settle(tester);
        expect(_phase(tester), VideoRecorderPhase.recording);
        expect(find.textContaining('Paused'), findsNothing);
      }
      expect(steady.pauseCalls, 0);
      expect(steady.stopCalls, 0);
      expect(steady.cancelCalls, 0);
      await _closeAll(tester);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'preparing disables the shutter and shows Getting the camera ready in the status line',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final _GatedListRecorder preparing = _GatedListRecorder();
      await _pumpApp(tester, layout: _Layout.bottomBar, recorder: preparing);
      await _open(tester);

      expect(_phase(tester), VideoRecorderPhase.preparing);
      expect(_inStatusLine(_preparing), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(videoShutterKey)),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      );
      await _tapShutter(tester);
      await tester.pump(stageBreathDuration);
      expect(_phase(tester), VideoRecorderPhase.preparing);
      expect(_inStatusLine(stageBreathingStatus), findsNothing);
      expect(preparing.startCalls, 0);

      preparing.listGate.complete();
      await _settle(tester);
      expect(_phase(tester), VideoRecorderPhase.idle);
      expect(_inStatusLine(_preparing), findsNothing);
      await _closeAll(tester);

      final _GatedStartRecorder arming = _GatedStartRecorder();
      await _pumpApp(tester, layout: _Layout.bottomBar, recorder: arming);
      await _open(tester);
      await _startNow(tester);
      expect(_phase(tester), VideoRecorderPhase.arming);
      expect(_inStatusLine(_preparing), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(videoShutterKey)),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      );

      await tester.tap(find.byKey(videoCloseKey));
      await _settle(tester);
      expect(arming.cancelCalls, 1);
      expect(find.byType(VideoRecorderSheet), findsNothing);
      arming.startGate.complete();
      await _settle(tester);
      await _closeAll(tester);
      semantics.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'a denied camera shows the live permission message on the full-window surface',
    (WidgetTester tester) async {
      for (final _Layout layout in _Layout.values) {
        final FakeVideoRecorder recorder = FakeVideoRecorder(
          listError: const VideoRecorderException(cameraPermissionMessage),
        );
        final _Harness harness = await _pumpApp(
          tester,
          layout: layout,
          recorder: recorder,
        );
        await _open(tester);

        expect(_phase(tester), VideoRecorderPhase.denied, reason: '$layout');
        final Finder message = find.text(cameraPermissionMessage);
        expect(message, findsOneWidget, reason: '$layout');
        expect(
          find.ancestor(of: message, matching: find.byType(RecorderSurface)),
          findsOneWidget,
          reason: '$layout',
        );
        expect(
          tester.getRect(find.byType(RecorderSurface)),
          Offset.zero & harness.window,
          reason: '$layout',
        );
        expect(fakeVideoPreview(), findsNothing, reason: '$layout');
        expect(find.byType(CameraPicker), findsNothing, reason: '$layout');

        final int listed = recorder.listCalls;
        await _tapShutter(tester);
        await _settle(tester);
        expect(recorder.listCalls, listed + 1, reason: '$layout');
        expect(recorder.startCalls, 0, reason: '$layout');
        expect(message, findsOneWidget, reason: '$layout');

        await tester.tap(find.byKey(videoCloseKey));
        await _settle(tester);
        expect(
          find.byType(VideoRecorderSheet),
          findsNothing,
          reason: '$layout',
        );
        await _closeAll(tester);
      }
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('nudges show below the status line and the cap keeps the take', (
    WidgetTester tester,
  ) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder();
    final FakeCaptureService service = FakeCaptureService();
    final _Harness harness = await _pumpApp(
      tester,
      layout: _Layout.sidebar,
      recorder: recorder,
      service: service,
    );
    await _open(tester);

    expect(find.text(_capHint), findsOneWidget);
    expect(
      tester.getRect(find.text(_capHint)).top,
      greaterThanOrEqualTo(
        tester.getRect(find.byType(RecorderStatusLine)).bottom,
      ),
    );

    await _startNow(tester);
    expect(find.text(_capHint), findsNothing);

    recorder.elapsedValue = const Duration(minutes: 5);
    await tester.pump(const Duration(minutes: 5));
    await tester.pump();
    final Finder nudge = find.text(videoNudge5Message);
    expect(nudge, findsOneWidget);
    expect(find.byType(Toast), findsNothing);
    expect(
      tester.getRect(nudge).top,
      greaterThanOrEqualTo(
        tester.getRect(find.byType(RecorderStatusLine)).bottom,
      ),
    );
    expect(
      tester.getRect(nudge).bottom,
      lessThanOrEqualTo(tester.getRect(find.byKey(videoShutterKey)).top),
    );
    expect(tester.widget<Text>(nudge).style?.color, const Color(0xFFB7A58C));

    recorder.elapsedValue = const Duration(minutes: 10);
    await tester.pump(const Duration(minutes: 5));
    await tester.pump();
    expect(find.text(videoNudge10Message), findsOneWidget);

    recorder.elapsedValue = const Duration(minutes: 20);
    await tester.pump(const Duration(minutes: 10));
    await tester.pump();
    expect(find.text(videoNudge20Message), findsOneWidget);
    expect(service.requests, isEmpty);

    recorder.elapsedValue = videoHardCap;
    await tester.pump(const Duration(minutes: 10));
    await _settle(tester);

    expect(recorder.stopCalls, 1);
    expect(recorder.cancelCalls, 0);
    expect(service.requests, hasLength(1));
    expect(harness.results, <String?>['entry-1']);
    expect(find.byType(VideoRecorderSheet), findsNothing);
    await _closeAll(tester);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'the video recorder shows the reflection question without the kicker when the setting is on',
    (WidgetTester tester) async {
      for (final _Layout layout in _Layout.values) {
        await _pumpApp(
          tester,
          layout: layout,
          recorder: FakeVideoRecorder(),
          reflection: true,
        );
        await _open(tester);

        final Finder question = find.descendant(
          of: find.byType(VideoRecorderSheet),
          matching: find.byKey(reflectionQuestionKey),
        );
        expect(question, findsOneWidget, reason: '$layout');
        expect(find.text(reflectionKicker), findsNothing, reason: '$layout');
        expect(
          find.text(reflectionShuffleLabel),
          findsOneWidget,
          reason: '$layout',
        );
        final double gap = layout == _Layout.sidebar ? 34 : 10;
        expect(
          tester.getRect(question).top -
              tester.getRect(find.byKey(videoCloseKey)).bottom,
          greaterThanOrEqualTo(gap),
          reason: '$layout',
        );
        await _closeAll(tester);

        await _pumpApp(tester, layout: layout, recorder: FakeVideoRecorder());
        await _open(tester);
        expect(find.byType(VideoRecorderSheet), findsOneWidget);
        expect(find.byKey(reflectionQuestionKey), findsNothing);
        await _closeAll(tester);
      }
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'the camera picker shows only while idle with more than one camera',
    (WidgetTester tester) async {
      for (final _Layout layout in _Layout.values) {
        final FakeVideoRecorder recorder = FakeVideoRecorder(
          devices: const <VideoCaptureDevice>[
            VideoCaptureDevice(
              id: 'built-in-id',
              label: 'FaceTime HD Camera with a very long descriptive name',
            ),
            VideoCaptureDevice(id: 'usb-id', label: 'USB Camera'),
          ],
        );
        final _Harness harness = await _pumpApp(
          tester,
          layout: layout,
          recorder: recorder,
        );
        await _open(tester);

        final Finder picker = find.byType(CameraPicker);
        expect(picker, findsOneWidget, reason: '$layout');
        final Rect pickerRect = tester.getRect(picker);
        final Rect chip = tester.getRect(
          find.text(layout == _Layout.sidebar ? 'Self-view on' : 'Mirror on'),
        );
        final Rect leave = tester.getRect(find.byKey(videoCloseKey));
        expect(
          pickerRect.right,
          lessThanOrEqualTo(chip.left),
          reason: '$layout',
        );
        expect(
          pickerRect.left,
          greaterThanOrEqualTo(leave.right),
          reason: '$layout',
        );
        expect(
          chip.right,
          lessThanOrEqualTo(harness.window.width),
          reason: '$layout',
        );
        expect(
          (pickerRect.center.dy - leave.center.dy).abs(),
          lessThan(1),
          reason: '$layout',
        );
        final RenderParagraph label = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: picker,
            matching: find.text(
              'FaceTime HD Camera with a very long descriptive name',
            ),
          ),
        );
        expect(label.maxLines, 1, reason: '$layout');
        expect(label.overflow, TextOverflow.ellipsis, reason: '$layout');
        expect(tester.takeException(), isNull, reason: '$layout');

        await _tapShutter(tester);
        expect(picker, findsNothing, reason: '$layout');
        await _tapShutter(tester);
        await _settle(tester);
        expect(_phase(tester), VideoRecorderPhase.recording, reason: '$layout');
        expect(picker, findsNothing, reason: '$layout');
        await _closeAll(tester);

        await _pumpApp(
          tester,
          layout: layout,
          recorder: FakeVideoRecorder(
            devices: const <VideoCaptureDevice>[
              VideoCaptureDevice(id: 'built-in-id', label: 'Built-in Camera'),
            ],
          ),
        );
        await _open(tester);
        expect(_phase(tester), VideoRecorderPhase.idle, reason: '$layout');
        expect(picker, findsNothing, reason: '$layout');
        await _closeAll(tester);
      }
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'Keep saves the video and Let it go discards it with the let-go toast',
    (WidgetTester tester) async {
      final FakeVideoRecorder keeping = FakeVideoRecorder(supportsPause: true);
      final FakeCaptureService saved = FakeCaptureService();
      final _Harness keptHarness = await _pumpApp(
        tester,
        layout: _Layout.bottomBar,
        recorder: keeping,
        service: saved,
      );
      await _open(tester);
      await _startNow(tester);
      expect(find.text('Keep'), findsOneWidget);
      expect(find.text('Let go'), findsOneWidget);

      await tester.tap(find.byKey(videoSaveCircleKey));
      await _settle(tester);
      expect(keeping.stopCalls, 1);
      expect(saved.requests, hasLength(1));
      expect(keptHarness.results, <String?>['entry-1']);
      expect(find.text(_savedToast), findsOneWidget);
      await _closeAll(tester);

      final FakeVideoRecorder letting = FakeVideoRecorder(supportsPause: true);
      final FakeCaptureService unsaved = FakeCaptureService();
      final _Harness letHarness = await _pumpApp(
        tester,
        layout: _Layout.bottomBar,
        recorder: letting,
        service: unsaved,
      );
      await _open(tester);
      await _startNow(tester);

      await tester.tap(find.byKey(videoDiscardCircleKey));
      await _settle(tester);
      expect(letting.pauseCalls, 1);
      expect(_phase(tester), VideoRecorderPhase.paused);
      expect(find.byType(LetGoPanel), findsOneWidget);
      expect(find.text(letGoTitle), findsOneWidget);
      expect(find.text('Discard this recording?'), findsNothing);
      expect(find.byKey(videoShutterKey), findsNothing);

      await tester.tap(find.text(letGoKeepGoingLabel));
      await _settle(tester);
      expect(find.byType(LetGoPanel), findsNothing);
      expect(_phase(tester), VideoRecorderPhase.paused);
      expect(letting.cancelCalls, 0);

      await tester.tap(find.byKey(videoCloseKey));
      await _settle(tester);
      expect(find.byType(LetGoPanel), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(find.byType(LetGoPanel), findsNothing);
      expect(find.byType(VideoRecorderSheet), findsOneWidget);
      expect(letting.cancelCalls, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await _settle(tester);
      expect(letting.resumeCalls, 1);
      expect(_phase(tester), VideoRecorderPhase.recording);

      await tester.tap(find.byKey(videoDiscardCircleKey));
      await _settle(tester);
      await tester.tap(find.byKey(videoDiscardConfirmKey));
      await _settle(tester);
      expect(letting.cancelCalls, 1);
      expect(letting.stopCalls, 0);
      expect(unsaved.requests, isEmpty);
      expect(letHarness.results, <String?>[null]);
      expect(find.byType(VideoRecorderSheet), findsNothing);
      expect(find.text(_letGoToast), findsOneWidget);
      expect(find.text('Recording discarded'), findsNothing);
      await _closeAll(tester);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('the saved toast waits until the video recorder has faded out', (
    WidgetTester tester,
  ) async {
    for (final _Layout layout in _Layout.values) {
      final _Harness keeping = await _pumpApp(
        tester,
        layout: layout,
        recorder: FakeVideoRecorder(supportsPause: true),
      );
      await _open(tester);
      await _startNow(tester);

      await tester.tap(find.byKey(videoSaveCircleKey));

      await _expectToastOnceFadedOut(
        tester,
        harness: keeping,
        toast: _savedToast,
        delivered: <String?>['entry-1'],
      );
      await _closeAll(tester);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the let-go toast waits until the video recorder has faded out', (
    WidgetTester tester,
  ) async {
    for (final _Layout layout in _Layout.values) {
      final _Harness letting = await _pumpApp(
        tester,
        layout: layout,
        recorder: FakeVideoRecorder(supportsPause: true),
      );
      await _open(tester);
      await _startNow(tester);
      await tester.tap(find.byKey(videoDiscardCircleKey));
      await _settle(tester);

      await tester.tap(find.byKey(videoDiscardConfirmKey));

      await _expectToastOnceFadedOut(
        tester,
        harness: letting,
        toast: _letGoToast,
        delivered: <String?>[null],
      );
      await _closeAll(tester);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'video recorder geometry matches the prototype shutter and dark surface',
    (WidgetTester tester) async {
      for (final _Layout layout in _Layout.values) {
        await _pumpApp(
          tester,
          layout: layout,
          recorder: FakeVideoRecorder(supportsPause: true),
        );
        await _open(tester);

        final Finder preview = fakeVideoPreview(deviceId: 'built-in-id');
        final Iterable<ColoredBox> stages = tester.widgetList<ColoredBox>(
          find.ancestor(of: preview, matching: find.byType(ColoredBox)),
        );
        expect(
          stages.map((ColoredBox box) => box.color),
          contains(_stage),
          reason: '$layout',
        );
        final double shutter = layout == _Layout.sidebar ? 80 : 72;
        expect(
          tester.getSize(find.byKey(videoShutterKey)),
          Size(shutter, shutter),
          reason: '$layout',
        );
        expect(
          tester.getCenter(find.byKey(videoShutterKey)).dx,
          closeTo(tester.view.physicalSize.width / 2, 0.5),
          reason: '$layout',
        );

        await _startNow(tester);
        expect(
          tester.getCenter(find.byKey(videoShutterKey)).dx,
          closeTo(tester.view.physicalSize.width / 2, 0.5),
          reason: '$layout',
        );
        final double side = layout == _Layout.sidebar ? 52 : 48;
        expect(
          tester.getSize(find.byKey(videoSaveCircleKey)).width,
          greaterThanOrEqualTo(side),
          reason: '$layout',
        );
        final Rect timer = tester.getRect(find.byKey(recorderTimerKey));
        final Rect controls = tester
            .getRect(find.byKey(videoDiscardCircleKey))
            .expandToInclude(tester.getRect(find.byKey(videoShutterKey)))
            .expandToInclude(tester.getRect(find.byKey(videoSaveCircleKey)));
        expect(timer.overlaps(controls), isFalse, reason: '$layout');

        await tester.tap(find.byKey(videoCloseKey));
        await _settle(tester);
        final Rect panel = tester.getRect(find.byType(LetGoPanel));
        final Rect pausedTimer = tester.getRect(find.byKey(recorderTimerKey));
        expect(pausedTimer.overlaps(panel), isFalse, reason: '$layout');
        expect(tester.takeException(), isNull, reason: '$layout');
        await _closeAll(tester);
      }
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
