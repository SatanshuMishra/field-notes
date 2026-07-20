import 'package:field_notes/features/reminders/reminder_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reminderDateKey', () {
    test('formats a date as YYYY-MM-DD', () {
      expect(reminderDateKey(DateTime(2026, 7, 19)), '2026-07-19');
    });

    test('zero-pads single-digit months and days', () {
      expect(reminderDateKey(DateTime(2026, 1, 2)), '2026-01-02');
    });

    test('ignores the time component', () {
      expect(reminderDateKey(DateTime(2026, 12, 31, 23, 59, 59)), '2026-12-31');
    });

    test('pads years to four digits', () {
      expect(reminderDateKey(DateTime(999, 3, 4)), '0999-03-04');
    });
  });
}
