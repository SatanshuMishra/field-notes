import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reminder_providers.dart';

const String notificationsOffLabel = 'Notifications are off for Field Notes.';
const String openSystemSettingsLabel = 'Open System Settings';
const String openSystemSettingsFailure = 'Could not open System Settings.';

const double _centredGap = 12;
const double _centredRunGap = 4;

enum NotificationsOffLayout { row, centred }

class NotificationsOffNotice extends ConsumerWidget {
  const NotificationsOffNotice({
    super.key,
    required this.onFeedback,
    this.layout = NotificationsOffLayout.row,
  });

  final ValueChanged<String> onFeedback;
  final NotificationsOffLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget button = StickerButton(
      label: openSystemSettingsLabel,
      variant: StickerButtonVariant.secondary,
      padTapTarget: true,
      onPressed: () => _openNotificationSettings(ref),
    );
    return switch (layout) {
      NotificationsOffLayout.row => SettingsFieldRow(
        label: notificationsOffLabel,
        control: button,
      ),
      NotificationsOffLayout.centred => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: _centredGap,
        runSpacing: _centredRunGap,
        children: <Widget>[
          Semantics(
            container: true,
            liveRegion: true,
            child: Text(
              notificationsOffLabel,
              textAlign: TextAlign.center,
              style: context.textStyles.labelSans,
            ),
          ),
          Semantics(container: true, child: button),
        ],
      ),
    };
  }

  Future<void> _openNotificationSettings(WidgetRef ref) async {
    try {
      await ref.read(notificationSettingsOpenerProvider).open();
    } catch (error) {
      debugPrint('Could not open notification settings: $error');
      onFeedback(openSystemSettingsFailure);
    }
  }
}
