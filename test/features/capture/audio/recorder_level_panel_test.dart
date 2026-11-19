import 'dart:async';

import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/media/audio_output.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/input_level.dart';
import 'package:field_notes/features/capture/audio/input_panel.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/video/video_composer.dart';
import 'package:field_notes/features/capture/video/video_recorder_provider.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/features/capture/voice/voice_composer.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

import '../../../app/support/app_shell_harness.dart';
import '../../settings/support/fake_settings_repository.dart';
import '../video/video_test_support.dart'
    show
        FakeCaptureService,
        FakeVideoRecorder,
        fakeVideoDevices,
        reflectionPromptsOff;
import '../voice/voice_test_support.dart' show FakeVoiceRecorder;

const String _date = '2026-10-14';
const Duration _fade = Duration(milliseconds: 600);
const Duration _step = Duration(milliseconds: 50);

const InputDevice _macBook = InputDevice(
  id: 'a',
  label: 'MacBook Pro Microphone',
);
const InputDevice _corsair = InputDevice(id: 'b', label: 'CORSAIR HS80 MAX');

class _QuietMicrophone extends Fake implements AudioRecorder {
  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async =>
      const Stream<Uint8List>.empty();

  @override
  Future<String?> stop() async => null;

  @override
  Future<void> dispose() async {}
}

class _CountingMicrophones {
  int made = 0;

  AudioRecorder call() {
    made++;
    return _QuietMicrophone();
  }
}

class _FakeOutput extends AudioOutput {
  _FakeOutput();

  @override
  Future<String?> defaultOutputName() async => 'MacBook Pro Speakers';

  @override
  Future<List<AudioOutputDevice>> listOutputs() async =>
      const <AudioOutputDevice>[
        AudioOutputDevice(id: null, name: 'System output'),
      ];

  @override
  Future<void> openSoundSettings() async {}
}

List<Override> _audioOverrides(AudioRecorderFactory microphone) => <Override>[
  audioInputListerProvider.overrideWithValue(
    () async => const <InputDevice>[_macBook, _corsair],
  ),
  inputLevelRecorderProvider.overrideWithValue(microphone),
  audioOutputProvider.overrideWithValue(_FakeOutput()),
];

void _desktopView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void _phoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(384, 832);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 24);
}

Future<void> _pumpAlone(
  WidgetTester tester,
  Widget child,
  AudioRecorderFactory microphone,
) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        reflectionPromptsOff(),
        ..._audioOverrides(microphone),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpShell(WidgetTester tester, TargetPlatform platform) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        ...shellOverrides(),
        voiceRecorderProvider.overrideWith((Ref ref) => FakeVoiceRecorder()),
        videoRecorderProvider.overrideWith((Ref ref) => FakeVideoRecorder()),
        captureServiceProvider.overrideWith((Ref ref) => FakeCaptureService()),
        reflectionPromptsOff(),
        ..._audioOverrides(_QuietMicrophone.new),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openFromShell(
  WidgetTester tester,
  Future<String?> Function(BuildContext context, String date) open,
) async {
  unawaited(open(tester.element(find.byType(AppShell)), _date));
  await tester.pump();
  await tester.pump(_fade);
  for (int index = 0; index < 14; index += 1) {
    await tester.pump(_step);
  }
}

Future<void> _openPanel(WidgetTester tester) async {
  await tester.tap(find.byKey(recorderInputKey));
  await tester.pump();
  await tester.pump();
  expect(find.byType(InputPanel), findsOneWidget);
}

int _litSegments(WidgetTester tester) {
  final Color ink = tester
      .widget<InputLevelMeter>(find.byType(InputLevelMeter))
      .ink;
  return <int>[
    for (int index = 0; index < inputLevelSegments; index++)
      if ((tester
                      .widget<DecoratedBox>(
                        find.byKey(inputLevelSegmentKey(index)),
                      )
                      .decoration
                  as BoxDecoration)
              .color ==
          ink)
        index,
  ].length;
}

void _expectRowsUsable(WidgetTester tester) {
  for (final Key row in const <Key>[
    inputDeviceRowKey,
    inputProfileRowKey,
    inputVolumeRowKey,
  ]) {
    expect(find.byKey(row).hitTestable(), findsOneWidget, reason: '$row');
  }
}

