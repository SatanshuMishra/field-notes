import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:field_notes/data/media/live_audio_channel.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/live_audio_capture.dart';
import 'package:field_notes/features/capture/voice/record_voice_recorder.dart';
import 'package:field_notes/features/capture/voice/voice_level.dart';
import 'package:field_notes/features/capture/voice/voice_recorder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';

class _StreamingAudioRecorder extends Fake implements AudioRecorder {
  final StreamController<Uint8List> chunks = StreamController<Uint8List>();
  RecordConfig? streamedWith;
  int pauses = 0;
  int resumes = 0;

  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    streamedWith = config;
    return chunks.stream;
  }

  @override
  Future<void> pause() async {
    pauses += 1;
  }

  @override
  Future<void> resume() async {
    resumes += 1;
  }

  @override
  Future<String?> stop() async {
    await chunks.close();
    return null;
  }

  @override
  Future<void> cancel() async {
    await chunks.close();
  }

  @override
  Future<void> dispose() async {}
}

class _FakeLiveEncoder extends Fake implements LiveEncoder {
  _FakeLiveEncoder(this.output);

  final String output;
  final List<({String path, int sampleRate, int channels, int bitRate})>
  opened = <({String path, int sampleRate, int channels, int bitRate})>[];
  final List<List<int>> appended = <List<int>>[];
  int closes = 0;
  int cancels = 0;

  @override
  Future<int> open({
    required String path,
    required int sampleRate,
    required int channels,
    required int bitRate,
  }) async {
    opened.add((
      path: path,
      sampleRate: sampleRate,
      channels: channels,
      bitRate: bitRate,
    ));
    return 7;
  }

  @override
  Future<void> append(int id, Uint8List pcm) async {
    appended.add(_samples(pcm));
  }

  @override
  Future<String> close(int id) async {
    closes += 1;
    return output;
  }

  @override
  Future<void> cancel(int id) async {
    cancels += 1;
  }
}

class _DelayingChain implements RunningVoiceChain {
  List<int> _held = List<int>.filled(960, 0);

  @override
  int get delaySamples => 960;

  @override
  Future<Uint8List> process(Uint8List pcm16) async {
    final List<int> joined = <int>[..._held, ..._samples(pcm16)];
    final int count = pcm16.lengthInBytes ~/ 2;
    _held = joined.sublist(count);
    return _pcm(joined.sublist(0, count));
  }

  @override
  Future<Uint8List> flush() async {
    final List<int> rest = _held;
    _held = <int>[];
    return _pcm(rest);
  }

  @override
  Future<void> close() async {}
}

Uint8List _pcm(List<int> samples) {
  final ByteData data = ByteData(samples.length * 2);
  for (int index = 0; index < samples.length; index += 1) {
    data.setInt16(index * 2, samples[index], Endian.little);
  }
  return data.buffer.asUint8List();
}

List<int> _samples(Uint8List pcm) {
  final ByteData data = ByteData.sublistView(pcm);
  return <int>[
    for (int index = 0; index < pcm.lengthInBytes ~/ 2; index += 1)
      data.getInt16(index * 2, Endian.little),
  ];
}

VoiceChainRunner _fixedChain(RunningVoiceChain chain) =>
    ({required InputProfile profile, required int volume}) async => chain;

Future<Directory> _tempDirectory() async {
  final Directory temp = await Directory.systemTemp.createTemp(
    'live_voice_test_',
  );
  addTearDown(() => temp.delete(recursive: true));
  return temp;
}

Future<
  ({
    RecordVoiceRecorder recorder,
    _StreamingAudioRecorder microphone,
    _FakeLiveEncoder encoder,
    Directory temp,
  })
>
_liveRecorder({
  required InputProfile profile,
  required int volume,
  VoiceChainRunner chainRunner = runVoiceChainInline,
  AudioInput input = const AudioInput(id: null, label: 'System default'),
}) async {
  final Directory temp = await _tempDirectory();
  final _StreamingAudioRecorder microphone = _StreamingAudioRecorder();
  final _FakeLiveEncoder encoder = _FakeLiveEncoder(
    p.join(temp.path, 'encoded_take.m4a'),
  );
  final RecordVoiceRecorder recorder = RecordVoiceRecorder(
    recorder: microphone,
    encoder: encoder,
    chainRunner: chainRunner,
    temporaryDirectory: () async => temp,
    resolveInput: () async => input,
    resolveProcessing: () async => (profile: profile, volume: volume),
  );
  addTearDown(recorder.dispose);
  return (
    recorder: recorder,
    microphone: microphone,
    encoder: encoder,
    temp: temp,
  );
}

