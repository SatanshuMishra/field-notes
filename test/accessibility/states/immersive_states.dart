import 'dart:async';

import 'package:camera/camera.dart' show CameraDescription, CameraLensDirection;
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart'
    show cameraDeviceLabels;
import 'package:field_notes/features/capture/video/camera_picker.dart';
import 'package:field_notes/features/capture/video/video_composer.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart'
    show VideoCaptureDevice;
import 'package:field_notes/features/capture/video/video_recorder_provider.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/features/capture/voice/voice_composer.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/capture/video/video_test_support.dart'
    show FakeVideoRecorder, fakeVideoDevices;
import '../../features/capture/voice/voice_test_support.dart'
    show FakeCaptureService, FakeVoiceRecorder;
import '../support/a11y_state.dart';

const String _today = '2026-09-28';
const String _launcherLabel = 'open';
const CaptureException _heldSaveFailure = CaptureException(
  'Could not save your entry.',
);

const Duration _step = Duration(milliseconds: 50);
const Duration _panelOpen = Duration(milliseconds: 300);

final List<VideoCaptureDevice> _phoneCameras = cameraDeviceLabels(
  const <CameraDescription>[
    CameraDescription(
      name: '0',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    ),
    CameraDescription(
      name: '1',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 270,
    ),
  ],
);

Duration _fadeIn(A11yVariant variant) => immersiveFadeFor(variant.layout);

List<VideoCaptureDevice> _camerasFor(A11yVariant variant) =>
    variant.desktop ? fakeVideoDevices : _phoneCameras;

typedef _Open = Future<Object?> Function(BuildContext context);

class _Launcher extends StatelessWidget {
  const _Launcher(this.open);

  final _Open open;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async => open(context),
      child: const Text(_launcherLabel),
    );
  }
}

Future<void> _openRecorder(
  WidgetTester tester, {
  required A11yVariant variant,
  required _Open open,
  required List<Override> overrides,
}) async {
  variant.useWindow(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: variant.theme,
        builder: variant.scaleText,
        home: Scaffold(body: Center(child: _Launcher(open))),
      ),
    ),
  );
  await tester.tap(find.text(_launcherLabel));
  await tester.pump();
  await tester.pump(_fadeIn(variant));
  await tester.pump(_step);
}

Future<void> _openVoice(
  WidgetTester tester,
  A11yVariant variant, {
  bool prompts = false,
  FakeCaptureService? service,
  VoidCallback? onClosed,
}) {
  return _openRecorder(
    tester,
    variant: variant,
    open: (BuildContext context) => showVoiceComposer(context, _today),
    overrides: <Override>[
      voiceRecorderProvider.overrideWith((Ref ref) => FakeVoiceRecorder()),
      captureServiceProvider.overrideWith((Ref ref) {
        if (onClosed != null) {
          ref.onDispose(onClosed);
        }
        return service ?? FakeCaptureService();
      }),
      reflectionPromptsEnabledProvider.overrideWithValue(prompts),
    ],
  );
}

Future<void> _openVideo(
  WidgetTester tester,
  A11yVariant variant, {
  bool supportsPause = true,
}) {
  return _openRecorder(
    tester,
    variant: variant,
    open: (BuildContext context) => showVideoComposer(context, _today),
    overrides: <Override>[
      videoRecorderProvider.overrideWith(
        (Ref ref) => FakeVideoRecorder(
          devices: _camerasFor(variant),
          supportsPause: supportsPause,
        ),
      ),
      voiceRecorderProvider.overrideWith((Ref ref) => FakeVoiceRecorder()),
      captureServiceProvider.overrideWith((Ref ref) => FakeCaptureService()),
      reflectionPromptsEnabledProvider.overrideWithValue(false),
    ],
  );
}

void _requireVoicePhase(WidgetTester tester, VoiceRecorderPhase phase) {
  final VoiceRecorderPhase shown = tester
      .widget<VoiceRecorderSheet>(find.byType(VoiceRecorderSheet))
      .phase;
  if (shown != phase) {
    throw StateError('the voice recorder shows $shown, not $phase');
  }
}

void _requireVideoPhase(WidgetTester tester, VideoRecorderPhase phase) {
  final VideoRecorderPhase shown = tester
      .widget<VideoRecorderSheet>(find.byType(VideoRecorderSheet))
      .phase;
  if (shown != phase) {
    throw StateError('the video recorder shows $shown, not $phase');
  }
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pump();
  await tester.pump(_step);
}

Future<void> _openPanel(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pump();
  await tester.pump(_panelOpen);
}

