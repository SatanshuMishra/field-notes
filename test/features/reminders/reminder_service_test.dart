import 'package:field_notes/domain/services/reminder_service.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';

const ReminderService _service = ReminderService();

List<ReminderBooking> _upcoming({
  ReminderSchedule schedule = ReminderSchedule.evenings,
  ReminderTime customTime = ReminderTime.defaultTime,
  required DateTime now,
  Map<DateTime, ReminderDay> days = const <DateTime, ReminderDay>{},
}) => _service.upcomingReminders(
  enabled: true,
  schedule: schedule,
  customTime: customTime,
  now: now,
  days: days,
)!;

List<DateTime> _onDay(List<ReminderBooking> bookings, int day) => <DateTime>[
  for (final ReminderBooking booking in bookings)
    if (booking.at.day == day) booking.at,
];

void main() {
  group('ReminderService.upcomingReminders', () {
    test('returns null when reminders are disabled', () {
      expect(
        _service.upcomingReminders(
          enabled: false,
          schedule: ReminderSchedule.evenings,
          customTime: ReminderTime.defaultTime,
          now: DateTime(2026, 7, 19, 8),
        ),
        isNull,
      );
    });

    test('Evenings schedules 8:30 PM and the 10:30 PM last call each day', () {
      final List<ReminderBooking> bookings = _upcoming(
        now: DateTime(2026, 7, 19, 8),
      );

      expect(bookings.map((ReminderBooking b) => b.at).toList(), <DateTime>[
        for (int day = 19; day <= 25; day++) ...<DateTime>[
          DateTime(2026, 7, day, 20, 30),
          DateTime(2026, 7, day, 22, 30),
        ],
      ]);
      expect(bookings.first.body, reminderEveningBody);
      expect(bookings[1].body, reminderLastCallBody);
    });

    test('Midday and evening schedules 12:30 PM, 8:30 PM and 10:30 PM', () {
      final List<ReminderBooking> bookings = _upcoming(
        schedule: ReminderSchedule.middayAndEvening,
        now: DateTime(2026, 7, 19, 8),
      );

      expect(bookings, hasLength(21));
      expect(_onDay(bookings, 19), <DateTime>[
        DateTime(2026, 7, 19, 12, 30),
        DateTime(2026, 7, 19, 20, 30),
        DateTime(2026, 7, 19, 22, 30),
      ]);
      expect(
        bookings.take(3).map((ReminderBooking b) => b.body).toList(),
        <String>[reminderMiddayBody, reminderEveningBody, reminderLastCallBody],
      );
    });

    test('Custom 7:15 AM schedules 7:15 AM and the 10:30 PM last call', () {
      final List<ReminderBooking> bookings = _upcoming(
        schedule: ReminderSchedule.custom,
        customTime: const ReminderTime(hour: 7, minute: 15),
        now: DateTime(2026, 7, 19, 6),
      );

      expect(bookings, hasLength(14));
      expect(_onDay(bookings, 19), <DateTime>[
        DateTime(2026, 7, 19, 7, 15),
        DateTime(2026, 7, 19, 22, 30),
      ]);
      expect(bookings.first.body, reminderEveningBody);
      expect(bookings[1].body, reminderLastCallBody);
    });

    test('Custom 9:45 PM becomes the last call itself', () {
      final List<ReminderBooking> bookings = _upcoming(
        schedule: ReminderSchedule.custom,
        customTime: const ReminderTime(hour: 21, minute: 45),
        now: DateTime(2026, 7, 19, 6),
      );

      expect(bookings, hasLength(7));
      expect(_onDay(bookings, 19), <DateTime>[DateTime(2026, 7, 19, 21, 45)]);
      expect(bookings.first.body, reminderLastCallBody);
      expect(
        bookings.first.id,
        ReminderService.bookingIdFor(
          DateTime(2026, 7, 19),
          ReminderNudge.lastCall,
        ),
      );
    });

    test('a custom time just before 9:30 PM keeps its own nudge', () {
      expect(
        _onDay(
          _upcoming(
            schedule: ReminderSchedule.custom,
            customTime: const ReminderTime(hour: 21, minute: 29),
            now: DateTime(2026, 7, 19, 6),
          ),
          19,
        ),
        <DateTime>[
          DateTime(2026, 7, 19, 21, 29),
          DateTime(2026, 7, 19, 22, 30),
        ],
      );
      expect(
        _onDay(
          _upcoming(
            schedule: ReminderSchedule.custom,
            customTime: const ReminderTime(hour: 21, minute: 30),
            now: DateTime(2026, 7, 19, 6),
          ),
          19,
        ),
        <DateTime>[DateTime(2026, 7, 19, 21, 30)],
      );
    });

    test('a complete day has no remaining nudges, and tomorrow keeps its', () {
      final List<ReminderBooking> bookings = _upcoming(
        schedule: ReminderSchedule.middayAndEvening,
        now: DateTime(2026, 7, 19, 8),
        days: <DateTime, ReminderDay>{
          DateTime(2026, 7, 19): const ReminderDay(hasBloom: true, logCount: 1),
        },
      );

      expect(_onDay(bookings, 19), isEmpty);
      expect(_onDay(bookings, 20), hasLength(3));
      expect(bookings, hasLength(18));
    });

    test('a day with only a log or only a bloom keeps every nudge', () {
      for (final ReminderDay partial in const <ReminderDay>[
        ReminderDay(logCount: 2),
        ReminderDay(hasBloom: true),
      ]) {
        expect(
          _onDay(
            _upcoming(
              now: DateTime(2026, 7, 19, 8),
              days: <DateTime, ReminderDay>{DateTime(2026, 7, 19): partial},
            ),
            19,
          ),
          <DateTime>[
            DateTime(2026, 7, 19, 20, 30),
            DateTime(2026, 7, 19, 22, 30),
          ],
          reason: '$partial',
        );
      }
    });

    test("the last call's text names what the day is missing", () {
      String lastCallFor(ReminderDay day) => _upcoming(
        now: DateTime(2026, 7, 19, 21),
        days: <DateTime, ReminderDay>{DateTime(2026, 7, 19): day},
      ).first.body;

      expect(lastCallFor(const ReminderDay()), reminderLastCallBody);
      expect(
        lastCallFor(const ReminderDay(logCount: 1)),
        'Before today closes, pick a bloom for it.',
      );
      expect(
        lastCallFor(const ReminderDay(hasBloom: true)),
        'Before today closes, add a few words about it.',
      );
      expect(
        reminderLastCallBody,
        "The day's almost over. There's still time to look back on it.",
      );
    });

    test('the nudges keep their approved words', () {
      expect(
        reminderMiddayBody,
        "A moment for today? Jot down how it's going so far.",
      );
      expect(
        reminderEveningBody,
        'How was today? A few words and a bloom are plenty.',
      );
    });

    test('no reminder text mentions the streak', () {
      for (final String body in <String>[
        reminderMiddayBody,
        reminderEveningBody,
        reminderLastCallBody,
        reminderLastCallBloomBody,
        reminderLastCallLogBody,
      ]) {
        expect(body.toLowerCase(), isNot(contains('streak')), reason: body);
      }
    });

    test("skips today's nudges whose time has passed or is now", () {
      expect(
        _onDay(_upcoming(now: DateTime(2026, 7, 19, 20, 30)), 19),
        <DateTime>[DateTime(2026, 7, 19, 22, 30)],
      );
      expect(
        _onDay(_upcoming(now: DateTime(2026, 7, 19, 22, 30)), 19),
        isEmpty,
      );
      expect(
        _upcoming(now: DateTime(2026, 7, 19, 22, 30)).first.at,
        DateTime(2026, 7, 20, 20, 30),
      );
    });

    test('rolls into the next month at a month boundary', () {
      final List<ReminderBooking> bookings = _upcoming(
        now: DateTime(2026, 7, 31, 23),
      );

      expect(bookings.first.at, DateTime(2026, 8, 1, 20, 30));
      expect(bookings.last.at, DateTime(2026, 8, 6, 22, 30));
    });

    test('every booking id is distinct and from the reserved range', () {
      final List<ReminderBooking> bookings = _upcoming(
        schedule: ReminderSchedule.middayAndEvening,
        now: DateTime(2026, 7, 19, 8),
      );
      final Set<int> ids = <int>{
        for (final ReminderBooking booking in bookings) booking.id,
      };

      expect(ids, hasLength(21));
      expect(ReminderService.bookingIds.toSet(), ids);
    });

    test("a day's nudges keep their ids when the window moves a day on", () {
      final List<ReminderBooking> today = _upcoming(
        schedule: ReminderSchedule.middayAndEvening,
        now: DateTime(2026, 7, 19, 8),
      );
      final List<ReminderBooking> tomorrow = _upcoming(
        schedule: ReminderSchedule.middayAndEvening,
        now: DateTime(2026, 7, 20, 8),
      );

      expect(
        tomorrow.where((ReminderBooking b) => b.at.day != 26).toList(),
        today.where((ReminderBooking b) => b.at.day != 19).toList(),
      );
    });
  });
}
