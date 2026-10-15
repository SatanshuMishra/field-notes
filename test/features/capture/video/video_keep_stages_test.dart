import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/video/video_composer.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder_provider.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

const Size _sidebarWindow = Size(1280, 800);
const String _date = '2026-10-14';
const String _openLabel = 'open';
const Duration _fade = Duration(milliseconds: 600);
const Duration _step = Duration(milliseconds: 50);

Future<void> _pumpApp(
  WidgetTester tester, {
  required VideoRecorder recorder,
  required FakeCaptureService service,
}) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  tester.view.physicalSize = _sidebarWindow;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        videoRecorderProvider.overrideWith((Ref ref) => recorder),
        captureServiceProvider.overrideWith((Ref ref) => service),
        reflectionPromptsOff(),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.windows),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: TextButton(
                onPressed: () => showVideoComposer(context, _date),
                child: const Text(_openLabel),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 14; i++) {
    await tester.pump(_step);
  }
}

Future<void> _openAndRecord(WidgetTester tester) async {
  await tester.tap(find.text(_openLabel));
  await tester.pump();
  await tester.pump(_fade);
  await _settle(tester);
  await tester.tap(find.byKey(videoShutterKey));
  await tester.pump();
  await tester.tap(find.byKey(videoShutterKey));
  await tester.pump();
  await _settle(tester);
  expect(_phase(tester), VideoRecorderPhase.recording);
}

Future<void> _keep(WidgetTester tester) async {
  await tester.tap(find.byKey(videoSaveCircleKey));
  await tester.pump();
}

Future<void> _closeAll(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

VideoRecorderPhase _phase(WidgetTester tester) =>
    tester.widget<VideoRecorderSheet>(find.byType(VideoRecorderSheet)).phase;

void main() {
  testWidgets('kept parts return the take to paused', (
    WidgetTester tester,
  ) async {
    for (final String message in <String>[
      videoJoinMessage,
      videoLastPartMessage,
    ]) {
      final FakeVideoRecorder recorder = FakeVideoRecorder(
        supportsPause: true,
        stopError: VideoSegmentsKeptException(message),
      );
      final FakeCaptureService service = FakeCaptureService();
      await _pumpApp(tester, recorder: recorder, service: service);
      await _openAndRecord(tester);

      await _keep(tester);
      await _settle(tester);

      expect(recorder.stopCalls, 1);
      expect(_phase(tester), VideoRecorderPhase.paused);
      expect(find.text(message), findsOneWidget);
      expect(find.textContaining('Nothing was saved'), findsNothing);
      expect(service.requests, isEmpty);

      await _closeAll(tester);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a slow stop within the stop timeout still saves', (
    WidgetTester tester,
  ) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder(supportsPause: true)
      ..elapsedValue = const Duration(seconds: 60)
      ..stopDelay = const Duration(seconds: 50);
    final FakeCaptureService service = FakeCaptureService();
    await _pumpApp(tester, recorder: recorder, service: service);
    await _openAndRecord(tester);

    await _keep(tester);
    await tester.pump(const Duration(seconds: 21));
    expect(find.text(videoSaveTimeoutMessage), findsNothing);
    expect(service.requests, isEmpty);
    await tester.pump(const Duration(seconds: 28));
    expect(find.text(videoSaveTimeoutMessage), findsNothing);
    expect(service.requests, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await _settle(tester);
    expect(find.text(videoSaveTimeoutMessage), findsNothing);
    expect(service.requests, hasLength(1));
    expect(service.requests.single, isA<VideoCaptureRequest>());
    await tester.pump(_fade);
    await _settle(tester);
    expect(find.byType(VideoRecorderSheet), findsNothing);

    recorder.stopDelay = null;
    await _openAndRecord(tester);
    await _keep(tester);
    await tester.pump();
    await _settle(tester);
    expect(find.text(videoSaveTimeoutMessage), findsNothing);
    expect(service.requests, hasLength(2));
    expect(service.requests.last, isA<VideoCaptureRequest>());
    expect(recorder.stopCalls, 2);

    await tester.pump(_fade);
    await _settle(tester);
    await _closeAll(tester);
    debugDefaultTargetPlatformOverride = null;
  });
}
