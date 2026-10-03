import 'dart:async';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/data/drafts/draft_paths.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/format/clock_format.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart'
    show CaptureMedia;
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/capture_route.dart';
import 'package:field_notes/features/capture/core/composer_guard.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/core/note_draft_controller.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show ComposerMediaScope, spellCheckAvailable;
import 'package:field_notes/features/notes/notes.dart';
import 'package:field_notes/features/notes/photos/photo_import.dart';
import 'package:field_notes/features/today/today_date.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import 'text_composer_sheet.dart';

const String unexpectedSaveMessage =
    'Could not save your note. Please try again.';

const String textSaveTimeoutMessage =
    'Saving took too long. Nothing was saved — please try again.';

const Duration textSaveTimeout = Duration(seconds: 20);

const String newNoteTitle = 'New note';

typedef NoteSaveOutcome = ({String? entryId, String? errorMessage});

Future<NoteSaveOutcome> awaitNoteSave(
  Future<NoteSaveResult> pending, {
  required Duration timeout,
  required String unexpectedMessage,
}) async {
  try {
    final NoteSaveResult result = await pending.timeout(timeout);
    return (entryId: result.entry.id, errorMessage: null);
  } on TimeoutException {
    unawaited(pending.then((_) {}, onError: (_) {}));
    return (entryId: null, errorMessage: textSaveTimeoutMessage);
  } on NoteWriteException catch (error) {
    return (entryId: null, errorMessage: error.message);
  } catch (error, stackTrace) {
    debugPrint('Note save failed: $error\n$stackTrace');
    return (entryId: null, errorMessage: unexpectedMessage);
  }
}

class TextComposerConnector extends ConsumerStatefulWidget {
  const TextComposerConnector({
    super.key,
    required this.date,
    this.saveTimeout = textSaveTimeout,
    this.exit = ComposerExit.cancel,
  });

  final String date;
  final Duration saveTimeout;
  final ComposerExit exit;

  @override
  ConsumerState<TextComposerConnector> createState() =>
      _TextComposerConnectorState();
}

class _TextComposerConnectorState extends ConsumerState<TextComposerConnector> {
  bool _isSaving = false;
  String? _errorMessage;
  late final DateTime _openedAt;
  late final bool _forToday;
  late final String _draftKey;
  late final TextEditingController _controller;
  late final NoteDraftController _draft;

  @override
  void initState() {
    super.initState();
    _openedAt = ref.read(todayClockProvider)();
    _forToday = widget.date == ref.read(todayDateProvider);
    _draftKey = newNoteDraftKey(widget.date);
    _controller = TextEditingController();
    _draft = NoteDraftController(
      key: _draftKey,
      store: ref.read(draftStoreProvider.future),
    )..attach(_controller);
    unawaited(_draft.restore());
  }

  @override
  void dispose() {
    _draft.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _composeKicker(BuildContext context) {
    if (_forToday) {
      final String clock = formatClock(
        context,
        TimeOfDay.fromDateTime(_openedAt),
      );
      return 'Today · $clock';
    }
    final DateTime? parsed = parseDateKey(widget.date);
    return parsed == null ? widget.date : dayTitleFor(parsed, today: _openedAt);
  }

  String _savedToMessage() {
    final DateTime? parsed = parseDateKey(widget.date);
    final DateTime now = ref.read(todayClockProvider)();
    final String place =
        parsed == null ? widget.date : dayShortLabelFor(parsed, today: now);
    return 'Saved to $place';
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
      unexpectedMessage: unexpectedSaveMessage,
    );
    if (!mounted) {
      return;
    }
    final String? entryId = outcome.entryId;
    if (entryId == null) {
      _fail(outcome.errorMessage ?? unexpectedSaveMessage);
      return;
    }
    await _draft.seal();
    if (!mounted) {
      return;
    }
    showTransientToast(context, _savedToMessage());
    Navigator.of(context).pop(entryId);
  }

  Future<NoteSaveResult> _persist(String text) async {
    await _draft.settle();
    final NoteWriter writer = await ref.read(noteWriterProvider.future);
    final List<String> photoMediaIds = await notePhotoMediaIds(
      text,
      () => ref.read(notePhotoStoreProvider.future),
    );
    return writer.save(
      date: widget.date,
      source: text,
      photoMediaIds: photoMediaIds,
      draftKey: _draftKey,
    );
  }

  void _fail(String message) {
    setState(() {
      _isSaving = false;
      _errorMessage = message;
    });
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
    return ListenableBuilder(
      listenable: _draft,
      builder: (BuildContext context, Widget? child) {
        return ComposerGuard(
          isDirty: () => _draft.isDirty || _draft.isRestoring,
          locked: _isSaving,
          onDiscard: _draft.discard,
          builder: (BuildContext context, VoidCallback requestClose) {
            return TextComposerSheet(
              controller: _controller,
              onSave: _save,
              onCancel: requestClose,
              draftRestored: _draft.restoredDraft,
              onDiscardDraft: _draft.discardRestored,
              errorMessage: _errorMessage,
              isSaving: _isSaving,
              title: newNoteTitle,
              kicker: _composeKicker(context),
              exit: widget.exit,
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

Future<String?> showTextComposer(
  BuildContext context,
  String date, {
  ComposerExit exit = ComposerExit.cancel,
}) {
  return showComposerRoute<String>(
    context,
    barrierLabel: 'Dismiss note composer',
    child: TextComposerConnector(date: date, exit: exit),
  );
}

final CaptureRoute textCaptureRoute = CaptureRoute(
  type: EntryType.text,
  open: showTextComposer,
);