Future<void> _startVoiceTake(WidgetTester tester) async {
  await _tap(tester, voiceRecordButtonKey);
  _requireVoicePhase(tester, VoiceRecorderPhase.breathing);
  await _tap(tester, voiceRecordButtonKey);
  _requireVoicePhase(tester, VoiceRecorderPhase.recording);
}

Future<void> _startVideoTake(WidgetTester tester) async {
  _requireVideoPhase(tester, VideoRecorderPhase.idle);
  await _tap(tester, videoShutterKey);
  _requireVideoPhase(tester, VideoRecorderPhase.breathing);
  await _tap(tester, videoShutterKey);
  _requireVideoPhase(tester, VideoRecorderPhase.recording);
}

Future<void> _showSecondQuestion(WidgetTester tester) async {
  final Finder first = find.descendant(
    of: find.byKey(reflectionQuestionKey),
    matching: find.text(reflectionQuestions.first, findRichText: true),
  );
  for (
    int shuffle = 0;
    shuffle < reflectionQuestions.length && first.evaluate().isEmpty;
    shuffle++
  ) {
    await _tap(tester, reflectionShuffleKey);
    await tester.pump(_panelOpen);
  }
  await _tap(tester, reflectionShuffleKey);
  await tester.pump(_panelOpen);
}

Future<void> _pumpVoiceQuestion(
  WidgetTester tester,
  A11yVariant variant,
) async {
  await _openVoice(tester, variant, prompts: true);
  await _showSecondQuestion(tester);
  _requireVoicePhase(tester, VoiceRecorderPhase.idle);
}

Future<void> _pumpVoiceBreathing(
  WidgetTester tester,
  A11yVariant variant,
) async {
  await _openVoice(tester, variant);
  await _tap(tester, voiceRecordButtonKey);
  _requireVoicePhase(tester, VoiceRecorderPhase.breathing);
}

Future<void> _pumpVoiceRecording(
  WidgetTester tester,
  A11yVariant variant,
) async {
  await _openVoice(tester, variant);
  await _startVoiceTake(tester);
}

Future<void> _pumpVoicePaused(WidgetTester tester, A11yVariant variant) async {
  await _pumpVoiceRecording(tester, variant);
  await _tap(tester, voiceRecordButtonKey);
  _requireVoicePhase(tester, VoiceRecorderPhase.paused);
}

Future<void> _pumpVoiceLetGo(WidgetTester tester, A11yVariant variant) async {
  await _pumpVoiceRecording(tester, variant);
  await _openPanel(tester, voiceDiscardPillKey);
  _requireVoicePhase(tester, VoiceRecorderPhase.paused);
}

Future<void> _pumpVoiceSaving(WidgetTester tester, A11yVariant variant) async {
  final Completer<void> heldSave = Completer<void>();
  await _openVoice(
    tester,
    variant,
    service: FakeCaptureService(
      failure: _heldSaveFailure,
      gate: heldSave.future,
    ),
    onClosed: heldSave.complete,
  );
  await _startVoiceTake(tester);
  await _tap(tester, voiceSavePillKey);
  _requireVoicePhase(tester, VoiceRecorderPhase.saving);
}

Future<void> _pumpVoiceSaveError(
  WidgetTester tester,
  A11yVariant variant,
) async {
  await _openVoice(
    tester,
    variant,
    service: FakeCaptureService(failure: _heldSaveFailure),
  );
  await _startVoiceTake(tester);
  await _tap(tester, voiceSavePillKey);
  await tester.pump(_panelOpen);
}

Future<void> _pumpVideoIdle(WidgetTester tester, A11yVariant variant) async {
  await _openVideo(tester, variant);
  _requireVideoPhase(tester, VideoRecorderPhase.idle);
}

Future<void> _pumpVideoCameraOff(
  WidgetTester tester,
  A11yVariant variant,
) async {
  await _openVideo(tester, variant);
  await _tap(tester, videoCameraKey);
  await _startVideoTake(tester);
}

Future<void> _pumpVideoLetGo(WidgetTester tester, A11yVariant variant) async {
  await _openVideo(tester, variant);
  await _startVideoTake(tester);
  await _openPanel(tester, videoDiscardCircleKey);
  _requireVideoPhase(tester, VideoRecorderPhase.paused);
}

Future<void> _pumpVideoWithoutPause(
  WidgetTester tester,
  A11yVariant variant,
) async {
  await _openVideo(tester, variant, supportsPause: false);
  await _startVideoTake(tester);
}

Finder _semanticsLabelled(String label) => find.byWidgetPredicate(
  (Widget widget) => widget is Semantics && widget.properties.label == label,
);

