import 'dart:async';
import 'dart:io';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/settings/app_settings.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/audio/take_cleanup.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/video/video_composer.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder_provider.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/features/capture/voice/voice_composer.dart';
import 'package:field_notes/features/capture/voice/voice_recorder.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../video/video_test_support.dart'
    show
        CameraOffVoiceRecorder,
        FakeCaptureService,
        FakeTakeCleanup,
        FakeVideoRecorder,
        reflectionPromptsOff,
        takeCleanupOverride;
import '../voice/voice_test_support.dart' show FakeVoiceRecorder;

const String _date = '2026-10-14';
const String _voiceLabel = 'voice';
const String _videoLabel = 'video';
const String _timeoutMessage =
    'Saving took too long. Nothing was saved — please try again.';
const Duration _fade = Duration(milliseconds: 600);
const Duration _step = Duration(milliseconds: 50);

final TargetPlatformVariant _mac = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

AppSettings _settings(InputProfile profile, int volume) =>
    AppSettings.defaults.copyWith(inputProfile: profile, inputVolume: volume);

VoiceRecording _voiceTake(String path) => VoiceRecording(
  media: CaptureFile(file: File(path), mime: 'audio/mp4', durationMs: 4200),
  durationMs: 4200,
);

VideoRecording _videoTake(String path) => VideoRecording(
  media: CaptureFile(file: File(path), mime: 'video/mp4', durationMs: 6000),
  durationMs: 6000,
  thumbnail: const CaptureBytes(bytes: <int>[7, 8], mime: 'image/jpeg'),
);

class _Launcher extends ConsumerWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appSettingsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextButton(
          onPressed: () => showVoiceComposer(context, _date),
          child: const Text(_voiceLabel),
        ),
        TextButton(
          onPressed: () => showVideoComposer(context, _date),
          child: const Text(_videoLabel),
        ),
      ],
    );
  }
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required AppSettings settings,
  required FakeTakeCleanup cleanup,
  required FakeCaptureService service,
  FakeVoiceRecorder? voice,
  FakeVideoRecorder? video,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final FakeVoiceRecorder voiceRecorder = voice ?? FakeVoiceRecorder();
  final FakeVideoRecorder videoRecorder = video ?? FakeVideoRecorder();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        voiceRecorderProvider.overrideWith((Ref ref) => voiceRecorder),
        videoRecorderProvider.overrideWith((Ref ref) => videoRecorder),
        captureServiceProvider.overrideWith((Ref ref) => service),
        appSettingsProvider.overrideWith(
          (Ref ref) => Stream<AppSettings>.value(settings),
        ),
        takeCleanupOverride(cleanup),
        reflectionPromptsOff(),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: const Scaffold(body: Center(child: _Launcher())),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  for (int index = 0; index < 14; index += 1) {
    await tester.pump(_step);
  }
}

Future<void> _openVoice(WidgetTester tester) async {
  await tester.tap(find.text(_voiceLabel));
  await tester.pump();
  await tester.pump(_fade);
}

Future<void> _recordVoice(WidgetTester tester, FakeVoiceRecorder voice) async {
  await tester.tap(find.byKey(voiceRecordButtonKey));
  await tester.pump();
  await tester.tap(find.byKey(voiceRecordButtonKey));
  await tester.pump();
  await tester.pump(_step);
  voice.elapsed = const Duration(milliseconds: 300);
}

Future<void> _keepVoice(WidgetTester tester) async {
  await tester.tap(find.byKey(voiceSavePillKey));
  await tester.pump();
  await tester.pump(_step);
}

Future<void> _openVideo(WidgetTester tester, {bool cameraOff = false}) async {
  await tester.tap(find.text(_videoLabel));
  await tester.pump();
  await tester.pump(_fade);
  await _settle(tester);
  if (cameraOff) {
    await tester.tap(find.byKey(videoCameraKey));
    await tester.pump();
    await _settle(tester);
  }
}

Future<void> _recordVideo(WidgetTester tester) async {
  await tester.tap(find.byKey(videoShutterKey));
  await tester.pump();
  await tester.tap(find.byKey(videoShutterKey));
  await tester.pump();
  await _settle(tester);
}

