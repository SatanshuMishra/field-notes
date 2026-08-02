import 'dart:async';

import 'package:camera/camera.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
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

class _ArmingRecorder implements VideoRecorder {
  final Completer<void> startGate = Completer<void>();

  int startCalls = 0;
  int cancelCalls = 0;
  int releaseCalls = 0;
  bool committed = false;
  bool _aborted = false;
  bool _sessionLive = false;

  @override
  Duration get elapsed => Duration.zero;

  @override
  Future<List<VideoCaptureDevice>> listDevices() async =>
      List<VideoCaptureDevice>.of(fakeVideoDevices);

  @override
  Widget? openSession(String deviceId) {
    _sessionLive = true;
    return SizedBox(
      key: ValueKey<String>('arming-preview-$deviceId'),
      width: 120,
      height: 120,
    );
  }

  @override
  Future<void> start() async {
    startCalls++;
    await startGate.future;
    if (_aborted) {
      throw const VideoRecorderException(videoStartMessage);
    }
    committed = true;
  }

  @override
  Future<VideoRecording> stop() async {
    return const VideoRecording(
      media: CaptureBytes(bytes: <int>[1], mime: 'video/mp4', durationMs: 1),
      durationMs: 1,
    );
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    _aborted = true;
  }

  @override
  Future<void> release() async {
    if (!_sessionLive) {
      return;
    }
    _sessionLive = false;
    releaseCalls++;
  }

  @override
  Future<void> dispose() async {
    await release();
  }
}

class _HangingReleaseRecorder implements VideoRecorder {
  int releaseCalls = 0;
  bool _sessionLive = false;

  @override
  Duration get elapsed => Duration.zero;

  @override
  Future<List<VideoCaptureDevice>> listDevices() async =>
      List<VideoCaptureDevice>.of(fakeVideoDevices);

  @override
  Widget? openSession(String deviceId) {
    _sessionLive = true;
    return SizedBox(
      key: ValueKey<String>('hang-release-preview-$deviceId'),
      width: 120,
      height: 120,
    );
  }

  @override
  Future<void> start() async {}

  @override
  Future<VideoRecording> stop() async {
    return const VideoRecording(
      media: CaptureBytes(bytes: <int>[1], mime: 'video/mp4', durationMs: 1),
      durationMs: 1,
    );
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> release() async {
    if (!_sessionLive) {
      return;
    }
    releaseCalls++;
    await Completer<void>().future;
  }

  @override
  Future<void> dispose() async {}
}

class _Trigger extends StatelessWidget {
  const _Trigger({
    required this.recorder,
    required this.service,
    this.releaseTimeout = cameraReleaseTimeout,
  });

