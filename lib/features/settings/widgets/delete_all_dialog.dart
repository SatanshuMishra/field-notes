import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:flutter/material.dart';

const String _deleteAllTitle = 'Delete everything?';
const String _deleteAllMessage =
    'This erases every entry, photo, and mood on this device. '
    'It cannot be undone.';
const String _keepLabel = 'Keep my journal';
const String _deleteLabel = 'Delete everything';

Future<bool> confirmDeleteAll(BuildContext context) async {
  if (resolveShellLayout(Theme.of(context).platform) == ShellLayout.bottomBar) {
    return showConfirmDialog(
      context,
      title: _deleteAllTitle,
      message: _deleteAllMessage,
      confirmLabel: _deleteLabel,
      cancelLabel: _keepLabel,
      danger: true,
    );
  }
  final bool? confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) => const DeleteAllConfirmDialog(),
  );
  return confirmed ?? false;
}

class DeleteAllConfirmDialog extends StatelessWidget {
  const DeleteAllConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final FieldNotesTextStyles textStyles = context.textStyles;
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: StickerCard(
            surface: context.colors.cardBright,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(_deleteAllTitle, style: textStyles.titleSerif),
                const SizedBox(height: 8),
                Text(_deleteAllMessage, style: textStyles.bodySans),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    StickerButton(
                      label: _keepLabel,
                      variant: StickerButtonVariant.secondary,
                      padTapTarget: true,
                      autofocus: true,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    StickerButton(
                      label: _deleteLabel,
                      variant: StickerButtonVariant.danger,
                      padTapTarget: true,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
