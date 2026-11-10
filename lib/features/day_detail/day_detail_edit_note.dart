import 'dart:async';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/format/clock_format.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart'
    show CaptureMedia;
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/composer_guard.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/core/journal_note_writer.dart'
    show NoteSourceParts, composeNoteSource, readTitledNoteSource;
import 'package:field_notes/features/capture/core/note_draft_controller.dart';
import 'package:field_notes/features/capture/core/saved_note_day_line.dart';
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
  final DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(
    entry.createdAt,
  ).toLocal();
  return 'Editing ${partOfDayFor(createdAt.hour)} note';
}

String _editableSourceOf(Entry entry) =>
    composeNoteSource(title: entry.title, body: entry.textContent ?? '');

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
    final String initialText = _editableSourceOf(widget.entry);
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
    final NoteSourceParts note = readTitledNoteSource(text);
    final NoteWriter writer = await ref.read(noteWriterProvider.future);
    final List<String> photoMediaIds = await notePhotoMediaIds(
      note.body,
      () => ref.read(notePhotoStoreProvider.future),
    );
    return writer.save(
      entryId: widget.entry.id,
      date: widget.date,
      source: note.body,
      title: note.carriesTitle ? note.title : null,
      photoMediaIds: photoMediaIds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool spellCheck =
        spellCheckAvailable &&
        ref.exists(appSettingsProvider) &&
        ref.watch(spellCheckEnabledProvider);
    return ComposerMediaScope(
      resolver: ref.watch(notesMediaResolverProvider).value,
      child: _composer(spellCheck: spellCheck),
    );
  }

  String _clock(BuildContext context) => formatClock(
    context,
    TimeOfDay.fromDateTime(
      DateTime.fromMillisecondsSinceEpoch(widget.entry.createdAt),
    ),
  );

  Widget _composer({required bool spellCheck}) {
    final ValueChanged<bool>? onDone = widget.onDone;
    final DateTime? day = parseDateKey(widget.date);
    return ListenableBuilder(
      listenable: _draft,
      builder: (BuildContext context, Widget? child) {
        return ComposerGuard(
          isDirty: () => _draft.isDirty || _draft.isRestoring,
          locked: _isSaving,
          onDiscard: _draft.discard,
          popResult: false,
          editingSavedNote: true,
          onClose: onDone == null ? null : (Object? result) => onDone(false),
          builder: (BuildContext context, VoidCallback requestClose) {
            return TextComposerSheet(
              controller: _controller,
              title: editNoteTitleFor(widget.entry),
              kicker: _kicker,
              dayLine: savedNoteDayLine(
                dayTitle: _kicker,
                clock: _clock(context),
              ),
              compactDayLine: day == null
                  ? null
                  : savedNoteShortDayLine(day: day, clock: _clock(context)),
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
  return showComposerRoute<bool>(
    context,
    barrierLabel: 'Dismiss note editor',
    child: EditNoteConnector(entry: entry, date: date, exit: exit),
  );
}
