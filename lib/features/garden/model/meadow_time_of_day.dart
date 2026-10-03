import 'package:flutter/foundation.dart';

const String meadowCustomTimeLabel = 'Custom';

@immutable
class MeadowTimeOfDay {
  const MeadowTimeOfDay({required this.label, required this.sub, this.minutes});

  final String label;
  final String sub;
  final int? minutes;

  bool get live => minutes == null;

  @override
  bool operator ==(Object other) =>
      other is MeadowTimeOfDay &&
      other.label == label &&
      other.sub == sub &&
      other.minutes == minutes;

  @override
  int get hashCode => Object.hash(label, sub, minutes);

  @override
  String toString() =>
      'MeadowTimeOfDay(label: $label, sub: $sub, minutes: $minutes)';
}

const MeadowTimeOfDay meadowTimeNow = MeadowTimeOfDay(
  label: 'Now',
  sub: 'live',
);
const MeadowTimeOfDay meadowTimeMorning = MeadowTimeOfDay(
  label: 'Morning',
  sub: '8 am',
  minutes: 8 * 60,
);
const MeadowTimeOfDay meadowTimeAfternoon = MeadowTimeOfDay(
  label: 'Afternoon',
  sub: '2 pm',
  minutes: 14 * 60,
);
const MeadowTimeOfDay meadowTimeEvening = MeadowTimeOfDay(
  label: 'Evening',
  sub: '7 pm',
  minutes: 19 * 60,
);
const MeadowTimeOfDay meadowTimeNight = MeadowTimeOfDay(
  label: 'Night',
  sub: '11 pm',
  minutes: 23 * 60,
);

const List<MeadowTimeOfDay> meadowTimesOfDay = <MeadowTimeOfDay>[
  meadowTimeNow,
  meadowTimeMorning,
  meadowTimeAfternoon,
  meadowTimeEvening,
  meadowTimeNight,
];

MeadowTimeOfDay? meadowTimeOfDayAt(int? minutes) {
  for (final MeadowTimeOfDay time in meadowTimesOfDay) {
    if (time.minutes == minutes) {
      return time;
    }
  }
  return null;
}

String meadowTimeOfDayLabel(int? minutes) =>
    meadowTimeOfDayAt(minutes)?.label ?? meadowCustomTimeLabel;

DateTime meadowTodayAt(DateTime today, int minutes) {
  final DateTime local = today.toLocal();
  return DateTime(
    local.year,
    local.month,
    local.day,
    minutes ~/ 60,
    minutes % 60,
  );
}
