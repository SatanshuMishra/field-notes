import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/voice/voice_composer.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'voice_test_support.dart';

class _SlowCountingCaptureService implements CaptureService {
  _SlowCountingCaptureService({required this.delay});

  final Duration delay;
  int captureCalls = 0;

  @override
  Future<CaptureResult> capture(CaptureRequest request) async {
    captureCalls++;
    await Future<void>.delayed(delay);
    final Day day = Day(
      id: 'day-1',
      date: request.date,
      createdAt: 0,
      updatedAt: 0,
    );
    final Entry entry = Entry(
      id: 'entry-1',
      dayId: day.id,
      type: request.type,
      createdAt: 0,
      updatedAt: 0,
    );
    return CaptureResult(day: day, entry: entry, photos: const <EntryPhoto>[]);
  }
}

class _Trigger extends StatelessWidget {
  const _Trigger({required this.timeout, required this.onResult});

  final Duration timeout;
  final ValueChanged<String?> onResult;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async => onResult(
        await showGeneralDialog<String>(
          context: context,
          barrierDismissible: false,
          barrierLabel: 'Dismiss voice recorder',
          pageBuilder: (
            BuildContext dialogContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return VoiceComposerConnector(
              date: '2026-07-20',
              saveTimeout: timeout,
            );
          },
        ),
      ),
      child: const Text('open'),
    );
  }
}

void main() {
  testWidgets(
      'a save that completes within the timeout invokes capture() exactly once '
      'and pops with the real entry id', (WidgetTester tester) async {
    final FakeVoiceRecorder recorder = FakeVoiceRecorder();
    final _SlowCountingCaptureService service = _SlowCountingCaptureService(
      delay: const Duration(milliseconds: 200),
    );
    String? result = 'unset';

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          voiceRecorderProvider.overrideWith((Ref ref) => recorder),
          captureServiceProvider.overrideWith((Ref ref) => service),
        ],
        child: voiceHarness(
          _Trigger(
            timeout: const Duration(milliseconds: 500),
            onResult: (String? id) => result = id,
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Stop & save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));

    expect(service.captureCalls, 1);
    expect(result, 'entry-1');
    expect(find.byType(VoiceRecorderSheet), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
