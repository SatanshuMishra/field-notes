import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/photos/photo_relocation.dart';
import 'package:flutter/foundation.dart';

const String photoRemovedToastMessage = 'Photo removed';
const String photoRemovedToastActionLabel = 'Undo';

const int _lineFeed = 0x0A;
const int _carriageReturn = 0x0D;

enum PhotoToast { added, removed }

@immutable
final class PhotoCommandResult {
  const PhotoCommandResult({required this.transaction, this.toast});

  final Transaction transaction;
  final PhotoToast? toast;
}

sealed class PhotoKeyResult {
  const PhotoKeyResult();
}

final class PhotoKeySelect extends PhotoKeyResult {
  const PhotoKeySelect(this.selection);

  final NoteSelection selection;
}

final class PhotoKeyEdit extends PhotoKeyResult {
  const PhotoKeyEdit(this.transaction);

  final Transaction transaction;
}

MdBlock? selectedPhoto(EditorState state) {
  final NoteSelection selection = state.selection;
  final MdBlock? unit = state.tree.blockAt(selection.start);
  if (unit == null || unit.kind != MdBlockKind.photoLine) {
    return null;
  }
  final MdRange line = unit.sourceRange;
  if (selection.isCollapsed) {
    return line.start <= selection.start && selection.start <= line.end
        ? unit
        : null;
  }
  final int end = selection.end;
  final bool covers =
      selection.start == line.start &&
      (end == line.end ||
          end == line.end + _lineBreakLengthAt(state.source, line.end));
  return covers ? unit : null;
}

Transaction? setPhotoSize(EditorState state, MdBlock photo, MdPhotoSize size) {
  final MdPhotoLine line = _photoLine(state, photo);
  final MdPhotoPlacement current = line.placement;
  final MdPhotoPlacement next = current.copyWith(size: size);
  if (current.isValid && next == current) {
    return null;
  }
  return _writeTitle(state, photo, line, next);
}

Transaction? setPhotoSide(EditorState state, MdBlock photo, MdPhotoSide side) {
  final MdPhotoLine line = _photoLine(state, photo);
  final MdPhotoPlacement current = line.placement;
  if (current.isValid && current.size == MdPhotoSize.full) {
    return null;
  }
  final MdPhotoPlacement next = current.copyWith(side: side);
  if (current.isValid && next == current) {
    return null;
  }
  return _writeTitle(state, photo, line, next);
}

Transaction? setPhotoCaption(EditorState state, MdBlock photo, String caption) {
  final MdPhotoLine line = _photoLine(state, photo);
  final String next = sanitizePhotoCaption(caption).trim();
  if (next == line.caption) {
    return null;
  }
  return _slotTransaction(state, photo, line.captionRange, next);
}

Transaction? replacePhotoReference(
  EditorState state,
  MdBlock photo,
  String reference,
) {
  if (reference.isEmpty || !reference.codeUnits.every(_isHexDigit)) {
    throw ArgumentError.value(
      reference,
      'reference',
      'must be one or more hex digits',
    );
  }
  final MdPhotoLine line = _photoLine(state, photo);
  if (reference == line.reference) {
    return null;
  }
  return _slotTransaction(state, photo, line.referenceRange, reference);
}

bool canMovePhotoUp(EditorState state, MdBlock photo) =>
    photoMoveUpBoundary(state.source, state.tree, photo) != null;

bool canMovePhotoDown(EditorState state, MdBlock photo) =>
    photoMoveDownBoundary(state.source, state.tree, photo) != null;

Transaction? movePhotoUp(EditorState state, MdBlock photo) =>
    _move(state, photo, photoMoveUpBoundary(state.source, state.tree, photo));

Transaction? movePhotoDown(EditorState state, MdBlock photo) =>
    _move(state, photo, photoMoveDownBoundary(state.source, state.tree, photo));

PhotoCommandResult removePhoto(EditorState state, MdBlock photo) =>
    PhotoCommandResult(
      transaction: _removal(state, photo),
      toast: PhotoToast.removed,
    );

PhotoKeyResult? photoBackspace(EditorState state) {
  final MdBlock? selected = selectedPhoto(state);
  if (selected != null) {
    return PhotoKeyEdit(_removal(state, selected));
  }
  final NoteSelection selection = state.selection;
  final String source = state.source;
  final int caret = selection.start;
  if (!selection.isCollapsed ||
      caret == 0 ||
      source.codeUnitAt(caret - 1) != _lineFeed) {
    return null;
  }
  final int previousEnd =
      caret >= 2 && source.codeUnitAt(caret - 2) == _carriageReturn
      ? caret - 2
      : caret - 1;
  final MdBlock? unit = state.tree.blockAt(previousEnd);
  if (unit == null ||
      unit.kind != MdBlockKind.photoLine ||
      unit.sourceRange.end != previousEnd) {
    return null;
  }
  return PhotoKeySelect(photoSelection(source, unit));
}

