import 'dart:async';

import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:field_notes/features/capture/video/video_composer.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder_provider.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

const MethodChannel _cameraChannel = MethodChannel('camera_macos');

class _SlowSecondListRecorder extends FakeVideoRecorder {
  _SlowSecondListRecorder() : super(devices: const <VideoCaptureDevice>[]);

  final Completer<List<VideoCaptureDevice>> secondList =
      Completer<List<VideoCaptureDevice>>();

  @override
  Future<List<VideoCaptureDevice>> listDevices() {
    listCalls++;
    if (listCalls == 1) {
      return Future<List<VideoCaptureDevice>>.value(
        const <VideoCaptureDevice>[],
      );
    }
    return secondList.future;
  }
}

Widget _app(VideoRecorder recorder) => ProviderScope(
  overrides: <Override>[
    videoRecorderProvider.overrideWith((Ref ref) => recorder),
    captureServiceProvider.overrideWith((Ref ref) => FakeCaptureService()),
    reflectionPromptsOff(),
  ],
  child: videoHarness(
    Builder(
      builder: (BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showVideoComposer(context, '2026-09-29'),
        child: const Text('open'),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  testWidgets('a device with no camera says so instead of asking for access', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(FakeVideoRecorder(devices: const <VideoCaptureDevice>[])),
    );
    await _open(tester);

    expect(find.text(videoDeviceListMessage), findsOneWidget);
    expect(find.text(cameraPermissionMessage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'pressing Start with no camera keeps the message while it checks again',
    (WidgetTester tester) async {
      final _SlowSecondListRecorder recorder = _SlowSecondListRecorder();
      await tester.pumpWidget(_app(recorder));
      await _open(tester);

      await tester.tap(find.byKey(videoShutterKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(recorder.listCalls, 2);
      expect(find.text(videoDeviceListMessage), findsOneWidget);

      recorder.secondList.complete(const <VideoCaptureDevice>[]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(videoDeviceListMessage), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('a refused camera permission on macOS asks for access', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_cameraChannel, (MethodCall call) async {
          if (call.method == 'listDevices') {
            throw PlatformException(
              code: 'CAMERA_INITIALIZATION_ERROR',
              message: 'Permission not granted',
            );
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_cameraChannel, null),
    );

    await expectLater(
      CameraMacosVideoRecorder().listDevices(),
      throwsA(
        isA<VideoRecorderException>().having(
          (VideoRecorderException error) => error.message,
          'message',
          cameraPermissionMessage,
        ),
      ),
    );
  });
}
