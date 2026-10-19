import 'dart:async';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/audio/microphone_hearing.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:field_notes/features/capture/voice/voice_recorder.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../voice/voice_test_support.dart' show FakeVoiceRecorder;

const MethodChannel cameraMacosChannel = MethodChannel('camera_macos');

Future<void> sendMacMovieStart({Duration? firstFrameAge}) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          cameraMacosChannel.name,
          cameraMacosChannel.codec.encodeMethodCall(
            MethodCall(
              'onVideoRecordingStarted',
              firstFrameAge == null
                  ? null
                  : <String, Object?>{
                      'firstFrameAgeMs': firstFrameAge.inMilliseconds,
                    },
            ),
          ),
          (ByteData? _) {},
        );

Widget videoHarness(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: child)),
  );
}

Override reflectionPromptsOff() =>
    reflectionPromptsEnabledProvider.overrideWithValue(false);

Widget videoSheetHarness(Widget child) {
  return ProviderScope(
    overrides: <Override>[reflectionPromptsOff()],
    child: videoHarness(child),
  );
}

Finder fakeVideoPreview({String? deviceId}) {
  return find.byWidgetPredicate((Widget widget) {
    final Key? key = widget.key;
    if (key is! ValueKey<String>) {
      return false;
    }
    return deviceId == null
        ? key.value.startsWith('fake-video-preview-')
        : key.value == 'fake-video-preview-$deviceId';
  });
}

const List<VideoCaptureDevice> fakeVideoDevices = <VideoCaptureDevice>[
  VideoCaptureDevice(id: 'built-in-id', label: 'Built-in Camera'),
  VideoCaptureDevice(id: 'usb-id', label: 'USB Camera'),
];

class FakeVideoRecorder implements VideoRecorder, CameraControls {
  FakeVideoRecorder({
    this.recording,
    this.startError,
    this.stopError,
    List<VideoCaptureDevice> devices = fakeVideoDevices,
    this.listError,
    this.releaseError,
    this.livePreview = true,
    this.supportsPause = false,
  }) : devices = List<VideoCaptureDevice>.of(devices);

  final VideoRecording? recording;
  final VideoRecorderException? startError;
  final VideoRecorderException? stopError;
  final VideoRecorderException? listError;
  final VideoRecorderException? releaseError;
  final bool livePreview;

  @override
  final bool supportsPause;

  List<VideoCaptureDevice> devices;

  int startCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  int releaseCalls = 0;
  int releaseSavedCalls = 0;
  final List<VideoRecording> savedReleases = <VideoRecording>[];
  int disposeCalls = 0;
  int listCalls = 0;
  bool _sessionLive = false;
  final List<String> previewDeviceIds = <String>[];
  Completer<void>? stopGate;
  Duration? stopDelay;
  Duration? releaseDelay;
  int releasesFinished = 0;

  Duration elapsedValue = Duration.zero;

  String? get previewDeviceId =>
      previewDeviceIds.isEmpty ? null : previewDeviceIds.last;

  @override
  Duration get elapsed => elapsedValue;

  @override
  Stream<double> get level => const Stream<double>.empty();

  final StreamController<MicrophoneHearing> _hearing =
      StreamController<MicrophoneHearing>.broadcast();
  MicrophoneHearing _hearingNow = MicrophoneHearing.hearing;

  @override
  Stream<MicrophoneHearing> get hearing => _hearing.stream;

  @override
  MicrophoneHearing get hearingNow => _hearingNow;

  void hear(MicrophoneHearing next) {
    _hearingNow = next;
    _hearing.add(next);
  }

  @override
  double zoom = 1;

  final List<Offset> focusPoints = <Offset>[];

  @override
  Rect? previewRectIn(Size area) =>
      livePreview && _sessionLive ? Offset.zero & area : null;

  @override
  Future<ZoomRange?> zoomRange() async => const ZoomRange(1, 4);

  @override
  Future<void> setZoom(double zoom) async => this.zoom = zoom;

  @override
  Future<void> focusAt(Offset point) async => focusPoints.add(point);

  @override
  Future<List<VideoCaptureDevice>> listDevices() async {
    listCalls++;
    final VideoRecorderException? error = listError;
    if (error != null) {
      throw error;
    }
    return List<VideoCaptureDevice>.of(devices);
  }

  @override
  Future<void> start() async {
    startCalls++;
    final VideoRecorderException? error = startError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
  }

