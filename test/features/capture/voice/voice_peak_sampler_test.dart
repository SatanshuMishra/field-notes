import 'package:field_notes/features/capture/voice/voice_peak_sampler.dart';
import 'package:flutter_test/flutter_test.dart';

Duration _ms(int milliseconds) => Duration(milliseconds: milliseconds);

void _hearEvery60Ms(
  VoicePeakSampler sampler, {
  required int fromMs,
  required int untilMs,
  Map<int, double> loud = const <int, double>{},
}) {
  for (int ms = fromMs; ms < untilMs; ms += 60) {
    sampler.hear(loud[ms] ?? 0, _ms(ms));
  }
}

void main() {
  test('each 100 ms window keeps its highest smoothed level', () {
    final VoicePeakSampler sampler = VoicePeakSampler();

    sampler.hear(0, _ms(0));
    sampler.hear(1, _ms(60));
    sampler.hear(1, _ms(120));
    sampler.hear(0, _ms(180));

    expect(sampler.finish(_ms(200)), <double>[0.6, 0.94]);
  });

  test('a window with no level still gets a peak', () {
    final VoicePeakSampler sampler = VoicePeakSampler();

    sampler.hear(0.8, _ms(0));

    expect(sampler.finish(_ms(300)), <double>[0.72, 0.79, 0.8]);
  });

  test('paused time adds no peaks', () {
    final VoicePeakSampler sampler = VoicePeakSampler();

    sampler.hear(0.5, _ms(0));
    sampler.hear(0.5, _ms(60));
    sampler.hear(0.5, _ms(120));
    for (int wallMs = 0; wallMs < 5000; wallMs += 60) {
      sampler.hear(0.5, _ms(150));
    }
    sampler.hear(0.5, _ms(210));

    expect(sampler.finish(_ms(250)), <double>[0.45, 0.5, 0.5]);
  });

  test('a stop on a window edge adds no empty peak', () {
    final VoicePeakSampler sampler = VoicePeakSampler();

    for (int ms = 0; ms <= 300; ms += 60) {
      sampler.hear(0.5, _ms(ms));
    }

    expect(sampler.finish(_ms(300)), hasLength(3));
  });

  test('silence keeps exact zero peaks', () {
    final VoicePeakSampler sampler = VoicePeakSampler();

    sampler.hear(0, _ms(0));
    sampler.hear(0, _ms(60));
    sampler.hear(0, _ms(120));
    sampler.hear(0, _ms(180));

    expect(sampler.finish(_ms(200)), <double>[0, 0]);
  });

  test('an hour of recording keeps every 100 ms peak', () {
    final VoicePeakSampler sampler = VoicePeakSampler();

    _hearEvery60Ms(sampler, fromMs: 0, untilMs: 1800000);
    final List<double> halfHour = sampler.finish(_ms(1800000));

    expect(halfHour, hasLength(18000));

    _hearEvery60Ms(
      sampler,
      fromMs: 1800000,
      untilMs: 3600000,
      loud: const <int, double>{1800060: 1},
    );
    final List<double> hour = sampler.finish(_ms(3600000));

    expect(hour, hasLength(36000));
    expect(hour.sublist(17999, 18012), <double>[
      0,
      0.6,
      0.75,
      0.49,
      0.29,
      0.17,
      0.1,
      0.06,
      0.03,
      0.02,
      0.01,
      0.01,
      0,
    ]);
  });

  test('one window past an hour merges pairs', () {
    final VoicePeakSampler sampler = VoicePeakSampler();

    _hearEvery60Ms(
      sampler,
      fromMs: 0,
      untilMs: 3600100,
      loud: const <int, double>{1800060: 1, 3600000: 1, 3600060: 1},
    );
    final List<double> peaks = sampler.finish(_ms(3600100));

    expect(peaks, hasLength(18001));
    expect(peaks, <double>[
      ...List<double>.filled(9000, 0),
      0.75,
      0.49,
      0.17,
      0.06,
      0.02,
      0.01,
      ...List<double>.filled(8994, 0),
      0.9,
    ]);
  });

  test('a ten-hour recording stays within 36,000 peaks covering all of it', () {
    final VoicePeakSampler sampler = VoicePeakSampler();

    _hearEvery60Ms(
      sampler,
      fromMs: 0,
      untilMs: 36000000,
      loud: const <int, double>{35999940: 1},
    );
    final List<double> peaks = sampler.finish(_ms(36000000));

    expect(peaks, hasLength(22500));
    expect(peaks.sublist(0, 22499), everyElement(0));
    expect(peaks.last, 0.75);
  });

  test('a recording stopped at once has no peaks', () {
    final VoicePeakSampler sampler = VoicePeakSampler();

    sampler.hear(0.7, Duration.zero);

    expect(sampler.finish(Duration.zero), isEmpty);
  });
}
