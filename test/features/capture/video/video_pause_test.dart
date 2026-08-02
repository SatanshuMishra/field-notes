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

class _PausableRecorder extends FakeVideoRecorder {
  _PausableRecorder() : super(supportsPause: true);

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

  @override
  Future<VideoRecording> stop() async {
    _running = false;
    return super.stop();
  }
}

class _Trigger extends StatelessWidget {
  const _Trigger();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async => showVideoComposer(context, '2026-08-02'),
      child: const Text('open'),
    );
  }
}

Widget _app({
  required VideoRecorder recorder,
  required FakeCaptureService service,
}) {
  return ProviderScope(
    overrides: <Override>[
      videoRecorderProvider.overrideWith((Ref ref) => recorder),
      captureServiceProvider.overrideWith((Ref ref) => service),
    ],
    child: videoHarness(const _Trigger()),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _tapShutter(WidgetTester tester) async {
  await tester.tap(find.byKey(videoShutterKey));
  for (int i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

VideoRecorderSheet _sheet(WidgetTester tester) =>
    tester.widget<VideoRecorderSheet>(find.byType(VideoRecorderSheet));

Future<void> _record(
  WidgetTester tester,
  _PausableRecorder recorder,
  Duration by,
) async {
  recorder.advance(by);
  await tester.pump(by);
  await tester.pump();
}

void main() {
  testWidgets(
      'the shutter walks idle to recording to paused to recording on a '
      'recorder that supports pause', (WidgetTester tester) async {
    final _PausableRecorder recorder = _PausableRecorder();
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(_app(recorder: recorder, service: service));
    await _open(tester);

    expect(_sheet(tester).phase, VideoRecorderPhase.idle);
    expect(find.byKey(videoDiscardCircleKey), findsNothing);
    expect(find.byKey(videoSaveCircleKey), findsNothing);

    await _tapShutter(tester);
    expect(_sheet(tester).phase, VideoRecorderPhase.recording);
    expect(find.byKey(videoDiscardCircleKey), findsOneWidget);
    expect(find.byKey(videoSaveCircleKey), findsOneWidget);

    await _tapShutter(tester);
    expect(_sheet(tester).phase, VideoRecorderPhase.paused);
    expect(recorder.pauseCalls, 1);
    expect(find.text('paused · resume or save your clip'), findsOneWidget);
    expect(find.byKey(videoDiscardCircleKey), findsOneWidget);
    expect(find.byKey(videoSaveCircleKey), findsOneWidget);

    await _tapShutter(tester);
    expect(_sheet(tester).phase, VideoRecorderPhase.recording);
    expect(recorder.resumeCalls, 1);
    expect(recorder.stopCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the timer freezes while paused and resumes from where it stopped',
      (WidgetTester tester) async {
    final _PausableRecorder recorder = _PausableRecorder();
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(_app(recorder: recorder, service: service));
    await _open(tester);
    await _tapShutter(tester);

    await _record(tester, recorder, const Duration(seconds: 8));
    expect(_sheet(tester).elapsed, const Duration(seconds: 8));

    await _tapShutter(tester);
    expect(_sheet(tester).phase, VideoRecorderPhase.paused);

    await _record(tester, recorder, const Duration(seconds: 30));
    expect(_sheet(tester).elapsed, const Duration(seconds: 8));

    await _tapShutter(tester);
    await _record(tester, recorder, const Duration(seconds: 5));
    expect(_sheet(tester).elapsed, const Duration(seconds: 13));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('saving from paused persists the take and closes the composer',
      (WidgetTester tester) async {
    final _PausableRecorder recorder = _PausableRecorder();
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(_app(recorder: recorder, service: service));
    await _open(tester);
    await _tapShutter(tester);
    await _record(tester, recorder, const Duration(seconds: 6));

    await _tapShutter(tester);
    expect(_sheet(tester).phase, VideoRecorderPhase.paused);

    await tester.tap(find.byKey(videoSaveCircleKey));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(recorder.stopCalls, 1);
    expect(service.requests, hasLength(1));
    expect(find.byType(VideoRecorderSheet), findsNothing);
  });

  testWidgets('discarding from paused confirms first, then cancels the take',
      (WidgetTester tester) async {
    final _PausableRecorder recorder = _PausableRecorder();
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(_app(recorder: recorder, service: service));
    await _open(tester);
    await _tapShutter(tester);
    await _tapShutter(tester);
    expect(_sheet(tester).phase, VideoRecorderPhase.paused);

    await tester.tap(find.byKey(videoDiscardCircleKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(videoDiscardConfirmTitle), findsOneWidget);
    expect(recorder.cancelCalls, 0);

    await tester.tap(find.text(videoDiscardConfirmCancelLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_sheet(tester).phase, VideoRecorderPhase.paused);
    expect(recorder.cancelCalls, 0);

    await tester.tap(find.byKey(videoDiscardCircleKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(videoDiscardConfirmKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 300));

    expect(recorder.cancelCalls, 1);
    expect(service.requests, isEmpty);
    expect(find.byType(VideoRecorderSheet), findsNothing);
    expect(find.text(videoDiscardedToastMessage), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'a nudge whose wall-clock moment passes while paused still fires after '
      'resume, and the 30 minute cap is never swallowed',
      (WidgetTester tester) async {
    final _PausableRecorder recorder = _PausableRecorder();
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(_app(recorder: recorder, service: service));
    await _open(tester);
    await _tapShutter(tester);

    await _record(tester, recorder, const Duration(minutes: 4, seconds: 50));
    expect(find.text(videoNudge5Message), findsNothing);

    await _tapShutter(tester);
    expect(_sheet(tester).phase, VideoRecorderPhase.paused);

    await _record(tester, recorder, const Duration(minutes: 10));
    expect(find.text(videoNudge5Message), findsNothing);

    await _tapShutter(tester);
    expect(_sheet(tester).phase, VideoRecorderPhase.recording);

    await _record(tester, recorder, const Duration(seconds: 15));
    expect(find.text(videoNudge5Message), findsOneWidget);

    await _record(tester, recorder, const Duration(minutes: 5));
    expect(find.text(videoNudge10Message), findsOneWidget);

    await _record(tester, recorder, const Duration(minutes: 10));
    expect(find.text(videoNudge20Message), findsOneWidget);

    expect(service.requests, isEmpty);

    recorder.advance(const Duration(minutes: 10));
    await tester.pump(const Duration(minutes: 10));
    await tester.pumpAndSettle();

    expect(recorder.stopCalls, 1);
    expect(service.requests, hasLength(1));
    expect(find.byType(VideoRecorderSheet), findsNothing);
  });
}