  @override
  Future<VideoRecording> stop() async {
    stopCalls++;
    final Completer<void>? gate = stopGate;
    if (gate != null) {
      await gate.future;
    }
    final Duration? delay = stopDelay;
    if (delay != null) {
      await Future<void>.delayed(delay);
    }
    final VideoRecorderException? error = stopError;
    if (error != null) {
      throw error;
    }
    return recording ??
        const VideoRecording(
          media: CaptureBytes(
            bytes: <int>[1, 2, 3],
            mime: 'video/mp4',
            durationMs: 6000,
          ),
          durationMs: 6000,
          thumbnail: CaptureBytes(bytes: <int>[7, 8], mime: 'image/jpeg'),
        );
  }

  @override
  Future<void> releaseSaved(VideoRecording recording) async {
    releaseSavedCalls++;
    savedReleases.add(recording);
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }

  @override
  Future<void> release() async {
    if (!_sessionLive) {
      return;
    }
    _sessionLive = false;
    releaseCalls++;
    final Duration? delay = releaseDelay;
    if (delay != null) {
      await Future<void>.delayed(delay);
    }
    releasesFinished++;
    final VideoRecorderException? error = releaseError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await release();
  }

  @override
  Widget? openSession(String deviceId) {
    previewDeviceIds.add(deviceId);
    _sessionLive = true;
    if (!livePreview) {
      return null;
    }
    return SizedBox(
      key: ValueKey<String>('fake-video-preview-$deviceId'),
      width: 120,
      height: 120,
    );
  }
}

class DeferredReadyVideoRecorder implements VideoRecorder {
  DeferredReadyVideoRecorder();

  final Completer<void> _ready = Completer<void>();
  Widget? _preview;
  bool _sessionLive = false;

  bool started = false;
  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  int releaseCalls = 0;
  int releaseSavedCalls = 0;
  int disposeCalls = 0;

  @override
  Duration get elapsed => Duration.zero;

  @override
  Stream<double> get level => const Stream<double>.empty();

  @override
  Stream<MicrophoneHearing> get hearing =>
      const Stream<MicrophoneHearing>.empty();

  @override
  MicrophoneHearing get hearingNow => MicrophoneHearing.hearing;

  @override
  bool get supportsPause => false;

  @override
  Future<List<VideoCaptureDevice>> listDevices() async =>
      List<VideoCaptureDevice>.of(fakeVideoDevices);

  @override
  Future<void> start() async {
    startCalls++;
    await _ready.future;
    started = true;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<VideoRecording> stop() async {
    stopCalls++;
    return const VideoRecording(
      media: CaptureBytes(bytes: <int>[1], mime: 'video/mp4', durationMs: 1),
      durationMs: 1,
    );
  }

  @override
  Future<void> releaseSaved(VideoRecording recording) async {
    releaseSavedCalls++;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
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
    disposeCalls++;
    await release();
  }

  @override
  Widget? openSession(String deviceId) {
    _sessionLive = true;
    return _preview ??= _ReadySignal(
      onReady: () {
        if (!_ready.isCompleted) {
          _ready.complete();
        }
      },
    );
  }
}

class _ReadySignal extends StatefulWidget {
  const _ReadySignal({required this.onReady});

  final VoidCallback onReady;

  @override
  State<_ReadySignal> createState() => _ReadySignalState();
}

class _ReadySignalState extends State<_ReadySignal> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onReady());
  }

  @override
  Widget build(BuildContext context) => const SizedBox(
    key: ValueKey('deferred-preview'),
    width: 120,
    height: 120,
  );
}

class CameraOffVoiceRecorder extends FakeVoiceRecorder {
  CameraOffVoiceRecorder({super.permission, super.recording});

  Object? permissionError;
  final List<String> calls = <String>[];

  @override
  Future<bool> hasPermission() async {
    calls.add('hasPermission');
    final Object? error = permissionError;
    if (error != null) {
      throw error;
    }
    return super.hasPermission();
  }

  @override
  Future<void> start() {
    calls.add('start');
    return super.start();
  }

  @override
  Future<void> pause() {
    calls.add('pause');
    return super.pause();
  }

  @override
  Future<void> resume() {
    calls.add('resume');
    return super.resume();
  }

  @override
  Future<VoiceRecording> stop() {
    calls.add('stop');
    return super.stop();
  }

  @override
  Future<void> cancel() {
    calls.add('cancel');
    return super.cancel();
  }
}

class FakeCaptureService implements CaptureService {
  FakeCaptureService({this.failure, this.gate});

  final CaptureException? failure;
  final Future<void>? gate;
  final List<CaptureRequest> requests = <CaptureRequest>[];

  @override
  Future<CaptureResult> capture(CaptureRequest request) async {
    requests.add(request);
    final Future<void>? gate = this.gate;
    if (gate != null) {
      await gate;
    }
    final CaptureException? error = failure;
    if (error != null) {
      throw error;
    }
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
