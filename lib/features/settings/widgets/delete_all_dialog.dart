import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:flutter/material.dart';

Future<bool> confirmDeleteAll(BuildContext context) async {
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
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: StickerCard(
            surface: Palette.cardBright,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Delete everything?', style: TypographyTokens.titleSerif),
                const SizedBox(height: 8),
                Text(
                  'This erases every entry, photo, and mood on this device. '
                  'It cannot be undone.',
                  style: TypographyTokens.bodySans,
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    StickerButton(
                      label: 'Keep my journal',
                      variant: StickerButtonVariant.secondary,
                      padTapTarget: true,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    StickerButton(
                      label: 'Delete everything',
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
