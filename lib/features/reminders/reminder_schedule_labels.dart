import 'package:field_notes/design/format/clock_format.dart';
import 'package:field_notes/domain/services/reminder_service.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';

const String reminderScheduleGroupLabel = 'When to nudge';
const String reminderDefaultTag = 'default';
const String reminderLastCallExplainer =
    'If the day still needs a bloom or a log, one last nudge before it '
    'closes. Comes with any schedule.';

String reminderClockLabel(BuildContext context, ReminderTime time) =>
    formatClock(context, TimeOfDay(hour: time.hour, minute: time.minute));

String reminderScheduleTitle(ReminderSchedule schedule) => switch (schedule) {
  ReminderSchedule.evenings => 'Evenings',
  ReminderSchedule.middayAndEvening => 'Midday and evening',
  ReminderSchedule.custom => 'Custom time',
};

String reminderScheduleDetail(
  BuildContext context,
  ReminderSchedule schedule,
) => switch (schedule) {
  ReminderSchedule.evenings =>
    'Once, around ${reminderClockLabel(context, ReminderService.eveningTime)}.',
  ReminderSchedule.middayAndEvening =>
    'Around ${reminderClockLabel(context, ReminderService.middayTime)} and '
        '${reminderClockLabel(context, ReminderService.eveningTime)}.',
  ReminderSchedule.custom => 'Once, when you choose.',
};

String reminderLastCallTitle(BuildContext context, ReminderTime time) =>
    'Last call at ${reminderClockLabel(context, time)}';
