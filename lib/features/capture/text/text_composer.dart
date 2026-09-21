import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/data/database/ids.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/capture_route.dart';
import 'package:field_notes/features/capture/core/composer_guard.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/core/note_draft_controller.dart';
import 'package:field_notes/features/notes/notes.dart';
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

Widget composerPhotoRail(BuildContext context, ComposerRailSlot slot) {
  return ComposerPhotoRail(
    controller: slot.controller,
    measure: slot.measure,
    editorFocusNode: slot.focusNode,
    maxHeight: slot.maxHeight,
  );
}

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
  });

  final String date;
  final Duration saveTimeout;

  @override
  ConsumerState<TextComposerConnector> createState() =>
      _TextComposerConnectorState();
}

class _TextComposerConnectorState extends ConsumerState<TextComposerConnector> {
  bool _isSaving = false;
  String? _errorMessage;
  late final String _metaText;
  late final String _title;
  late final String _sessionId;
  late final TextEditingController _controller;
  late final NoteDraftController _draft;

  @override
  void initState() {
    super.initState();
    _metaText = _composeMeta();
    _title = _composeTitle();
    _sessionId = newId();
    _controller = TextEditingController();
    _draft = NoteDraftController(
      key: _sessionId,
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

  String _composeTitle() {
    if (widget.date == ref.read(todayDateProvider)) {
      return newNoteTitle;
    }
    final DateTime? parsed = parseDateKey(widget.date);
    final String dayLabel =
        parsed == null ? widget.date : headerDateLabel(parsed);
    return '$newNoteTitle · $dayLabel';
  }

  String _composeMeta() {
    final DateTime? parsed = parseDateKey(widget.date);
    final String longDate =
        parsed == null ? widget.date : headerDateLabel(parsed);
    final DateTime now = ref.read(todayClockProvider)();
    final String hour = now.hour.toString().padLeft(2, '0');
    final String minute = now.minute.toString().padLeft(2, '0');
    return '$longDate · $hour:$minute';
  }

  Future<void> _save(String text) async {
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
      draftKey: _sessionId,
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
    return ListenableBuilder(
      listenable: _draft,
      builder: (BuildContext context, Widget? child) {
        return ComposerGuard(
          isDirty: () => _draft.isDirty,
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
              title: _title,
              metaText: _metaText,
              photoRail: composerPhotoRail,
            );
          },
        );
      },
    );
  }
}

Future<String?> showTextComposer(BuildContext context, String date) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Dismiss note composer',
    barrierColor: const Color(0x00000000),
    transitionDuration: Motion.modalPop,
    pageBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return DialogHost(
        child: ComposerShell(child: TextComposerConnector(date: date)),
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

final CaptureRoute textCaptureRoute = CaptureRoute(
  type: EntryType.text,
  open: showTextComposer,
);
