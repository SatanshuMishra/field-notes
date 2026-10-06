import 'dart:async';

import 'package:camera/camera.dart' show CameraDescription, CameraLensDirection;
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/theme/app_theme.dart';
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
import 'package:flutter/foundation.dart';
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

final List<VideoCaptureDevice> _phoneCameras =
    cameraDeviceLabels(const <CameraDescription>[
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
    ]);

enum _Layout {
  sidebar(
    suffix: 'sidebar',
    platform: TargetPlatform.macOS,
    window: Size(1280, 800),
  ),
  bottomBar(
    suffix: 'bottom-bar',
    platform: TargetPlatform.android,
    window: Size(360, 740),
  );

  const _Layout({
    required this.suffix,
    required this.platform,
    required this.window,
  });

  final String suffix;
  final TargetPlatform platform;
  final Size window;

  Duration get fade => immersiveFadeFor(resolveShellLayout(platform));

  List<VideoCaptureDevice> get cameras =>
      this == sidebar ? fakeVideoDevices : _phoneCameras;
}

typedef _Open = Future<Object?> Function(BuildContext context);

typedef _LayoutPump =
    Future<void> Function(WidgetTester tester, _Layout layout);

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

Future<void> _inLayout(
  WidgetTester tester,
  _Layout layout,
  _LayoutPump pump,
) async {
  debugDefaultTargetPlatformOverride = layout.platform;
  try {
    await pump(tester, layout);
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _openRecorder(
  WidgetTester tester, {
  required _Layout layout,
  required _Open open,
  required List<Override> overrides,
}) async {
  tester.view.physicalSize = layout.window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: layout.platform),
        home: Scaffold(body: Center(child: _Launcher(open))),
      ),
    ),
  );
  await tester.tap(find.text(_launcherLabel));
  await tester.pump();
  await tester.pump(layout.fade);
  await tester.pump(_step);
}

Future<void> _openVoice(
  WidgetTester tester,
  _Layout layout, {
  bool prompts = false,
  FakeCaptureService? service,
}) {
  return _openRecorder(
    tester,
    layout: layout,
    open: (BuildContext context) => showVoiceComposer(context, _today),
    overrides: <Override>[
      voiceRecorderProvider.overrideWith((Ref ref) => FakeVoiceRecorder()),
      captureServiceProvider.overrideWith(
        (Ref ref) => service ?? FakeCaptureService(),
      ),
      reflectionPromptsEnabledProvider.overrideWithValue(prompts),
    ],
  );
}

