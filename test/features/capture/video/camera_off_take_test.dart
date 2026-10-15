import 'dart:async';
import 'dart:io';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/video/camera_glyphs.dart';
import 'package:field_notes/features/capture/video/camera_picker.dart';
import 'package:field_notes/features/capture/video/camera_selection.dart';
import 'package:field_notes/features/capture/video/video_composer.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder_provider.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/features/capture/voice/voice_composer.dart'
    show voiceSavedToastMessage;
import 'package:field_notes/features/capture/voice/voice_recorder.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

enum _Layout {
  mac(platform: TargetPlatform.macOS, window: Size(1280, 800), topInset: 0),
  phone(platform: TargetPlatform.android, window: Size(384, 832), topInset: 24);

  const _Layout({
    required this.platform,
    required this.window,
    required this.topInset,
  });

  final TargetPlatform platform;
  final Size window;
  final double topInset;
}

const String _date = '2026-10-14';
const String _openLabel = 'open';
const String _cameraOffTitle = 'Camera off.';
const String _cameraOffMessage = 'Only your voice is kept, as a voice log.';
const Duration _fade = Duration(milliseconds: 600);
const Duration _step = Duration(milliseconds: 50);
const Duration _second = Duration(seconds: 1);

const List<VideoCaptureDevice> _phoneCameras = <VideoCaptureDevice>[
  VideoCaptureDevice(id: '0', label: 'Back camera'),
  VideoCaptureDevice(id: '1', label: 'Front camera'),
];

void _useLayout(WidgetTester tester, _Layout layout) {
  debugDefaultTargetPlatformOverride = layout.platform;
  tester.view.physicalSize = layout.window;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: layout.topInset);
  tester.view.viewPadding = FakeViewPadding(top: layout.topInset);
  addTearDown(tester.view.reset);
}

Future<void> _pumpComposer(
  WidgetTester tester, {
  required _Layout layout,
  required FakeVideoRecorder recorder,
  required CameraOffVoiceRecorder voice,
  required FakeCaptureService service,
}) async {
  _useLayout(tester, layout);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        videoRecorderProvider.overrideWith((Ref ref) => recorder),
        voiceRecorderProvider.overrideWith((Ref ref) => voice),
        captureServiceProvider.overrideWith((Ref ref) => service),
        reflectionPromptsOff(),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: layout.platform),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Align(
              alignment: Alignment.bottomLeft,
              child: TextButton(
                onPressed: () => showVideoComposer(context, _date),
                child: const Text(_openLabel),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required _Layout layout,
  required VideoRecorderSheet sheet,
}) async {
  _useLayout(tester, layout);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[reflectionPromptsOff()],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: layout.platform),
        home: Scaffold(body: sheet),
      ),
    ),
  );
  await tester.pump(_step);
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 14; i++) {
    await tester.pump(_step);
  }
}

Future<void> _pass(WidgetTester tester, Duration time) async {
  final int steps = time.inMilliseconds ~/ _step.inMilliseconds;
  for (int i = 0; i < steps; i++) {
    await tester.pump(_step);
  }
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text(_openLabel));
  await tester.pump();
  await tester.pump(_fade);
  await _settle(tester);
  expect(_phase(tester), VideoRecorderPhase.idle);
}

Future<void> _tapKey(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pump();
  await _settle(tester);
}

Future<void> _startNow(WidgetTester tester) async {
  await tester.tap(find.byKey(videoShutterKey));
  await tester.pump();
  await tester.tap(find.byKey(videoShutterKey));
  await tester.pump();
  await _settle(tester);
}

Future<void> _closeAll(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  debugDefaultTargetPlatformOverride = null;
}

VideoRecorderSheet _sheet(WidgetTester tester) =>
    tester.widget<VideoRecorderSheet>(find.byType(VideoRecorderSheet));

VideoRecorderPhase _phase(WidgetTester tester) => _sheet(tester).phase;

Finder _anyPreview() => find.byWidgetPredicate((Widget widget) {
  final Key? key = widget.key;
  return key is ValueKey<String> && key.value.startsWith('fake-video-preview-');
}, skipOffstage: false);

