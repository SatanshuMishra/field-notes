import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:field_notes/features/capture/voice/record_voice_recorder.dart';
import 'package:field_notes/features/capture/voice/voice_composer.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart' show RecordConfig;

import '../audio/live_audio_test_support.dart';
import 'voice_test_support.dart';

const Key _frameKey = ValueKey<String>('voice-level-frame');
const double _silentDbfs = -160;
const double _loudDbfs = -6;
const Duration _frame = Duration(milliseconds: 16);
const int _framesAfterStart = 90;
const Duration _chunkEvery = Duration(milliseconds: 100);
const int _chunkSamples = 4800;

class _NoDiskDirectory extends Fake implements Directory {
  @override
  String get path => '/voice-level-test';

  @override
  Future<Directory> create({bool recursive = false}) async => this;
}

class _SpeakingMicrophone extends FakeMicrophone {
  _SpeakingMicrophone(this.dbfs);

  final double dbfs;
  Timer? _speaking;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    final Stream<Uint8List> chunks = await super.startStream(config);
    _speaking?.cancel();
    _speaking = Timer.periodic(
      _chunkEvery,
      (Timer _) => push(pcmAtDbfs(dbfs, samples: _chunkSamples)),
    );
    return chunks;
  }

  void fallQuiet() => _speaking?.cancel();

  @override
  Future<String?> stop() {
    fallQuiet();
    return super.stop();
  }

  @override
  Future<void> cancel() {
    fallQuiet();
    return super.cancel();
  }
}

class _RecorderTrigger extends StatelessWidget {
  const _RecorderTrigger();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showVoiceComposer(context, '2026-10-11'),
      child: const Text('open'),
    );
  }
}

Widget _app(FakeMicrophone mic) {
  return RepaintBoundary(
    key: _frameKey,
    child: ProviderScope(
      overrides: <Override>[
        voiceRecorderProvider.overrideWith(
          (Ref ref) => RecordVoiceRecorder(
            recorder: mic,
            encoder: FakeLiveAudio(writesFiles: false),
            chainRunner: passThroughChain,
            temporaryDirectory: () async => _NoDiskDirectory(),
          ),
        ),
        captureServiceProvider.overrideWith((Ref ref) => FakeCaptureService()),
        reflectionPromptsEnabledProvider.overrideWithValue(false),
      ],
      child: voiceHarness(const _RecorderTrigger()),
    ),
  );
}

bool get _desktop => defaultTargetPlatform == TargetPlatform.macOS;

void _sizeWindow(WidgetTester tester) {
  tester.view.physicalSize = _desktop
      ? const Size(1280, 800)
      : const Size(384, 832);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<double> _warmthAroundOrb(WidgetTester tester) async {
  final Rect zone = tester.getRect(find.byKey(voiceOrbZoneKey));
  final double reach = _desktop ? 60 : 44;
  final double orbRadius = (_desktop ? voiceSidebarOrb : voiceBottomBarOrb) / 2;
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_frameKey));
  final ByteData? bytes = await tester.runAsync<ByteData?>(() async {
    final ui.Image image = await boundary.toImage();
    try {
      return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    } finally {
      image.dispose();
    }
  });
  final Uint8List rgba = bytes!.buffer.asUint8List();
  final int width = boundary.size.width.round();
  final int height = boundary.size.height.round();
  final Offset centre = zone.center;
  final double outer = zone.width / 2 + reach;
  final double inner = orbRadius + 6;
  double warmth = 0;
  for (
    int y = (centre.dy - outer).floor();
    y <= (centre.dy + outer).ceil();
    y++
  ) {
    for (
      int x = (centre.dx - outer).floor();
      x <= (centre.dx + outer).ceil();
      x++
    ) {
      if (x < 0 || y < 0 || x >= width || y >= height) {
        continue;
      }
      final double distance = (Offset(x + 0.5, y + 0.5) - centre).distance;
      if (distance < inner || distance > outer) {
        continue;
      }
      warmth += rgba[(y * width + x) * 4];
    }
  }
  return warmth;
}

