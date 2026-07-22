import 'dart:async';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:flutter/material.dart';

Widget videoHarness(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: child)),
  );
}

class FakeVideoRecorder implements VideoRecorder {
  FakeVideoRecorder({
    this.permission = true,
    this.recording,
    this.startError,
    this.stopError,
  });

  final bool permission;
  final VideoRecording? recording;
  final VideoRecorderException? startError;
  final VideoRecorderException? stopError;

  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  int disposeCalls = 0;

  @override
  Future<bool> hasPermission() async => permission;

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
  Future<void> dispose() async {
    disposeCalls++;
  }

  @override
  Widget buildPreview() =>
      const SizedBox(key: ValueKey('fake-video-preview'), width: 120, height: 120);
}

class DeferredReadyVideoRecorder implements VideoRecorder {
  DeferredReadyVideoRecorder({this.permission = true});

  final bool permission;
  final Completer<void> _ready = Completer<void>();
  Widget? _preview;

  bool started = false;
  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  int disposeCalls = 0;

  @override
  Future<bool> hasPermission() async => permission;

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
  Future<void> dispose() async {
    disposeCalls++;
  }

  @override
  Widget buildPreview() => _preview ??= _ReadySignal(
        onReady: () {
          if (!_ready.isCompleted) {
            _ready.complete();
          }
        },
      );
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
