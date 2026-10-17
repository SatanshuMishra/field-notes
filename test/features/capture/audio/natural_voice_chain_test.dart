import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/audio/natural_voice_chain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rnnoise/rnnoise.dart';

const String _fixturePath = 'test/fixtures/audio/voice_over_fan_48k.wav';
const int _wavHeaderBytes = 44;
const int _rate = 48000;
const double _fullScale = 32768;
const int _rnnoiseFrame = 480;
const List<(int, int)> _pauseSpans = <(int, int)>[
  (182400, 240000),
  (403200, 499200),
  (700800, 772800),
  (931200, 979200),
];
const (int, int) _longestPause = (403200, 499200);
const int _pauseGuard = 9600;
const int _levelWindow = 4800;
const int _burstStart = 576000;
const int _burstLength = 9600;
const double _burstFrequency = 7000;
const int _burstRamp = 240;
const int _chunkSamples = 4800;
const int _noiseSeed = 20261017;

const Set<NaturalVoiceStage> _deEsserAndLimiter = <NaturalVoiceStage>{
  NaturalVoiceStage.deEsser,
  NaturalVoiceStage.limiter,
};
const Set<NaturalVoiceStage> _everyStage = <NaturalVoiceStage>{
  NaturalVoiceStage.deEsser,
  NaturalVoiceStage.leveller,
  NaturalVoiceStage.limiter,
};

Float64List _readFixture() {
  final Uint8List bytes = File(_fixturePath).readAsBytesSync();
  final ByteData data = ByteData.sublistView(bytes);
  final int count = (bytes.length - _wavHeaderBytes) ~/ 2;
  final Float64List samples = Float64List(count);
  for (int index = 0; index < count; index += 1) {
    samples[index] = data
        .getInt16(_wavHeaderBytes + index * 2, Endian.little)
        .toDouble();
  }
  return samples;
}

Uint8List _pcm(Float64List samples) {
  final ByteData data = ByteData(samples.length * 2);
  for (int index = 0; index < samples.length; index += 1) {
    data.setInt16(
      index * 2,
      samples[index].round().clamp(-32768, 32767),
      Endian.little,
    );
  }
  return data.buffer.asUint8List();
}

Float64List _samplesOf(List<Uint8List> chunks) {
  final int total = chunks.fold<int>(
    0,
    (int sum, Uint8List chunk) => sum + chunk.length ~/ 2,
  );
  final Float64List samples = Float64List(total);
  int at = 0;
  for (final Uint8List chunk in chunks) {
    final ByteData data = ByteData.sublistView(chunk);
    for (int index = 0; index < chunk.length ~/ 2; index += 1) {
      samples[at] = data.getInt16(index * 2, Endian.little).toDouble();
      at += 1;
    }
  }
  return samples;
}

NaturalVoiceChain _isolation(
  Set<NaturalVoiceStage> stages, {
  int attenuationLimitDb = 15,
}) {
  final NaturalVoiceChain chain = NaturalVoiceChain(
    profile: InputProfile.voiceIsolation,
    volume: 100,
    attenuationLimitDb: attenuationLimitDb,
    stages: stages,
  );
  addTearDown(chain.dispose);
  return chain;
}

Float64List _runAll(NaturalVoiceChain chain, Float64List input) {
  final Uint8List bytes = _pcm(input);
  final List<Uint8List> chunks = <Uint8List>[];
  for (int start = 0; start < bytes.length; start += _chunkSamples * 2) {
    chunks.add(
      chain.process(
        Uint8List.sublistView(
          bytes,
          start,
          math.min(bytes.length, start + _chunkSamples * 2),
        ),
      ),
    );
  }
  chunks.add(chain.flush());
  return _samplesOf(chunks);
}

Float64List _runAligned(NaturalVoiceChain chain, Float64List input) {
  final Float64List output = _runAll(chain, input);
  expect(output.length, input.length + chain.delaySamples);
  return Float64List.sublistView(output, chain.delaySamples);
}

double _decibels(double power) => 10 * math.log(power) / math.ln10;

double _rmsDbfs(Float64List samples, int start, int end) {
  double sum = 0;
  for (int index = start; index < end; index += 1) {
    sum += samples[index] * samples[index];
  }
  return _decibels(sum / (end - start) / (_fullScale * _fullScale));
}

