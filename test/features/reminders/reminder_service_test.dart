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

  group('a custom time from midnight to 3:59 AM is the late night of the day '
      'before', () {
    const ReminderTime quarterPastOne = ReminderTime(hour: 1, minute: 15);

    List<ReminderBooking> lateNight({
      required DateTime now,
      Map<DateTime, ReminderDay> days = const <DateTime, ReminderDay>{},
    }) => _upcoming(
      schedule: ReminderSchedule.custom,
      customTime: quarterPastOne,
      now: now,
      days: days,
    );

    test('1:15 AM books only the last call, the next morning, for the day '
        'before', () {
      final List<ReminderBooking> bookings = lateNight(
        now: DateTime(2026, 7, 19, 8),
      );

      expect(bookings.map((ReminderBooking b) => b.at).toList(), <DateTime>[
        for (int day = 19; day <= 25; day++) DateTime(2026, 7, day + 1, 1, 15),
      ]);
      expect(bookings.map((ReminderBooking b) => b.id).toList(), <int>[
        for (int day = 19; day <= 25; day++)
          ReminderService.bookingIdFor(
            DateTime(2026, 7, day),
            ReminderNudge.lastCall,
          ),
      ]);
      expect(bookings.map((ReminderBooking b) => b.body).toSet(), <String>{
        reminderLastCallBody,
      });
      expect(bookings.where((ReminderBooking b) => b.at.hour == 22), isEmpty);
    });

    test("the late-night last call names what that day is missing", () {
      final List<ReminderBooking> bookings = lateNight(
        now: DateTime(2026, 7, 19, 8),
        days: <DateTime, ReminderDay>{
          DateTime(2026, 7, 19): const ReminderDay(hasBloom: true),
          DateTime(2026, 7, 20): const ReminderDay(logCount: 1),
        },
      );

      expect(bookings[0].at, DateTime(2026, 7, 20, 1, 15));
      expect(bookings[0].body, reminderLastCallLogBody);
      expect(bookings[1].at, DateTime(2026, 7, 21, 1, 15));
      expect(bookings[1].body, reminderLastCallBloomBody);
    });

    test('it is skipped once that day is complete, judged on that day', () {
      final List<ReminderBooking> dayBeforeDone = lateNight(
        now: DateTime(2026, 7, 19, 8),
        days: <DateTime, ReminderDay>{
          DateTime(2026, 7, 19): const ReminderDay(hasBloom: true, logCount: 1),
        },
      );
      final List<ReminderBooking> newDateDone = lateNight(
        now: DateTime(2026, 7, 19, 8),
        days: <DateTime, ReminderDay>{
          DateTime(2026, 7, 20): const ReminderDay(hasBloom: true, logCount: 1),
        },
      );

      expect(dayBeforeDone.first.at, DateTime(2026, 7, 21, 1, 15));
      expect(dayBeforeDone, hasLength(6));
      expect(newDateDone.first.at, DateTime(2026, 7, 20, 1, 15));
      expect(
        newDateDone.map((ReminderBooking b) => b.at),
        isNot(contains(DateTime(2026, 7, 21, 1, 15))),
      );
    });

    test('after midnight the day before still has its last call until it is '
        'complete', () {
      final DateTime halfPastMidnight = DateTime(2026, 7, 20, 0, 30);

      final List<ReminderBooking> open = lateNight(now: halfPastMidnight);
      final List<ReminderBooking> done = lateNight(
        now: halfPastMidnight,
        days: <DateTime, ReminderDay>{
          DateTime(2026, 7, 19): const ReminderDay(hasBloom: true, logCount: 1),
        },
      );

      expect(open.first.at, DateTime(2026, 7, 20, 1, 15));
      expect(
        open.first.id,
        ReminderService.bookingIdFor(
          DateTime(2026, 7, 19),
          ReminderNudge.lastCall,
        ),
      );
      expect(open, hasLength(7));
      expect(done.first.at, DateTime(2026, 7, 21, 1, 15));
      expect(
        lateNight(now: DateTime(2026, 7, 20, 1, 15)).first.at,
        DateTime(2026, 7, 21, 1, 15),
      );
    });

    test('3:59 AM is a last call and 4:00 AM a morning nudge with the 10:30 '
        'PM last call', () {
      expect(
        _service.slotsFor(
          ReminderSchedule.custom,
          const ReminderTime(hour: 3, minute: 59),
        ),
        const <ReminderSlot>[
          ReminderSlot(
            nudge: ReminderNudge.lastCall,
            time: ReminderTime(hour: 3, minute: 59),
          ),
        ],
      );
      expect(
        _service.slotsFor(
          ReminderSchedule.custom,
          const ReminderTime(hour: 4, minute: 0),
        ),
        const <ReminderSlot>[
          ReminderSlot(
            nudge: ReminderNudge.evening,
            time: ReminderTime(hour: 4, minute: 0),
          ),
          ReminderSlot(
            nudge: ReminderNudge.lastCall,
            time: ReminderService.lastCallTime,
          ),
        ],
      );
      expect(
        _upcoming(
          schedule: ReminderSchedule.custom,
          customTime: const ReminderTime(hour: 3, minute: 59),
          now: DateTime(2026, 7, 19, 8),
        ).first.at,
        DateTime(2026, 7, 20, 3, 59),
      );
      expect(
        _upcoming(
          schedule: ReminderSchedule.custom,
          customTime: const ReminderTime(hour: 4, minute: 0),
          now: DateTime(2026, 7, 19, 3),
        ).take(2).map((ReminderBooking b) => b.at).toList(),
        <DateTime>[DateTime(2026, 7, 19, 4), DateTime(2026, 7, 19, 22, 30)],
      );
    });

    test('late-night ids stay in the reserved range and never collide across '
        'the date change', () {
      for (final DateTime now in <DateTime>[
        DateTime(2026, 7, 19, 8),
        DateTime(2026, 7, 20, 0, 30),
        DateTime(2026, 7, 31, 2),
      ]) {
        final List<ReminderBooking> bookings = lateNight(now: now);
        final Set<int> ids = <int>{
          for (final ReminderBooking booking in bookings) booking.id,
        };

        expect(ids, hasLength(bookings.length), reason: '$now');
        expect(
          ReminderService.bookingIds.toSet().containsAll(ids),
          isTrue,
          reason: '$now',
        );
      }
      final List<ReminderBooking> beforeFour = lateNight(
        now: DateTime(2026, 7, 20, 0, 30),
      );
      final List<ReminderBooking> afterFour = lateNight(
        now: DateTime(2026, 7, 20, 8),
      );
      expect(
        afterFour.where((ReminderBooking b) => b.at.day != 27).toList(),
        beforeFour.where((ReminderBooking b) => b.at.day != 20).toList(),
      );
    });
  });

  group('the reminder window follows the 4 AM day', () {
    test('before 4 AM the window starts on the day before', () {
      expect(_service.windowDays(DateTime(2026, 7, 20, 3, 59)), <DateTime>[
        for (int day = 19; day <= 25; day++) DateTime(2026, 7, day),
      ]);
      expect(_service.windowDays(DateTime(2026, 7, 20, 4)), <DateTime>[
        for (int day = 20; day <= 26; day++) DateTime(2026, 7, day),
      ]);
      expect(
        _service.windowDays(DateTime(2026, 8, 1, 1)).first,
        DateTime(2026, 7, 31),
      );
    });
  });
}