const List<A11yStatefulControl> _cameraToggle = <A11yStatefulControl>[
  A11yStatefulControl.label(videoCameraLabel, A11yStateKind.toggled),
];

List<A11yState> _inBothLayouts({
  required String id,
  required A11yPumpBody pump,
  required List<A11yProof> proof,
  List<A11yStatefulControl> stateful = const <A11yStatefulControl>[],
}) {
  final A11yLayoutHalf either = A11yLayoutHalf(
    pump: pump,
    proof: proof,
    stateful: stateful,
  );
  return a11yInBothLayouts(id: id, phone: either, desktop: either);
}

final List<A11yState> immersiveStates = <A11yState>[
  ..._inBothLayouts(
    id: 'i1-voice-question',
    pump: _pumpVoiceQuestion,
    proof: <A11yProof>[
      A11yProof(find.byKey(reflectionQuestionKey)),
      A11yProof(find.byKey(reflectionShuffleKey)),
      A11yProof(find.byKey(voiceRecordButtonKey)),
    ],
  ),
  ..._inBothLayouts(
    id: 'i2-voice-breathing',
    pump: _pumpVoiceBreathing,
    proof: <A11yProof>[
      A11yProof(find.text(stageCountdownWords)),
      A11yProof(_semanticsLabelled(voiceStartNowLabel)),
    ],
  ),
  ..._inBothLayouts(
    id: 'i3-voice-recording',
    pump: _pumpVoiceRecording,
    proof: <A11yProof>[
      A11yProof(find.text(stageRecordingStatus)),
      A11yProof(find.byKey(recorderTimerKey)),
      A11yProof(find.byKey(voiceDiscardPillKey)),
      A11yProof(find.byKey(voiceSavePillKey)),
    ],
  ),
  ..._inBothLayouts(
    id: 'i4-voice-paused',
    pump: _pumpVoicePaused,
    proof: <A11yProof>[
      A11yProof(find.text(stagePausedStatus)),
      A11yProof(_semanticsLabelled(voiceResumeLabel)),
      A11yProof(find.byKey(voiceSavePillKey)),
    ],
  ),
  ..._inBothLayouts(
    id: 'i5-voice-let-go',
    pump: _pumpVoiceLetGo,
    proof: <A11yProof>[
      A11yProof(find.byType(LetGoPanel)),
      A11yProof(find.byKey(voiceKeepGoingKey)),
      A11yProof(find.byKey(voiceDiscardConfirmKey)),
    ],
  ),
  ..._inBothLayouts(
    id: 'i6-voice-saving',
    pump: _pumpVoiceSaving,
    proof: <A11yProof>[A11yProof(find.text(voiceSavingStatus))],
  ),
  ..._inBothLayouts(
    id: 'i7-video-idle',
    pump: _pumpVideoIdle,
    proof: <A11yProof>[
      A11yProof(find.byKey(videoShutterKey)),
      A11yProof(find.byKey(videoCameraKey)),
      A11yProof(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is CameraPicker || widget.key == videoFlipCameraKey,
        ),
      ),
    ],
    stateful: _cameraToggle,
  ),
  ..._inBothLayouts(
    id: 'i8-video-camera-off',
    pump: _pumpVideoCameraOff,
    proof: <A11yProof>[
      A11yProof(find.text(videoCameraOffTitle)),
      A11yProof(find.text(stageRecordingStatus)),
      A11yProof(find.byKey(videoSaveCircleKey)),
    ],
  ),
  ..._inBothLayouts(
    id: 'i9-video-let-go',
    pump: _pumpVideoLetGo,
    proof: <A11yProof>[
      A11yProof(find.byType(LetGoPanel)),
      A11yProof(find.byKey(videoKeepGoingKey)),
      A11yProof(find.byKey(videoDiscardConfirmKey)),
    ],
  ),
  ..._inBothLayouts(
    id: 'i10-video-without-pause',
    pump: _pumpVideoWithoutPause,
    proof: <A11yProof>[
      A11yProof(_semanticsLabelled(videoStopAndKeepLabel)),
      A11yProof(find.text(stageRecordingStatus)),
      A11yProof(find.byKey(videoSaveCircleKey)),
    ],
  ),
  ..._inBothLayouts(
    id: 'i11-voice-save-error',
    pump: _pumpVoiceSaveError,
    proof: <A11yProof>[
      A11yProof(find.byKey(voiceErrorKey)),
      A11yProof(find.text(_heldSaveFailure.message)),
      A11yProof(find.byKey(voiceSavePillKey)),
    ],
  ),
];
