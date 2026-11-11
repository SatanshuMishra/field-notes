import '../settings/reminder_schedule.dart';
import '../settings/reminder_time.dart';
import 'streak_service.dart';

const String reminderMiddayBody =
    "A moment for today? Jot down how it's going so far.";
const String reminderEveningBody =
    'How was today? A few words and a bloom are plenty.';
const String reminderLastCallBody =
    "The day's almost over. There's still time to look back on it.";
const String reminderLastCallBloomBody =
    'Before today closes, pick a bloom for it.';
const String reminderLastCallLogBody =
    'Before today closes, add a few words about it.';

const ReminderTime _lateNightEnd = ReminderTime(
  hour: lateNightEndHour,
  minute: 0,
);

enum ReminderNudge { midday, evening, lastCall }

class ReminderSlot {
  const ReminderSlot({required this.nudge, required this.time});

  final ReminderNudge nudge;
  final ReminderTime time;

  bool get isLateNight => time.isBefore(_lateNightEnd);

  DateTime on(DateTime day) => DateTime(
    day.year,
    day.month,
    isLateNight ? day.day + 1 : day.day,
    time.hour,
    time.minute,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderSlot && nudge == other.nudge && time == other.time;

  @override
  int get hashCode => Object.hash(nudge, time);

  @override
  String toString() => 'ReminderSlot(nudge: $nudge, time: $time)';
}

class ReminderDay {
  const ReminderDay({this.hasBloom = false, this.logCount = 0});

  final bool hasBloom;
  final int logCount;

  bool get isComplete => isDayComplete(hasBloom: hasBloom, logCount: logCount);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderDay &&
          hasBloom == other.hasBloom &&
          logCount == other.logCount;

  @override
  int get hashCode => Object.hash(hasBloom, logCount);

  @override
  String toString() => 'ReminderDay(hasBloom: $hasBloom, logCount: $logCount)';
}

class ReminderBooking {
  const ReminderBooking({
    required this.id,
    required this.at,
    required this.body,
  });

  final int id;
  final DateTime at;
  final String body;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderBooking &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          at == other.at &&
          body == other.body;

  @override
  int get hashCode => Object.hash(id, at, body);

  @override
  String toString() => 'ReminderBooking(id: $id, at: $at, body: $body)';
}

class ReminderService {
  const ReminderService();

  static const int firstBookingId = 1001;
  static const int windowLength = 7;
  static const ReminderTime middayTime = ReminderTime(hour: 12, minute: 30);
  static const ReminderTime eveningTime = ReminderTime.defaultTime;
  static const ReminderTime lastCallTime = ReminderTime(hour: 22, minute: 30);
  static const ReminderTime lastCallFrom = ReminderTime(hour: 21, minute: 30);

  static final int _nudgesPerDay = ReminderNudge.values.length;

  static final List<int> bookingIds = List<int>.unmodifiable(
    List<int>.generate(
      windowLength * _nudgesPerDay,
      (int offset) => firstBookingId + offset,
    ),
  );

  static int bookingIdFor(DateTime day, ReminderNudge nudge) =>
      firstBookingId +
      (_dayNumber(day) % windowLength) * _nudgesPerDay +
      nudge.index;

  static int _dayNumber(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  List<ReminderSlot> slotsFor(
    ReminderSchedule schedule,
    ReminderTime customTime,
  ) => List<ReminderSlot>.unmodifiable(switch (schedule) {
    ReminderSchedule.evenings => const <ReminderSlot>[
      ReminderSlot(nudge: ReminderNudge.evening, time: eveningTime),
      ReminderSlot(nudge: ReminderNudge.lastCall, time: lastCallTime),
    ],
    ReminderSchedule.middayAndEvening => const <ReminderSlot>[
      ReminderSlot(nudge: ReminderNudge.midday, time: middayTime),
      ReminderSlot(nudge: ReminderNudge.evening, time: eveningTime),
      ReminderSlot(nudge: ReminderNudge.lastCall, time: lastCallTime),
    ],
    ReminderSchedule.custom
        when customTime.isBefore(_lateNightEnd) ||
            !customTime.isBefore(lastCallFrom) =>
      <ReminderSlot>[
        ReminderSlot(nudge: ReminderNudge.lastCall, time: customTime),
      ],
    ReminderSchedule.custom => <ReminderSlot>[
      ReminderSlot(nudge: ReminderNudge.evening, time: customTime),
      const ReminderSlot(nudge: ReminderNudge.lastCall, time: lastCallTime),
    ],
  });

  String bodyFor(ReminderNudge nudge, ReminderDay day) => switch (nudge) {
    ReminderNudge.midday => reminderMiddayBody,
    ReminderNudge.evening => reminderEveningBody,
    ReminderNudge.lastCall => switch ((day.hasBloom, day.logCount > 0)) {
      (false, true) => reminderLastCallBloomBody,
      (true, false) => reminderLastCallLogBody,
      _ => reminderLastCallBody,
    },
  };

  List<DateTime> windowDays(DateTime now) {
    final int firstDay = now.hour < lateNightEndHour ? now.day - 1 : now.day;
    return List<DateTime>.unmodifiable(
      List<DateTime>.generate(
        windowLength,
        (int offset) => DateTime(now.year, now.month, firstDay + offset),
      ),
    );
  }

  List<ReminderBooking>? upcomingReminders({
    required bool enabled,
    required ReminderSchedule schedule,
    required ReminderTime customTime,
    required DateTime now,
    Map<DateTime, ReminderDay> days = const <DateTime, ReminderDay>{},
  }) {
    if (!enabled) {
      return null;
    }
    final Map<DateTime, ReminderDay> byDate = <DateTime, ReminderDay>{
      for (final MapEntry<DateTime, ReminderDay> day in days.entries)
        DateTime(day.key.year, day.key.month, day.key.day): day.value,
    };
    final List<ReminderSlot> slots = slotsFor(schedule, customTime);
    return List<ReminderBooking>.unmodifiable(<ReminderBooking>[
      for (final DateTime date in windowDays(now))
        if (byDate[date] ?? const ReminderDay() case final ReminderDay day
            when !day.isComplete)
          for (final ReminderSlot slot in slots)
            if (slot.on(date).isAfter(now))
              ReminderBooking(
                id: bookingIdFor(date, slot.nudge),
                at: slot.on(date),
                body: bodyFor(slot.nudge, day),
              ),
    ]);
  }
}
