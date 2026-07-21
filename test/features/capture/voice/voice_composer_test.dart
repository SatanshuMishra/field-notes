import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/voice/voice_composer.dart';
import 'package:field_notes/features/capture/voice/voice_recorder.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'voice_test_support.dart';

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
    ],
    child: voiceHarness(
      _RecorderTrigger(date: '2026-07-20', onResult: onResult),
    ),
  );
}

Future<void> _openComposer(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  testWidgets('records then saves a voice entry and closes with its id',
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

    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(recorder.startCalls, 1);
    expect(find.byType(WaveformBars), findsOneWidget);

    await tester.tap(find.text('Stop & save'));
    await tester.pump();
    await tester.pumpAndSettle();

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

  testWidgets('a denied microphone shows the permission message and records nothing',
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

    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(micPermissionMessage), findsOneWidget);
    expect(recorder.startCalls, 0);
    expect(service.requests, isEmpty);
    expect(find.byType(WaveformBars), findsNothing);
    expect(result, 'unset');
  });

  testWidgets('a failed save surfaces the reason and stays open to retry',
      (WidgetTester tester) async {
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

    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Stop & save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Could not save your entry.'), findsOneWidget);
    expect(service.requests, hasLength(1));
    expect(find.byType(VoiceRecorderSheet), findsOneWidget);
    expect(result, 'unset');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cancelling while recording discards and closes',
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

    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(recorder.cancelCalls, 1);
    expect(service.requests, isEmpty);
    expect(result, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
