import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/audio/audio_cleanup.dart';
import 'package:flutter_test/flutter_test.dart';

const double _fullScale = 32768;
const int _seed = 4810;

class _Wav {
  const _Wav({
    required this.sampleRate,
    required this.channels,
    required this.frames,
    required this.samples,
  });

  final int sampleRate;
  final int channels;
  final int frames;
  final Int16List samples;
}

Uint8List _header({
  required int sampleRate,
  required int channels,
  required int dataBytes,
  int format = 1,
  int bits = 16,
}) {
  final ByteData header = ByteData(44);
  void tag(int offset, String value) {
    for (int index = 0; index < 4; index += 1) {
      header.setUint8(offset + index, value.codeUnitAt(index));
    }
  }

  tag(0, 'RIFF');
  header.setUint32(4, 36 + dataBytes, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  header
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, format, Endian.little)
    ..setUint16(22, channels, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * channels * bits ~/ 8, Endian.little)
    ..setUint16(32, channels * bits ~/ 8, Endian.little)
    ..setUint16(34, bits, Endian.little);
  tag(36, 'data');
  header.setUint32(40, dataBytes, Endian.little);
  return header.buffer.asUint8List();
}

void _writeWav(
  String path, {
  required int sampleRate,
  required int channels,
  required int frames,
  required int Function(int frame, int channel) sample,
}) {
  final RandomAccessFile file = File(path).openSync(mode: FileMode.write);
  try {
    file.writeFromSync(
      _header(
        sampleRate: sampleRate,
        channels: channels,
        dataBytes: frames * channels * 2,
      ),
    );
    const int piece = 44100;
    for (int start = 0; start < frames; start += piece) {
      final int count = math.min(piece, frames - start);
      final ByteData bytes = ByteData(count * channels * 2);
      int offset = 0;
      for (int frame = start; frame < start + count; frame += 1) {
        for (int channel = 0; channel < channels; channel += 1) {
          bytes.setInt16(offset, sample(frame, channel), Endian.little);
          offset += 2;
        }
      }
      file.writeFromSync(bytes.buffer.asUint8List());
    }
  } finally {
    file.closeSync();
  }
}

_Wav _readWav(String path, {bool samples = true}) {
  final RandomAccessFile file = File(path).openSync();
  try {
    final int length = file.lengthSync();
    final ByteData riff = ByteData.sublistView(file.readSync(12));
    expect(String.fromCharCodes(riff.buffer.asUint8List(0, 4)), 'RIFF');
    expect(String.fromCharCodes(riff.buffer.asUint8List(8, 4)), 'WAVE');
    int position = 12;
    int? sampleRate;
    int? channels;
    int? bits;
    int? format;
    int? dataOffset;
    int? dataBytes;
    while (position + 8 <= length) {
      file.setPositionSync(position);
      final ByteData chunk = ByteData.sublistView(file.readSync(8));
      final String id = String.fromCharCodes(chunk.buffer.asUint8List(0, 4));
      final int size = chunk.getUint32(4, Endian.little);
      if (id == 'fmt ') {
        final ByteData fmt = ByteData.sublistView(file.readSync(16));
        format = fmt.getUint16(0, Endian.little);
        channels = fmt.getUint16(2, Endian.little);
        sampleRate = fmt.getUint32(4, Endian.little);
        bits = fmt.getUint16(14, Endian.little);
      } else if (id == 'data') {
        dataOffset = position + 8;
        dataBytes = size;
      }
      position += 8 + size + (size & 1);
    }
    expect(format, 1);
    expect(bits, 16);
    expect(dataOffset, isNotNull);
    expect(dataOffset! + dataBytes!, lessThanOrEqualTo(length));
    final int frames = dataBytes ~/ (channels! * 2);
    Int16List values = Int16List(0);
    if (samples) {
      file.setPositionSync(dataOffset);
      final ByteData data = ByteData.sublistView(file.readSync(dataBytes));
      values = Int16List(frames * channels);
      for (int index = 0; index < values.length; index += 1) {
        values[index] = data.getInt16(index * 2, Endian.little);
      }
    }
    return _Wav(
      sampleRate: sampleRate!,
      channels: channels,
      frames: frames,
      samples: values,
    );
  } finally {
    file.closeSync();
  }
}

double _rms(Iterable<int> samples) {
  double sum = 0;
  int count = 0;
  for (final int sample in samples) {
    sum += sample * sample;
    count += 1;
  }
  return math.sqrt(sum / count);
}

double _db(double ratio) => 20 * math.log(ratio) / math.ln10;

double _frequency(Int16List samples, int sampleRate) {
  int crossings = 0;
  for (int index = 1; index < samples.length; index += 1) {
    if (samples[index - 1] < 0 && samples[index] >= 0) {
      crossings += 1;
    }
  }
  return crossings / (samples.length / sampleRate);
}