Future<void> _openVideo(
  WidgetTester tester,
  _Layout layout, {
  bool supportsPause = true,
}) {
  return _openRecorder(
    tester,
    layout: layout,
    open: (BuildContext context) => showVideoComposer(context, _today),
    overrides: <Override>[
      videoRecorderProvider.overrideWith(
        (Ref ref) => FakeVideoRecorder(
          devices: layout.cameras,
          supportsPause: supportsPause,
        ),
      ),
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

Future<void> _pumpVoiceQuestion(WidgetTester tester, _Layout layout) async {
  await _openVoice(tester, layout, prompts: true);
  _requireVoicePhase(tester, VoiceRecorderPhase.idle);
}

Future<void> _pumpVoiceBreathing(WidgetTester tester, _Layout layout) async {
  await _openVoice(tester, layout);
  await _tap(tester, voiceRecordButtonKey);
  _requireVoicePhase(tester, VoiceRecorderPhase.breathing);
}

Future<void> _pumpVoiceRecording(WidgetTester tester, _Layout layout) async {
  await _openVoice(tester, layout);
  await _startVoiceTake(tester);
}

Future<void> _pumpVoicePaused(WidgetTester tester, _Layout layout) async {
  await _pumpVoiceRecording(tester, layout);
  await _tap(tester, voiceRecordButtonKey);
  _requireVoicePhase(tester, VoiceRecorderPhase.paused);
}

Future<void> _pumpVoiceLetGo(WidgetTester tester, _Layout layout) async {
  await _pumpVoiceRecording(tester, layout);
  await _openPanel(tester, voiceDiscardPillKey);
  _requireVoicePhase(tester, VoiceRecorderPhase.paused);
}

Future<void> _pumpVoiceSaving(WidgetTester tester, _Layout layout) async {
  final Completer<void> heldSave = Completer<void>();
  await _openVoice(
    tester,
    layout,
    service: FakeCaptureService(
      failure: _heldSaveFailure,
      gate: heldSave.future,
    ),
  );
  await _startVoiceTake(tester);
  await _tap(tester, voiceSavePillKey);
  _requireVoicePhase(tester, VoiceRecorderPhase.saving);
  tester.binding.addPostFrameCallback((Duration _) => heldSave.complete());
}

Future<void> _pumpVideoIdle(WidgetTester tester, _Layout layout) async {
  await _openVideo(tester, layout);
  _requireVideoPhase(tester, VideoRecorderPhase.idle);
}

Future<void> _pumpVideoSelfViewOff(WidgetTester tester, _Layout layout) async {
  await _openVideo(tester, layout);
  await _startVideoTake(tester);
  await _tap(tester, videoSelfViewKey);
  _requireVideoPhase(tester, VideoRecorderPhase.recording);
}

Future<void> _pumpVideoLetGo(WidgetTester tester, _Layout layout) async {
  await _openVideo(tester, layout);
  await _startVideoTake(tester);
  await _openPanel(tester, videoDiscardCircleKey);
  _requireVideoPhase(tester, VideoRecorderPhase.paused);
}

Future<void> _pumpVideoWithoutPause(WidgetTester tester, _Layout layout) async {
  await _openVideo(tester, layout, supportsPause: false);
  await _startVideoTake(tester);
}

Finder _semanticsLabelled(String label) => find.byWidgetPredicate(
  (Widget widget) => widget is Semantics && widget.properties.label == label,
);

const List<A11yStatefulControl> _selfViewToggle = <A11yStatefulControl>[
  A11yStatefulControl.label(videoSelfViewLabel, A11yStateKind.toggled),
];

List<A11yState> _inBothLayouts({
  required String id,
  required _LayoutPump pump,
  required List<A11yProof> proof,
  List<A11yStatefulControl> stateful = const <A11yStatefulControl>[],
}) {
  return <A11yState>[
    for (final _Layout layout in _Layout.values)
      A11yState(
        id: '$id-${layout.suffix}',
        pump: (WidgetTester tester) => _inLayout(tester, layout, pump),
        proof: proof,
        stateful: stateful,
      ),
  ];
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
      A11yProof(find.text(stageBreathingStatus)),
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
      A11yProof(find.byKey(videoSelfViewKey)),
      A11yProof(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is CameraPicker || widget.key == videoFlipCameraKey,
        ),
      ),
    ],
    stateful: _selfViewToggle,
  ),
  ..._inBothLayouts(
    id: 'i8-video-self-view-off',
    pump: _pumpVideoSelfViewOff,
    proof: <A11yProof>[
      A11yProof(find.text(videoSelfViewOffTitle)),
      A11yProof(find.text(stageRecordingStatus)),
      A11yProof(find.byKey(videoSaveCircleKey)),
    ],
    stateful: _selfViewToggle,
  ),
  ..._inBothLayouts(
    id: 'i9-video-let-go',
    pump: _pumpVideoLetGo,
    proof: <A11yProof>[
      A11yProof(find.byType(LetGoPanel)),
      A11yProof(find.byKey(videoKeepGoingKey)),
      A11yProof(find.byKey(videoDiscardConfirmKey)),
    ],
    stateful: _selfViewToggle,
  ),
  ..._inBothLayouts(
    id: 'i10-video-without-pause',
    pump: _pumpVideoWithoutPause,
    proof: <A11yProof>[
      A11yProof(_semanticsLabelled(videoStopAndKeepLabel)),
      A11yProof(find.text(stageRecordingStatus)),
      A11yProof(find.byKey(videoSaveCircleKey)),
    ],
    stateful: _selfViewToggle,
  ),
];
