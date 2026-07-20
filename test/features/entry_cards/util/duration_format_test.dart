import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/features/entry_cards/util/duration_format.dart';

void main() {
  group('formatMediaDuration', () {
    test('formats sub-minute durations as 0:ss', () {
      expect(formatMediaDuration(5000), '0:05');
      expect(formatMediaDuration(0), '0:00');
    });

    test('formats minutes and seconds', () {
      expect(formatMediaDuration(65000), '1:05');
      expect(formatMediaDuration(600000), '10:00');
    });

    test('formats durations of an hour or more as h:mm:ss', () {
      expect(formatMediaDuration(3725000), '1:02:05');
    });

    test('treats null and negatives as zero', () {
      expect(formatMediaDuration(null), '0:00');
      expect(formatMediaDuration(-1), '0:00');
    });
  });
}
