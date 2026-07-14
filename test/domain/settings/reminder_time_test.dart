import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/domain/settings/reminder_time.dart';

void main() {
  group('ReminderTime', () {
    test('defaultTime is 20:30', () {
      expect(ReminderTime.defaultTime.hour, 20);
      expect(ReminderTime.defaultTime.minute, 30);
    });

    test('minutesSinceMidnight is hour*60 + minute', () {
      expect(
        const ReminderTime(hour: 20, minute: 30).minutesSinceMidnight,
        1230,
      );
      expect(const ReminderTime(hour: 0, minute: 0).minutesSinceMidnight, 0);
      expect(
        const ReminderTime(hour: 23, minute: 59).minutesSinceMidnight,
        1439,
      );
    });

    test('fromMinutes round-trips a valid minute count', () {
      expect(
        ReminderTime.fromMinutes(1230),
        const ReminderTime(hour: 20, minute: 30),
      );
      expect(
        ReminderTime.fromMinutes(0),
        const ReminderTime(hour: 0, minute: 0),
      );
    });

    test('fromMinutes returns null for out-of-range input', () {
      expect(ReminderTime.fromMinutes(-1), isNull);
      expect(ReminderTime.fromMinutes(1440), isNull);
    });

    test('value equality', () {
      expect(
        const ReminderTime(hour: 7, minute: 15),
        const ReminderTime(hour: 7, minute: 15),
      );
      expect(
        const ReminderTime(hour: 7, minute: 15),
        isNot(const ReminderTime(hour: 7, minute: 16)),
      );
    });
  });
}
