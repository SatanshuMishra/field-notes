import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:field_notes/data/media/captured_audio.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/live_audio_capture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'live_audio_test_support.dart';

const int _samplesPerChunk = 4800;
const int _chunkNs = 100000000;
const int _firstChunkCapturedAtNs = 5000000000;
const int _samplesPerMs = 48;
const int _samplesIn90Ms = 4320;

class _Take {
  _Take(this.async)
    : microphone = FakeMicrophone(),
      sound = FakeLiveAudio(writesFiles: false),
      captureTimes = StreamController<CapturedAudio>.broadcast() {
    capture = LiveAudioCapture(
      recorderFactory: () => microphone,
      encoder: sound,
      chainRunner: passThroughChain,
      captureTimes: captureTimes.stream,
      clock: () => async.elapsed,
    );
    capture.start(
      input: const AudioInput(id: null, label: 'System default'),
      profile: InputProfile.studio,
      volume: 100,
      path: 'take.m4a',
      armed: true,
    );
    async.flushMicrotasks();
  }

  final FakeAsync async;
  final FakeMicrophone microphone;
  final FakeLiveAudio sound;
  final StreamController<CapturedAudio> captureTimes;
  late final LiveAudioCapture capture;

  void hearChunk(int index, {List<String> recorders = const <String>['mic']}) {
    for (final String recorderId in recorders) {
      captureTimes.add(
        CapturedAudio(
          recorderId: recorderId,
          firstSample: index * _samplesPerChunk,
          samples: _samplesPerChunk,
          capturedAtNs: _firstChunkCapturedAtNs + index * _chunkNs,
        ),
      );
    }
    async.flushMicrotasks();
    microphone.push(pcmAtDbfs(-20, samples: _samplesPerChunk));
    async.flushMicrotasks();
  }

  List<int> keep() {
    LiveAudioTake? take;
    capture.stop().then((LiveAudioTake kept) => take = kept);
    async.flushMicrotasks();
    expect(take, isNotNull);
    final List<int> written = <int>[
      for (final Uint8List pcm in sound.appended)
        for (int offset = 0; offset + 1 < pcm.length; offset += 2)
          pcm.buffer
              .asByteData(pcm.offsetInBytes)
              .getInt16(offset, Endian.little),
    ];
    capture.dispose();
    captureTimes.close();
    async.flushMicrotasks();
    return written;
  }
}

int _leadingSilence(List<int> samples) =>
    samples.takeWhile((int sample) => sample == 0).length;

void main() {
  test('the sound starts at the sample the microphone captured as the first '
      'frame was captured, when that sample is still to come', () {
    fakeAsync((FakeAsync async) {
      final _Take take = _Take(async);
      async.elapse(const Duration(milliseconds: 100));
      take.hearChunk(0);
      async.elapse(const Duration(milliseconds: 100));
      take.hearChunk(1);

      take.capture.beginWriting(
        pictureCapturedAtNs: _firstChunkCapturedAtNs + 2 * _chunkNs + 30000000,
      );
      async.elapse(const Duration(milliseconds: 10));
      take.hearChunk(2);

      final List<int> written = take.keep();
      expect(written.length, _samplesPerChunk - 30 * _samplesPerMs);
      expect(_leadingSilence(written), 0);
    });
  });

  test('the sound opens with silence for the samples the microphone captured '
      'after the first frame but before writing began', () {
    fakeAsync((FakeAsync async) {
      final _Take take = _Take(async);
      async.elapse(const Duration(milliseconds: 100));
      take.hearChunk(0);
      async.elapse(const Duration(milliseconds: 100));
      take.hearChunk(1);

      take.capture.beginWriting(
        pictureStartedAgo: const Duration(milliseconds: 90),
        pictureCapturedAtNs: _firstChunkCapturedAtNs + _chunkNs + 50000000,
      );
      async.elapse(const Duration(milliseconds: 10));
      take.hearChunk(2);

      final List<int> written = take.keep();
      expect(_leadingSilence(written), 50 * _samplesPerMs);
      expect(written.length, 50 * _samplesPerMs + _samplesPerChunk);
    });
  });

  test('a take whose capture times cannot be told apart from another '
      'stream lines up by arrival instead', () {
    fakeAsync((FakeAsync async) {
      final _Take take = _Take(async);
      const List<String> twoStreams = <String>['mic', 'meter'];
      async.elapse(const Duration(milliseconds: 100));
      take.hearChunk(0, recorders: twoStreams);
      async.elapse(const Duration(milliseconds: 100));
      take.hearChunk(1, recorders: twoStreams);

      take.capture.beginWriting(
        pictureStartedAgo: const Duration(milliseconds: 90),
        pictureCapturedAtNs: _firstChunkCapturedAtNs + _chunkNs + 50000000,
      );
      async.elapse(const Duration(milliseconds: 10));
      take.hearChunk(2, recorders: twoStreams);

      final List<int> written = take.keep();
      expect(_leadingSilence(written), _samplesIn90Ms);
      expect(written.length, _samplesIn90Ms + 10 * _samplesPerMs);
    });
  });
}