void main() {
  test('chunks reach the encoder cleaned and in order', () async {
    final live = await _liveRecorder(
      profile: InputProfile.studio,
      volume: 200,
      chainRunner: runVoiceChainInIsolate,
    );

    await live.recorder.start();
    live.microphone.chunks
      ..add(_pcm(<int>[1000, -2000, 20000]))
      ..add(_pcm(<int>[-20000, 5, 300]))
      ..add(_pcm(<int>[16384, -16384, 0]));
    await live.recorder.stop();

    expect(live.encoder.opened, hasLength(1));
    expect(live.encoder.opened.single.sampleRate, 48000);
    expect(live.encoder.opened.single.channels, 1);
    expect(live.encoder.opened.single.bitRate, 96000);
    expect(p.isWithin(live.temp.path, live.encoder.opened.single.path), isTrue);
    expect(live.encoder.appended, <List<int>>[
      <int>[2000, -4000, 32767],
      <int>[-32768, 10, 600],
      <int>[32767, -32768, 0],
    ]);
    expect(live.encoder.closes, 1);
  });

  test('the stream is configured for the chain', () async {
    final live = await _liveRecorder(
      profile: InputProfile.studio,
      volume: 100,
      input: const AudioInput(id: 'mic-2', label: 'USB microphone'),
    );

    await live.recorder.start();

    final RecordConfig config = live.microphone.streamedWith!;
    expect(config.encoder, AudioEncoder.pcm16bits);
    expect(config.sampleRate, 48000);
    expect(config.numChannels, 1);
    expect(config.device?.id, 'mic-2');
    expect(
      config.androidConfig.audioSource,
      AndroidAudioSource.voiceRecognition,
    );

    await live.recorder.cancel();
  });

  test('the file lines up with the microphone', () async {
    final live = await _liveRecorder(
      profile: InputProfile.voiceIsolation,
      volume: 100,
      chainRunner: _fixedChain(_DelayingChain()),
    );

    await live.recorder.start();
    for (int chunk = 0; chunk < 10; chunk += 1) {
      live.microphone.chunks.add(
        _pcm(<int>[
          for (int index = 1; index <= 960; index += 1) chunk * 960 + index,
        ]),
      );
    }
    await live.recorder.stop();

    final List<int> written = <int>[
      for (final List<int> chunk in live.encoder.appended) ...chunk,
    ];
    expect(written.first, 1);
    expect(written, hasLength(9600));
    expect(written.last, 9600);
  });

  test('paused chunks are not recorded', () async {
    final live = await _liveRecorder(profile: InputProfile.studio, volume: 100);

    await live.recorder.start();
    live.microphone.chunks.add(_pcm(<int>[11, 12, 13]));
    await pumpEventQueue();
    await live.recorder.pause();
    live.microphone.chunks.add(_pcm(<int>[21, 22, 23]));
    await pumpEventQueue();
    await live.recorder.resume();
    live.microphone.chunks.add(_pcm(<int>[31, 32, 33]));
    await pumpEventQueue();
    await live.recorder.stop();

    expect(live.encoder.appended, <List<int>>[
      <int>[11, 12, 13],
      <int>[31, 32, 33],
    ]);
    expect(live.microphone.pauses, 1);
    expect(live.microphone.resumes, 1);
  });

  test('the level follows the processed sound', () async {
    final live = await _liveRecorder(profile: InputProfile.studio, volume: 100);
    final List<double> levels = <double>[];
    final StreamSubscription<double> subscription = live.recorder.level.listen(
      levels.add,
    );
    addTearDown(subscription.cancel);

    await live.recorder.start();
    live.microphone.chunks.add(
      _pcm(<int>[
        for (int index = 0; index < 4800; index += 1)
          index.isEven ? 1036 : -1036,
      ]),
    );
    await pumpEventQueue();

    expect(levels, hasLength(1));
    expect(levels.single, closeTo(voiceLevelFromDbfs(-30), 0.001));
    expect(voiceLevelFromDbfs(-30), 0.5);

    await live.recorder.cancel();
  });

  test('stop returns the encoded take', () async {
    final live = await _liveRecorder(profile: InputProfile.studio, volume: 100);

    await live.recorder.start();
    for (int chunk = 0; chunk < 32; chunk += 1) {
      live.microphone.chunks.add(_pcm(List<int>.filled(4800, 200)));
    }
    final VoiceRecording recording = await live.recorder.stop();

    final CaptureMedia media = recording.media;
    expect(media, isA<CaptureFile>());
    final CaptureFile file = media as CaptureFile;
    expect(file.file.path, p.join(live.temp.path, 'encoded_take.m4a'));
    expect(file.mime, 'audio/mp4');
    expect(file.durationMs, closeTo(3200, 50));
    expect(recording.durationMs, closeTo(3200, 50));
  });
}
