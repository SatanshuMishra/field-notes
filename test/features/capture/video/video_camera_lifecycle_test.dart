import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/video/camera_picker.dart';
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
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _settle(WidgetTester tester, {int times = 8}) async {
  for (int i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets(
      'opening the recorder starts a live preview instead of showing the '
      'crosshatch placeholder', (WidgetTester tester) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder();
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(
      _recorderApp(recorder: recorder, service: service),
    );
    await _openComposer(tester);

    expect(fakeVideoPreview(deviceId: 'built-in-id'), findsOneWidget);
    expect(find.byType(CrossHatchPlaceholder), findsNothing);
    expect(find.text('Record'), findsOneWidget);
    expect(recorder.startCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cancelling the recorder releases the camera exactly once',
      (WidgetTester tester) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder();
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(
      _recorderApp(recorder: recorder, service: service),
    );
    await _openComposer(tester);

    await tester.tap(find.text('Cancel'));
    await _settle(tester);

    expect(recorder.releaseCalls, 1);
    expect(find.byType(VideoRecorderSheet), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(recorder.releaseCalls, 1);
  });

  testWidgets(
      'recording, stopping and saving releases the camera exactly once',
      (WidgetTester tester) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder();
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(
      _recorderApp(recorder: recorder, service: service),
    );
    await _openComposer(tester);

    await tester.tap(find.text('Record'));
    await _settle(tester);

    await tester.tap(find.text('Stop & save'));
    await _settle(tester);

    expect(service.requests, hasLength(1));
    expect(recorder.stopCalls, 1);
    expect(recorder.releaseCalls, 1);
    expect(find.byType(VideoRecorderSheet), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(recorder.releaseCalls, 1);
  });

  testWidgets(
      'tearing down the recorder without an explicit dismissal still releases '
      'the camera', (WidgetTester tester) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder();
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(
      _recorderApp(recorder: recorder, service: service),
    );
    await _openComposer(tester);

    expect(recorder.releaseCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(recorder.releaseCalls, 1);
  });

  testWidgets(
      'the camera picker lists every connected camera and previews the one the '
      'user picks', (WidgetTester tester) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder();
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(
      _recorderApp(recorder: recorder, service: service),
    );
    await _openComposer(tester);

    expect(find.byType(CameraPicker), findsOneWidget);
    expect(find.text('Built-in Camera'), findsOneWidget);

    await tester.tap(find.text('Built-in Camera'));
    await tester.pumpAndSettle();

    expect(find.text('USB Camera'), findsOneWidget);

    await tester.tap(find.text('USB Camera'));
    await tester.pumpAndSettle();
    await _settle(tester);

    expect(recorder.previewDeviceId, 'usb-id');
    expect(fakeVideoPreview(deviceId: 'usb-id'), findsOneWidget);
    expect(fakeVideoPreview(deviceId: 'built-in-id'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the picked camera is remembered the next time the sheet opens',
      (WidgetTester tester) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder();
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(
      _recorderApp(recorder: recorder, service: service),
    );
    await _openComposer(tester);

    await tester.tap(find.text('Built-in Camera'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USB Camera'));
    await tester.pumpAndSettle();
    await _settle(tester);

    await tester.tap(find.text('Cancel'));
    await _settle(tester);

    await _openComposer(tester);

    expect(recorder.previewDeviceId, 'usb-id');
    expect(fakeVideoPreview(deviceId: 'usb-id'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'a remembered camera that is no longer connected falls back to a '
      'connected one', (WidgetTester tester) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder();
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(
      _recorderApp(recorder: recorder, service: service),
    );
    await _openComposer(tester);

    await tester.tap(find.text('Built-in Camera'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USB Camera'));
    await tester.pumpAndSettle();
    await _settle(tester);

    await tester.tap(find.text('Cancel'));
    await _settle(tester);

    recorder.devices = const <VideoCaptureDevice>[
      VideoCaptureDevice(id: 'built-in-id', label: 'Built-in Camera'),
    ];

    await _openComposer(tester);

    expect(recorder.previewDeviceId, 'built-in-id');
    expect(fakeVideoPreview(deviceId: 'built-in-id'), findsOneWidget);
    expect(find.text('Built-in Camera'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'no connected camera surfaces the denied state instead of a dead preview',
      (WidgetTester tester) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder(
      devices: const <VideoCaptureDevice>[],
    );
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(
      _recorderApp(recorder: recorder, service: service),
    );
    await _openComposer(tester);

    expect(find.text(cameraPermissionMessage), findsOneWidget);
    expect(find.byType(CameraPicker), findsNothing);
    expect(fakeVideoPreview(), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'a camera enumeration failure surfaces its reason instead of a dead '
      'preview', (WidgetTester tester) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder(
      listError: const VideoRecorderException(videoDeviceListMessage),
    );
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(
      _recorderApp(recorder: recorder, service: service),
    );
    await _openComposer(tester);

    expect(find.text(videoDeviceListMessage), findsOneWidget);
    expect(fakeVideoPreview(), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
