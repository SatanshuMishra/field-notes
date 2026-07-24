import 'dart:async';

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

class _HangingStopRecorder implements VideoRecorder {
  final Completer<VideoRecording> _never = Completer<VideoRecording>();
  int stopCalls = 0;
  int releaseCalls = 0;
  bool _sessionLive = false;

  @override
  Future<List<VideoCaptureDevice>> listDevices() async =>
      List<VideoCaptureDevice>.of(fakeVideoDevices);

  @override
  Future<void> start() async {}

  @override
  Future<VideoRecording> stop() {
    stopCalls++;
    return _never.future;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> release() async {
    if (!_sessionLive) {
      return;
    }
    _sessionLive = false;
    releaseCalls++;
  }

  @override
  Future<void> dispose() async {}

  @override
  Widget? openSession(String deviceId) {
    _sessionLive = true;
    return const SizedBox(
      key: ValueKey('hang-video-preview'),
      width: 120,
      height: 120,
    );
  }
}

class _Trigger extends StatelessWidget {
  const _Trigger({required this.timeout});

  final Duration timeout;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async => showGeneralDialog<String>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Dismiss video recorder',
        pageBuilder: (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return VideoComposerConnector(
            date: '2026-07-21',
            saveTimeout: timeout,
          );
        },
      ),
      child: const Text('open'),
    );
  }
}

void main() {
  testWidgets(
      'when the recorder stop() never completes, the save is bounded: the '
      '"Saving…" state clears and a timeout error is surfaced instead of '
      'hanging', (WidgetTester tester) async {
    final _HangingStopRecorder recorder = _HangingStopRecorder();
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          videoRecorderProvider.overrideWith((Ref ref) => recorder),
          captureServiceProvider.overrideWith((Ref ref) => service),
        ],
        child: videoHarness(
          const _Trigger(timeout: Duration(milliseconds: 100)),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));

    await tester.tap(find.text('Stop & save'));
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 150));

    expect(recorder.stopCalls, 1);
    expect(service.requests, isEmpty);
    expect(find.text(videoSaveTimeoutMessage), findsOneWidget);
    expect(find.text('Saving…'), findsNothing);
    expect(find.text('Stop & save'), findsOneWidget);
    expect(find.byType(VideoRecorderSheet), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
