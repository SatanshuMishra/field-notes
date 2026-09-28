import '../settings/reminder_time.dart';

class ReminderBooking {
  const ReminderBooking({required this.id, required this.at});

  final int id;
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderBooking &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          at == other.at;

  @override
  int get hashCode => Object.hash(id, at);

  @override
  String toString() => 'ReminderBooking(id: $id, at: $at)';
}

class ReminderService {
  const ReminderService();

  static const int firstBookingId = 1001;
  static const int windowLength = 7;

  static final List<int> bookingIds = List<int>.unmodifiable(
    List<int>.generate(windowLength, (int offset) => firstBookingId + offset),
  );

  List<DateTime> windowDays(DateTime now) => List<DateTime>.unmodifiable(
        List<DateTime>.generate(
          windowLength,
          (int offset) => DateTime(now.year, now.month, now.day + offset),
        ),
      );

  List<ReminderBooking>? upcomingReminders({
    required bool enabled,
    required ReminderTime time,
    required DateTime now,
    required bool todayHasEntry,
    Set<DateTime> daysWithEntries = const <DateTime>{},
  }) {
    if (!enabled) {
      return null;
    }
    final Set<DateTime> written = <DateTime>{
      for (final DateTime day in daysWithEntries)
        DateTime(day.year, day.month, day.day),
    };
    DateTime slotOn(DateTime day) =>
        DateTime(day.year, day.month, day.day, time.hour, time.minute);
    final List<DateTime> days = windowDays(now);
    return List<ReminderBooking>.unmodifiable(<ReminderBooking>[
      for (int offset = 0; offset < days.length; offset++)
        if (!written.contains(days[offset]) &&
            (offset > 0 ||
                (!todayHasEntry && slotOn(days[offset]).isAfter(now))))
          ReminderBooking(
            id: firstBookingId + offset,
            at: slotOn(days[offset]),
          ),
    ]);
  }
}
