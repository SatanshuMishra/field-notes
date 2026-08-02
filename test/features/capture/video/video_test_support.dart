import 'dart:async';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget videoHarness(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: child)),
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

class FakeVideoRecorder implements VideoRecorder {
  FakeVideoRecorder({
    this.recording,
    this.startError,
    this.stopError,
    List<VideoCaptureDevice> devices = fakeVideoDevices,
    this.listError,
    this.releaseError,
    this.livePreview = true,
  }) : devices = List<VideoCaptureDevice>.of(devices);

  final VideoRecording? recording;
  final VideoRecorderException? startError;
  final VideoRecorderException? stopError;
  final VideoRecorderException? listError;
  final VideoRecorderException? releaseError;
  final bool livePreview;
  List<VideoCaptureDevice> devices;

  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  int releaseCalls = 0;
  int disposeCalls = 0;
  int listCalls = 0;
  bool _sessionLive = false;
  final List<String> previewDeviceIds = <String>[];

  Duration elapsedValue = Duration.zero;

  String? get previewDeviceId =>
      previewDeviceIds.isEmpty ? null : previewDeviceIds.last;

  @override
  Duration get elapsed => elapsedValue;

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
  Future<VideoRecording> stop() async {
    stopCalls++;
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
  int disposeCalls = 0;

  @override
  Duration get elapsed => Duration.zero;

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
  Future<VideoRecording> stop() async {
    stopCalls++;
    return const VideoRecording(
      media: CaptureBytes(bytes: <int>[1], mime: 'video/mp4', durationMs: 1),
      durationMs: 1,
    );
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
  Widget build(BuildContext context) =>
      const SizedBox(key: ValueKey('deferred-preview'), width: 120, height: 120);
}

class FakeCaptureService implements CaptureService {
  FakeCaptureService({this.failure});

  final CaptureException? failure;
  final List<CaptureRequest> requests = <CaptureRequest>[];

  @override
  Future<CaptureResult> capture(CaptureRequest request) async {
    requests.add(request);
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
