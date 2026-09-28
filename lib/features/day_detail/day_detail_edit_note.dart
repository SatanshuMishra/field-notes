import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart'
    show CaptureMedia;
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/composer_guard.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/core/note_draft_controller.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/entry_cards/compact/log_preview.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show ComposerMediaScope, spellCheckAvailable;
import 'package:field_notes/features/notes/notes.dart';
import 'package:field_notes/features/notes/photos/photo_import.dart';
import 'package:field_notes/features/today/today_date.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

const String editNoteSaveLabel = 'Save changes';
const String editNoteFailedMessage =
    "Couldn't save your changes. Please try again.";
const String editNoteUpdatedMessage = 'Entry updated';

String editNoteTitleFor(Entry entry) {
  final DateTime createdAt =
      DateTime.fromMillisecondsSinceEpoch(entry.createdAt).toLocal();
  return 'Editing ${partOfDayFor(createdAt.hour)} note';
}

class EditNoteConnector extends ConsumerStatefulWidget {
  const EditNoteConnector({
    super.key,
    required this.entry,
    required this.date,
    this.saveTimeout = textSaveTimeout,
    this.exit = ComposerExit.cancel,
    this.onDone,
  });

  final Entry entry;
  final String date;
  final Duration saveTimeout;
  final ComposerExit exit;
  final ValueChanged<bool>? onDone;

  @override
  ConsumerState<EditNoteConnector> createState() => _EditNoteConnectorState();
}

class _EditNoteConnectorState extends ConsumerState<EditNoteConnector> {
  bool _isSaving = false;
  String? _errorMessage;
  late final String _kicker;
  late final TextEditingController _controller;
  late final NoteDraftController _draft;

  @override
  void initState() {
    super.initState();
    _kicker = _composeKicker();
    final String initialText = widget.entry.textContent ?? '';
    _controller = TextEditingController(text: initialText);
    _draft = NoteDraftController(
      key: widget.entry.id,
      store: ref.read(draftStoreProvider.future),
      initialSource: initialText,
    )..attach(_controller);
    unawaited(_draft.restore());
  }

  @override
  void dispose() {
    _draft.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _composeKicker() {
    final DateTime? parsed = parseDateKey(widget.date);
    if (parsed == null) {
      return widget.date;
    }
    return dayTitleFor(parsed, today: ref.read(todayClockProvider)());
  }

  Future<void> _save(String text) async {
    if (_draft.isRestoring) {
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    final NoteSaveOutcome outcome = await awaitNoteSave(
      _persist(text),
      timeout: widget.saveTimeout,
      unexpectedMessage: editNoteFailedMessage,
    );
    if (!mounted) {
      return;
    }
    if (outcome.entryId == null) {
      setState(() {
        _isSaving = false;
        _errorMessage = outcome.errorMessage ?? editNoteFailedMessage;
      });
      return;
    }
    await _draft.seal();
    if (!mounted) {
      return;
    }
    showTransientToast(context, editNoteUpdatedMessage);
    final ValueChanged<bool>? onDone = widget.onDone;
    if (onDone == null) {
      Navigator.of(context).pop(true);
    } else {
      onDone(true);
    }
  }

  Future<NoteSaveResult> _persist(String text) async {
    await _draft.settle();
    final NoteWriter writer = await ref.read(noteWriterProvider.future);
    final List<String> photoMediaIds = await notePhotoMediaIds(
      text,
      () => ref.read(notePhotoStoreProvider.future),
    );
    return writer.save(
      entryId: widget.entry.id,
      date: widget.date,
      source: text,
      photoMediaIds: photoMediaIds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool spellCheck = spellCheckAvailable &&
        ref.exists(appSettingsProvider) &&
        ref.watch(spellCheckEnabledProvider);
    return ComposerMediaScope(
      resolver: ref.watch(notesMediaResolverProvider).value,
      child: _composer(spellCheck: spellCheck),
    );
  }

  Widget _composer({required bool spellCheck}) {
    final ValueChanged<bool>? onDone = widget.onDone;
    return ListenableBuilder(
      listenable: _draft,
      builder: (BuildContext context, Widget? child) {
        return ComposerGuard(
          isDirty: () => _draft.isDirty || _draft.isRestoring,
          locked: _isSaving,
          onDiscard: _draft.discard,
          popResult: false,
          onClose: onDone == null ? null : (Object? result) => onDone(false),
          builder: (BuildContext context, VoidCallback requestClose) {
            return TextComposerSheet(
              controller: _controller,
              title: editNoteTitleFor(widget.entry),
              kicker: _kicker,
              exit: widget.exit,
              saveLabel: editNoteSaveLabel,
              onSave: _save,
              onCancel: requestClose,
              draftRestored: _draft.restoredDraft,
              onDiscardDraft: _draft.discardRestored,
              errorMessage: _errorMessage,
              isSaving: _isSaving,
              onAddPhoto: () => importNotePhotos(ref),
              spellCheckEnabled: spellCheck,
              photoMediaImporter: (CaptureMedia photo) async =>
                  (await ref.read(notePhotoStoreProvider.future))
                      .importPhoto(photo),
            );
          },
        );
      },
    );
  }
}

Future<bool?> showEditNote(
  BuildContext context, {
  required Entry entry,
  required String date,
  ComposerExit exit = ComposerExit.cancel,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Dismiss note editor',
    barrierColor: const Color(0x00000000),
    transitionDuration: Motion.modalPop,
    pageBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return DialogHost(
        child: ComposerShell(
          closeOnScrimTap: true,
          responsive: true,
          sprig: ComposerSprigPlacement.rightEdge,
          child: EditNoteConnector(entry: entry, date: date, exit: exit),
        ),
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
