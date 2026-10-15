import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rnnoise/rnnoise.dart';

const int _frame = 480;
const int _framesInTwoSeconds = 200;
const int _framesInFirst100Ms = 10;
const double _fullScale = 32768;
const double _noiseDbfs = -30;
const int _seed = 20261014;

double _dbfs(Iterable<Float32List> frames) {
  double sum = 0;
  int count = 0;
  for (final Float32List frame in frames) {
    for (final double sample in frame) {
      sum += sample * sample;
      count += 1;
    }
  }
  final double rms = math.sqrt(sum / count);
  return 20 * math.log(rms / _fullScale) / math.ln10;
}

List<Float32List> _whiteNoise() {
  final math.Random random = math.Random(_seed);
  final double spread = _fullScale * math.pow(10, _noiseDbfs / 20);
  double gaussian() {
    final double u1 = 1 - random.nextDouble();
    final double u2 = random.nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  return <Float32List>[
    for (int frame = 0; frame < _framesInTwoSeconds; frame += 1)
      Float32List.fromList(<double>[
        for (int sample = 0; sample < _frame; sample += 1)
          (gaussian() * spread).clamp(-32768, 32767).toDouble(),
      ]),
  ];
}

void main() {
  test('RNNoise quiets white noise by at least 10 dB', () {
    final Denoiser denoiser = Denoiser();
    addTearDown(denoiser.dispose);
    expect(Denoiser.frameSize, 480);

    final List<Float32List> input = _whiteNoise();
    final List<Float32List> output = <Float32List>[
      for (final Float32List frame in input) denoiser.process(frame),
    ];

    expect(output, hasLength(200));
    for (final Float32List frame in output) {
      expect(frame, hasLength(480));
      for (final double sample in frame) {
        expect(sample, inInclusiveRange(-32768, 32767));
      }
    }

    final double inputLevel = _dbfs(input.skip(_framesInFirst100Ms));
    final double outputLevel = _dbfs(output.skip(_framesInFirst100Ms));
    expect(inputLevel, closeTo(-30, 0.5));
    expect(outputLevel, lessThanOrEqualTo(inputLevel - 10));
  });

  test('RNNoise keeps silence silent', () {
    final Denoiser denoiser = Denoiser();
    addTearDown(denoiser.dispose);

    for (int frame = 0; frame < _framesInTwoSeconds; frame += 1) {
      final Float32List zeros = Float32List(_frame);
      final Float32List out = denoiser.process(zeros);
      expect(out, hasLength(480));
      expect(identical(out, zeros), isFalse);
      expect(out.every((double sample) => sample == 0), isTrue);
    }
  });

  test('RNNoise refuses a frame that is not 480 samples', () {
    final Denoiser denoiser = Denoiser();
    addTearDown(denoiser.dispose);

    expect(() => denoiser.process(Float32List(479)), throwsArgumentError);
    expect(() => denoiser.process(Float32List(481)), throwsArgumentError);
  });
}