int Function(int frame, int channel) _sine({
  required double hertz,
  required int sampleRate,
  required double dbfs,
  bool Function(int channel)? on,
}) {
  final double amplitude = _fullScale * math.pow(10, dbfs / 20);
  return (int frame, int channel) {
    if (on != null && !on(channel)) {
      return 0;
    }
    return (amplitude * math.sin(2 * math.pi * hertz * frame / sampleRate))
        .round();
  };
}

Future<T> _inline<T>(FutureOr<T> Function() work) async => work();

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('audio_cleanup_test_');
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  String inRoot(String name) => '${root.path}/$name';

  test('a ten-minute take is cleaned without holding it in memory', () async {
    final String input = inRoot('ten-minutes.wav');
    final String output = inRoot('ten-minutes-clean.wav');
    _writeWav(
      input,
      sampleRate: 44100,
      channels: 1,
      frames: 600 * 44100,
      sample: _sine(hertz: 1000, sampleRate: 44100, dbfs: -12),
    );

    final int before = ProcessInfo.currentRss;
    await cleanAudio(
      input: input,
      output: output,
      profile: InputProfile.studio,
      volume: 50,
    );
    final int peak = ProcessInfo.maxRss;

    final _Wav cleaned = _readWav(output, samples: false);
    expect(cleaned.sampleRate, 48000);
    expect(cleaned.channels, 1);
    expect(cleaned.frames, closeTo(28800000, 48));
    expect(peak - before, lessThan(64 * 1024 * 1024));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('a 48 kHz mono take keeps its length and loses its noise with Voice Isolation', () async {
    final String input = inRoot('noise.wav');
    final String output = inRoot('noise-clean.wav');
    final math.Random random = math.Random(_seed);
    final double spread = _fullScale * math.pow(10, -30 / 20);
    double gaussian() {
      final double u1 = 1 - random.nextDouble();
      final double u2 = random.nextDouble();
      return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
    }

    _writeWav(
      input,
      sampleRate: 48000,
      channels: 1,
      frames: 3 * 48000,
      sample: (int frame, int channel) =>
          (gaussian() * spread).round().clamp(-32768, 32767),
    );

    await cleanAudio(
      input: input,
      output: output,
      profile: InputProfile.voiceIsolation,
      volume: 100,
    );

    final _Wav source = _readWav(input);
    final _Wav cleaned = _readWav(output);
    expect(cleaned.sampleRate, 48000);
    expect(cleaned.channels, 1);
    expect(cleaned.frames, 144000);
    final double inputRms = _rms(source.samples.skip(4800));
    final double outputRms = _rms(cleaned.samples.skip(4800));
    expect(_db(inputRms / _fullScale), closeTo(-30, 0.5));
    expect(_db(outputRms / inputRms), lessThanOrEqualTo(-10));
  });

  test('a 44.1 kHz stereo take becomes 48 kHz mono', () async {
    final String input = inRoot('stereo.wav');
    final String output = inRoot('stereo-clean.wav');
    _writeWav(
      input,
      sampleRate: 44100,
      channels: 2,
      frames: 2 * 44100,
      sample: _sine(hertz: 1000, sampleRate: 44100, dbfs: -12),
    );

    await cleanAudio(
      input: input,
      output: output,
      profile: InputProfile.studio,
      volume: 120,
      run: _inline,
    );

    final _Wav source = _readWav(input);
    final _Wav cleaned = _readWav(output);
    expect(cleaned.sampleRate, 48000);
    expect(cleaned.channels, 1);
    expect(cleaned.frames, closeTo(96000, 48));
    expect(_frequency(cleaned.samples, 48000), closeTo(1000, 10));
    final double inputRms = _rms(<int>[
      for (int index = 0; index < source.samples.length; index += 2)
        source.samples[index],
    ]);
    expect(_db(_rms(cleaned.samples) / (inputRms * 1.2)), closeTo(0, 0.2));
  });

  test(
    'a take with three channels at another rate becomes 48 kHz mono',
    () async {
      final String input = inRoot('three.wav');
      final String output = inRoot('three-clean.wav');
      _writeWav(
        input,
        sampleRate: 32000,
        channels: 3,
        frames: 32000,
        sample: _sine(
          hertz: 440,
          sampleRate: 32000,
          dbfs: -12,
          on: (int channel) => channel == 0,
        ),
      );

      await cleanAudio(
        input: input,
        output: output,
        profile: InputProfile.studio,
        volume: 50,
        run: _inline,
      );

      final _Wav source = _readWav(input);
      final _Wav cleaned = _readWav(output);
      expect(cleaned.sampleRate, 48000);
      expect(cleaned.channels, 1);
      expect(cleaned.frames, closeTo(48000, 48));
      expect(_frequency(cleaned.samples, 48000), closeTo(440, 4.4));
      final double channelRms = _rms(<int>[
        for (int index = 0; index < source.samples.length; index += 3)
          source.samples[index],
      ]);
      expect(
        _db(_rms(cleaned.samples) / (channelRms / 3 * 0.5)),
        closeTo(0, 0.3),
      );
    },
  );

  test('volume 0 gives silence and loud gain clamps', () async {
    final String input = inRoot('square.wav');
    int square(int frame, int channel) =>
        (frame ~/ 240).isEven ? 32767 : -32768;
    _writeWav(
      input,
      sampleRate: 48000,
      channels: 1,
      frames: 48000,
      sample: square,
    );

    final String silent = inRoot('square-0.wav');
    await cleanAudio(
      input: input,
      output: silent,
      profile: InputProfile.studio,
      volume: 0,
      run: _inline,
    );
    final _Wav quiet = _readWav(silent);
    expect(quiet.frames, 48000);
    expect(quiet.samples.every((int sample) => sample == 0), isTrue);

    final String loud = inRoot('square-200.wav');
    await cleanAudio(
      input: input,
      output: loud,
      profile: InputProfile.studio,
      volume: 200,
      run: _inline,
    );
    final _Wav clamped = _readWav(loud);
    expect(clamped.frames, 48000);
    for (int frame = 0; frame < clamped.frames; frame += 1) {
      final int sample = clamped.samples[frame];
      expect(sample == -32768 || sample == 32767, isTrue);
      expect(sample, square(frame, 0) > 0 ? 32767 : -32768);
    }
  });

  test('a malformed WAV is refused', () async {
    Uint8List wav({
      int format = 1,
      int bits = 16,
      int channels = 1,
      int sampleRate = 48000,
      int dataBytes = 4800,
      int? claimedDataBytes,
      bool fmt = true,
      bool data = true,
    }) {
      final Uint8List full = _header(
        sampleRate: sampleRate,
        channels: channels,
        dataBytes: claimedDataBytes ?? dataBytes,
        format: format,
        bits: bits,
      );
      final BytesBuilder builder = BytesBuilder()..add(full.sublist(0, 12));
      if (fmt) {
        builder.add(full.sublist(12, 36));
      }
      if (data) {
        builder
          ..add(full.sublist(36, 44))
          ..add(Uint8List(dataBytes + (dataBytes & 1)));
      } else {
        builder
          ..add(<int>[0x4C, 0x49, 0x53, 0x54, 4, 0, 0, 0])
          ..add(<int>[0x49, 0x4E, 0x46, 0x4F]);
      }
      return builder.takeBytes();
    }

    final Map<String, Uint8List> malformed = <String, Uint8List>{
      '8-bit PCM': wav(bits: 8),
      'float PCM': wav(format: 3, bits: 32),
      'no fmt chunk': wav(fmt: false),
      'no data chunk': wav(data: false),
      'a 3-byte data chunk': wav(dataBytes: 3),
      'sample rate 0': wav(sampleRate: 0),
      '0 channels': wav(channels: 0),
      'a data chunk claiming 96000 bytes in a file holding 4800': wav(
        claimedDataBytes: 96000,
      ),
    };

    for (final MapEntry<String, Uint8List> entry in malformed.entries) {
      final String input = inRoot('malformed.wav');
      final String output = inRoot('malformed-clean.wav');
      File(input).writeAsBytesSync(entry.value);
      await expectLater(
        cleanAudio(
          input: input,
          output: output,
          profile: InputProfile.studio,
          volume: 100,
          run: _inline,
        ),
        throwsA(isA<AudioCleanupException>()),
        reason: entry.key,
      );
      expect(File(output).existsSync(), isFalse, reason: entry.key);
    }
  });

  test('cleanup work is handed to the isolate runner', () async {
    final String input = inRoot('voice.wav');
    _writeWav(
      input,
      sampleRate: 48000,
      channels: 1,
      frames: 4800,
      sample: _sine(hertz: 220, sampleRate: 48000, dbfs: -20),
    );
    int handed = 0;
    Future<T> recording<T>(FutureOr<T> Function() work) async {
      handed += 1;
      return work();
    }

    Future<T> skipping<T>(FutureOr<T> Function() work) async {
      handed += 1;
      return null as T;
    }

    await cleanAudio(
      input: input,
      output: inRoot('voice-1.wav'),
      profile: InputProfile.voiceIsolation,
      volume: 100,
      run: recording,
    );
    expect(handed, 1);
    await cleanAudio(
      input: input,
      output: inRoot('voice-2.wav'),
      profile: InputProfile.voiceIsolation,
      volume: 100,
      run: recording,
    );
    expect(handed, 2);
    expect(_readWav(inRoot('voice-1.wav')).frames, 4800);
    expect(_readWav(inRoot('voice-2.wav')).frames, 4800);

    await cleanAudio(
      input: input,
      output: inRoot('voice-3.wav'),
      profile: InputProfile.voiceIsolation,
      volume: 100,
      run: skipping,
    );
    expect(handed, 3);
    expect(File(inRoot('voice-3.wav')).existsSync(), isFalse);
  });
}
