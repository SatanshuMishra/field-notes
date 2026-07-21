import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings_controller.dart';
import '../settings_feedback.dart';
import '../settings_providers.dart';

typedef TimeOfDayPicker = Future<TimeOfDay?> Function(
  BuildContext context,
  TimeOfDay initial,
);

Future<TimeOfDay?> showSettingsTimePicker(
  BuildContext context,
  TimeOfDay initial,
) {
  return showTimePicker(context: context, initialTime: initial);
}

class RemindersSoundSection extends ConsumerWidget {
  const RemindersSoundSection({
    super.key,
    required this.settings,
    required this.onFeedback,
    this.pickTime = showSettingsTimePicker,
  });

  final AppSettings settings;
  final SettingsFeedbackSink onFeedback;
  final TimeOfDayPicker pickTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(reminderSyncProvider);
    return SettingsSection(
      title: 'Reminders & sound',
      children: <Widget>[
        SettingsFieldRow(
          label: 'Daily reminder',
          description: 'One nudge a day, skipped once you have written.',
          control: SettingsToggle(
            value: settings.reminderEnabled,
            onChanged: (bool value) => _apply(
              ref,
              () => ref
                  .read(settingsControllerProvider)
                  .setReminderEnabled(value),
            ),
          ),
        ),
        SettingsFieldRow(
          label: 'Reminder time',
          description: 'When the nudge arrives.',
          control: SettingsTimeField(
            value: TimeOfDay(
              hour: settings.reminderTime.hour,
              minute: settings.reminderTime.minute,
            ),
            onTap: () => _chooseTime(context, ref),
          ),
        ),
        SettingsFieldRow(
          label: 'Sound effects',
          description: 'Page turns, pencils, and chimes.',
          control: SettingsToggle(
            value: settings.soundEnabled,
            onChanged: (bool value) => _apply(
              ref,
              () =>
                  ref.read(settingsControllerProvider).setSoundEnabled(value),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _chooseTime(BuildContext context, WidgetRef ref) async {
    final SettingsController controller = ref.read(settingsControllerProvider);
    final TimeOfDay? picked = await pickTime(
      context,
      TimeOfDay(
        hour: settings.reminderTime.hour,
        minute: settings.reminderTime.minute,
      ),
    );
    if (picked == null) {
      return;
    }
    await _apply(
      ref,
      () => controller.setReminderTime(
        ReminderTime(hour: picked.hour, minute: picked.minute),
      ),
    );
  }

  Future<void> _apply(
    WidgetRef ref,
    Future<SettingsWriteResult> Function() action,
  ) async {
    final SettingsWriteResult result = await action();
    if (result is SettingsWriteFailed) {
      onFeedback(result.message);
    }
  }
}
