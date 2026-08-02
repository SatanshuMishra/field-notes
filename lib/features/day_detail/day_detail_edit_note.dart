import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/state/state.dart';

const String editNoteTitle = 'Edit note';
const String editNoteSaveLabel = 'Save changes';
const String editNoteFailedMessage =
    "Couldn't save your changes. Please try again.";
const String editNoteConfirmTitle = 'Save changes?';
const String editNoteConfirmMessage = 'Update this note with your edits?';
const String editNoteConfirmCancelLabel = 'Cancel';
const Key editNoteConfirmSaveKey = ValueKey<String>('edit-note-confirm-save');

const double _confirmMaxWidth = 420;
const double _confirmTitleGap = 8;
const double _confirmActionsGap = 20;
const double _confirmActionSpacing = 12;

class EditNoteConnector extends ConsumerStatefulWidget {
  const EditNoteConnector({super.key, required this.entry});

  final Entry entry;

  @override
  ConsumerState<EditNoteConnector> createState() => _EditNoteConnectorState();
}

class _EditNoteConnectorState extends ConsumerState<EditNoteConnector> {
  bool _isSaving = false;
  String? _errorMessage;

  Future<bool> _confirmSaveChanges() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => const _SaveChangesConfirmDialog(),
    );
    return confirmed ?? false;
  }

  Future<void> _save(String text) async {
    final bool confirmed = await _confirmSaveChanges();
    if (!confirmed || !mounted) {
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await ref.read(journalRepositoryProvider).updateEntryText(
            id: widget.entry.id,
            textContent: text,
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _errorMessage = editNoteFailedMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextComposerSheet(
      initialText: widget.entry.textContent ?? '',
      title: editNoteTitle,
      saveLabel: editNoteSaveLabel,
      onSave: _save,
      onCancel: () => Navigator.of(context).pop(false),
      errorMessage: _errorMessage,
      isSaving: _isSaving,
    );
  }
}

class _SaveChangesConfirmDialog extends StatelessWidget {
  const _SaveChangesConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _confirmMaxWidth),
          child: StickerCard(
            surface: Palette.cardBright,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  editNoteConfirmTitle,
                  style: TypographyTokens.titleSerif,
                ),
                const SizedBox(height: _confirmTitleGap),
                Text(
                  editNoteConfirmMessage,
                  style: TypographyTokens.bodySans,
                ),
                const SizedBox(height: _confirmActionsGap),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: _confirmActionSpacing,
                  runSpacing: _confirmActionSpacing,
                  children: <Widget>[
                    StickerButton(
                      label: editNoteConfirmCancelLabel,
                      variant: StickerButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    StickerButton(
                      key: editNoteConfirmSaveKey,
                      label: editNoteSaveLabel,
                      variant: StickerButtonVariant.primary,
                      labelStyle: TypographyTokens.captureLabelSans,
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

Future<bool?> showEditNote(BuildContext context, {required Entry entry}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss note editor',
    barrierColor: const Color(0x00000000),
    transitionDuration: Motion.modalPop,
    pageBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return DialogHost(
        child: ComposerShell(child: EditNoteConnector(entry: entry)),
      );
    },
    transitionBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      final Animation<double> curved = CurvedAnimation(
        parent: animation,
        curve: Motion.entranceCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
