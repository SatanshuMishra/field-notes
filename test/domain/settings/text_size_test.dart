import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/domain/settings/text_size.dart';

void main() {
  group('TextSize', () {
    test('values map to the 1..3 slider positions', () {
      expect(TextSize.small.value, 1);
      expect(TextSize.medium.value, 2);
      expect(TextSize.large.value, 3);
    });

    test('fromValue resolves known slider positions', () {
      expect(TextSize.fromValue(1), TextSize.small);
      expect(TextSize.fromValue(2), TextSize.medium);
      expect(TextSize.fromValue(3), TextSize.large);
    });

    test('fromValue returns null for out-of-range or null input', () {
      expect(TextSize.fromValue(0), isNull);
      expect(TextSize.fromValue(4), isNull);
      expect(TextSize.fromValue(null), isNull);
    });
  });
}