  final VideoRecorder recorder;
  final CaptureService service;
  final Duration releaseTimeout;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: <Override>[
        videoRecorderProvider.overrideWith((Ref ref) => recorder),
        captureServiceProvider.overrideWith((Ref ref) => service),
      ],
      child: videoHarness(
        Builder(
          builder: (BuildContext inner) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showGeneralDialog<String>(
              context: inner,
              barrierDismissible: false,
              barrierLabel: 'Dismiss video recorder',
              pageBuilder: (
                BuildContext dialogContext,
                Animation<double> animation,
                Animation<double> secondaryAnimation,
              ) {
                return VideoComposerConnector(
                  date: '2026-07-21',
                  releaseTimeout: releaseTimeout,
                );
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}

Future<void> _open(WidgetTester tester) async {
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

CameraDescription _camera(String name, CameraLensDirection direction) {
  return CameraDescription(
    name: name,
    lensDirection: direction,
    sensorOrientation: 0,
  );
}

void main() {
  group('mobile camera labels', () {
    test('names each camera by lens direction', () {
      final List<VideoCaptureDevice> devices = cameraDeviceLabels(
        <CameraDescription>[
          _camera('0', CameraLensDirection.back),
          _camera('1', CameraLensDirection.front),
          _camera('2', CameraLensDirection.external),
        ],
      );

      expect(devices.map((VideoCaptureDevice d) => d.label), <String>[
        'Back camera',
        'Front camera',
        'External camera',
      ]);
      expect(devices.map((VideoCaptureDevice d) => d.id), <String>['0', '1', '2']);
    });

    test('disambiguates multiple cameras that share a direction', () {
      final List<VideoCaptureDevice> devices = cameraDeviceLabels(
        <CameraDescription>[
          _camera('0', CameraLensDirection.back),
          _camera('1', CameraLensDirection.back),
        ],
      );

      expect(devices.map((VideoCaptureDevice d) => d.label), <String>[
        'Back camera 1',
        'Back camera 2',
      ]);
    });
  });

  test('the mobile recorder offers no pre-record preview widget', () {
    final CameraVideoRecorder recorder = CameraVideoRecorder();

    expect(recorder.openSession('back'), isNull);
  });

  testWidgets(
      'a recorder with no live pre-record preview keeps the crosshatch, not an '
      'empty frame', (WidgetTester tester) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder(livePreview: false);
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(
      _Trigger(recorder: recorder, service: service),
    );
    await _open(tester);

    expect(find.byType(CrossHatchPlaceholder), findsWidgets);
    expect(find.byType(CameraPicker), findsOneWidget);
    expect(find.text('tap the button to start recording'), findsOneWidget);
    expect(fakeVideoPreview(), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'cancelling while a recording start is still in flight cancels it and '
      'releases without committing the recording', (WidgetTester tester) async {
    final _ArmingRecorder recorder = _ArmingRecorder();
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(
      _Trigger(recorder: recorder, service: service),
    );
    await _open(tester);

    await tester.tap(find.byKey(videoShutterKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(recorder.startCalls, 1);
    expect(find.text('Getting the camera ready…'), findsOneWidget);

    await tester.tap(find.byKey(videoCloseKey));
    await _settle(tester);

    expect(recorder.cancelCalls, 1);
    expect(recorder.releaseCalls, 1);
    expect(find.byType(VideoRecorderSheet), findsNothing);

    recorder.startGate.complete();
    await _settle(tester);

    expect(recorder.committed, isFalse);
    expect(service.requests, isEmpty);
  });

  testWidgets(
      'a camera switch that fails to release the old session surfaces the '
      'reason on the sheet', (WidgetTester tester) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder(
      releaseError: const VideoRecorderException(videoReleaseMessage),
    );
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(
      _Trigger(recorder: recorder, service: service),
    );
    await _open(tester);

    await tester.tap(find.text('Built-in Camera'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USB Camera'));
    await tester.pumpAndSettle();
    await _settle(tester);

    expect(find.text(videoReleaseMessage), findsOneWidget);
    expect(find.byType(VideoRecorderSheet), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'a release that never completes does not hang dismissal — the sheet '
      'still closes', (WidgetTester tester) async {
    final _HangingReleaseRecorder recorder = _HangingReleaseRecorder();
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(
      _Trigger(
        recorder: recorder,
        service: service,
        releaseTimeout: const Duration(milliseconds: 100),
      ),
    );
    await _open(tester);

    await tester.tap(find.byKey(videoCloseKey));
    await tester.pump();
    expect(recorder.releaseCalls, 1);

    await tester.pump(const Duration(milliseconds: 150));
    await _settle(tester);

    expect(find.byType(VideoRecorderSheet), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'a camera enumeration fault shows its own reason, distinct from the '
      'permission copy', (WidgetTester tester) async {
    final FakeVideoRecorder recorder = FakeVideoRecorder(
      listError: const VideoRecorderException(videoDeviceListMessage),
    );
    final FakeCaptureService service = FakeCaptureService();

    await tester.pumpWidget(
      _Trigger(recorder: recorder, service: service),
    );
    await _open(tester);

    expect(find.text(videoDeviceListMessage), findsOneWidget);
    expect(find.text(cameraPermissionMessage), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
