import 'package:fake_async/fake_async.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/live_audio_capture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'live_audio_test_support.dart';

const Duration _chunkEvery = Duration(milliseconds: 100);
const int _samplesPerChunk = 4800;

typedef _Take = void Function(
  FakeAsync async,
  LiveAudioCapture capture,
  List<FakeMicrophone> microphones,
);

void _keptTake(String name, int recordedSamples, _Take take) {
  test(name, () {
    fakeAsync((FakeAsync async) {
      final List<FakeMicrophone> microphones = <FakeMicrophone>[];
      final FakeLiveAudio sound = FakeLiveAudio(writesFiles: false);
      final LiveAudioCapture capture = LiveAudioCapture(
        recorderFactory: () {
          final FakeMicrophone microphone = FakeMicrophone();
          microphones.add(microphone);
          return microphone;
        },
        encoder: sound,
        chainRunner: passThroughChain,
        clock: () => async.elapsed,
      );
      capture.start(
        input: const AudioInput(id: null, label: 'System default'),
        profile: InputProfile.studio,
        volume: 100,
        path: 'take.m4a',
      );
      async.flushMicrotasks();

      take(async, capture, microphones);

      LiveAudioTake? kept;
      capture.stop().then((LiveAudioTake result) => kept = result);
      async.flushMicrotasks();
      expect(kept, isNotNull);

      expect(
        (sound.samplesAppended - recordedSamples).abs(),
        lessThanOrEqualTo(_samplesPerChunk),
      );
      capture.dispose();
      async.flushMicrotasks();
    });
  });
}

void _speak(FakeAsync async, List<FakeMicrophone> microphones, int chunks) {
  for (int chunk = 0; chunk < chunks; chunk += 1) {
    async.elapse(_chunkEvery);
    microphones.last.push(pcmAtDbfs(-20, samples: _samplesPerChunk));
    async.flushMicrotasks();
  }
}

void _pauseFor(FakeAsync async, LiveAudioCapture capture, Duration pause) {
  capture.pause();
  async.flushMicrotasks();
  async.elapse(pause);
}

void main() {
  _keptTake(
    'a take kept while paused writes no sound for the paused stretch',
    10 * _samplesPerChunk,
    (FakeAsync async, LiveAudioCapture capture, List<FakeMicrophone> mics) {
      _speak(async, mics, 10);
      _pauseFor(async, capture, const Duration(seconds: 5));
    },
  );

  _keptTake(
    'a take paused, resumed and paused again before keeping writes only its sound',
    10 * _samplesPerChunk,
    (FakeAsync async, LiveAudioCapture capture, List<FakeMicrophone> mics) {
      _speak(async, mics, 5);
      _pauseFor(async, capture, const Duration(seconds: 3));
      capture.resume();
      async.flushMicrotasks();
      _speak(async, mics, 5);
      _pauseFor(async, capture, const Duration(seconds: 3));
    },
  );

  _keptTake(
    'a take paused twice before keeping writes no sound for either pause',
    10 * _samplesPerChunk,
    (FakeAsync async, LiveAudioCapture capture, List<FakeMicrophone> mics) {
      _speak(async, mics, 10);
      _pauseFor(async, capture, const Duration(seconds: 3));
      _pauseFor(async, capture, const Duration(seconds: 3));
    },
  );

  _keptTake(
    'a take paused while its microphone is reopened writes no sound for the pause',
    15 * _samplesPerChunk + 960,
    (FakeAsync async, LiveAudioCapture capture, List<FakeMicrophone> mics) {
      _speak(async, mics, 10);
      async.elapse(const Duration(milliseconds: 520));
      async.flushMicrotasks();
      _pauseFor(async, capture, const Duration(seconds: 5));
    },
  );

  _keptTake(
    'a dead stretch before a pause is still kept as silence',
    30 * _samplesPerChunk,
    (FakeAsync async, LiveAudioCapture capture, List<FakeMicrophone> mics) {
      _speak(async, mics, 10);
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      _pauseFor(async, capture, const Duration(seconds: 5));
    },
  );

  _keptTake(
    'a take paused and resumed before keeping writes only its sound',
    10 * _samplesPerChunk,
    (FakeAsync async, LiveAudioCapture capture, List<FakeMicrophone> mics) {
      _speak(async, mics, 5);
      _pauseFor(async, capture, const Duration(seconds: 3));
      capture.resume();
      async.flushMicrotasks();
      _speak(async, mics, 5);
    },
  );
}
