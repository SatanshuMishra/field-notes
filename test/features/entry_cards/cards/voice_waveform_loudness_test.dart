import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/entry_cards/cards/voice_waveform.dart';

void _expectBars(List<double> actual, List<double> expected, double within) {
  expect(actual, hasLength(expected.length));
  for (int index = 0; index < expected.length; index++) {
    expect(
      actual[index],
      closeTo(expected[index], within),
      reason: 'bar $index',
    );
  }
}

void main() {
  test('a passage twice as loud draws a bar twice as tall', () {
    _expectBars(voiceWaveformBars(<double>[0.85, 1.0], 2), <double>[
      0.50,
      1.0,
    ], 0.01);
  });

  test('steady speech a few decibels apart draws clearly different bars', () {
    _expectBars(voiceWaveformBars(<double>[0.8, 0.9, 1.0], 3), <double>[
      0.40,
      0.63,
      1.0,
    ], 0.01);
  });

  test('room noise far below the speech drops to the floor', () {
    _expectBars(voiceWaveformBars(<double>[0.0, 0.3, 1.0], 3), <double>[
      0.07,
      0.07,
      1.0,
    ], 0.001);
    _expectBars(voiceWaveformBars(<double>[0.0, 0.0, 0.0], 3), <double>[
      0.07,
      0.07,
      0.07,
    ], 0.001);
  });
}
