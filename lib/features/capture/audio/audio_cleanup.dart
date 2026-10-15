import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:rnnoise/rnnoise.dart';

import 'package:field_notes/domain/settings/input_profile.dart';

typedef IsolateRunner = Future<T> Function<T>(FutureOr<T> Function() work);

const int cleanedSampleRate = 48000;
const int _blockFrames = 48000;
const int _wavHeaderBytes = 44;
const int _pcmFormat = 1;
const int _bitsPerSample = 16;
const int _bytesPerSample = 2;
const int _zeroCrossings = 16;
const int _kernelSteps = 1024;
const int _minSample = -32768;
const int _maxSample = 32767;

class AudioCleanupException implements Exception {
  const AudioCleanupException(this.message);

  final String message;

  @override
  String toString() => 'AudioCleanupException: $message';
}

Future<void> cleanAudio({
  required String input,
  required String output,
  required InputProfile profile,
  required int volume,
  IsolateRunner? run,
}) {
  final IsolateRunner runner = run ?? _runInIsolate;
  return runner<void>(() => _cleanFile(input, output, profile, volume));
}

Future<T> _runInIsolate<T>(FutureOr<T> Function() work) => Isolate.run<T>(work);

class _WavLayout {
  const _WavLayout({
    required this.channels,
    required this.sampleRate,
    required this.dataOffset,
    required this.frames,
  });

  final int channels;
  final int sampleRate;
  final int dataOffset;
  final int frames;
}

class _Format {
  const _Format({
    required this.audioFormat,
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
  });

  final int audioFormat;
  final int channels;
  final int sampleRate;
  final int bitsPerSample;
}

void _cleanFile(
  String inputPath,
  String outputPath,
  InputProfile profile,
  int volume,
) {
  final RandomAccessFile source;
  try {
    source = File(inputPath).openSync();
  } on FileSystemException catch (error) {
    throw AudioCleanupException('Could not open $inputPath: ${error.message}');
  }
  try {
    final _WavLayout layout = _readLayout(source);
    _writeCleaned(source, layout, outputPath, profile, volume);
  } on FileSystemException catch (error) {
    throw AudioCleanupException('Could not clean $inputPath: ${error.message}');
  } finally {
    source.closeSync();
  }
}

ByteData _readAt(RandomAccessFile file, int offset, int count) {
  file.setPositionSync(offset);
  final Uint8List bytes = file.readSync(count);
  if (bytes.length != count) {
    throw const AudioCleanupException('The WAV file ends early.');
  }
  return ByteData.sublistView(bytes);
}

String _tag(ByteData bytes, int offset) => String.fromCharCodes(<int>[
  for (int index = offset; index < offset + 4; index += 1)
    bytes.getUint8(index),
]);

_WavLayout _readLayout(RandomAccessFile file) {
  final int length = file.lengthSync();
  if (length < 12) {
    throw const AudioCleanupException('The file is too short to be a WAV.');
  }
  final ByteData riff = _readAt(file, 0, 12);
  if (_tag(riff, 0) != 'RIFF' || _tag(riff, 8) != 'WAVE') {
    throw const AudioCleanupException('The file is not a RIFF/WAVE file.');
  }
  _Format? format;
  int? dataOffset;
  int? dataBytes;
  int position = 12;
  while (position + 8 <= length && (format == null || dataOffset == null)) {
    final ByteData header = _readAt(file, position, 8);
    final String id = _tag(header, 0);
    final int size = header.getUint32(4, Endian.little);
    final int body = position + 8;
    if (id == 'fmt ') {
      if (size < 16 || size > length - body) {
        throw const AudioCleanupException('The fmt chunk is incomplete.');
      }
      final ByteData fmt = _readAt(file, body, 16);
      format = _Format(
        audioFormat: fmt.getUint16(0, Endian.little),
        channels: fmt.getUint16(2, Endian.little),
        sampleRate: fmt.getUint32(4, Endian.little),
        bitsPerSample: fmt.getUint16(14, Endian.little),
      );
    } else if (id == 'data') {
      if (size > length - body) {
        throw AudioCleanupException(
          'The data chunk claims $size bytes but the file holds '
          '${length - body}.',
        );
      }
      if (size.isOdd) {
        throw const AudioCleanupException(
          'The data chunk has an odd byte count.',
        );
      }
      dataOffset = body;
      dataBytes = size;
    }
    position = body + size + (size & 1);
  }
  if (format == null) {
    throw const AudioCleanupException('The WAV file has no fmt chunk.');
  }
  if (dataOffset == null || dataBytes == null) {
    throw const AudioCleanupException('The WAV file has no data chunk.');
  }
  if (format.audioFormat != _pcmFormat) {
    throw AudioCleanupException(
      'The WAV file is not PCM (format ${format.audioFormat}).',
    );
  }
  if (format.bitsPerSample != _bitsPerSample) {
    throw AudioCleanupException(
      'The WAV file is ${format.bitsPerSample}-bit, not 16-bit.',
    );
  }
  if (format.channels == 0) {
    throw const AudioCleanupException('The WAV file has no channels.');
  }
  if (format.sampleRate == 0) {
    throw const AudioCleanupException('The WAV file has a sample rate of 0.');
  }
  return _WavLayout(
    channels: format.channels,
    sampleRate: format.sampleRate,
    dataOffset: dataOffset,
    frames: dataBytes ~/ (format.channels * _bytesPerSample),
  );
}

