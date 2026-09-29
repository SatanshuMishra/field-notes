import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:field_notes/features/capture/voice/voice_composer.dart';
import 'package:field_notes/features/capture/voice/voice_recorder.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'voice_test_support.dart';

class _TickingRecorder extends FakeVoiceRecorder {
  _TickingRecorder();

  bool _running = false;
  Duration _accumulated = Duration.zero;

  void advance(Duration by) {
    if (_running) {
      _accumulated += by;
    }
  }

  @override
  Duration get elapsed => _accumulated;

  @override
  Future<void> start() async {
    await super.start();
    _running = true;
  }

  @override
  Future<void> pause() async {
    await super.pause();
    _running = false;
  }

  @override
  Future<void> resume() async {
    await super.resume();
    _running = true;
  }
}

class _Trigger extends StatelessWidget {
  const _Trigger();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async => showVoiceComposer(context, '2026-08-02'),
      child: const Text('open'),
    );
  }
}

Widget _app({
  required VoiceRecorder recorder,
  required FakeCaptureService service,
}) {
  return ProviderScope(
    overrides: <Override>[
      voiceRecorderProvider.overrideWith((Ref ref) => recorder),
      captureServiceProvider.overrideWith((Ref ref) => service),
      reflectionPromptsEnabledProvider.overrideWithValue(false),
    ],
    child: voiceHarness(const _Trigger()),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

VoiceRecorderSheet _sheet(WidgetTester tester) =>
    tester.widget<VoiceRecorderSheet>(find.byType(VoiceRecorderSheet));

void main() {
  testWidgets(
    'the orb walks idle through the breath to recording, paused and recording '
    'again, freezing the timer while paused, and Keep this saves the take',
    (WidgetTester tester) async {
      final _TickingRecorder recorder = _TickingRecorder();
      final FakeCaptureService service = FakeCaptureService();

      await tester.pumpWidget(_app(recorder: recorder, service: service));
      await _open(tester);

      expect(_sheet(tester).phase, VoiceRecorderPhase.idle);
      expect(find.byKey(voiceSavePillKey), findsNothing);

      await tester.tap(find.byKey(voiceRecordButtonKey));
      await tester.pump();
      expect(_sheet(tester).phase, VoiceRecorderPhase.breathing);
      expect(recorder.startCalls, 0);
      expect(find.byKey(voiceSavePillKey), findsNothing);

      await tester.pump(stageBreathDuration);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_sheet(tester).phase, VoiceRecorderPhase.recording);
      expect(recorder.startCalls, 1);
      expect(find.byKey(voiceSavePillKey), findsOneWidget);
      expect(find.byKey(voiceDiscardPillKey), findsOneWidget);

      recorder.advance(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 250));
      expect(_sheet(tester).elapsed, const Duration(milliseconds: 500));

      await tester.tap(find.byKey(voiceRecordButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_sheet(tester).phase, VoiceRecorderPhase.paused);
      expect(recorder.pauseCalls, 1);
      expect(find.text(stagePausedStatus), findsOneWidget);
      expect(find.byKey(voiceSavePillKey), findsOneWidget);

      recorder.advance(const Duration(milliseconds: 750));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_sheet(tester).elapsed, const Duration(milliseconds: 500));

      await tester.tap(find.byKey(voiceRecordButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_sheet(tester).phase, VoiceRecorderPhase.recording);
      expect(recorder.resumeCalls, 1);

      recorder.advance(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 250));
      expect(_sheet(tester).elapsed, const Duration(milliseconds: 800));

      await tester.tap(find.byKey(voiceRecordButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_sheet(tester).phase, VoiceRecorderPhase.paused);

      await tester.tap(find.byKey(voiceSavePillKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 700));

      expect(recorder.stopCalls, 1);
      expect(service.requests, hasLength(1));
      expect(find.byType(VoiceRecorderSheet), findsNothing);
      expect(find.text(voiceSavedToastMessage), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'letting an active take go asks first, keeps the take paused when Keep '
    'going is chosen, and is not offered at all while idle',
    (WidgetTester tester) async {
      final FakeVoiceRecorder recorder = FakeVoiceRecorder();
      final FakeCaptureService service = FakeCaptureService();

      await tester.pumpWidget(_app(recorder: recorder, service: service));
      await _open(tester);

      expect(find.byKey(voiceDiscardPillKey), findsNothing);
      await tester.tap(find.byKey(voiceCloseKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text(letGoTitle), findsNothing);
      expect(find.byType(VoiceRecorderSheet), findsNothing);
      expect(recorder.cancelCalls, 0);

      await _open(tester);
      await startVoiceTake(tester);

      await tester.tap(find.byKey(voiceDiscardPillKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(letGoTitle), findsOneWidget);

      await tester.tap(find.text(letGoKeepGoingLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(VoiceRecorderSheet), findsOneWidget);
      expect(_sheet(tester).phase, VoiceRecorderPhase.paused);
      expect(recorder.cancelCalls, 0);

      await tester.tap(find.byKey(voiceDiscardPillKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(letGoTitle), findsOneWidget);
      expect(recorder.pauseCalls, 1);

      await tester.tap(find.byKey(voiceDiscardConfirmKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 700));

      expect(recorder.cancelCalls, 1);
      expect(service.requests, isEmpty);
      expect(find.byType(VoiceRecorderSheet), findsNothing);
      expect(find.text(voiceLetGoToastMessage), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
