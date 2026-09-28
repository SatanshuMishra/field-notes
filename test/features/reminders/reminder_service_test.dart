import 'package:field_notes/domain/services/reminder_service.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReminderService.upcomingReminders', () {
    const ReminderService service = ReminderService();
    const ReminderTime time = ReminderTime.defaultTime;

    test('returns null when reminders are disabled', () {
      expect(
        service.upcomingReminders(
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
        service.upcomingReminders(
          enabled: true,
          time: time,
          now: DateTime(2026, 7, 19, 8),
          todayHasEntry: false,
        ),
        <ReminderBooking>[
          for (final (int id, int day) in const <(int, int)>[
            (1001, 19),
            (1002, 20),
            (1003, 21),
            (1004, 22),
            (1005, 23),
            (1006, 24),
            (1007, 25),
          ])
            ReminderBooking(id: id, at: DateTime(2026, 7, day, 20, 30)),
        ],
      );
    });

    test('skips to tomorrow when today already has an entry', () {
      expect(
        service.upcomingReminders(
          enabled: true,
          time: time,
          now: DateTime(2026, 7, 19, 8),
          todayHasEntry: true,
        ),
        <ReminderBooking>[
          for (final (int id, int day) in const <(int, int)>[
            (1002, 20),
            (1003, 21),
            (1004, 22),
            (1005, 23),
            (1006, 24),
            (1007, 25),
          ])
            ReminderBooking(id: id, at: DateTime(2026, 7, day, 20, 30)),
        ],
      );
    });

    test("skips to tomorrow when today's time has already passed", () {
      expect(
        service.upcomingReminders(
          enabled: true,
          time: time,
          now: DateTime(2026, 7, 19, 21, 15),
          todayHasEntry: false,
        ),
        <ReminderBooking>[
          for (final (int id, int day) in const <(int, int)>[
            (1002, 20),
            (1003, 21),
            (1004, 22),
            (1005, 23),
            (1006, 24),
            (1007, 25),
          ])
            ReminderBooking(id: id, at: DateTime(2026, 7, day, 20, 30)),
        ],
      );
    });

    test('skips to tomorrow when now is exactly the reminder time', () {
      expect(
        service.upcomingReminders(
          enabled: true,
          time: time,
          now: DateTime(2026, 7, 19, 20, 30),
          todayHasEntry: false,
        ),
        <ReminderBooking>[
          for (final (int id, int day) in const <(int, int)>[
            (1002, 20),
            (1003, 21),
            (1004, 22),
            (1005, 23),
            (1006, 24),
            (1007, 25),
          ])
            ReminderBooking(id: id, at: DateTime(2026, 7, day, 20, 30)),
        ],
      );
    });

    test('rolls into the next month at a month boundary', () {
      expect(
        service.upcomingReminders(
          enabled: true,
          time: time,
          now: DateTime(2026, 7, 31, 22),
          todayHasEntry: false,
        ),
        <ReminderBooking>[
          for (final (int id, int day) in const <(int, int)>[
            (1002, 1),
            (1003, 2),
            (1004, 3),
            (1005, 4),
            (1006, 5),
            (1007, 6),
          ])
            ReminderBooking(id: id, at: DateTime(2026, 8, day, 20, 30)),
        ],
      );
    });

    test('honors a custom reminder time', () {
      expect(
        service.upcomingReminders(
          enabled: true,
          time: const ReminderTime(hour: 7, minute: 5),
          now: DateTime(2026, 7, 19, 6, 59),
          todayHasEntry: false,
        ),
        <ReminderBooking>[
          for (final (int id, int day) in const <(int, int)>[
            (1001, 19),
            (1002, 20),
            (1003, 21),
            (1004, 22),
            (1005, 23),
            (1006, 24),
            (1007, 25),
          ])
            ReminderBooking(id: id, at: DateTime(2026, 7, day, 7, 5)),
        ],
      );
    });
  });
}
