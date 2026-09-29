import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/reminders/reminder_scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings_controller.dart';
import '../settings_feedback.dart';
import '../settings_providers.dart';

typedef TimeOfDayPicker =
    Future<TimeOfDay?> Function(BuildContext context, TimeOfDay initial);

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
    final bool notificationsOff =
        settings.reminderEnabled &&
        ref.watch(reminderPermissionStatusProvider).value ==
            ReminderPermission.denied;
    return SettingsSection(
      title: 'Reminders & sound',
      children: <Widget>[
        SettingsFieldRow(
          label: 'Daily reminder',
          description: 'One nudge a day, skipped once you have written.',
          control: SettingsToggle(
            semanticLabel: 'Daily reminder',
            value: settings.reminderEnabled,
            onChanged: (bool value) => _setReminderEnabled(ref, value),
          ),
        ),
        if (notificationsOff)
          SettingsFieldRow(
            label: 'Notifications are off for Field Notes.',
            control: StickerButton(
              label: 'Open System Settings',
              variant: StickerButtonVariant.secondary,
              padTapTarget: true,
              onPressed: () => _openNotificationSettings(ref),
            ),
          ),
        SettingsFieldRow(
          label: 'Reflection question',
          description: 'Show a gentle prompt when recording voice or video.',
          control: SettingsToggle(
            semanticLabel: 'Reflection question',
            value: settings.reflectionPromptsEnabled,
            onChanged: (bool value) => _apply(
              ref,
              () => ref
                  .read(settingsControllerProvider)
                  .setReflectionPromptsEnabled(value),
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
          description: 'A soft pencil sound when you plant a mood.',
          control: SettingsToggle(
            semanticLabel: 'Sound effects',
            value: settings.soundEnabled,
            onChanged: (bool value) => _apply(
              ref,
              () => ref.read(settingsControllerProvider).setSoundEnabled(value),
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

  Future<void> _setReminderEnabled(WidgetRef ref, bool value) async {
    final SettingsController controller = ref.read(settingsControllerProvider);
    final ReminderPermissionStatus permission = ref.read(
      reminderPermissionStatusProvider.notifier,
    );
    final bool saved = await _apply(
      ref,
      () => controller.setReminderEnabled(value),
    );
    if (saved && value) {
      await permission.requestUnlessGranted();
    }
  }

  Future<void> _openNotificationSettings(WidgetRef ref) async {
    try {
      await ref.read(notificationSettingsOpenerProvider).open();
    } catch (error) {
      debugPrint('Could not open notification settings: $error');
      onFeedback('Could not open System Settings.');
    }
  }

  Future<bool> _apply(
    WidgetRef ref,
    Future<SettingsWriteResult> Function() action,
  ) async {
    final SettingsWriteResult result = await action();
    if (result is SettingsWriteFailed) {
      onFeedback(result.message);
      return false;
    }
    return true;
  }
}