double _pauseRmsDbfs(Float64List samples) {
  double sum = 0;
  int count = 0;
  for (final (int start, int end) in _pauseSpans) {
    for (int index = start + _pauseGuard; index < end - _pauseGuard; index++) {
      sum += samples[index] * samples[index];
      count += 1;
    }
  }
  return _decibels(sum / count / (_fullScale * _fullScale));
}

Float64List _biquad(Float64List input, List<double> b, List<double> a) {
  final Float64List output = Float64List(input.length);
  double x1 = 0;
  double x2 = 0;
  double y1 = 0;
  double y2 = 0;
  for (int index = 0; index < input.length; index += 1) {
    final double x = input[index];
    final double y = b[0] * x + b[1] * x1 + b[2] * x2 - a[0] * y1 - a[1] * y2;
    x2 = x1;
    x1 = x;
    y2 = y1;
    y1 = y;
    output[index] = y;
  }
  return output;
}

double _integratedLufs(Float64List samples) {
  final Float64List normalised = Float64List.fromList(<double>[
    for (final double sample in samples) sample / _fullScale,
  ]);
  final Float64List shelved = _biquad(
    normalised,
    <double>[1.53512485958697, -2.69169618940638, 1.19839281085285],
    <double>[-1.69065929318241, 0.73248077421585],
  );
  final Float64List weighted = _biquad(
    shelved,
    <double>[1.0, -2.0, 1.0],
    <double>[-1.99004745483398, 0.99007225036621],
  );
  const int block = 19200;
  const int hop = 4800;
  final List<double> powers = <double>[
    for (int start = 0; start + block <= weighted.length; start += hop)
      <double>[
            for (int index = start; index < start + block; index += 1)
              weighted[index] * weighted[index],
          ].reduce((double a, double b) => a + b) /
          block,
  ];
  double lufs(double power) => -0.691 + _decibels(power);
  double mean(List<double> values) =>
      values.reduce((double a, double b) => a + b) / values.length;
  final List<double> audible = powers
      .where((double power) => lufs(power) > -70)
      .toList();
  final double relativeGate = lufs(mean(audible)) - 10;
  return lufs(
    mean(audible.where((double power) => lufs(power) > relativeGate).toList()),
  );
}

Float64List _oversampledFourTimes(Float64List samples) {
  const int factor = 4;
  const int zeroCrossings = 24;
  const int half = zeroCrossings * factor;
  final Float64List kernel = Float64List(2 * half + 1);
  for (int index = -half; index <= half; index += 1) {
    final double time = index / factor;
    final double sinc = index == 0
        ? 1
        : math.sin(math.pi * time) / (math.pi * time);
    final double window =
        0.42 +
        0.5 * math.cos(math.pi * index / half) +
        0.08 * math.cos(2 * math.pi * index / half);
    kernel[index + half] = sinc * window;
  }
  final Float64List output = Float64List(samples.length * factor);
  for (int position = 0; position < output.length; position += 1) {
    double sum = 0;
    final int first = math.max(0, (position - half + factor - 1) ~/ factor);
    final int last = math.min(samples.length - 1, (position + half) ~/ factor);
    for (int source = first; source <= last; source += 1) {
      sum += samples[source] * kernel[source * factor - position + half];
    }
    output[position] = sum;
  }
  return output;
}

double _toneEnergy(Float64List samples, int start, int end, double frequency) {
  final double coefficient = 2 * math.cos(2 * math.pi * frequency / _rate);
  double previous = 0;
  double beforePrevious = 0;
  for (int index = start; index < end; index += 1) {
    final double current =
        samples[index] + coefficient * previous - beforePrevious;
    beforePrevious = previous;
    previous = current;
  }
  return previous * previous +
      beforePrevious * beforePrevious -
      coefficient * previous * beforePrevious;
}

Float64List _rawRnnoise(Float64List input) {
  final Denoiser denoiser = Denoiser();
  addTearDown(denoiser.dispose);
  final Float64List output = Float64List(input.length);
  final Float32List frame = Float32List(_rnnoiseFrame);
  for (int start = 0; start + _rnnoiseFrame <= input.length; start += 480) {
    for (int index = 0; index < _rnnoiseFrame; index += 1) {
      frame[index] = input[start + index];
    }
    output.setAll(start, denoiser.process(frame));
  }
  return output;
}