void main() {
  testWidgets('a camera-off take without the microphone does not start', (
    WidgetTester tester,
  ) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder(supportsPause: true);
    final CameraOffVoiceRecorder voice = CameraOffVoiceRecorder(
      permission: false,
    );
    await _pumpComposer(
      tester,
      layout: _Layout.mac,
      recorder: recorder,
      voice: voice,
      service: FakeCaptureService(),
    );
    await _open(tester);
    await _tapKey(tester, videoCameraKey);

    await _startNow(tester);
    expect(_phase(tester), VideoRecorderPhase.idle);
    expect(find.text(micPermissionMessage), findsOneWidget);
    expect(voice.startCalls, 0);

    voice.permissionError = StateError('the microphone check failed');
    await _startNow(tester);
    expect(_phase(tester), VideoRecorderPhase.idle);
    expect(find.text(micPermissionMessage), findsOneWidget);
    expect(voice.startCalls, 0);
    expect(voice.calls, <String>['hasPermission', 'hasPermission']);
    expect(recorder.startCalls, 0);

    await _closeAll(tester);
  });

  testWidgets('a camera-off take saves a voice log and no video', (
    WidgetTester tester,
  ) async {
    final VoiceRecording take = VoiceRecording(
      media: CaptureFile(
        file: File('/captures/camera-off-take.m4a'),
        mime: 'audio/mp4',
        durationMs: 4200,
      ),
      durationMs: 4200,
    );
    final FakeVideoRecorder recorder = FakeVideoRecorder(supportsPause: true);
    final CameraOffVoiceRecorder voice = CameraOffVoiceRecorder(
      recording: take,
    );
    final FakeCaptureService service = FakeCaptureService();
    await _pumpComposer(
      tester,
      layout: _Layout.mac,
      recorder: recorder,
      voice: voice,
      service: service,
    );
    await _open(tester);
    await _tapKey(tester, videoCameraKey);
    await _startNow(tester);
    expect(_phase(tester), VideoRecorderPhase.recording);

    await _tapKey(tester, videoSaveCircleKey);

    expect(service.requests, hasLength(1));
    expect(service.requests.whereType<VideoCaptureRequest>(), isEmpty);
    final VoiceCaptureRequest request =
        service.requests.single as VoiceCaptureRequest;
    expect(request.audio, same(take.media));
    expect(
      (request.audio as CaptureFile).file.path,
      '/captures/camera-off-take.m4a',
    );
    expect(request.durationMs, 4200);
    expect(request.peaks, isEmpty);
    expect(recorder.startCalls, 0);
    expect(voice.startCalls, 1);
    expect(voice.stopCalls, 1);
    expect(voice.releaseSavedCalls, 1);
    expect(find.text(voiceSavedToastMessage), findsOneWidget);
    expect(find.text(videoSavedToastMessage), findsNothing);

    await _closeAll(tester);
  });

  testWidgets('turning the camera off releases the camera and its preview', (
    WidgetTester tester,
  ) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder();
    await _pumpComposer(
      tester,
      layout: _Layout.phone,
      recorder: recorder,
      voice: CameraOffVoiceRecorder(),
      service: FakeCaptureService(),
    );
    await _open(tester);
    expect(_anyPreview(), findsOneWidget);
    expect(recorder.releaseCalls, 0);

    await _tapKey(tester, videoCameraKey);

    expect(recorder.releaseCalls, 1);
    expect(_anyPreview(), findsNothing);
    expect(find.text('Camera off.'), findsOneWidget);
    expect(_phase(tester), VideoRecorderPhase.idle);

    await _closeAll(tester);
  });

  testWidgets('turning the camera back on reopens it for a video take', (
    WidgetTester tester,
  ) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder(supportsPause: true);
    final CameraOffVoiceRecorder voice = CameraOffVoiceRecorder();
    final FakeCaptureService service = FakeCaptureService();
    await _pumpComposer(
      tester,
      layout: _Layout.mac,
      recorder: recorder,
      voice: voice,
      service: service,
    );
    await _open(tester);
    await _tapKey(tester, videoCameraKey);
    final int opened = recorder.previewDeviceIds.length;

    await _tapKey(tester, videoCameraKey);

    expect(recorder.previewDeviceIds, hasLength(opened + 1));
    expect(recorder.previewDeviceIds.last, 'built-in-id');
    expect(_anyPreview(), findsOneWidget);
    expect(find.text(_cameraOffTitle), findsNothing);

    await _startNow(tester);
    await _tapKey(tester, videoSaveCircleKey);

    expect(service.requests, hasLength(1));
    expect(service.requests.single, isA<VideoCaptureRequest>());
    expect(recorder.startCalls, 1);
    expect(voice.startCalls, 0);

    await _closeAll(tester);
  });

  testWidgets('a camera-off take pauses, resumes and can be let go', (
    WidgetTester tester,
  ) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder(supportsPause: true);
    final CameraOffVoiceRecorder voice = CameraOffVoiceRecorder();
    final FakeCaptureService service = FakeCaptureService();
    await _pumpComposer(
      tester,
      layout: _Layout.mac,
      recorder: recorder,
      voice: voice,
      service: service,
    );
    await _open(tester);
    await _tapKey(tester, videoCameraKey);
    await _startNow(tester);
    expect(_phase(tester), VideoRecorderPhase.recording);

    await _tapKey(tester, videoShutterKey);
    expect(_phase(tester), VideoRecorderPhase.paused);
    await _tapKey(tester, videoShutterKey);
    expect(_phase(tester), VideoRecorderPhase.recording);

    await _tapKey(tester, videoCloseKey);
    await _tapKey(tester, videoDiscardConfirmKey);

    expect(
      voice.calls,
      containsAllInOrder(<String>['pause', 'resume', 'cancel']),
    );
    expect(voice.cancelCalls, 1);
    expect(voice.stopCalls, 0);
    expect(service.requests, isEmpty);
    expect(recorder.startCalls, 0);
    expect(recorder.cancelCalls, 0);
    expect(find.byType(VideoRecorderSheet), findsNothing);

    await _closeAll(tester);
  });

  testWidgets(
    'the camera control ignores taps while the camera is opening or closing',
    (WidgetTester tester) async {
      final FakeVideoRecorder recorder = FakeVideoRecorder(supportsPause: true)
        ..releaseDelay = const Duration(milliseconds: 500);
      await _pumpComposer(
        tester,
        layout: _Layout.mac,
        recorder: recorder,
        voice: CameraOffVoiceRecorder(),
        service: FakeCaptureService(),
      );
      await _open(tester);
      final int opened = recorder.previewDeviceIds.length;

      await tester.tap(find.byKey(videoCameraKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(videoCameraKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(recorder.releaseCalls, 1);
      expect(recorder.releasesFinished, 0);
      expect(recorder.previewDeviceIds, hasLength(opened));

      await tester.pump(const Duration(milliseconds: 400));
      await _settle(tester);

      expect(recorder.releasesFinished, 1);
      expect(recorder.releaseCalls, 1);
      expect(recorder.previewDeviceIds, hasLength(opened));
      expect(find.text(_cameraOffTitle), findsOneWidget);

      await _closeAll(tester);
    },
  );

  testWidgets('the shutter is ignored while the camera closes', (
    WidgetTester tester,
  ) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder(supportsPause: true)
      ..releaseDelay = const Duration(milliseconds: 500);
    final CameraOffVoiceRecorder voice = CameraOffVoiceRecorder();
    await _pumpComposer(
      tester,
      layout: _Layout.mac,
      recorder: recorder,
      voice: voice,
      service: FakeCaptureService(),
    );
    await _open(tester);
    expect(_sheet(tester).cameraOn, isTrue);

    await tester.tap(find.byKey(videoCameraKey));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tap(find.byKey(videoShutterKey));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.byKey(videoShutterKey));
    await tester.pump();
    expect(recorder.releasesFinished, 0);
    await _pass(tester, _second);

    expect(recorder.releasesFinished, 1);
    expect(_phase(tester), VideoRecorderPhase.idle);
    expect(find.text(_cameraOffTitle), findsOneWidget);
    expect(voice.calls, isEmpty);

    await tester.tap(find.byKey(videoShutterKey));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(videoShutterKey));
    await tester.pump();
    await _pass(tester, _second);

    expect(_phase(tester), VideoRecorderPhase.recording);
    expect(voice.startCalls, 1);
    expect(recorder.startCalls, 0);

    await _closeAll(tester);
  });

  testWidgets(
    'a camera chosen while the camera is off is remembered but not opened',
    (WidgetTester tester) async {
      final FakeVideoRecorder recorder = FakeVideoRecorder(supportsPause: true);
      await _pumpComposer(
        tester,
        layout: _Layout.mac,
        recorder: recorder,
        voice: CameraOffVoiceRecorder(),
        service: FakeCaptureService(),
      );
      await _open(tester);
      expect(find.byType(CameraPicker), findsOneWidget);
      await _tapKey(tester, videoCameraKey);
      final int releases = recorder.releaseCalls;
      final int opened = recorder.previewDeviceIds.length;

      _sheet(tester).onDeviceChanged!('usb-id');
      await tester.pump();
      await _settle(tester);

      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(VideoRecorderSheet)),
      );
      expect(find.byType(CameraPicker), findsNothing);
      expect(container.read(selectedCameraDeviceProvider), 'usb-id');
      expect(recorder.releaseCalls, releases);
      expect(recorder.previewDeviceIds, hasLength(opened));

      await _tapKey(tester, videoCameraKey);

      expect(recorder.previewDeviceIds, hasLength(opened + 1));
      expect(recorder.previewDeviceIds.last, 'usb-id');
      expect(recorder.releaseCalls, releases);

      await _closeAll(tester);
    },
  );

  testWidgets('the flip control hides while the camera is off', (
    WidgetTester tester,
  ) async {
    final List<String> picked = <String>[];
    await _pumpSheet(
      tester,
      layout: _Layout.phone,
      sheet: VideoRecorderSheet(
        phase: VideoRecorderPhase.idle,
        devices: _phoneCameras,
        selectedDeviceId: '0',
        onDeviceChanged: picked.add,
        controls: FakeVideoRecorder(),
        cameraOn: false,
        onCameraChanged: (bool _) {},
        onStart: () {},
        onStop: () {},
        onLeave: () {},
      ),
    );

    expect(find.byKey(videoFlipCameraKey), findsNothing);

    final Offset centre = tester.getCenter(find.byType(VideoRecorderSheet));
    await tester.tapAt(centre);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(centre);
    await tester.pump(const Duration(milliseconds: 400));

    expect(picked, isEmpty);

    await _closeAll(tester);
  });

  testWidgets('a failed camera-off save keeps the camera off', (
    WidgetTester tester,
  ) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder(supportsPause: true);
    await _pumpComposer(
      tester,
      layout: _Layout.mac,
      recorder: recorder,
      voice: CameraOffVoiceRecorder(),
      service: FakeCaptureService(failure: const CaptureException('disk full')),
    );
    await _open(tester);
    await _tapKey(tester, videoCameraKey);
    final int opened = recorder.previewDeviceIds.length;
    await _startNow(tester);
    expect(_phase(tester), VideoRecorderPhase.recording);

    await _tapKey(tester, videoSaveCircleKey);

    expect(find.text('disk full'), findsOneWidget);
    expect(_phase(tester), VideoRecorderPhase.recording);
    expect(find.text('Camera off.'), findsOneWidget);
    expect(recorder.previewDeviceIds, hasLength(opened));
    expect(_anyPreview(), findsNothing);

    await _closeAll(tester);
  });

  testWidgets('a timed-out camera-off save keeps the camera off', (
    WidgetTester tester,
  ) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder(supportsPause: true);
    final Completer<void> never = Completer<void>();
    await _pumpComposer(
      tester,
      layout: _Layout.mac,
      recorder: recorder,
      voice: CameraOffVoiceRecorder(),
      service: FakeCaptureService(gate: never.future),
    );
    await _open(tester);
    await _tapKey(tester, videoCameraKey);
    final int opened = recorder.previewDeviceIds.length;
    await _startNow(tester);

    await tester.tap(find.byKey(videoSaveCircleKey));
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    await tester.pump();

    expect(find.text(videoSaveTimeoutMessage), findsOneWidget);
    expect(find.text('Camera off.'), findsOneWidget);
    expect(recorder.previewDeviceIds, hasLength(opened));
    expect(_anyPreview(), findsNothing);

    await _closeAll(tester);
  });

  testWidgets('a camera-off take is timed by the voice recorder', (
    WidgetTester tester,
  ) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder(supportsPause: true);
    final CameraOffVoiceRecorder voice = CameraOffVoiceRecorder();
    final FakeCaptureService service = FakeCaptureService();
    await _pumpComposer(
      tester,
      layout: _Layout.mac,
      recorder: recorder,
      voice: voice,
      service: service,
    );

    await _open(tester);
    await _tapKey(tester, videoCameraKey);
    await _startNow(tester);
    voice.elapsed = const Duration(minutes: 29, seconds: 59);
    expect(recorder.elapsed, Duration.zero);
    await _tapKey(tester, videoShutterKey);
    expect(_phase(tester), VideoRecorderPhase.paused);
    await tester.tap(find.byKey(videoShutterKey));
    await tester.pump();
    expect(_phase(tester), VideoRecorderPhase.recording);
    await tester.pump(const Duration(seconds: 1));
    await _settle(tester);

    expect(voice.stopCalls, 1);
    expect(service.requests, hasLength(1));
    expect(service.requests.single, isA<VoiceCaptureRequest>());
    expect(find.byType(VideoRecorderSheet), findsNothing);

    voice.elapsed = Duration.zero;
    await _open(tester);
    await _startNow(tester);
    recorder.elapsedValue = const Duration(minutes: 29, seconds: 59);
    await _tapKey(tester, videoShutterKey);
    expect(_phase(tester), VideoRecorderPhase.paused);
    await tester.tap(find.byKey(videoShutterKey));
    await tester.pump();
    expect(_phase(tester), VideoRecorderPhase.recording);
    await tester.pump(const Duration(seconds: 1));
    await _settle(tester);

    expect(recorder.stopCalls, 1);
    expect(service.requests, hasLength(2));
    expect(service.requests.last, isA<VideoCaptureRequest>());
    expect(find.byType(VideoRecorderSheet), findsNothing);

    await _closeAll(tester);
  });

  testWidgets('a paused or saving camera-off take shows its own time', (
    WidgetTester tester,
  ) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder(supportsPause: true);
    final CameraOffVoiceRecorder voice = CameraOffVoiceRecorder();
    final Completer<void> held = Completer<void>();
    await _pumpComposer(
      tester,
      layout: _Layout.mac,
      recorder: recorder,
      voice: voice,
      service: FakeCaptureService(gate: held.future),
    );

    await _open(tester);
    await _startNow(tester);
    recorder.elapsedValue = const Duration(minutes: 3, seconds: 10);
    await _tapKey(tester, videoShutterKey);
    expect(find.text('3:10'), findsOneWidget);
    await _tapKey(tester, videoCloseKey);
    await _tapKey(tester, videoDiscardConfirmKey);
    expect(find.byType(VideoRecorderSheet), findsNothing);
    expect(recorder.elapsed, const Duration(minutes: 3, seconds: 10));

    await _open(tester);
    await _tapKey(tester, videoCameraKey);
    await _startNow(tester);
    voice.elapsed = const Duration(seconds: 42);
    await _tapKey(tester, videoShutterKey);

    expect(_phase(tester), VideoRecorderPhase.paused);
    expect(_sheet(tester).elapsed, const Duration(seconds: 42));
    expect(find.text('0:42'), findsOneWidget);
    expect(find.text('3:10'), findsNothing);

    await tester.tap(find.byKey(videoSaveCircleKey));
    await tester.pump();
    await tester.pump(_step);

    expect(_phase(tester), VideoRecorderPhase.saving);
    expect(_sheet(tester).elapsed, const Duration(seconds: 42));
    expect(find.text('3:10'), findsNothing);

    held.complete();
    await _settle(tester);
    await _closeAll(tester);
  });

  testWidgets('the camera control shows only while idle', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    for (final VideoRecorderPhase phase in <VideoRecorderPhase>[
      VideoRecorderPhase.idle,
      VideoRecorderPhase.preparing,
      VideoRecorderPhase.breathing,
      VideoRecorderPhase.arming,
      VideoRecorderPhase.recording,
      VideoRecorderPhase.paused,
      VideoRecorderPhase.saving,
      VideoRecorderPhase.denied,
    ]) {
      await _pumpSheet(
        tester,
        layout: _Layout.mac,
        sheet: VideoRecorderSheet(
          key: ValueKey<VideoRecorderPhase>(phase),
          phase: phase,
          devices: fakeVideoDevices,
          selectedDeviceId: 'built-in-id',
          onDeviceChanged: (String _) {},
          onCameraChanged: (bool _) {},
          supportsPause: true,
          onPause: () {},
          onResume: () {},
          onStart: () {},
          onStop: () {},
          onLeave: () {},
        ),
      );
      final Finder control = find.byKey(videoCameraKey);
      if (phase == VideoRecorderPhase.idle) {
        expect(control, findsOneWidget, reason: phase.name);
        expect(
          tester.getSemantics(control),
          isSemantics(label: 'Camera', hasToggledState: true, isToggled: true),
          reason: phase.name,
        );
        expect(
          find.descendant(
            of: control,
            matching: find.byWidgetPredicate(
              (Widget widget) =>
                  widget is CameraGlyph &&
                  widget.kind == CameraGlyphKind.camera,
            ),
          ),
          findsOneWidget,
          reason: phase.name,
        );
      } else {
        expect(control, findsNothing, reason: phase.name);
      }
    }
    semantics.dispose();
    await _closeAll(tester);
  });

  testWidgets('a camera-off take says only the voice is kept', (
    WidgetTester tester,
  ) async {
    for (final VideoRecorderPhase phase in <VideoRecorderPhase>[
      VideoRecorderPhase.idle,
      VideoRecorderPhase.recording,
    ]) {
      await _pumpSheet(
        tester,
        layout: _Layout.phone,
        sheet: VideoRecorderSheet(
          phase: phase,
          devices: _phoneCameras,
          selectedDeviceId: '0',
          cameraOn: false,
          onCameraChanged: (bool _) {},
          onStart: () {},
          onStop: () {},
          onLeave: () {},
        ),
      );
      expect(find.text('Camera off.'), findsOneWidget, reason: phase.name);
      expect(
        find.text('Only your voice is kept, as a voice log.'),
        findsOneWidget,
        reason: phase.name,
      );
      expect(
        find.text('The camera is still recording.'),
        findsNothing,
        reason: phase.name,
      );
    }
    expect(_cameraOffMessage, videoCameraOffMessage);
    await _closeAll(tester);
  });

  testWidgets('a tap where the camera control was does nothing during a take', (
    WidgetTester tester,
  ) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder(supportsPause: true);
    final CameraOffVoiceRecorder voice = CameraOffVoiceRecorder();
    await _pumpComposer(
      tester,
      layout: _Layout.mac,
      recorder: recorder,
      voice: voice,
      service: FakeCaptureService(),
    );
    await _open(tester);
    final Offset where = tester.getCenter(find.byKey(videoCameraKey));
    await _startNow(tester);
    expect(_phase(tester), VideoRecorderPhase.recording);
    expect(find.byKey(videoCameraKey), findsNothing);

    await tester.tapAt(where);
    await tester.pump();
    await _settle(tester);

    expect(recorder.releaseCalls, 0);
    expect(_phase(tester), VideoRecorderPhase.recording);
    expect(recorder.startCalls, 1);
    expect(voice.calls, isEmpty);

    await _closeAll(tester);
  });
}
