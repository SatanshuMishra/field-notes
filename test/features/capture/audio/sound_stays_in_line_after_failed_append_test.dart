import 'dart:io';
import 'dart:typed_data';

import 'package:field_notes/data/media/live_audio_channel.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/live_audio_capture.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'live_audio_test_support.dart';

const int _chunk = 4800;
const int _chunksBefore = 3;
const int _chunksAfter = 3;
const int _heard = (_chunksBefore + 1 + _chunksAfter) * _chunk;
const int _bytesPerSample = 2;

int _valueAt(int index) => index % 30000 + 1;

Uint8List _ramp(int from, int samples) {
  final ByteData data = ByteData(samples * _bytesPerSample);
  for (int index = 0; index < samples; index += 1) {
    data.setInt16(
      index * _bytesPerSample,
      _valueAt(from + index),
      Endian.little,
    );
  }
  return data.buffer.asUint8List();
}

class _TimelineEncoder extends Fake implements LiveEncoder {
  _TimelineEncoder(this.takenBeforeFailing);

  final int takenBeforeFailing;
  final BytesBuilder file = BytesBuilder();
  bool failNext = false;

  int get samples => file.length ~/ _bytesPerSample;

  int sampleAt(int index) =>
      ByteData.sublistView(file.toBytes())
          .getInt16(index * _bytesPerSample, Endian.little);

  @override
  Future<int> open({
    required String path,
    required int sampleRate,
    required int channels,
    required int bitRate,
  }) async {
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(<int>[1]);
    return 7;
  }

  @override
  Future<void> append(int id, Uint8List pcm) async {
    if (!failNext) {
      file.add(pcm);
      return;
    }
    failNext = false;
    file.add(
      Uint8List.sublistView(pcm, 0, takenBeforeFailing * _bytesPerSample),
    );
    throw LiveAudioException(
      appendPcmMethod,
      PlatformException(
        code: 'encode-failed',
        message: 'The encoder stopped taking audio',
        details: takenBeforeFailing,
      ),
    );
  }

  @override
  Future<String> close(int id) async => '/unused.m4a';

  @override
  Future<void> cancel(int id) async {}
}

Future<void> _settle() async {
  for (int turn = 0; turn < 20; turn += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<(_TimelineEncoder, LiveAudioTake)> _recordWithOneFailedAppend(
  int takenBeforeFailing,
) async {
  final Directory root = Directory.systemTemp.createTempSync('sound_shift_');
  addTearDown(() => root.deleteSync(recursive: true));
  final FakeMicrophone mic = FakeMicrophone();
  final _TimelineEncoder encoder = _TimelineEncoder(takenBeforeFailing);
  final LiveAudioCapture capture = LiveAudioCapture(
    recorderFactory: () => mic,
    encoder: encoder,
    chainRunner: passThroughChain,
  );
  await capture.start(
    input: const AudioInput(id: null, label: 'System default'),
    profile: InputProfile.studio,
    volume: 100,
    path: '${root.path}/sound.m4a',
  );
  int heard = 0;
  void hear() {
    mic.push(_ramp(heard, _chunk));
    heard += _chunk;
  }

  for (int index = 0; index < _chunksBefore; index += 1) {
    hear();
  }
  await _settle();
  encoder.failNext = true;
  hear();
  await _settle();
  for (int index = 0; index < _chunksAfter; index += 1) {
    hear();
  }
  await _settle();
  return (encoder, await capture.stop());
}

void _expectInLine(_TimelineEncoder encoder, LiveAudioTake take) {
  expect(
    encoder.samples,
    _heard,
    reason: 'the file holds as many samples as were heard',
  );
  expect(take.durationMs, _heard * 1000 ~/ liveAudioSampleRate);
  for (int index = (_chunksBefore + 1) * _chunk; index < _heard; index += 1) {
    expect(
      encoder.sampleAt(index),
      _valueAt(index),
      reason: 'the sample heard at $index is written at $index',
    );
  }
}

void main() {
  test('a failed append that took nothing keeps later sound at the time it was heard', () async {
    final (_TimelineEncoder encoder, LiveAudioTake take) =
        await _recordWithOneFailedAppend(0);
    _expectInLine(encoder, take);
  });

  test('a failed append that took part of its chunk keeps later sound at the time it was heard', () async {
    final (_TimelineEncoder encoder, LiveAudioTake take) =
        await _recordWithOneFailedAppend(_chunk ~/ 2);
    _expectInLine(encoder, take);
  });
}
