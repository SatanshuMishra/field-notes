import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:flutter/material.dart';

const EdgeInsets _desktopGutter = EdgeInsets.symmetric(
  horizontal: settingsGutter,
);

class SettingsNotice extends StatelessWidget {
  const SettingsNotice({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final Widget notice = Row(
      children: <Widget>[
        Expanded(child: Toast(message: message)),
        const SizedBox(width: 12),
        StickerButton(
          label: 'Dismiss',
          variant: StickerButtonVariant.secondary,
          padTapTarget: true,
          onPressed: onDismiss,
        ),
      ],
    );
    return switch (resolveShellLayout(Theme.of(context).platform)) {
      ShellLayout.sidebar => Padding(padding: _desktopGutter, child: notice),
      ShellLayout.bottomBar => notice,
    };
  }
}
