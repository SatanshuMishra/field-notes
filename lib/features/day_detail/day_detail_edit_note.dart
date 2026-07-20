import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/state/state.dart';

const String editNoteTitle = 'Edit note';
const String editNoteSaveLabel = 'Save changes';
const String editNoteFailedMessage =
    "Couldn't save your changes. Please try again.";

class EditNoteConnector extends ConsumerStatefulWidget {
  const EditNoteConnector({super.key, required this.entry});

  final Entry entry;

  @override
  ConsumerState<EditNoteConnector> createState() => _EditNoteConnectorState();
}

class _EditNoteConnectorState extends ConsumerState<EditNoteConnector> {
  bool _isSaving = false;
  String? _errorMessage;

  Future<void> _save(String text) async {
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

Future<bool?> showEditNote(BuildContext context, {required Entry entry}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss note editor',
    barrierColor: Palette.ink.withValues(alpha: 0.32),
    transitionDuration: Motion.modalPop,
    pageBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return EditNoteConnector(entry: entry);
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
