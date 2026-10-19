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
const int _firstCapturedAtNs = 5000000000;
const int _previewChunks = 50;
const int _reopenedChunks = 30;
const int _samplesPerMs = 48;
const Duration _chunkEvery = Duration(milliseconds: 100);

void main() {
  for (final int callAfterMs in <int>[30, 450]) {
    test('a microphone that stops just before the movie starts keeps the '
        'reopened sound, starting on the clock where it was heard '
        '(movie start $callAfterMs ms after the last chunk)', () {
      fakeAsync((FakeAsync async) {
        final FakeMicrophone microphone = FakeMicrophone();
        final FakeLiveAudio sound = FakeLiveAudio(writesFiles: false);
        final StreamController<CapturedAudio> captureTimes =
            StreamController<CapturedAudio>.broadcast();
        final LiveAudioCapture capture = LiveAudioCapture(
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

        void hear(String recorderId, int index, int capturedAtNs) {
          captureTimes.add(
            CapturedAudio(
              recorderId: recorderId,
              firstSample: index * _samplesPerChunk,
              samples: _samplesPerChunk,
              capturedAtNs: capturedAtNs,
            ),
          );
          async.flushMicrotasks();
          microphone.push(pcmAtDbfs(-20, samples: _samplesPerChunk));
          async.flushMicrotasks();
        }

        for (int index = 0; index < _previewChunks; index += 1) {
          async.elapse(_chunkEvery);
          hear('preview', index, _firstCapturedAtNs + index * _chunkNs);
        }

        async.elapse(Duration(milliseconds: callAfterMs));
        final Duration pictureStartedAt = async.elapsed;
        capture.beginWriting(
          pictureCapturedAtNs:
              _firstCapturedAtNs + _previewChunks * _chunkNs + 30000000,
        );

        async.elapse(Duration(milliseconds: 600 - callAfterMs));
        expect(microphone.streamsOpened, 2);

        Duration? reopenedSoundFrom;
        for (int index = 0; index < _reopenedChunks; index += 1) {
          async.elapse(_chunkEvery);
          reopenedSoundFrom ??= async.elapsed - _chunkEvery;
          hear('reopened', index, 9000000000 + index * _chunkNs);
        }

        capture.stop();
        async.flushMicrotasks();

        final List<int> written = <int>[
          for (final Uint8List pcm in sound.appended)
            for (int offset = 0; offset + 1 < pcm.length; offset += 2)
              pcm.buffer
                  .asByteData(pcm.offsetInBytes)
                  .getInt16(offset, Endian.little),
        ];
        final int heard = written.where((int sample) => sample != 0).length;
        final int leadingSilence = written
            .takeWhile((int sample) => sample == 0)
            .length;
        final int silenceOnTheClock =
            (reopenedSoundFrom! - pictureStartedAt).inMicroseconds *
            _samplesPerMs ~/
            1000;

        expect(heard, _reopenedChunks * _samplesPerChunk);
        expect(
          (leadingSilence - silenceOnTheClock).abs(),
          lessThanOrEqualTo(60 * _samplesPerMs),
        );
        capture.dispose();
        captureTimes.close();
        async.flushMicrotasks();
      });
    });
  }
}