Future<void> _keepVideo(WidgetTester tester) async {
  await tester.tap(find.byKey(videoSaveCircleKey));
  await tester.pump();
  await tester.pump(_step);
}

Future<void> _finish(WidgetTester tester) async {
  for (int index = 0; index < 40; index += 1) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _closeAll(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

File _file(CaptureMedia media) => (media as CaptureFile).file;

void main() {
  testWidgets('a cleaned voice take is saved with its new file and no peaks', (
    WidgetTester tester,
  ) async {
    final VoiceRecording take = _voiceTake('/captures/voice_1.m4a');
    final FakeVoiceRecorder voice = FakeVoiceRecorder(recording: take);
    final FakeTakeCleanup cleanup = FakeTakeCleanup(
      rewritten: File('/cleaned/voice_1.m4a'),
      delay: const Duration(seconds: 1),
    );
    final FakeCaptureService service = FakeCaptureService();
    await _pumpApp(
      tester,
      settings: _settings(InputProfile.voiceIsolation, 100),
      cleanup: cleanup,
      service: service,
      voice: voice,
    );
    await _openVoice(tester);
    await _recordVoice(tester, voice);

    await _keepVoice(tester);

    expect(find.text('Clearing background noise…'), findsOneWidget);
    expect(service.requests, isEmpty);

    await tester.pump(const Duration(seconds: 1));
    await _finish(tester);

    expect(cleanup.kinds, <TakeKind>[TakeKind.voice]);
    expect(cleanup.profiles, <InputProfile>[InputProfile.voiceIsolation]);
    final VoiceCaptureRequest request =
        service.requests.single as VoiceCaptureRequest;
    expect(_file(request.audio).path, '/cleaned/voice_1.m4a');
    expect(request.audio.mime, 'audio/mp4');
    expect(request.durationMs, 4200);
    expect(request.peaks, isEmpty);

    await _closeAll(tester);
  }, variant: _mac);

  testWidgets('a voice take saved as recorded keeps its sampled peaks', (
    WidgetTester tester,
  ) async {
    final VoiceRecording take = _voiceTake('/captures/voice_2.m4a');
    final FakeVoiceRecorder voice = FakeVoiceRecorder(recording: take);
    final FakeTakeCleanup cleanup = FakeTakeCleanup(
      delay: const Duration(seconds: 1),
    );
    final FakeCaptureService service = FakeCaptureService();
    await _pumpApp(
      tester,
      settings: _settings(InputProfile.studio, 100),
      cleanup: cleanup,
      service: service,
      voice: voice,
    );
    await _openVoice(tester);
    await _recordVoice(tester, voice);

    await _keepVoice(tester);

    expect(find.text('Saving your recording…'), findsOneWidget);
    expect(find.text('Clearing background noise…'), findsNothing);
    expect(find.text('Adjusting the volume…'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await _finish(tester);

    final VoiceCaptureRequest request =
        service.requests.single as VoiceCaptureRequest;
    expect(request.audio, same(take.media));
    expect(_file(request.audio).path, '/captures/voice_2.m4a');
    expect(request.peaks, <double>[0.0, 0.0, 0.0]);
    expect(cleanup.released, isEmpty);

    await _closeAll(tester);
  }, variant: _mac);

  testWidgets('a cleaned video take is saved with its new file', (
    WidgetTester tester,
  ) async {
    final VideoRecording take = _videoTake('/captures/video_3.mp4');
    final FakeVideoRecorder video = FakeVideoRecorder(recording: take);
    final FakeTakeCleanup cleanup = FakeTakeCleanup(
      rewritten: File('/cleaned/video_3.mp4'),
      delay: const Duration(seconds: 1),
    );
    final FakeCaptureService service = FakeCaptureService();
    await _pumpApp(
      tester,
      settings: _settings(InputProfile.studio, 140),
      cleanup: cleanup,
      service: service,
      video: video,
    );
    await _openVideo(tester);
    await _recordVideo(tester);

    await _keepVideo(tester);

    expect(find.text('Adjusting the volume…'), findsOneWidget);
    expect(service.requests, isEmpty);

    await tester.pump(const Duration(seconds: 1));
    await _finish(tester);

    expect(cleanup.kinds, <TakeKind>[TakeKind.video]);
    expect(cleanup.volumes, <int>[140]);
    final VideoCaptureRequest request =
        service.requests.single as VideoCaptureRequest;
    expect(_file(request.video).path, '/cleaned/video_3.mp4');
    expect(request.video.mime, 'video/mp4');
    expect(request.durationMs, 6000);
    expect(request.thumbnail, same(take.thumbnail));

    await _closeAll(tester);
  }, variant: _mac);

  testWidgets('a cleaned camera-off take is saved as a voice log', (
    WidgetTester tester,
  ) async {
    final VoiceRecording take = _voiceTake('/captures/camera_off_4.m4a');
    final CameraOffVoiceRecorder voice = CameraOffVoiceRecorder(
      recording: take,
    );
    final FakeTakeCleanup cleanup = FakeTakeCleanup(
      rewritten: File('/cleaned/camera_off_4.m4a'),
    );
    final FakeCaptureService service = FakeCaptureService();
    await _pumpApp(
      tester,
      settings: _settings(InputProfile.voiceIsolation, 100),
      cleanup: cleanup,
      service: service,
      voice: voice,
    );
    await _openVideo(tester, cameraOff: true);
    await _recordVideo(tester);

    await _keepVideo(tester);
    await _finish(tester);

    expect(cleanup.kinds, <TakeKind>[TakeKind.voice]);
    expect(service.requests.whereType<VideoCaptureRequest>(), isEmpty);
    final VoiceCaptureRequest request =
        service.requests.single as VoiceCaptureRequest;
    expect(_file(request.audio).path, '/cleaned/camera_off_4.m4a');
    expect(request.peaks, isEmpty);

    await _closeAll(tester);
  }, variant: _mac);

  testWidgets('the save timeout starts after the cleanup', (
    WidgetTester tester,
  ) async {
    final FakeTakeCleanup cleanup = FakeTakeCleanup(
      rewritten: File('/cleaned/slow.m4a'),
      delay: const Duration(seconds: 30),
    );
    final FakeCaptureService service = FakeCaptureService();
    final FakeVoiceRecorder voice = FakeVoiceRecorder(
      recording: _voiceTake('/captures/voice_5.m4a'),
    );
    await _pumpApp(
      tester,
      settings: _settings(InputProfile.voiceIsolation, 100),
      cleanup: cleanup,
      service: service,
      voice: voice,
    );
    await _openVoice(tester);
    await _recordVoice(tester, voice);
    await _keepVoice(tester);

    await tester.pump(const Duration(seconds: 30));
    await _finish(tester);

    expect(service.requests, hasLength(1));
    expect(service.requests.single, isA<VoiceCaptureRequest>());
    expect(find.text(_timeoutMessage), findsNothing);
    await _closeAll(tester);

    await _pumpApp(
      tester,
      settings: _settings(InputProfile.voiceIsolation, 100),
      cleanup: cleanup,
      service: service,
      video: FakeVideoRecorder(recording: _videoTake('/captures/v_5.mp4')),
    );
    await _openVideo(tester);
    await _recordVideo(tester);
    await _keepVideo(tester);

    await tester.pump(const Duration(seconds: 30));
    await _finish(tester);

    expect(service.requests, hasLength(2));
    expect(service.requests.last, isA<VideoCaptureRequest>());
    expect(find.text(_timeoutMessage), findsNothing);
    expect(cleanup.takes, hasLength(2));

    await _closeAll(tester);
  }, variant: _mac);

  testWidgets('a rewritten take is released once its capture ends', (
    WidgetTester tester,
  ) async {
    final File rewritten = File('/cleaned/rewritten.m4a');
    final FakeTakeCleanup cleanup = FakeTakeCleanup(rewritten: rewritten);
    final AppSettings settings = _settings(InputProfile.voiceIsolation, 100);

    final VoiceRecording voiceTake = _voiceTake('/captures/voice_6.m4a');
    final FakeVoiceRecorder voice = FakeVoiceRecorder(recording: voiceTake);
    await _pumpApp(
      tester,
      settings: settings,
      cleanup: cleanup,
      service: FakeCaptureService(),
      voice: voice,
    );
    await _openVoice(tester);
    await _recordVoice(tester, voice);
    await _keepVoice(tester);
    await _finish(tester);
    expect(cleanup.released, <File>[rewritten]);
    expect(voice.savedReleases, hasLength(1));
    expect(voice.savedReleases.single, same(voiceTake));
    await _closeAll(tester);

    final VideoRecording videoTake = _videoTake('/captures/video_6.mp4');
    final FakeVideoRecorder video = FakeVideoRecorder(recording: videoTake);
    await _pumpApp(
      tester,
      settings: settings,
      cleanup: cleanup,
      service: FakeCaptureService(),
      video: video,
    );
    await _openVideo(tester);
    await _recordVideo(tester);
    await _keepVideo(tester);
    await _finish(tester);
    expect(cleanup.released, <File>[rewritten, rewritten]);
    expect(video.savedReleases, hasLength(1));
    expect(video.savedReleases.single, same(videoTake));
    await _closeAll(tester);

    final VoiceRecording offTake = _voiceTake('/captures/camera_off_6.m4a');
    final CameraOffVoiceRecorder cameraOff = CameraOffVoiceRecorder(
      recording: offTake,
    );
    await _pumpApp(
      tester,
      settings: settings,
      cleanup: cleanup,
      service: FakeCaptureService(),
      voice: cameraOff,
    );
    await _openVideo(tester, cameraOff: true);
    await _recordVideo(tester);
    await _keepVideo(tester);
    await _finish(tester);
    expect(cleanup.released, <File>[rewritten, rewritten, rewritten]);
    expect(cameraOff.savedReleases, hasLength(1));
    expect(cameraOff.savedReleases.single, same(offTake));
    await _closeAll(tester);

    final FakeVoiceRecorder failing = FakeVoiceRecorder(
      recording: _voiceTake('/captures/voice_6b.m4a'),
    );
    await _pumpApp(
      tester,
      settings: settings,
      cleanup: cleanup,
      service: FakeCaptureService(
        failure: const CaptureException('Could not save your entry.'),
      ),
      voice: failing,
    );
    await _openVoice(tester);
    await _recordVoice(tester, failing);
    await _keepVoice(tester);
    await _finish(tester);
    expect(find.text('Could not save your entry.'), findsOneWidget);
    expect(cleanup.released, <File>[
      rewritten,
      rewritten,
      rewritten,
      rewritten,
    ]);
    expect(failing.savedReleases, isEmpty);
    await _closeAll(tester);

    final Completer<void> slowCapture = Completer<void>();
    final VideoRecording slowTake = _videoTake('/captures/video_6b.mp4');
    final FakeVideoRecorder slow = FakeVideoRecorder(recording: slowTake);
    await _pumpApp(
      tester,
      settings: settings,
      cleanup: cleanup,
      service: FakeCaptureService(gate: slowCapture.future),
      video: slow,
    );
    await _openVideo(tester);
    await _recordVideo(tester);
    await _keepVideo(tester);

    await tester.pump(const Duration(seconds: 20));
    await tester.pump(_step);
    expect(find.text(_timeoutMessage), findsOneWidget);
    expect(cleanup.released, hasLength(4));

    await tester.pump(const Duration(seconds: 10));
    expect(cleanup.released, hasLength(4));
    slowCapture.complete();
    await tester.pump();
    await tester.pump(_step);

    expect(cleanup.released, <File>[
      rewritten,
      rewritten,
      rewritten,
      rewritten,
      rewritten,
    ]);
    expect(slow.savedReleases, hasLength(1));
    expect(slow.savedReleases.single, same(slowTake));

    await _closeAll(tester);
  }, variant: _mac);
}
