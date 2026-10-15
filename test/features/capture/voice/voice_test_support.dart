import 'dart:async';
import 'dart:io';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/audio/take_cleanup.dart';
import 'package:field_notes/features/capture/voice/voice_recorder.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget voiceHarness(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: child)),
  );
}

Widget voiceSheetHarness(Widget child) {
  return ProviderScope(
    overrides: <Override>[
      reflectionPromptsEnabledProvider.overrideWithValue(false),
    ],
    child: voiceHarness(child),
  );
}

Future<void> startVoiceTake(WidgetTester tester) async {
  await tester.tap(find.byKey(voiceRecordButtonKey));
  await tester.pump();
  await tester.tap(find.byKey(voiceRecordButtonKey));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

class FakeVoiceRecorder implements VoiceRecorder {
  FakeVoiceRecorder({
    this.permission = true,
    this.recording,
    this.startError,
    this.stopError,
  });

  final bool permission;
  final VoiceRecording? recording;
  final VoiceRecorderException? startError;
  final VoiceRecorderException? stopError;

  @override
  Duration elapsed = Duration.zero;

  final StreamController<double> levels = StreamController<double>.broadcast();

  @override
  Stream<double> get level => levels.stream;

  int startCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  int disposeCalls = 0;
  int releaseSavedCalls = 0;
  final List<VoiceRecording> savedReleases = <VoiceRecording>[];

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<void> start() async {
    startCalls++;
    final VoiceRecorderException? error = startError;
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
  Future<VoiceRecording> stop() async {
    stopCalls++;
    final VoiceRecorderException? error = stopError;
    if (error != null) {
      throw error;
    }
    return recording ??
        const VoiceRecording(
          media: CaptureBytes(
            bytes: <int>[1, 2, 3],
            mime: 'audio/mp4',
            durationMs: 4200,
          ),
          durationMs: 4200,
        );
  }

  @override
  Future<void> releaseSaved(VoiceRecording recording) async {
    releaseSavedCalls++;
    savedReleases.add(recording);
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
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

class FakeTakeCleanup extends TakeCleanup {
  FakeTakeCleanup({this.rewritten, this.delay = Duration.zero});

  final File? rewritten;
  final Duration delay;
  final List<File> takes = <File>[];
  final List<TakeKind> kinds = <TakeKind>[];
  final List<InputProfile> profiles = <InputProfile>[];
  final List<int> volumes = <int>[];
  final List<File> released = <File>[];

  @override
  Future<File> clean(
    File take, {
    required TakeKind kind,
    required InputProfile profile,
    required int volume,
    required Duration duration,
  }) async {
    takes.add(take);
    kinds.add(kind);
    profiles.add(profile);
    volumes.add(volume);
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return rewritten ?? take;
  }

  @override
  Future<void> release(File cleaned) async {
    released.add(cleaned);
  }
}

Override takeCleanupOverride(TakeCleanup cleanup) =>
    takeCleanupProvider.overrideWithValue(cleanup);
