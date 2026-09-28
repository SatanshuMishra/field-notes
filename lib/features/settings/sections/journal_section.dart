import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/note_engine/capabilities.dart'
    as capabilities;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings_controller.dart';
import '../settings_feedback.dart';
import '../settings_providers.dart';
import '../spell_check_availability.dart';

const Key spellCheckToggleKey = ValueKey<String>('settings-spell-check');
const String spellCheckUnavailableDescription =
    "Your keyboard's spell checker isn't available to Field Notes.";

String _textSizeLabel(TextSize size) => switch (size) {
  TextSize.small => 'Small',
  TextSize.medium => 'Medium',
  TextSize.large => 'Large',
};

class JournalSection extends ConsumerWidget {
  const JournalSection({
    super.key,
    required this.settings,
    required this.onFeedback,
    this.spellCheckAvailable = capabilities.spellCheckAvailable,
    this.spellCheckAvailability = SpellCheckAvailability.available,
  });

  final AppSettings settings;
  final SettingsFeedbackSink onFeedback;
  final bool spellCheckAvailable;
  final SpellCheckAvailability spellCheckAvailability;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool spellCheckWorks =
        spellCheckAvailability == SpellCheckAvailability.available;
    return SettingsSection(
      title: 'Journal',
      children: <Widget>[
        SettingsFieldRow(
          label: 'Text size',
          description: 'Applies across the app.',
          control: SettingsSegmented<TextSize>(
            segments: <SettingsSegment<TextSize>>[
              for (final TextSize size in TextSize.values)
                SettingsSegment<TextSize>(
                  value: size,
                  label: _textSizeLabel(size),
                ),
            ],
            value: settings.textSize,
            onChanged: (TextSize size) => _apply(
              ref,
              () =>
                  ref.read(settingsControllerProvider).setTextSize(size.value),
            ),
          ),
        ),
        SettingsFieldRow(
          label: 'Week starts on',
          description: 'Used by the calendar and this-week garden.',
          control: SettingsSelect<WeekStart>(
            options: <SettingsSelectOption<WeekStart>>[
              for (final WeekStart option in WeekStart.values)
                SettingsSelectOption<WeekStart>(
                  value: option,
                  label: option.label,
                ),
            ],
            value: settings.weekStart,
            onChanged: (WeekStart value) => _apply(
              ref,
              () => ref.read(settingsControllerProvider).setWeekStart(value),
            ),
          ),
        ),
        if (spellCheckAvailable)
          SettingsFieldRow(
            label: 'Spell check',
            description: spellCheckWorks
                ? 'Underlines misspelled words as you write. Checked on this device only.'
                : spellCheckUnavailableDescription,
            control: SettingsToggle(
              key: spellCheckToggleKey,
              semanticLabel: 'Spell check',
              enabled: spellCheckWorks,
              value: spellCheckWorks && settings.spellCheckEnabled,
              onChanged: (bool value) => _apply(
                ref,
                () => ref
                    .read(settingsControllerProvider)
                    .setSpellCheckEnabled(value),
              ),
            ),
          ),
      ],
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