Float64List _scaled(Float64List samples, double gain) => Float64List.fromList(
  <double>[for (final double sample in samples) sample * gain],
);

double _peak(Float64List samples) => samples.fold<double>(
  0,
  (double peak, double sample) => math.max(peak, sample.abs()),
);

void main() {
  test('pauses keep the room at the attenuation limit', () {
    final Float64List input = _readFixture();
    final Float64List output = _runAligned(
      _isolation(_deEsserAndLimiter),
      input,
    );

    final double inputPause = _pauseRmsDbfs(input);
    expect(inputPause, closeTo(-45, 1));
    expect(_pauseRmsDbfs(output), closeTo(inputPause - 15, 2));
    for (final (int start, int end) in _pauseSpans) {
      for (
        int window = start + _pauseGuard;
        window + _levelWindow <= end - _pauseGuard;
        window += _levelWindow
      ) {
        expect(
          _rmsDbfs(output, window, window + _levelWindow),
          greaterThanOrEqualTo(-75),
        );
      }
    }
  });

  test('full removal is no longer possible', () {
    final Float64List input = _readFixture();
    final Float64List output = _runAligned(
      _isolation(_deEsserAndLimiter),
      input,
    );
    final Float64List removed = _rawRnnoise(input);

    expect(
      _pauseRmsDbfs(output),
      greaterThanOrEqualTo(_pauseRmsDbfs(removed) + 8),
    );
  });

  test('the mixed-in input lines up with RNNoise', () {
    final math.Random random = math.Random(_noiseSeed);
    final double spread = _fullScale * math.pow(10, -60 / 20);
    final Float64List noise = Float64List(2 * _rate);
    for (int index = 0; index < noise.length; index += 1) {
      final double u1 = 1 - random.nextDouble();
      final double u2 = random.nextDouble();
      noise[index] =
          math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2) * spread;
    }
    final NaturalVoiceChain chain = _isolation(<NaturalVoiceStage>{});
    final Float64List output = _runAll(chain, noise);

    expect(chain.delaySamples, 960);
    const int maxLag = 2000;
    double best = double.negativeInfinity;
    int bestLag = -1;
    for (int lag = 0; lag < maxLag; lag += 1) {
      double sum = 0;
      for (int index = 0; index + maxLag < noise.length; index += 1) {
        sum += noise[index] * output[index + lag];
      }
      if (sum > best) {
        best = sum;
        bestLag = lag;
      }
    }
    expect(bestLag, chain.delaySamples);
    final Float64List aligned = Float64List.sublistView(
      output,
      chain.delaySamples,
    );
    final double inputLevel = _rmsDbfs(noise, _rate ~/ 10, noise.length);
    expect(inputLevel, closeTo(-60, 0.5));
    expect(
      _rmsDbfs(aligned, _rate ~/ 10, noise.length),
      closeTo(inputLevel - 15, 1),
    );
  });

  test('loud speech stays under the ceiling', () {
    final Float64List fixture = _readFixture();
    final Float64List input = _scaled(fixture, 32767 / _peak(fixture));
    expect(_peak(input), closeTo(32767, 0.5));
    final Float64List output = _runAligned(_isolation(_everyStage), input);

    final double ceiling = _fullScale * math.pow(10, -1 / 20);
    expect(_peak(output), lessThanOrEqualTo(ceiling));
    expect(_peak(_oversampledFourTimes(output)), lessThanOrEqualTo(ceiling));
  });

  test('quiet speech rises towards spoken-word loudness', () {
    final Float64List fixture = _readFixture();
    final double gain = math
        .pow(10, (-32 - _integratedLufs(fixture)) / 20)
        .toDouble();
    final Float64List input = _scaled(fixture, gain);
    expect(_integratedLufs(input), closeTo(-32, 0.01));
    final Float64List output = _runAligned(_isolation(_everyStage), input);

    final Float64List lastSixSeconds = Float64List.sublistView(
      output,
      input.length - 6 * _rate,
      input.length,
    );
    expect(_integratedLufs(lastSixSeconds), closeTo(-18, 2.5));
  });

  test('the leveller holds still in pauses', () {
    final Float64List input = _readFixture();
    final (int pauseStart, int pauseEnd) = _longestPause;
    expect(pauseEnd - pauseStart, 2 * _rate);
    final NaturalVoiceChain chain = _isolation(_everyStage);
    final Uint8List bytes = _pcm(input);
    final List<double> gainsInPause = <double>[];
    for (int start = 0; start < bytes.length; start += _rnnoiseFrame * 2) {
      chain.process(
        Uint8List.sublistView(
          bytes,
          start,
          math.min(bytes.length, start + _rnnoiseFrame * 2),
        ),
      );
      final int heard = start ~/ 2 + _rnnoiseFrame - chain.delaySamples;
      if (heard >= pauseStart && heard <= pauseEnd) {
        gainsInPause.add(chain.levellerGainDb);
      }
    }

    expect(gainsInPause.length, greaterThanOrEqualTo(190));
    final double lowest = gainsInPause.reduce(math.min);
    final double highest = gainsInPause.reduce(math.max);
    expect(highest - lowest, lessThan(1));
  });

  test('hard s sounds are softened', () {
    final Float64List input = _readFixture();
    final double amplitude = 32767 * math.pow(10, -20 / 20).toDouble();
    for (int index = 0; index < _burstLength; index += 1) {
      final int fromEdge = math.min(index, _burstLength - index);
      final double ramp = fromEdge < _burstRamp
          ? 0.5 - 0.5 * math.cos(math.pi * fromEdge / _burstRamp)
          : 1;
      input[_burstStart + index] +=
          amplitude *
          ramp *
          math.sin(2 * math.pi * _burstFrequency * index / _rate);
    }
    final Float64List softened = _runAligned(
      _isolation(<NaturalVoiceStage>{NaturalVoiceStage.deEsser}),
      input,
    );
    final Float64List bypassed = _runAligned(
      _isolation(<NaturalVoiceStage>{}),
      input,
    );

    final int burstEnd = _burstStart + _burstLength;
    final double reduction = _decibels(
      _toneEnergy(bypassed, _burstStart, burstEnd, _burstFrequency) /
          _toneEnergy(softened, _burstStart, burstEnd, _burstFrequency),
    );
    expect(reduction, inInclusiveRange(2, 6));
  });

  test('processing runs well ahead of real time', () {
    final Float64List fixture = _readFixture();
    final Float64List looped = Float64List(60 * _rate);
    for (int index = 0; index < looped.length; index += 1) {
      looped[index] = fixture[index % fixture.length];
    }
    final Uint8List bytes = _pcm(looped);
    final List<Uint8List> chunks = <Uint8List>[
      for (int start = 0; start < bytes.length; start += _chunkSamples * 2)
        Uint8List.sublistView(bytes, start, start + _chunkSamples * 2),
    ];
    final NaturalVoiceChain chain = _isolation(_everyStage);

    final Stopwatch stopwatch = Stopwatch()..start();
    for (final Uint8List chunk in chunks) {
      chain.process(chunk);
    }
    chain.flush();
    stopwatch.stop();

    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
  });

  test('studio at full volume is untouched', () {
    final Uint8List input = _pcm(_readFixture());
    final NaturalVoiceChain chain = NaturalVoiceChain(
      profile: InputProfile.studio,
      volume: 100,
    );
    addTearDown(chain.dispose);

    expect(chain.delaySamples, 0);
    final Uint8List output = chain.process(input);
    expect(chain.flush(), isEmpty);
    expect(output, orderedEquals(input));
  });

  test('studio applies the input volume only', () {
    final NaturalVoiceChain chain = NaturalVoiceChain(
      profile: InputProfile.studio,
      volume: 150,
    );
    addTearDown(chain.dispose);

    final Uint8List output = chain.process(
      _pcm(Float64List.fromList(<double>[1000, -20000, 30000])),
    );
    expect(chain.flush(), isEmpty);
    expect(
      _samplesOf(<Uint8List>[output]),
      orderedEquals(<double>[1500, -30000, 32767]),
    );
  });
}
