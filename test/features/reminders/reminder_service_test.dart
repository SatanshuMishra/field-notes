import 'package:field_notes/domain/services/reminder_service.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReminderService.nextReminderAt', () {
    const ReminderService service = ReminderService();
    const ReminderTime time = ReminderTime.defaultTime;

    test('returns null when reminders are disabled', () {
      expect(
        service.nextReminderAt(
          enabled: false,
          time: time,
          now: DateTime(2026, 7, 19, 8),
          todayHasEntry: false,
        ),
        isNull,
      );
    });

    test('schedules today when the time is ahead and today has no entry', () {
      expect(
        service.nextReminderAt(
          enabled: true,
          time: time,
          now: DateTime(2026, 7, 19, 8),
          todayHasEntry: false,
        ),
        DateTime(2026, 7, 19, 20, 30),
      );
    });

    test('skips to tomorrow when today already has an entry', () {
      expect(
        service.nextReminderAt(
          enabled: true,
          time: time,
          now: DateTime(2026, 7, 19, 8),
          todayHasEntry: true,
        ),
        DateTime(2026, 7, 20, 20, 30),
      );
    });

    test("skips to tomorrow when today's time has already passed", () {
      expect(
        service.nextReminderAt(
          enabled: true,
          time: time,
          now: DateTime(2026, 7, 19, 21, 15),
          todayHasEntry: false,
        ),
        DateTime(2026, 7, 20, 20, 30),
      );
    });

    test('skips to tomorrow when now is exactly the reminder time', () {
      expect(
        service.nextReminderAt(
          enabled: true,
          time: time,
          now: DateTime(2026, 7, 19, 20, 30),
          todayHasEntry: false,
        ),
        DateTime(2026, 7, 20, 20, 30),
      );
    });

    test('rolls into the next month at a month boundary', () {
      expect(
        service.nextReminderAt(
          enabled: true,
          time: time,
          now: DateTime(2026, 7, 31, 22),
          todayHasEntry: false,
        ),
        DateTime(2026, 8, 1, 20, 30),
      );
    });

    test('honors a custom reminder time', () {
      expect(
        service.nextReminderAt(
          enabled: true,
          time: const ReminderTime(hour: 7, minute: 5),
          now: DateTime(2026, 7, 19, 6, 59),
          todayHasEntry: false,
        ),
        DateTime(2026, 7, 19, 7, 5),
      );
    });
  });
}
