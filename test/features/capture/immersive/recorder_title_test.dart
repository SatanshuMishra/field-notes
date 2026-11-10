import 'dart:async';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/toast.dart';
import 'package:field_notes/features/capture/audio/input_panel.dart';
import 'package:field_notes/features/capture/audio/recorder_input_ring.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:field_notes/features/capture/video/camera_picker.dart';
import 'package:field_notes/features/capture/video/video_composer.dart';
import 'package:field_notes/features/capture/video/video_recorder_provider.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/features/capture/voice/voice_composer.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../day_detail/support/day_detail_harness.dart'
    show FakeJournalRepository;
import '../video/video_test_support.dart';
import '../voice/voice_test_support.dart' show startVoiceTake;

enum _Recorder { voice, video }

const String _date = '2026-09-28';
const String _openLabel = 'open';
const String _title = 'Morning walk';
const Size _sidebarWindow = Size(1280, 800);
const Size _phoneWindow = Size(360, 740);
const Duration _step = Duration(milliseconds: 50);

class _GatedTitleJournal extends FakeJournalRepository {
  _GatedTitleJournal(this.gate);

  final Future<void> gate;

  @override
  Future<void> setEntryTitle(String entryId, String? title) async {
    await gate;
    return super.setEntryTitle(entryId, title);
  }
}

class _Rig {
  _Rig(this.kind, {FakeJournalRepository? journal})
    : journal = journal ?? FakeJournalRepository();

  final _Recorder kind;
  final FakeJournalRepository journal;
  final FakeCaptureService service = FakeCaptureService();
  final CameraOffVoiceRecorder voice = CameraOffVoiceRecorder();
  final FakeVideoRecorder video = FakeVideoRecorder(supportsPause: true);
  final List<String?> results = <String?>[];

  String get toast =>
      kind == _Recorder.voice ? 'Voice memo saved' : 'Video saved';

  Key get keepKey =>
      kind == _Recorder.voice ? voiceSavePillKey : videoSaveCircleKey;

  StagePhase stage(WidgetTester tester) => kind == _Recorder.voice
      ? tester
            .widget<VoiceRecorderSheet>(find.byType(VoiceRecorderSheet))
            .phase
            .stage
      : tester
            .widget<VideoRecorderSheet>(find.byType(VideoRecorderSheet))
            .phase
            .stage;
}

void _noop() {}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 20; i++) {
    await tester.pump(_step);
  }
}

Future<_Rig> _open(
  WidgetTester tester,
  _Recorder kind, {
  FakeJournalRepository? journal,
}) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  tester.view.physicalSize = _sidebarWindow;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _Rig rig = _Rig(kind, journal: journal);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(rig.journal),
        captureServiceProvider.overrideWith((Ref ref) => rig.service),
        voiceRecorderProvider.overrideWith((Ref ref) => rig.voice),
        videoRecorderProvider.overrideWith((Ref ref) => rig.video),
        reflectionPromptsEnabledProvider.overrideWithValue(false),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async => rig.results.add(
                kind == _Recorder.voice
                    ? await showVoiceComposer(context, _date)
                    : await showVideoComposer(context, _date),
              ),
              child: const Text(_openLabel),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text(_openLabel));
  await tester.pump();
  await _settle(tester);
  return rig;
}

Future<void> _startTake(WidgetTester tester, _Rig rig) async {
  if (rig.kind == _Recorder.voice) {
    await startVoiceTake(tester);
    return;
  }
  await tester.tap(find.byKey(videoShutterKey));
  await tester.pump();
  await tester.tap(find.byKey(videoShutterKey));
  await tester.pump();
  await _settle(tester);
}

Future<void> _keep(WidgetTester tester, _Rig rig) async {
  await tester.tap(find.byKey(rig.keepKey));
  await tester.pump();
  await _settle(tester);
}

String _toastTitleText(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(toastTitleFieldKey)).controller!.text;

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  debugDefaultTargetPlatformOverride = null;
}

