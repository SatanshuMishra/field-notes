import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/capture/immersive/voice_level_smoother.dart';

VoiceLevelSmoother _settledAt(double level) {
  final VoiceLevelSmoother smoother = VoiceLevelSmoother();
  smoother.hear(level, Duration.zero);
  _settle(smoother);
  return smoother;
}

void _settle(VoiceLevelSmoother smoother) {
  for (int step = 0; step < 3; step++) {
    smoother.advance(1);
  }
}

double _stepped(double from, double to, int steps, double dtSeconds) {
  final VoiceLevelSmoother smoother = _settledAt(from);
  expect(smoother.level, from);
  smoother.hear(to, const Duration(seconds: 4));
  for (int step = 0; step < steps; step++) {
    smoother.advance(dtSeconds);
  }
  return smoother.level;
}

List<(double, Duration)?> _hearAll(
  VoiceLevelSmoother smoother,
  List<(double, int)> arrivals,
) => <(double, Duration)?>[
  for (final (double level, int milliseconds) in arrivals)
    switch (smoother.hear(level, Duration(milliseconds: milliseconds))) {
      null => null,
      final VoiceLevelOnset onset => (onset.intensity, onset.at),
    },
];

void main() {
  test('the level rises steeply and falls slowly', () {
    final VoiceLevelSmoother smoother = VoiceLevelSmoother();
    expect(smoother.level, 0);

    smoother.hear(1, Duration.zero);
    smoother.advance(1 / 60);
    expect(smoother.level, closeTo(0.32, 1e-9));

    _settle(smoother);
    expect(smoother.level, 1);

    smoother.hear(0, const Duration(seconds: 4));
    smoother.advance(1 / 60);
    expect(smoother.level, closeTo(0.915, 1e-9));
  });

  test('the result does not depend on the frame rate', () {
    final double at60 = _stepped(0.2, 0.7, 60, 1 / 60);
    final double at30 = _stepped(0.2, 0.7, 30, 1 / 30);
    final double at120 = _stepped(0.2, 0.7, 120, 1 / 120);

    expect(at30, closeTo(at60, 1e-9));
    expect(at120, closeTo(at60, 1e-9));
    expect(at120, closeTo(at30, 1e-9));
  });

  test('a level at its target stays put', () {
    final VoiceLevelSmoother smoother = _settledAt(0.4);
    expect(smoother.level, 0.4);

    smoother.hear(0.4, const Duration(seconds: 4));
    smoother.advance(1 / 60);

    expect(smoother.level, 0.4);
  });

  test('a zero, negative or broken step changes nothing', () {
    final VoiceLevelSmoother smoother = _settledAt(0.3);
    expect(smoother.level, 0.3);
    smoother.hear(1, const Duration(seconds: 4));

    smoother.advance(0);
    expect(smoother.level, 0.3);

    smoother.advance(-0.05);
    expect(smoother.level, 0.3);

    smoother.advance(double.nan);
    expect(smoother.level, 0.3);
  });

  test('a long gap counts as one second', () {
    final VoiceLevelSmoother long = VoiceLevelSmoother();
    long.hear(1, Duration.zero);
    long.advance(5);

    final VoiceLevelSmoother second = VoiceLevelSmoother();
    second.hear(1, Duration.zero);
    second.advance(1);

    expect(long.level, second.level);
  });

  test('a sharp rise fires an onset with its level', () {
    final VoiceLevelSmoother smoother = VoiceLevelSmoother();

    expect(
      _hearAll(smoother, <(double, int)>[(0.1, 0), (0.5, 60)]),
      <(double, Duration)?>[null, (0.5, const Duration(milliseconds: 60))],
    );
  });

  test('small rises and falls fire nothing', () {
    final VoiceLevelSmoother smoother = VoiceLevelSmoother();
    smoother.hear(0.5, Duration.zero);

    expect(
      _hearAll(smoother, <(double, int)>[(0.6, 60), (0.6, 120), (0.2, 180)]),
      <(double, Duration)?>[null, null, null],
    );
  });

  test('a rise within 90 ms of an onset fires nothing', () {
    final VoiceLevelSmoother smoother = VoiceLevelSmoother();

    expect(
      _hearAll(smoother, <(double, int)>[
        (0, 0),
        (0.5, 0),
        (0.1, 40),
        (0.7, 80),
        (0.1, 100),
        (0.8, 200),
      ]),
      <(double, Duration)?>[
        null,
        (0.5, Duration.zero),
        null,
        null,
        null,
        (0.8, const Duration(milliseconds: 200)),
      ],
    );
  });

  test('the first level is compared with silence', () {
    final VoiceLevelSmoother smoother = VoiceLevelSmoother();

    expect(_hearAll(smoother, <(double, int)>[(0.6, 0)]), <(double, Duration)?>[
      (0.6, Duration.zero),
    ]);
  });

  test('a late level is compared with the last one that arrived', () {
    final VoiceLevelSmoother smoother = VoiceLevelSmoother();

    expect(
      _hearAll(smoother, <(double, int)>[(0.1, 0), (0.4, 300)]),
      <(double, Duration)?>[null, (0.4, const Duration(milliseconds: 300))],
    );
  });
}