PhotoKeyResult? photoDelete(EditorState state) {
  final MdBlock? selected = selectedPhoto(state);
  if (selected != null) {
    return PhotoKeyEdit(_removal(state, selected));
  }
  final NoteSelection selection = state.selection;
  final String source = state.source;
  final int caret = selection.start;
  final int lineBreak = _lineBreakLengthAt(source, caret);
  if (!selection.isCollapsed || lineBreak == 0) {
    return null;
  }
  final int nextStart = caret + lineBreak;
  final MdBlock? unit = state.tree.blockAt(nextStart);
  if (unit == null ||
      unit.kind != MdBlockKind.photoLine ||
      unit.sourceRange.start != nextStart) {
    return null;
  }
  return PhotoKeySelect(photoSelection(source, unit));
}

Transaction? typeOverSelectedPhoto(
  EditorState state,
  String text, {
  bool composing = false,
}) {
  if (composing && text.isEmpty) {
    throw ArgumentError.value(
      text,
      'text',
      'a composition must insert some text',
    );
  }
  final MdBlock? photo = selectedPhoto(state);
  if (photo == null) {
    return null;
  }
  final String source = state.source;
  final String lineBreak = noteLineBreak(source);
  final int at = photo.sourceRange.end;
  final int textStart = at + lineBreak.length;
  final int textEnd = textStart + text.length;
  return Transaction(
    changes: ChangeSet.single(source.length, at, at, '$lineBreak$text'),
    selection: NoteSelection.collapsed(textEnd),
    event: composing ? TransactionEvent.inputIme : TransactionEvent.inputType,
    composing: composing ? MdRange(textStart, textEnd) : null,
  );
}

String? copySelectedPhoto(EditorState state) {
  return selectedPhoto(state)?.sourceRange.sliceOf(state.source);
}

({String text, Transaction transaction})? cutSelectedPhoto(EditorState state) {
  final MdBlock? photo = selectedPhoto(state);
  if (photo == null) {
    return null;
  }
  return (
    text: photo.sourceRange.sliceOf(state.source),
    transaction: _removal(state, photo),
  );
}

Transaction _removal(EditorState state, MdBlock photo) {
  final PhotoEdit edit = photoRemoval(state.source, state.tree, photo);
  return Transaction(
    changes: edit.changes,
    selection: edit.selection,
    event: TransactionEvent.photo,
  );
}

Transaction? _move(EditorState state, MdBlock photo, int? boundary) {
  if (boundary == null) {
    return null;
  }
  final PhotoEdit? edit = photoRelocation(
    state.source,
    state.tree,
    photo,
    boundary,
  );
  return edit == null
      ? null
      : Transaction(
          changes: edit.changes,
          selection: edit.selection,
          event: TransactionEvent.photo,
        );
}

Transaction _writeTitle(
  EditorState state,
  MdBlock photo,
  MdPhotoLine line,
  MdPhotoPlacement placement,
) {
  final MdRange? title = line.titleRange;
  return title == null
      ? _slotTransaction(
          state,
          photo,
          MdRange(line.referenceRange.end, line.referenceRange.end),
          ' "${placement.format()}"',
        )
      : _slotTransaction(state, photo, title, placement.format());
}

Transaction _slotTransaction(
  EditorState state,
  MdBlock photo,
  MdRange slot,
  String text,
) {
  final MdRange line = photo.sourceRange;
  final int delta = text.length - slot.length;
  return Transaction(
    changes: ChangeSet.single(state.source.length, slot.start, slot.end, text),
    selection: NoteSelection(anchor: line.start, head: line.end + delta),
    event: TransactionEvent.photo,
  );
}

MdPhotoLine _photoLine(EditorState state, MdBlock photo) {
  final MdTree tree = state.tree;
  final int start = photo.sourceRange.start;
  final int? index =
      photo.kind != MdBlockKind.photoLine || start > tree.sourceLength
      ? null
      : tree.blockIndexAt(start);
  if (index == null || tree.blocks[index] != photo) {
    throw ArgumentError.value(
      photo,
      'photo',
      'is not a photo unit of the tree',
    );
  }
  return MdPhotoLine.ofBlock(photo, state.source);
}

int _lineBreakLengthAt(String source, int offset) {
  if (offset < source.length && source.codeUnitAt(offset) == _lineFeed) {
    return 1;
  }
  if (offset + 1 < source.length &&
      source.codeUnitAt(offset) == _carriageReturn &&
      source.codeUnitAt(offset + 1) == _lineFeed) {
    return 2;
  }
  return 0;
}

bool _isHexDigit(int unit) =>
    (unit >= 0x30 && unit <= 0x39) ||
    (unit >= 0x41 && unit <= 0x46) ||
    (unit >= 0x61 && unit <= 0x66);
