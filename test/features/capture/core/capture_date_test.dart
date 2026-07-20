import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('captureDateKey', () {
    test('formats a local date as zero-padded YYYY-MM-DD', () {
      expect(captureDateKey(DateTime(2026, 7, 5, 23, 59)), '2026-07-05');
      expect(captureDateKey(DateTime(2026, 12, 31)), '2026-12-31');
      expect(captureDateKey(DateTime(999, 1, 2)), '0999-01-02');
    });

    test('uses the local calendar day, not the UTC day', () {
      final DateTime utcNoon = DateTime.utc(2026, 7, 19, 12);
      expect(captureDateKey(utcNoon), captureDateKey(utcNoon.toLocal()));
    });
  });

  group('isCaptureDateKey', () {
    test('accepts a well-formed key', () {
      expect(isCaptureDateKey('2026-07-19'), isTrue);
    });

    test('rejects malformed input', () {
      expect(isCaptureDateKey('2026-7-19'), isFalse);
      expect(isCaptureDateKey('19-07-2026'), isFalse);
      expect(isCaptureDateKey('today'), isFalse);
      expect(isCaptureDateKey(''), isFalse);
    });
  });
}