void _writeCleaned(
  RandomAccessFile source,
  _WavLayout layout,
  String outputPath,
  InputProfile profile,
  int volume,
) {
  final _Resampler? resampler = layout.sampleRate == cleanedSampleRate
      ? null
      : _Resampler(layout.sampleRate, layout.frames);
  final _FrameDenoiser? denoiser = profile == InputProfile.voiceIsolation
      ? _FrameDenoiser()
      : null;
  final double gain = volume / 100;
  final File outputFile = File(outputPath);
  try {
    final RandomAccessFile sink = outputFile.openSync(mode: FileMode.write);
    bool complete = false;
    try {
      sink.writeFromSync(Uint8List(_wavHeaderBytes));
      source.setPositionSync(layout.dataOffset);
      int samples = 0;
      for (int done = 0; done < layout.frames; done += _blockFrames) {
        final int frames = math.min(_blockFrames, layout.frames - done);
        final Float64List mono = _readMono(source, frames, layout.channels);
        final Float64List rated = resampler?.push(mono) ?? mono;
        final Float64List cleaned = denoiser?.push(rated) ?? rated;
        samples += _writeSamples(sink, cleaned, gain);
      }
      if (denoiser != null) {
        samples += _writeSamples(sink, denoiser.finish(), gain);
      }
      sink
        ..setPositionSync(0)
        ..writeFromSync(_header(samples));
      complete = true;
    } finally {
      sink.closeSync();
      if (!complete) {
        _discard(outputFile);
      }
    }
  } finally {
    denoiser?.dispose();
  }
}

void _discard(File file) {
  try {
    file.deleteSync();
  } on FileSystemException {
    return;
  }
}

Float64List _readMono(RandomAccessFile source, int frames, int channels) {
  final int count = frames * channels * _bytesPerSample;
  final Uint8List bytes = source.readSync(count);
  if (bytes.length != count) {
    throw const AudioCleanupException('The WAV data ends early.');
  }
  final ByteData data = ByteData.sublistView(bytes);
  final Float64List mono = Float64List(frames);
  int offset = 0;
  for (int frame = 0; frame < frames; frame += 1) {
    int sum = 0;
    for (int channel = 0; channel < channels; channel += 1) {
      sum += data.getInt16(offset, Endian.little);
      offset += _bytesPerSample;
    }
    mono[frame] = sum / channels;
  }
  return mono;
}

int _writeSamples(RandomAccessFile sink, Float64List samples, double gain) {
  if (samples.isEmpty) {
    return 0;
  }
  final ByteData bytes = ByteData(samples.length * _bytesPerSample);
  for (int index = 0; index < samples.length; index += 1) {
    final int value = (samples[index] * gain).round().clamp(
      _minSample,
      _maxSample,
    );
    bytes.setInt16(index * _bytesPerSample, value, Endian.little);
  }
  sink.writeFromSync(bytes.buffer.asUint8List());
  return samples.length;
}

Uint8List _header(int samples) {
  final int dataBytes = samples * _bytesPerSample;
  final ByteData header = ByteData(_wavHeaderBytes);
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
    ..setUint16(20, _pcmFormat, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, cleanedSampleRate, Endian.little)
    ..setUint32(28, cleanedSampleRate * _bytesPerSample, Endian.little)
    ..setUint16(32, _bytesPerSample, Endian.little)
    ..setUint16(34, _bitsPerSample, Endian.little);
  tag(36, 'data');
  header.setUint32(40, dataBytes, Endian.little);
  return header.buffer.asUint8List();
}

