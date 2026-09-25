import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/data/database/ids.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/note_engine/capabilities.dart';
import 'package:field_notes/features/note_engine/commands/task_commands.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/notes/notes_providers.dart';

const String taskTickedMessage = 'Task ticked';
const String taskUntickedMessage = 'Task unticked';
const String taskToggleUndoLabel = 'Undo';
const String taskToggleFailedMessage = 'Could not save the change';

@immutable
final class TaskToggle {
  const TaskToggle({required this.previousSource, required this.ticked});

  final String previousSource;
  final bool ticked;
}

typedef NotePhotoStoreLoader = Future<NotePhotoStore> Function();

MdTree _parse(String source) => parseNoteTree(source, tables: tablesEnabled);

Future<TaskToggle?> toggleEntryTask({
  required Entry entry,
  required String date,
  required int boxOffset,
  required NoteWriter writer,
  required NotePhotoStoreLoader photoStore,
}) async {
  final String previous = entry.textContent ?? '';
  if (boxOffset < 0 || boxOffset > previous.length) {
    return null;
  }
  final Transaction? transaction = toggleTaskAt(
    EditorState.create(previous, parse: _parse),
    boxOffset,
  );
  if (transaction == null) {
    return null;
  }
  final String next = transaction.changes.apply(previous);
  await saveEntrySource(
    entry: entry,
    date: date,
    source: next,
    writer: writer,
    photoStore: photoStore,
  );
  return TaskToggle(previousSource: previous, ticked: _ticked(previous, next));
}

bool _ticked(String previous, String next) {
  for (int i = 0; i < next.length; i++) {
    if (previous.codeUnitAt(i) != next.codeUnitAt(i)) {
      return next[i].trim().isNotEmpty;
    }
  }
  return false;
}

Future<void> saveEntrySource({
  required Entry entry,
  required String date,
  required String source,
  required NoteWriter writer,
  required NotePhotoStoreLoader photoStore,
}) async {
  final List<String> photoMediaIds = await notePhotoMediaIds(
    source,
    photoStore,
  );
  await writer.save(
    entryId: entry.id,
    date: date,
    source: source,
    photoMediaIds: photoMediaIds,
    draftKey: newId(),
  );
}

Future<void> toggleTaskWithUndo(
  BuildContext context, {
  required Entry entry,
  required String date,
  required int boxOffset,
}) async {
  final ProviderContainer container = ProviderScope.containerOf(
    context,
    listen: false,
  );
  Future<NotePhotoStore> photoStore() =>
      container.read(notePhotoStoreProvider.future);
  final TaskToggle? toggle;
  try {
    toggle = await toggleEntryTask(
      entry: entry,
      date: date,
      boxOffset: boxOffset,
      writer: await container.read(noteWriterProvider.future),
      photoStore: photoStore,
    );
  } catch (error, stackTrace) {
    debugPrint('Task toggle failed: $error\n$stackTrace');
    if (context.mounted) {
      showTransientToast(context, taskToggleFailedMessage);
    }
    return;
  }
  if (toggle == null || !context.mounted) {
    return;
  }
  final String previousSource = toggle.previousSource;
  showTransientToast(
    context,
    toggle.ticked ? taskTickedMessage : taskUntickedMessage,
    action: ToastAction(
      label: taskToggleUndoLabel,
      onPressed: () async {
        try {
          await saveEntrySource(
            entry: entry,
            date: date,
            source: previousSource,
            writer: await container.read(noteWriterProvider.future),
            photoStore: photoStore,
          );
        } catch (error, stackTrace) {
          debugPrint('Task toggle undo failed: $error\n$stackTrace');
          if (context.mounted) {
            showTransientToast(context, taskToggleFailedMessage);
          }
        }
      },
    ),
  );
}
