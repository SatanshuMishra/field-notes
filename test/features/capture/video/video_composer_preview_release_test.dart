import 'dart:async';

import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/video/video_composer.dart';
import 'package:field_notes/features/capture/video/video_recorder_provider.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

void main() {
  testWidgets('the live preview leaves the tree before the recorder stops',
      (WidgetTester tester) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder();
    final FakeCaptureService service = FakeCaptureService();
    final Completer<void> gate = Completer<void>();
    recorder.stopGate = gate;

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          videoRecorderProvider.overrideWith((Ref ref) => recorder),
          captureServiceProvider.overrideWith((Ref ref) => service),
        ],
        child: videoHarness(
          const VideoComposerConnector(date: '2026-07-21'),
        ),
      ),
    );
    await tester.pump();

    const String deviceId = 'built-in-id';
    expect(fakeVideoPreview(deviceId: deviceId), findsOneWidget);

    await tester.tap(find.byKey(videoShutterKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(recorder.startCalls, 1);
    expect(fakeVideoPreview(deviceId: deviceId), findsOneWidget);

    await tester.tap(find.byKey(videoShutterKey));
    await tester.pump();

    expect(recorder.stopCalls, 1);
    expect(find.text('Saving your video…'), findsOneWidget);
    expect(fakeVideoPreview(deviceId: deviceId), findsNothing);

    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(service.requests, hasLength(1));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