class _Resampler {
  factory _Resampler(int sampleRate, int totalFrames) {
    final double cutoff = math.min(1, cleanedSampleRate / sampleRate);
    final double halfWidth = _zeroCrossings / cutoff;
    final int reach = halfWidth.ceil();
    final Float64List kernel = Float64List(reach * _kernelSteps + 2);
    for (int index = 0; index < kernel.length; index += 1) {
      final double distance = index / _kernelSteps;
      kernel[index] = distance >= halfWidth
          ? 0
          : cutoff * _sinc(cutoff * distance) * _blackman(distance / halfWidth);
    }
    return _Resampler._(
      sampleRate: sampleRate,
      totalFrames: totalFrames,
      outputs:
          (totalFrames * cleanedSampleRate * 2 + sampleRate) ~/
          (2 * sampleRate),
      reach: reach,
      kernel: kernel,
    );
  }

  _Resampler._({
    required this.sampleRate,
    required this.totalFrames,
    required this.outputs,
    required this.reach,
    required this.kernel,
  });

  final int sampleRate;
  final int totalFrames;
  final int outputs;
  final int reach;
  final Float64List kernel;
  Float64List _history = Float64List(0);
  int _historyStart = 0;
  int _next = 0;

  Float64List push(Float64List block) {
    final Float64List history = Float64List(_history.length + block.length)
      ..setAll(0, _history)
      ..setAll(_history.length, block);
    final int historyEnd = _historyStart + history.length;
    final bool ended = historyEnd >= totalFrames;
    final int bound = ended
        ? outputs - _next
        : math.max(
            0,
            math.min(
              outputs - _next,
              (historyEnd * cleanedSampleRate) ~/ sampleRate + 1 - _next,
            ),
          );
    final Float64List produced = Float64List(bound);
    int count = 0;
    while (_next < outputs && count < bound) {
      final int position = _next * sampleRate;
      final int base = position ~/ cleanedSampleRate;
      final double fraction =
          (position % cleanedSampleRate) / cleanedSampleRate;
      if (!ended && base + reach >= historyEnd) {
        break;
      }
      produced[count] = _sampleAt(history, base, fraction);
      count += 1;
      _next += 1;
    }
    final int keepFrom = math.max(
      _historyStart,
      (_next * sampleRate) ~/ cleanedSampleRate - reach,
    );
    final int drop = math.min(keepFrom - _historyStart, history.length);
    _history = Float64List.sublistView(history, drop);
    _historyStart += drop;
    return Float64List.sublistView(produced, 0, count);
  }

  double _sampleAt(Float64List history, int base, double fraction) {
    double sum = 0;
    final int last = math.min(base + reach, totalFrames - 1);
    for (int index = math.max(base - reach + 1, 0); index <= last; index += 1) {
      final double distance = (base - index + fraction).abs() * _kernelSteps;
      final int step = distance.toInt();
      if (step + 1 >= kernel.length) {
        continue;
      }
      final double weight =
          kernel[step] + (kernel[step + 1] - kernel[step]) * (distance - step);
      sum += history[index - _historyStart] * weight;
    }
    return sum;
  }
}

double _sinc(double x) {
  if (x == 0) {
    return 1;
  }
  final double angle = math.pi * x;
  return math.sin(angle) / angle;
}

double _blackman(double position) {
  if (position.abs() >= 1) {
    return 0;
  }
  return 0.42 +
      0.5 * math.cos(math.pi * position) +
      0.08 * math.cos(2 * math.pi * position);
}

class _FrameDenoiser {
  _FrameDenoiser() : _denoiser = Denoiser();

  final Denoiser _denoiser;
  final Float32List _pending = Float32List(Denoiser.frameSize);
  int _filled = 0;

  Float64List push(Float64List samples) {
    final int total = _filled + samples.length;
    final Float64List output = Float64List(total - total % Denoiser.frameSize);
    int written = 0;
    for (int index = 0; index < samples.length; index += 1) {
      _pending[_filled] = samples[index];
      _filled += 1;
      if (_filled == Denoiser.frameSize) {
        output.setAll(written, _denoiser.process(_pending));
        written += Denoiser.frameSize;
        _filled = 0;
      }
    }
    return output;
  }

  Float64List finish() {
    if (_filled == 0) {
      return Float64List(0);
    }
    final int kept = _filled;
    _pending.fillRange(kept, Denoiser.frameSize, 0);
    _filled = 0;
    return Float64List.fromList(
      Float32List.sublistView(_denoiser.process(_pending), 0, kept),
    );
  }

  void dispose() => _denoiser.dispose();
}