Future<double> _recordAndMeasure(WidgetTester tester, double dbfs) async {
  final _SpeakingMicrophone mic = _SpeakingMicrophone(dbfs);
  await tester.pumpWidget(_app(mic));
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await startVoiceTake(tester);
  for (int frame = 0; frame < _framesAfterStart; frame++) {
    await tester.pump(_frame);
  }
  expect(
    tester.widget<VoiceRecorderSheet>(find.byType(VoiceRecorderSheet)).phase,
    VoiceRecorderPhase.recording,
  );
  final double warmth = await _warmthAroundOrb(tester);
  mic.fallQuiet();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  return warmth;
}

void main() {
  testWidgets(
    'the recording orb answers to how loud the voice is',
    (WidgetTester tester) async {
      _sizeWindow(tester);

      final double silent = await _recordAndMeasure(tester, _silentDbfs);
      final double loud = await _recordAndMeasure(tester, _loudDbfs);

      expect(
        loud,
        greaterThan(silent * 1.15),
        reason:
            'the drawing around the orb must grow with the voice; '
            'silent $silent, loud $loud',
      );
    },
    variant: TargetPlatformVariant(const <TargetPlatform>{
      TargetPlatform.macOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'the breath keeps its settling glow and a pause rests the level drawing',
    (WidgetTester tester) async {
      _sizeWindow(tester);
      await tester.pumpWidget(_fakeApp(FakeVoiceRecorder()));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.byKey(voiceRecordButtonKey));
      await tester.pump();
      expect(_phase(tester), VoiceRecorderPhase.breathing);
      expect(
        tester.widget<BreathingGlow>(find.byType(BreathingGlow)).mode,
        BreathingGlowMode.settle,
      );
      expect(find.byType(VoiceLevelField), findsOneWidget);
      expect(
        tester.widget<VoiceLevelField>(find.byType(VoiceLevelField)).stage,
        VoiceLevelStage.breathing,
      );

      await _tapOrb(tester);
      expect(_phase(tester), VoiceRecorderPhase.recording);
      expect(
        tester.widget<VoiceLevelField>(find.byType(VoiceLevelField)).stage,
        VoiceLevelStage.recording,
      );

      await _tapOrb(tester);
      expect(_phase(tester), VoiceRecorderPhase.paused);
      expect(find.byType(BreathingGlow), findsNothing);
      expect(find.byType(VoiceLevelField), findsOneWidget);
      expect(
        tester.widget<VoiceLevelField>(find.byType(VoiceLevelField)).stage,
        VoiceLevelStage.paused,
      );
      expect(_orbOpacity(tester), 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
    variant: TargetPlatformVariant(const <TargetPlatform>{
      TargetPlatform.macOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'the comets layer carries on from the breath into pause',
    (WidgetTester tester) async {
      _sizeWindow(tester);
      await tester.pumpWidget(_fakeApp(FakeVoiceRecorder()));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.byKey(voiceRecordButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_phase(tester), VoiceRecorderPhase.breathing);
      final State<VoiceLevelField> breathing = tester.state(
        find.byType(VoiceLevelField),
      );
      expect(breathing, isA<VoiceLevelFieldState>());

      await _tapOrb(tester);
      expect(_phase(tester), VoiceRecorderPhase.recording);
      expect(
        tester.state<State<VoiceLevelField>>(find.byType(VoiceLevelField)),
        same(breathing),
      );

      await _tapOrb(tester);
      expect(_phase(tester), VoiceRecorderPhase.paused);
      expect(
        tester.state<State<VoiceLevelField>>(find.byType(VoiceLevelField)),
        same(breathing),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
    variant: TargetPlatformVariant(const <TargetPlatform>{
      TargetPlatform.macOS,
      TargetPlatform.android,
    }),
  );
}

Widget _fakeApp(FakeVoiceRecorder recorder) {
  return ProviderScope(
    overrides: <Override>[
      voiceRecorderProvider.overrideWith((Ref ref) => recorder),
      captureServiceProvider.overrideWith((Ref ref) => FakeCaptureService()),
      reflectionPromptsEnabledProvider.overrideWithValue(false),
    ],
    child: voiceHarness(const _RecorderTrigger()),
  );
}

VoiceRecorderPhase _phase(WidgetTester tester) =>
    tester.widget<VoiceRecorderSheet>(find.byType(VoiceRecorderSheet)).phase;

double _orbOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.descendant(
        of: find.byKey(voiceRecordButtonKey),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

Future<void> _tapOrb(WidgetTester tester) async {
  await tester.tap(find.byKey(voiceRecordButtonKey));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}
