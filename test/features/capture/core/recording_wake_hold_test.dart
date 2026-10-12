import 'package:field_notes/data/device/stay_awake.dart';
import 'package:field_notes/features/capture/core/recording_wake_hold.dart';
import 'package:field_notes/features/capture/immersive/stage_phase.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingStayAwake implements StayAwake {
  final List<String> calls = <String>[];

  @override
  Future<void> hold() async => calls.add('hold');

  @override
  Future<void> release() async => calls.add('release');
}

List<String> _recordChannelCalls() {
  final List<String> calls = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel(stayAwakeChannelName), (
        MethodCall call,
      ) async {
        calls.add(call.method);
        return null;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(stayAwakeChannelName),
          null,
        ),
  );
  return calls;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the wake hold follows the take on every way out', () async {
    final _RecordingStayAwake kept = _RecordingStayAwake();
    final RecordingWakeHold keptTake = RecordingWakeHold(kept);
    keptTake.update(live: false);
    expect(kept.calls, isEmpty);
    keptTake.update(live: true);
    keptTake.update(live: true);
    expect(kept.calls, <String>['hold']);
    keptTake.update(live: false);
    keptTake.update(live: false);
    expect(kept.calls, <String>['hold', 'release']);
    keptTake.dispose();
    expect(kept.calls, <String>['hold', 'release']);

    final _RecordingStayAwake retried = _RecordingStayAwake();
    final RecordingWakeHold retriedTake = RecordingWakeHold(retried);
    retriedTake.update(live: true);
    retriedTake.update(live: false);
    retriedTake.update(live: true);
    expect(retried.calls, <String>['hold', 'release', 'hold']);
    retriedTake.dispose();
    retriedTake.dispose();
    expect(retried.calls, <String>['hold', 'release', 'hold', 'release']);

    final _RecordingStayAwake torn = _RecordingStayAwake();
    final RecordingWakeHold tornTake = RecordingWakeHold(torn);
    tornTake.update(live: true);
    tornTake.dispose();
    expect(torn.calls, <String>['hold', 'release']);

    final _RecordingStayAwake untouched = _RecordingStayAwake();
    RecordingWakeHold(untouched).dispose();
    expect(untouched.calls, isEmpty);

    expect(
      <StagePhase, bool>{
        for (final StagePhase phase in StagePhase.values)
          phase: phase.holdsDeviceAwake,
      },
      <StagePhase, bool>{
        StagePhase.idle: false,
        StagePhase.breathing: true,
        StagePhase.recording: true,
        StagePhase.paused: true,
        StagePhase.saving: true,
      },
    );

    final List<String> channel = _recordChannelCalls();
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final RecordingWakeHold platformTake = RecordingWakeHold(
      container.read(stayAwakeProvider),
    );
    platformTake.update(live: true);
    platformTake.update(live: true);
    platformTake.update(live: false);
    platformTake.dispose();
    await pumpEventQueue();
    expect(channel, <String>['hold', 'release']);
  });

  test('every video phase keeps its stage', () {
    expect(
      <VideoRecorderPhase, StagePhase>{
        for (final VideoRecorderPhase phase in VideoRecorderPhase.values)
          phase: phase.stage,
      },
      <VideoRecorderPhase, StagePhase>{
        VideoRecorderPhase.preparing: StagePhase.idle,
        VideoRecorderPhase.idle: StagePhase.idle,
        VideoRecorderPhase.breathing: StagePhase.breathing,
        VideoRecorderPhase.arming: StagePhase.breathing,
        VideoRecorderPhase.recording: StagePhase.recording,
        VideoRecorderPhase.paused: StagePhase.paused,
        VideoRecorderPhase.saving: StagePhase.saving,
        VideoRecorderPhase.denied: StagePhase.idle,
      },
    );
  });
}