Future<void> _pumpVideoSheet(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Size window,
  VideoRecorderPhase phase = VideoRecorderPhase.idle,
  Stream<double> levels = const Stream<double>.empty(),
  TextEditingController? title,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[reflectionPromptsOff()],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: Scaffold(
          body: VideoRecorderSheet(
            phase: phase,
            onStart: _noop,
            onStop: _noop,
            onLeave: _noop,
            devices: fakeVideoDevices,
            selectedDeviceId: fakeVideoDevices.first.id,
            onDeviceChanged: (String _) {},
            onCameraChanged: (bool _) {},
            levels: levels,
            titleController: title,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void _forEachRecorder(
  String description,
  Future<void> Function(WidgetTester tester, _Rig rig) body,
) {
  for (final _Recorder kind in _Recorder.values) {
    testWidgets('${kind.name}: $description', (WidgetTester tester) async {
      final _Rig rig = await _open(tester, kind);
      await body(tester, rig);
      await _finish(tester);
    });
  }
}

void main() {
  _forEachRecorder('the field offers the title placeholder', (
    WidgetTester tester,
    _Rig rig,
  ) async {
    expect(find.byKey(recorderTitleFieldKey), findsOneWidget);
    expect(find.text(recorderTitlePlaceholder), findsOneWidget);
  });

  _forEachRecorder('a title typed before keeping reaches the saved log', (
    WidgetTester tester,
    _Rig rig,
  ) async {
    await tester.enterText(find.byKey(recorderTitleFieldKey), '  $_title ');
    await _startTake(tester, rig);
    await _keep(tester, rig);

    expect(rig.results, <String?>['entry-1']);
    expect(rig.journal.titleUpdates, <({String id, String? title})>[
      (id: 'entry-1', title: _title),
    ]);
    expect(find.text(rig.toast), findsOneWidget);
    expect(find.text(recorderTitlePlaceholder), findsNothing);
  });

  _forEachRecorder('a title typed during the take reaches the saved log', (
    WidgetTester tester,
    _Rig rig,
  ) async {
    await _startTake(tester, rig);
    await tester.enterText(find.byKey(recorderTitleFieldKey), _title);
    await _keep(tester, rig);

    expect(rig.journal.titleUpdates, <({String id, String? title})>[
      (id: 'entry-1', title: _title),
    ]);
  });

  _forEachRecorder('an untitled log can be named from the toast', (
    WidgetTester tester,
    _Rig rig,
  ) async {
    await _startTake(tester, rig);
    await _keep(tester, rig);

    expect(rig.journal.titleUpdates, isEmpty);
    expect(find.text(rig.toast), findsOneWidget);
    await tester.tap(find.text(recorderTitlePlaceholder));
    await tester.pump();

    await tester.enterText(find.byKey(toastTitleFieldKey), _title);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(rig.journal.titleUpdates, <({String id, String? title})>[
      (id: 'entry-1', title: _title),
    ]);
    expect(find.byKey(toastTitleFieldKey), findsNothing);
  });

  _forEachRecorder('a blank title names nothing and the toast still offers', (
    WidgetTester tester,
    _Rig rig,
  ) async {
    await tester.enterText(find.byKey(recorderTitleFieldKey), '   ');
    await _startTake(tester, rig);
    await _keep(tester, rig);

    expect(rig.journal.titleUpdates, isEmpty);
    expect(find.text(recorderTitlePlaceholder), findsOneWidget);
  });

  _forEachRecorder('a title that fails to save waits in the toast field', (
    WidgetTester tester,
    _Rig rig,
  ) async {
    rig.journal.updateError = StateError('disk full');
    await tester.enterText(find.byKey(recorderTitleFieldKey), _title);
    await _startTake(tester, rig);
    await _keep(tester, rig);

    expect(rig.results, <String?>['entry-1']);
    expect(rig.journal.titleUpdates, isEmpty);
    expect(find.text(rig.toast), findsOneWidget);
    await tester.tap(find.text(recorderTitlePlaceholder));
    await tester.pump();

    expect(_toastTitleText(tester), _title);
  });

  _forEachRecorder('a title the toast cannot save says so and stays to retry', (
    WidgetTester tester,
    _Rig rig,
  ) async {
    await _startTake(tester, rig);
    await _keep(tester, rig);
    await tester.tap(find.text(recorderTitlePlaceholder));
    await tester.pump();
    rig.journal.updateError = StateError('disk full');

    await tester.enterText(find.byKey(toastTitleFieldKey), _title);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(rig.journal.titleUpdates, isEmpty);
    expect(find.text(recorderTitleFailedMessage), findsOneWidget);
    expect(find.text(rig.toast), findsNothing);
    expect(_toastTitleText(tester), _title);

    rig.journal.updateError = null;
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(rig.journal.titleUpdates, <({String id, String? title})>[
      (id: 'entry-1', title: _title),
    ]);
    expect(find.byKey(toastTitleFieldKey), findsNothing);
  });

  testWidgets('video: the camera is released before a slow title write ends', (
    WidgetTester tester,
  ) async {
    final Completer<void> titleWrite = Completer<void>();
    final _Rig rig = await _open(
      tester,
      _Recorder.video,
      journal: _GatedTitleJournal(titleWrite.future),
    );
    await tester.enterText(find.byKey(recorderTitleFieldKey), _title);
    await _startTake(tester, rig);
    await _keep(tester, rig);

    expect(rig.journal.titleUpdates, isEmpty);
    expect(rig.video.releaseCalls, 1);

    titleWrite.complete();
    await _settle(tester);

    expect(rig.journal.titleUpdates, <({String id, String? title})>[
      (id: 'entry-1', title: _title),
    ]);
    expect(rig.results, <String?>['entry-1']);
    await _finish(tester);
  });

  _forEachRecorder('Space typed in the title does not start a take', (
    WidgetTester tester,
    _Rig rig,
  ) async {
    await tester.tap(find.byKey(recorderTitleFieldKey));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(rig.stage(tester), StagePhase.idle);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(rig.stage(tester), StagePhase.breathing);
  });

  _forEachRecorder('Escape in the title leaves the field, not the recorder', (
    WidgetTester tester,
    _Rig rig,
  ) async {
    await tester.tap(find.byKey(recorderTitleFieldKey));
    await tester.pump();
    final FocusNode field = tester
        .widget<TextField>(find.byKey(recorderTitleFieldKey))
        .focusNode!;
    expect(field.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(field.hasFocus, isFalse);
    expect(rig.results, isEmpty);
    expect(rig.stage(tester), StagePhase.idle);
  });

  testWidgets('the voice title is read-only while the log saves', (
    WidgetTester tester,
  ) async {
    final TextEditingController title = TextEditingController();
    addTearDown(title.dispose);
    await tester.pumpWidget(
      voiceHarnessWithTitle(VoiceRecorderPhase.saving, title),
    );
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byKey(recorderTitleFieldKey)).readOnly,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the video title is read-only while the log saves', (
    WidgetTester tester,
  ) async {
    final TextEditingController title = TextEditingController();
    addTearDown(title.dispose);
    await _pumpVideoSheet(
      tester,
      platform: TargetPlatform.macOS,
      window: _sidebarWindow,
      phase: VideoRecorderPhase.saving,
      title: title,
    );

    expect(
      tester.widget<TextField>(find.byKey(recorderTitleFieldKey)).readOnly,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a video recorder without camera access has no title field', (
    WidgetTester tester,
  ) async {
    final TextEditingController title = TextEditingController();
    addTearDown(title.dispose);
    await _pumpVideoSheet(
      tester,
      platform: TargetPlatform.macOS,
      window: _sidebarWindow,
      phase: VideoRecorderPhase.denied,
      title: title,
    );

    expect(find.byKey(recorderTitleFieldKey), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the voice recorder keeps its input button and live levels', (
    WidgetTester tester,
  ) async {
    final StreamController<double> levels =
        StreamController<double>.broadcast();
    addTearDown(levels.close);
    await tester.pumpWidget(
      voiceHarnessWithLevels(VoiceRecorderPhase.recording, levels.stream),
    );
    await tester.pump();

    expect(find.byKey(recorderInputKey), findsOneWidget);
    expect(
      tester
          .widget<RecorderInputButton>(find.byType(RecorderInputButton))
          .takeLevels,
      levels.stream,
    );
    expect(
      tester.widget<VoiceLevelField>(find.byType(VoiceLevelField)).levels,
      levels.stream,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the video recorder keeps its input button and level ring', (
    WidgetTester tester,
  ) async {
    final StreamController<double> levels =
        StreamController<double>.broadcast();
    addTearDown(levels.close);
    await _pumpVideoSheet(
      tester,
      platform: TargetPlatform.macOS,
      window: _sidebarWindow,
      levels: levels.stream,
    );

    levels.add(0.6);
    await tester.pump();
    await tester.pump(_step);

    expect(find.byKey(recorderInputKey), findsOneWidget);
    expect(find.byKey(recorderInputRingKey), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the video recorder keeps the camera picker and on/off button', (
    WidgetTester tester,
  ) async {
    await _pumpVideoSheet(
      tester,
      platform: TargetPlatform.macOS,
      window: _sidebarWindow,
    );

    expect(find.byType(CameraPicker), findsOneWidget);
    expect(find.byKey(videoCameraKey), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the video recorder keeps the flip button on a phone', (
    WidgetTester tester,
  ) async {
    await _pumpVideoSheet(
      tester,
      platform: TargetPlatform.android,
      window: _phoneWindow,
    );

    expect(find.byKey(videoFlipCameraKey), findsOneWidget);
    expect(find.byKey(videoCameraKey), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });
}

Widget voiceHarnessWithTitle(
  VoiceRecorderPhase phase,
  TextEditingController title,
) => ProviderScope(
  overrides: <Override>[reflectionPromptsOff()],
  child: videoHarness(
    VoiceRecorderSheet(
      phase: phase,
      onStart: _noop,
      onStop: _noop,
      onCancel: _noop,
      titleController: title,
    ),
  ),
);

Widget voiceHarnessWithLevels(
  VoiceRecorderPhase phase,
  Stream<double> levels,
) => ProviderScope(
  overrides: <Override>[reflectionPromptsOff()],
  child: videoHarness(
    VoiceRecorderSheet(
      phase: phase,
      onStart: _noop,
      onStop: _noop,
      onCancel: _noop,
      levels: levels,
    ),
  ),
);
