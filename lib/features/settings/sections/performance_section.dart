import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings_controller.dart';
import '../settings_feedback.dart';
import '../settings_providers.dart';

const Key meadowPauseToggleKey = ValueKey<String>('settings-meadow-pause');

class PerformanceSection extends ConsumerWidget {
  const PerformanceSection({
    super.key,
    required this.settings,
    required this.onFeedback,
  });

  final AppSettings settings;
  final SettingsFeedbackSink onFeedback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSection(
      title: 'Performance',
      children: <Widget>[
        SettingsFieldRow(
          label: 'Pause the Meadow in the background',
          description: "Stops the Meadow's motion while Field Notes is open but another window or app is in front. Saves battery.",
          control: SettingsToggle(
            key: meadowPauseToggleKey,
            semanticLabel: 'Pause the Meadow in the background',
            value: settings.meadowPausesWhenInactive,
            onChanged: (bool value) => _apply(
              ref,
              () => ref
                  .read(settingsControllerProvider)
                  .setMeadowPausesWhenInactive(value),
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
