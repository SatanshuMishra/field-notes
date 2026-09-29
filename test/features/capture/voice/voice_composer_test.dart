import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:field_notes/features/capture/voice/voice_composer.dart';
import 'package:field_notes/features/capture/voice/voice_recorder.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'voice_test_support.dart';

const Duration _closed = Duration(milliseconds: 700);

class _RecorderTrigger extends StatelessWidget {
  const _RecorderTrigger({required this.date, required this.onResult});

  final String date;
  final ValueChanged<String?> onResult;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async => onResult(await showVoiceComposer(context, date)),
      child: const Text('open'),
    );
  }
}

Widget _recorderApp({
  required VoiceRecorder recorder,
  required CaptureService service,
  required ValueChanged<String?> onResult,
}) {
  return ProviderScope(
    overrides: <Override>[
      voiceRecorderProvider.overrideWith((Ref ref) => recorder),
      captureServiceProvider.overrideWith((Ref ref) => service),
      reflectionPromptsEnabledProvider.overrideWithValue(false),
    ],
    child: voiceHarness(
      _RecorderTrigger(date: '2026-07-20', onResult: onResult),
    ),
  );
}

Future<void> _openComposer(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _sendSystemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

VoiceRecorderPhase _phase(WidgetTester tester) =>
    tester.widget<VoiceRecorderSheet>(find.byType(VoiceRecorderSheet)).phase;

void main() {
  testWidgets('records then saves a voice entry and closes with its id', (
    WidgetTester tester,
  ) async {
    final FakeVoiceRecorder recorder = FakeVoiceRecorder();
    final FakeCaptureService service = FakeCaptureService();
    String? result = 'unset';

    await tester.pumpWidget(
      _recorderApp(
        recorder: recorder,
        service: service,
        onResult: (String? id) => result = id,
      ),
    );

    await _openComposer(tester);

    await startVoiceTake(tester);

    expect(recorder.startCalls, 1);
    expect(_phase(tester), VoiceRecorderPhase.recording);
    expect(find.byKey(recorderTimerKey), findsOneWidget);

    await tester.tap(find.byKey(voiceSavePillKey));
    await tester.pump();
    await tester.pump(_closed);

    expect(recorder.stopCalls, 1);
    expect(service.requests, hasLength(1));
    final VoiceCaptureRequest request =
        service.requests.single as VoiceCaptureRequest;
    expect(request.date, '2026-07-20');
    expect(request.durationMs, 4200);
    expect(request.type, EntryType.voice);
    expect(result, 'entry-1');
    expect(find.byType(VoiceRecorderSheet), findsNothing);
  });

  testWidgets(
    'a denied microphone shows the permission message and records nothing',
    (WidgetTester tester) async {
      final FakeVoiceRecorder recorder = FakeVoiceRecorder(permission: false);
      final FakeCaptureService service = FakeCaptureService();
      String? result = 'unset';

      await tester.pumpWidget(
        _recorderApp(
          recorder: recorder,
          service: service,
          onResult: (String? id) => result = id,
        ),
      );

      await _openComposer(tester);

      await tester.tap(find.byKey(voiceRecordButtonKey));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));

      expect(find.text(micPermissionMessage), findsOneWidget);
      expect(recorder.startCalls, 0);
      expect(service.requests, isEmpty);
      expect(_phase(tester), VoiceRecorderPhase.idle);
      expect(result, 'unset');
    },
  );

  testWidgets('a failed save surfaces the reason and stays open to retry', (
    WidgetTester tester,
  ) async {
    final FakeVoiceRecorder recorder = FakeVoiceRecorder();
    final FakeCaptureService service = FakeCaptureService(
      failure: const CaptureException('Could not save your entry.'),
    );
    String? result = 'unset';

    await tester.pumpWidget(
      _recorderApp(
        recorder: recorder,
        service: service,
        onResult: (String? id) => result = id,
      ),
    );

    await _openComposer(tester);

    await startVoiceTake(tester);

    await tester.tap(find.byKey(voiceSavePillKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Could not save your entry.'), findsOneWidget);
    expect(service.requests, hasLength(1));
    expect(find.byType(VoiceRecorderSheet), findsOneWidget);
    expect(_phase(tester), VoiceRecorderPhase.recording);
    expect(result, 'unset');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'leaving while recording asks first, and letting go discards and closes',
    (WidgetTester tester) async {
      final FakeVoiceRecorder recorder = FakeVoiceRecorder();
      final FakeCaptureService service = FakeCaptureService();
      String? result = 'unset';

      await tester.pumpWidget(
        _recorderApp(
          recorder: recorder,
          service: service,
          onResult: (String? id) => result = id,
        ),
      );

      await _openComposer(tester);

      await startVoiceTake(tester);

      await tester.tap(find.byKey(voiceCloseKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text(letGoTitle), findsOneWidget);
      expect(recorder.pauseCalls, 1);
      expect(recorder.cancelCalls, 0);

      await tester.tap(find.byKey(voiceDiscardConfirmKey));
      await tester.pump();
      await tester.pump(_closed);

      expect(recorder.cancelCalls, 1);
      expect(service.requests, isEmpty);
      expect(result, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('a confirmed save releases the capture file', (
    WidgetTester tester,
  ) async {
    Future<FakeVoiceRecorder> recordAndSave(CaptureService service) async {
      final FakeVoiceRecorder recorder = FakeVoiceRecorder();
      await tester.pumpWidget(
        _recorderApp(
          recorder: recorder,
          service: service,
          onResult: (String? id) {},
        ),
      );
      await _openComposer(tester);
      await startVoiceTake(tester);
      await tester.tap(find.byKey(voiceSavePillKey));
      await tester.pump();
      await tester.pump(_closed);
      await tester.pumpWidget(const SizedBox.shrink());
      return recorder;
    }

    final FakeVoiceRecorder saved = await recordAndSave(FakeCaptureService());
    final FakeVoiceRecorder failed = await recordAndSave(
      FakeCaptureService(
        failure: const CaptureException('Could not save your entry.'),
      ),
    );

    expect(saved.stopCalls, 1);
    expect(saved.releaseSavedCalls, 1);
    expect(failed.stopCalls, 1);
    expect(failed.releaseSavedCalls, 0);
  });

  testWidgets('Escape closes an idle voice recorder', (
    WidgetTester tester,
  ) async {
    String? result = 'unset';

    await tester.pumpWidget(
      _recorderApp(
        recorder: FakeVoiceRecorder(),
        service: FakeCaptureService(),
        onResult: (String? id) => result = id,
      ),
    );

    await _openComposer(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(_closed);

    expect(find.byType(VoiceRecorderSheet), findsNothing);
    expect(result, isNull);
  });

  testWidgets(
    'Escape while recording asks to let go first, and Escape again keeps going',
    (WidgetTester tester) async {
      final FakeVoiceRecorder recorder = FakeVoiceRecorder();
      String? result = 'unset';

      await tester.pumpWidget(
        _recorderApp(
          recorder: recorder,
          service: FakeCaptureService(),
          onResult: (String? id) => result = id,
        ),
      );

      await _openComposer(tester);

      await startVoiceTake(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(letGoTitle), findsOneWidget);
      expect(recorder.cancelCalls, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(letGoTitle), findsNothing);
      expect(find.byType(VoiceRecorderSheet), findsOneWidget);
      expect(_phase(tester), VoiceRecorderPhase.paused);
      expect(recorder.cancelCalls, 0);
      expect(result, 'unset');

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Android back while recording asks to let go first',
    (WidgetTester tester) async {
      final FakeVoiceRecorder recorder = FakeVoiceRecorder();
      String? result = 'unset';

      await tester.pumpWidget(
        _recorderApp(
          recorder: recorder,
          service: FakeCaptureService(),
          onResult: (String? id) => result = id,
        ),
      );

      await _openComposer(tester);

      await startVoiceTake(tester);

      await _sendSystemBack(tester);

      expect(find.text(letGoTitle), findsOneWidget);
      expect(find.byType(VoiceRecorderSheet), findsOneWidget);
      expect(recorder.cancelCalls, 0);
      expect(result, 'unset');

      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
