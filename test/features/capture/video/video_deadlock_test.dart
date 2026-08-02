import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/video/video_composer.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder_provider.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

class _RecorderTrigger extends StatelessWidget {
  const _RecorderTrigger({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showVideoComposer(context, date),
      child: const Text('open'),
    );
  }
}

Widget _recorderApp({
  required VideoRecorder recorder,
  required CaptureService service,
}) {
  return ProviderScope(
    overrides: <Override>[
      videoRecorderProvider.overrideWith((Ref ref) => recorder),
      captureServiceProvider.overrideWith((Ref ref) => service),
    ],
    child: videoHarness(const _RecorderTrigger(date: '2026-07-21')),
  );
}

Future<void> _openComposer(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _settleStart(WidgetTester tester) async {
  await tester.tap(find.byKey(videoShutterKey));
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets(
      'start() proceeds once the preview mounts and completes readiness '
      '(no deadlock)', (WidgetTester tester) async {
    final DeferredReadyVideoRecorder recorder = DeferredReadyVideoRecorder();
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(
      _recorderApp(recorder: recorder, service: service),
    );

    await _openComposer(tester);
    await _settleStart(tester);

    expect(recorder.startCalls, 1);
    expect(recorder.started, isTrue);
    expect(
      find.byKey(const ValueKey('deferred-preview')),
      findsOneWidget,
    );
    expect(find.text('recording… tap pause or stop'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