RecorderInputButton _inputButton(WidgetTester tester) =>
    tester.widget<RecorderInputButton>(find.byType(RecorderInputButton));

VideoRecorderSheet _videoSheet({
  required Stream<double> levels,
  required bool cameraOn,
}) => VideoRecorderSheet(
  phase: VideoRecorderPhase.idle,
  levels: levels,
  cameraOn: cameraOn,
  onStart: () {},
  onStop: () {},
  onLeave: () {},
  onPause: () {},
  onResume: () {},
  supportsPause: true,
  devices: fakeVideoDevices,
  selectedDeviceId: fakeVideoDevices.first.id,
  onDeviceChanged: (String id) {},
  onCameraChanged: (bool on) {},
);

void main() {
  testWidgets(
    'the microphone panel is lit on its first frame from the recorder level',
    (WidgetTester tester) async {
      _desktopView(tester);
      final StreamController<double> levels =
          StreamController<double>.broadcast();
      addTearDown(levels.close);
      final _CountingMicrophones microphones = _CountingMicrophones();
      await _pumpAlone(
        tester,
        Center(child: RecorderInputButton(levels: levels.stream)),
        microphones.call,
      );

      levels.add(0.5);
      await tester.pump();
      await tester.tap(find.byKey(recorderInputKey));
      await tester.pump();

      expect(find.byType(InputPanel), findsOneWidget);
      expect(_litSegments(tester), 10);
      expect(find.byKey(inputDeviceRowKey).hitTestable(), findsOneWidget);
      expect(microphones.made, 0);

      levels.add(0.25);
      await tester.pump();
      expect(_litSegments(tester), 5);
      expect(microphones.made, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'the voice recorder feeds the microphone panel its level while ready',
    (WidgetTester tester) async {
      _desktopView(tester);
      final StreamController<double> levels =
          StreamController<double>.broadcast();
      addTearDown(levels.close);
      final _CountingMicrophones microphones = _CountingMicrophones();
      await _pumpAlone(
        tester,
        VoiceRecorderSheet(
          phase: VoiceRecorderPhase.idle,
          levels: levels.stream,
          onStart: () {},
          onStop: () {},
          onCancel: () {},
          onPause: () {},
          onResume: () {},
        ),
        microphones.call,
      );

      expect(_inputButton(tester).levels, levels.stream);
      expect(_inputButton(tester).takeLevels, isNull);

      await _openPanel(tester);

      expect(microphones.made, 0);
      _expectRowsUsable(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'the video recorder feeds the microphone panel its level before a take with the camera on',
    (WidgetTester tester) async {
      _desktopView(tester);
      final StreamController<double> levels =
          StreamController<double>.broadcast();
      addTearDown(levels.close);
      final _CountingMicrophones microphones = _CountingMicrophones();
      await _pumpAlone(
        tester,
        _videoSheet(levels: levels.stream, cameraOn: true),
        microphones.call,
      );

      expect(_inputButton(tester).levels, levels.stream);
      expect(_inputButton(tester).takeLevels, isNull);

      await _openPanel(tester);

      expect(microphones.made, 0);
      _expectRowsUsable(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'the video recorder panel opens its own microphone before a camera-off take',
    (WidgetTester tester) async {
      _desktopView(tester);
      final StreamController<double> levels =
          StreamController<double>.broadcast();
      addTearDown(levels.close);
      final _CountingMicrophones microphones = _CountingMicrophones();
      await _pumpAlone(
        tester,
        _videoSheet(levels: levels.stream, cameraOn: false),
        microphones.call,
      );

      expect(_inputButton(tester).levels, isNull);
      expect(_inputButton(tester).takeLevels, isNull);

      await _openPanel(tester);

      expect(microphones.made, 1);
      _expectRowsUsable(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('neither recorder offers a Voice settings row', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.reset);
    _desktopView(tester);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await _pumpShell(tester, TargetPlatform.macOS);
    await _openFromShell(tester, showVoiceComposer);
    expect(find.byType(VoiceComposerConnector), findsOneWidget);
    await _openPanel(tester);
    expect(find.text('Voice settings'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    _phoneView(tester);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await _pumpShell(tester, TargetPlatform.android);
    await _openFromShell(tester, showVideoComposer);
    expect(find.byType(VideoComposerConnector), findsOneWidget);
    await _openPanel(tester);
    expect(find.text('Voice settings'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });
}
