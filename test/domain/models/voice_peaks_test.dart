import 'package:field_notes/domain/models/voice_peaks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the peaks list merges pairs at the 36,001st value', () {
    final VoicePeaksAccumulator accumulator = VoicePeaksAccumulator();
    for (int pair = 0; pair < 18000; pair++) {
      if (pair.isEven) {
        accumulator
          ..add(0.1)
          ..add(0.9);
      } else {
        accumulator
          ..add(0.7)
          ..add(0.3);
      }
    }

    expect(accumulator.windowLength, const Duration(milliseconds: 100));
    expect(accumulator.finish(), hasLength(36000));

    accumulator.add(0.5);
    final List<double> peaks = accumulator.finish();

    expect(accumulator.windowLength, const Duration(milliseconds: 200));
    expect(peaks, hasLength(18001));
    expect(peaks, <double>[
      for (int pair = 0; pair < 18000; pair++) pair.isEven ? 0.9 : 0.7,
      0.5,
    ]);
  });

  test('values after a merge fill the current window by their highest', () {
    final VoicePeaksAccumulator accumulator = VoicePeaksAccumulator();
    for (int i = 0; i < 36000; i++) {
      accumulator.add(0.2);
    }

    accumulator
      ..add(0.4)
      ..add(0.6);
    final List<double> filled = accumulator.finish();
    accumulator.add(0.3);
    final List<double> started = accumulator.finish();

    expect(filled, hasLength(18001));
    expect(filled.last, 0.6);
    expect(started, hasLength(18002));
    expect(started.sublist(18000), <double>[0.6, 0.3]);
    expect(accumulator.windowLength, const Duration(milliseconds: 200));
  });

  test('a peak rounds to 2 decimals', () {
    expect(roundVoicePeak(0.6037), 0.6);
    expect(roundVoicePeak(0.9378), 0.94);
    expect(roundVoicePeak(0), 0);
    expect(roundVoicePeak(1), 1);
  });

  test('peaks encode to a JSON array and back', () {
    expect(encodeVoicePeaks(<double>[0, 0.25, 1]), '[0,0.25,1]');
    expect(encodeVoicePeaks(<double>[]), '[]');
    expect(decodeVoicePeaks('[0,0.25,1]'), <double>[0, 0.25, 1]);
    expect(decodeVoicePeaks('[]'), <double>[]);
  });

  test('a damaged stored value reads as no peaks', () {
    final String tooMany = '[${List<String>.filled(36001, '0').join(',')}]';

    expect(decodeVoicePeaks('oops'), isNull);
    expect(decodeVoicePeaks('{}'), isNull);
    expect(decodeVoicePeaks('[0.2,"a"]'), isNull);
    expect(decodeVoicePeaks('[1.5]'), isNull);
    expect(decodeVoicePeaks(tooMany), isNull);
    expect(decodeVoicePeaks(null), isNull);
  });
}
