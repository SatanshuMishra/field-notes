import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/video/video_composer.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder_provider.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/features/capture/video/video_timeline.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

class _RecorderTrigger extends StatelessWidget {
  const _RecorderTrigger({required this.date, required this.onResult});

  final String date;
  final ValueChanged<String?> onResult;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async => onResult(await showVideoComposer(context, date)),
      child: const Text('open'),
    );
  }
}

Widget _recorderApp({
  required VideoRecorder recorder,
  required CaptureService service,
  required ValueChanged<String?> onResult,
}) {
  return ProviderScope(
    overrides: <Override>[
      videoRecorderProvider.overrideWith((Ref ref) => recorder),
      captureServiceProvider.overrideWith((Ref ref) => service),
    ],
    child: videoHarness(
      _RecorderTrigger(date: '2026-07-21', onResult: onResult),
    ),
  );
}

Future<void> _openComposer(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _startRecording(WidgetTester tester) async {
  await tester.tap(find.text('Record'));
  for (int i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets(
      'records, surfaces 5/10/20-min nudges, auto-stops at 30 min, and saves '
      'a video entry with its thumbnail', (WidgetTester tester) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder();
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
    await _startRecording(tester);

    expect(recorder.startCalls, 1);
    expect(fakeVideoPreview(), findsOneWidget);

    await tester.pump(const Duration(minutes: 5));
    await tester.pump();
    expect(find.text(videoNudge5Message), findsOneWidget);

    await tester.pump(const Duration(minutes: 5));
    await tester.pump();
    expect(find.text(videoNudge10Message), findsOneWidget);

    await tester.pump(const Duration(minutes: 10));
    await tester.pump();
    expect(find.text(videoNudge20Message), findsOneWidget);

    expect(service.requests, isEmpty);

    await tester.pump(const Duration(minutes: 10));
    await tester.pumpAndSettle();

    expect(recorder.stopCalls, 1);
    expect(service.requests, hasLength(1));
    final VideoCaptureRequest request =
        service.requests.single as VideoCaptureRequest;
    expect(request.date, '2026-07-21');
    expect(request.durationMs, 6000);
    expect(request.type, EntryType.video);
    expect(request.thumbnail, isNotNull);
    expect(result, 'entry-1');
    expect(find.byType(VideoRecorderSheet), findsNothing);
  });

  testWidgets('a manual stop saves the video entry and closes with its id',
      (WidgetTester tester) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder();
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
    await _startRecording(tester);

    await tester.tap(find.text('Stop & save'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(recorder.stopCalls, 1);
    expect(service.requests, hasLength(1));
    final VideoCaptureRequest request =
        service.requests.single as VideoCaptureRequest;
    expect(request.type, EntryType.video);
    expect(request.durationMs, 6000);
    expect(request.thumbnail, isNotNull);
    expect(result, 'entry-1');
    expect(find.byType(VideoRecorderSheet), findsNothing);
  });

  testWidgets(
      'a granted camera shows the live capture UI and never surfaces a denied '
      'state', (WidgetTester tester) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder();
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(
      _recorderApp(
        recorder: recorder,
        service: service,
        onResult: (String? id) {},
      ),
    );

    await _openComposer(tester);
    await _startRecording(tester);

    expect(recorder.startCalls, 1);
    expect(fakeVideoPreview(), findsOneWidget);
    expect(find.text('Stop & save'), findsOneWidget);
    expect(find.text(cameraPermissionMessage), findsNothing);
    expect(find.text('Try again'), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets(
      'a denied camera shows the denied-state UI with guidance and a retry, and '
      'records nothing', (WidgetTester tester) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder(permission: false);
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

    expect(find.text(cameraPermissionMessage), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Record'), findsNothing);
    expect(recorder.startCalls, 0);
    expect(service.requests, isEmpty);
    expect(fakeVideoPreview(), findsNothing);
    expect(result, 'unset');

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Try again'), findsOneWidget);
    expect(recorder.startCalls, 0);
  });

  testWidgets(
      'a camera that never becomes ready surfaces the timeout guidance and '
      'returns to idle so the user can retry', (WidgetTester tester) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder(
      startError: const VideoRecorderException(videoStartTimeoutMessage),
    );
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(
      _recorderApp(
        recorder: recorder,
        service: service,
        onResult: (String? id) {},
      ),
    );

    await _openComposer(tester);
    await _startRecording(tester);

    expect(recorder.startCalls, 1);
    expect(find.text(videoStartTimeoutMessage), findsOneWidget);
    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Stop & save'), findsNothing);
    expect(fakeVideoPreview(deviceId: 'built-in-id'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('a failed save surfaces the reason and stays open to retry',
      (WidgetTester tester) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder();
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
    await _startRecording(tester);

    await tester.tap(find.text('Stop & save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Could not save your entry.'), findsOneWidget);
    expect(service.requests, hasLength(1));
    expect(find.byType(VideoRecorderSheet), findsOneWidget);
    expect(result, 'unset');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cancelling while recording discards and closes',
      (WidgetTester tester) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder();
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
    await _startRecording(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(recorder.cancelCalls, 1);
    expect(service.requests, isEmpty);
    expect(result, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
