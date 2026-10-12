import 'dart:async';

import 'package:field_notes/features/capture/voice/record_voice_recorder.dart';
import 'package:field_notes/features/capture/voice/voice_level.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

class _AmplitudeAudioRecorder extends Fake implements AudioRecorder {
  final StreamController<Amplitude> amplitudes =
      StreamController<Amplitude>.broadcast();
  final List<Duration> requestedIntervals = <Duration>[];

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) {
    requestedIntervals.add(interval);
    return amplitudes.stream;
  }

  @override
  Future<void> dispose() async {}
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('microphone readings map to a level from 0 to 1', () {
    expect(voiceLevelFromDbfs(-160), 0);
    expect(voiceLevelFromDbfs(-50), 0);
    expect(voiceLevelFromDbfs(-30), 0.5);
    expect(voiceLevelFromDbfs(-10), 1);
    expect(voiceLevelFromDbfs(0), 1);
    expect(voiceLevelFromDbfs(double.negativeInfinity), 0);
    expect(voiceLevelFromDbfs(double.nan), 0);
  });

  test('the record recorder streams the microphone level', () async {
    final _AmplitudeAudioRecorder audio = _AmplitudeAudioRecorder();
    final RecordVoiceRecorder recorder = RecordVoiceRecorder(recorder: audio);
    final List<double> levels = <double>[];
    final StreamSubscription<double> subscription = recorder.level.listen(
      levels.add,
    );

    audio.amplitudes
      ..add(Amplitude(current: -160, max: -160))
      ..add(Amplitude(current: -30, max: -30))
      ..add(Amplitude(current: -5, max: -5));
    await _settle();

    expect(levels, <double>[0, 0.5, 1]);
    expect(audio.requestedIntervals, <Duration>[voiceLevelInterval]);
    expect(voiceLevelInterval, const Duration(milliseconds: 60));
    expect(identical(recorder.level, recorder.level), isTrue);

    await subscription.cancel();
    await recorder.dispose();
    await audio.amplitudes.close();
  });

  test('the microphone level is read only once something listens', () async {
    final _AmplitudeAudioRecorder audio = _AmplitudeAudioRecorder();
    final RecordVoiceRecorder recorder = RecordVoiceRecorder(recorder: audio);

    final Stream<double> stream = recorder.level;
    expect(audio.requestedIntervals, isEmpty);
    expect(audio.amplitudes.hasListener, isFalse);

    final StreamSubscription<double> first = stream.listen((_) {});
    expect(audio.requestedIntervals, hasLength(1));
    expect(audio.amplitudes.hasListener, isTrue);

    final StreamSubscription<double> second = stream.listen((_) {});
    expect(audio.requestedIntervals, hasLength(1));

    await first.cancel();
    expect(audio.amplitudes.hasListener, isTrue);
    await second.cancel();
    await _settle();
    expect(audio.amplitudes.hasListener, isFalse);

    final StreamSubscription<double> third = stream.listen((_) {});
    expect(audio.requestedIntervals, hasLength(1));
    expect(audio.amplitudes.hasListener, isTrue);
    await third.cancel();
    await _settle();
    expect(audio.amplitudes.hasListener, isFalse);

    await recorder.dispose();
    await audio.amplitudes.close();
  });
}
