import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/projection/offset_map_builder.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show CharacterRange;

const int _lineFeed = 0x0A;
const int _carriageReturn = 0x0D;
const int _pipe = 0x7C;

sealed class DeltaOutcome {
  const DeltaOutcome();
}

final class MappedEdit extends DeltaOutcome {
  const MappedEdit(this.transaction);

  final Transaction transaction;

  @override
  String toString() => 'MappedEdit($transaction)';
}

final class SelectionEdit extends DeltaOutcome {
  const SelectionEdit({required this.selection, this.composing});

  final NoteSelection selection;
  final MdRange? composing;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectionEdit &&
          selection == other.selection &&
          composing == other.composing;

  @override
  int get hashCode => Object.hash(selection, composing);

  @override
  String toString() => 'SelectionEdit($selection, composing: $composing)';
}

sealed class ClassifiedEdit extends DeltaOutcome {
  const ClassifiedEdit();
}

final class BackspaceEdit extends ClassifiedEdit {
  const BackspaceEdit();

  @override
  bool operator ==(Object other) => other is BackspaceEdit;

  @override
  int get hashCode => (BackspaceEdit).hashCode;

  @override
  String toString() => 'BackspaceEdit()';
}

final class ForwardDeleteEdit extends ClassifiedEdit {
  const ForwardDeleteEdit();

  @override
  bool operator ==(Object other) => other is ForwardDeleteEdit;

  @override
  int get hashCode => (ForwardDeleteEdit).hashCode;

  @override
  String toString() => 'ForwardDeleteEdit()';
}

final class TypeAfterPhotoEdit extends ClassifiedEdit {
  const TypeAfterPhotoEdit({
    required this.photoLine,
    required this.text,
    required this.composing,
  });

  final MdRange photoLine;
  final String text;
  final bool composing;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypeAfterPhotoEdit &&
          photoLine == other.photoLine &&
          text == other.text &&
          composing == other.composing;

  @override
  int get hashCode =>
      Object.hash(TypeAfterPhotoEdit, photoLine, text, composing);

  @override
  String toString() =>
      "TypeAfterPhotoEdit($photoLine, '$text', composing: $composing)";
}

final class SelectPhotoEdit extends ClassifiedEdit {
  const SelectPhotoEdit(this.photoLine);

  final MdRange photoLine;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectPhotoEdit && photoLine == other.photoLine;

  @override
  int get hashCode => Object.hash(SelectPhotoEdit, photoLine);

  @override
  String toString() => 'SelectPhotoEdit($photoLine)';
}

final class RemovePhotoEdit extends ClassifiedEdit {
  const RemovePhotoEdit(this.photoLine);

  final MdRange photoLine;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemovePhotoEdit && photoLine == other.photoLine;

  @override
  int get hashCode => Object.hash(RemovePhotoEdit, photoLine);

  @override
  String toString() => 'RemovePhotoEdit($photoLine)';
}

final class ListMarkerEdit extends ClassifiedEdit {
  const ListMarkerEdit(this.contentStart);

  final int contentStart;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListMarkerEdit && contentStart == other.contentStart;

  @override
  int get hashCode => Object.hash(ListMarkerEdit, contentStart);

  @override
  String toString() => 'ListMarkerEdit($contentStart)';
}

final class EnterEdit extends ClassifiedEdit {
  const EnterEdit();

  @override
  bool operator ==(Object other) => other is EnterEdit;

  @override
  int get hashCode => (EnterEdit).hashCode;

  @override
  String toString() => 'EnterEdit()';
}

final class TableCellTextEdit extends ClassifiedEdit {
  const TableCellTextEdit({required this.replaced, required this.text});

  final MdRange replaced;
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableCellTextEdit &&
          replaced == other.replaced &&
          text == other.text;

  @override
  int get hashCode => Object.hash(TableCellTextEdit, replaced, text);

  @override
  String toString() => "TableCellTextEdit($replaced, '$text')";
}

final class RejectedEdit extends ClassifiedEdit {
  const RejectedEdit();

  @override
  bool operator ==(Object other) => other is RejectedEdit;

  @override
  int get hashCode => (RejectedEdit).hashCode;

  @override
  String toString() => 'RejectedEdit()';
}

DeltaOutcome mapDelta({
  required EditorState state,
  required VisibleText visible,
  required int windowBase,
  required TextEditingValue platformBefore,
  required TextEditingDelta delta,
  bool classify = true,
}) {
  final _Replaced? replaced = _replacedOf(delta);
  if (replaced == null) {
    return _selectionEdit(state, visible, windowBase, delta);
  }
  final bool composingBefore =
      _hasComposing(platformBefore.composing) || state.composing != null;
  if (classify && !composingBefore) {
    final ClassifiedEdit? classified = _classify(
      state,
      visible,
      windowBase,
      platformBefore,
      delta,
      replaced,
    );
    if (classified != null) {
      return classified;
    }
  }
  return MappedEdit(
    _transaction(
      state,
      visible,
      windowBase,
      platformBefore,
      delta,
      replaced,
      composingBefore: composingBefore,
    ),
  );
}

int sourcePositionForVisible({
  required EditorState state,
  required VisibleText visible,
  required int visibleOffset,
  required TextAffinity affinity,
}) {
  final SourceOffsets candidates = visible.map.visibleToSource(visibleOffset);
  final NoteSelection selection = state.selection;
  final int caret = selection.head;
  final int chosen =
      selection.isCollapsed &&
          (caret == candidates.upstream || caret == candidates.downstream)
      ? caret
      : candidates.upstream;
  final MdRange content = _contentRangeAt(state, visible, visibleOffset);
  final int clamped = chosen < content.start
      ? content.start
      : chosen > content.end
      ? content.end
      : chosen;
  return _isInsideCrlf(state.source, clamped) ? clamped - 1 : clamped;
}

MdRange sourceRangeForVisible({
  required EditorState state,
  required VisibleText visible,
  required TextRange visibleRange,
}) {
  final int low = visibleRange.start < visibleRange.end
      ? visibleRange.start
      : visibleRange.end;
  final int high = visibleRange.start < visibleRange.end
      ? visibleRange.end
      : visibleRange.start;
  if (low == high) {
    final int position = sourcePositionForVisible(
      state: state,
      visible: visible,
      visibleOffset: low,
      affinity: TextAffinity.downstream,
    );
    return MdRange(position, position);
  }
  final MdRange widened = _widenOverAtomics(visible, MdRange(low, high));
  final int start = visible.map.visibleToSource(widened.start).downstream;
  final int upstreamEnd = visible.map.visibleToSource(widened.end).upstream;
  final int end = upstreamEnd < start ? start : upstreamEnd;
  final MdRange withNodes = _widenOverHiddenNodes(
    state.tree,
    visible,
    widened,
    MdRange(start, end),
  );
  return _widenOverCrlf(state.source, withNodes);
}

TextSelection visibleSelectionFor({
  required VisibleText visible,
  required NoteSelection selection,
  required int windowBase,
}) {
  final AtomicObject? photo = _selectedPhotoAtomic(visible, selection);
  if (photo != null) {
    return TextSelection(
      baseOffset: photo.visibleOffset - windowBase,
      extentOffset: photo.visibleOffset + 1 - windowBase,
      affinity: selection.affinity,
    );
  }
  return TextSelection(
    baseOffset: visible.map.sourceToVisible(selection.anchor) - windowBase,
    extentOffset: visible.map.sourceToVisible(selection.head) - windowBase,
    affinity: selection.affinity,
  );
}

MdRange? selectedPhotoLine(EditorState state) {
  final NoteSelection selection = state.selection;
  final MdBlock? block = state.tree.blockAt(selection.start);
  if (block == null || block.kind != MdBlockKind.photoLine) {
    return null;
  }
  final MdRange line = block.sourceRange;
  if (selection.isCollapsed) {
    return line.start <= selection.start && selection.start <= line.end
        ? line
        : null;
  }
  if (selection.start != line.start) {
    return null;
  }
  final int breakEnd = line.end + _lineBreakLength(state.source, line.end);
  return selection.end == line.end || selection.end == breakEnd ? line : null;
}

final class _Replaced {
  const _Replaced(this.start, this.end, this.text);

  final int start;
  final int end;
  final String text;

  bool get isDeletion => text.isEmpty && end > start;
}

final class _CellHit {
  const _CellHit(this.row, this.content);

  final MdBlock row;
  final MdRange content;
}

_Replaced? _replacedOf(TextEditingDelta delta) => switch (delta) {
  final TextEditingDeltaInsertion insertion => _Replaced(
    insertion.insertionOffset,
    insertion.insertionOffset,
    insertion.textInserted,
  ),
  final TextEditingDeltaDeletion deletion => _Replaced(
    deletion.deletedRange.start,
    deletion.deletedRange.end,
    '',
  ),
  final TextEditingDeltaReplacement replacement => _Replaced(
    replacement.replacedRange.start,
    replacement.replacedRange.end,
    replacement.replacementText,
  ),
  _ => null,
};

bool _hasComposing(TextRange range) => range.isValid && !range.isCollapsed;

SelectionEdit _selectionEdit(
  EditorState state,
  VisibleText visible,
  int windowBase,
  TextEditingDelta delta,
) {
  final TextSelection platform = delta.selection;
  final NoteSelection selection;
  if (!platform.isValid) {
    selection = state.selection;
  } else if (platform.isCollapsed) {
    selection = NoteSelection.collapsed(
      sourcePositionForVisible(
        state: state,
        visible: visible,
        visibleOffset: platform.baseOffset + windowBase,
        affinity: platform.affinity,
      ),
      affinity: platform.affinity,
    );
  } else {
    final MdRange range = sourceRangeForVisible(
      state: state,
      visible: visible,
      visibleRange: TextRange(
        start: platform.start + windowBase,
        end: platform.end + windowBase,
      ),
    );
    selection = platform.baseOffset <= platform.extentOffset
        ? NoteSelection(
            anchor: range.start,
            head: range.end,
            affinity: platform.affinity,
          )
        : NoteSelection(
            anchor: range.end,
            head: range.start,
            affinity: platform.affinity,
          );
  }
  final TextRange composing = delta.composing;
  final MdRange? composingRange = _hasComposing(composing)
      ? sourceRangeForVisible(
          state: state,
          visible: visible,
          visibleRange: TextRange(
            start: composing.start + windowBase,
            end: composing.end + windowBase,
          ),
        )
      : null;
  return SelectionEdit(
    selection: selection,
    composing: composingRange == null || composingRange.isEmpty
        ? null
        : composingRange,
  );
}

ClassifiedEdit? _classify(
  EditorState state,
  VisibleText visible,
  int windowBase,
  TextEditingValue platformBefore,
  TextEditingDelta delta,
  _Replaced replaced,
) {
  final int start = replaced.start + windowBase;
  final int end = replaced.end + windowBase;
  final String text = replaced.text;
  final MdRange? selectedPhoto = selectedPhotoLine(state);
  if (selectedPhoto != null && text.isNotEmpty) {
    final AtomicObject? photo = _photoAtomicFor(visible, selectedPhoto);
    if (photo != null &&
        start <= photo.visibleOffset + 1 &&
        end >= photo.visibleOffset) {
      return TypeAfterPhotoEdit(
        photoLine: selectedPhoto,
        text: text,
        composing: _hasComposing(delta.composing),
      );
    }
  }
  if (replaced.isDeletion && _holdsOnlySeparators(visible, start, end)) {
    return const RejectedEdit();
  }
  final TextSelection before = platformBefore.selection;
  final bool replacesSelection =
      before.isValid &&
      !before.isCollapsed &&
      before.start == replaced.start &&
      before.end == replaced.end;
  if (text == '\n' && (start == end || replacesSelection)) {
    return const EnterEdit();
  }
  if (replaced.isDeletion && end == start + 1) {
    final AtomicObject? atStart = visible.atomicAtVisible(start);
    if (start > 0 && visible.text.codeUnitAt(start) == _lineFeed) {
      final AtomicObject? photo = visible.atomicAtVisible(start - 1);
      if (photo != null &&
          photo.kind == AtomicKind.photo &&
          photo.visibleOffset == start - 1 &&
          photo.sourceRange != selectedPhoto) {
        return SelectPhotoEdit(photo.sourceRange);
      }
    }
    if (atStart != null &&
        atStart.kind == AtomicKind.photo &&
        atStart.visibleOffset == start) {
      return RemovePhotoEdit(atStart.sourceRange);
    }
  }
  if (replaced.isDeletion && before.isValid && before.isCollapsed) {
    final String platformText = platformBefore.text;
    final int caret = before.baseOffset;
    if (replaced.end == caret &&
        _graphemeStartBefore(platformText, caret) == replaced.start) {
      return const BackspaceEdit();
    }
    if (replaced.start == caret &&
        _graphemeEndAfter(platformText, caret) == replaced.end) {
      return const ForwardDeleteEdit();
    }
  }
  if (replaced.isDeletion) {
    final int? contentStart = _listMarkerContentStart(
      state,
      visible,
      sourceRangeForVisible(
        state: state,
        visible: visible,
        visibleRange: TextRange(start: start, end: end),
      ),
    );
    if (contentStart != null) {
      return ListMarkerEdit(contentStart);
    }
  }
  if (text.isNotEmpty && _breaksCell(text)) {
    final _CellHit? first = _cellAt(state, visible, start);
    final _CellHit? last = _cellAt(state, visible, end);
    if (first != null &&
        last != null &&
        identical(first.row, last.row) &&
        first.content == last.content) {
      final MdRange range = sourceRangeForVisible(
        state: state,
        visible: visible,
        visibleRange: TextRange(start: start, end: end),
      );
      return TableCellTextEdit(
        replaced: _clampRange(range, first.content),
        text: text,
      );
    }
  }
  return null;
}

Transaction _transaction(
  EditorState state,
  VisibleText visible,
  int windowBase,
  TextEditingValue platformBefore,
  TextEditingDelta delta,
  _Replaced replaced, {
  required bool composingBefore,
}) {
  final int start = replaced.start + windowBase;
  final int end = replaced.end + windowBase;
  final String text = replaced.text;
  final MdRange range = _replacedSourceRange(
    state,
    visible,
    windowBase,
    platformBefore,
    delta,
    replaced,
  );
  final List<MdRange> pieces = _splitAtTables(state.tree, range);
  final ChangeSet changes = ChangeSet(
    length: state.source.length,
    replacements: <TextReplacement>[
      for (int i = 0; i < pieces.length; i++)
        TextReplacement(pieces[i].start, pieces[i].end, i == 0 ? text : ''),
    ],
  );
  final int insertionStart = pieces.first.start;
  int toSource(int platformOffset, TextAffinity affinity) {
    final int offset = platformOffset + windowBase;
    if (offset >= start && offset <= start + text.length) {
      return insertionStart + (offset - start);
    }
    final int oldOffset = offset < start
        ? offset
        : offset - text.length + (end - start);
    return changes.mapPosition(
      sourcePositionForVisible(
        state: state,
        visible: visible,
        visibleOffset: oldOffset,
        affinity: affinity,
      ),
      side: MapSide.after,
    );
  }

  final TextSelection after = delta.selection;
  final NoteSelection selection = after.isValid
      ? NoteSelection(
          anchor: toSource(after.baseOffset, after.affinity),
          head: toSource(after.extentOffset, after.affinity),
          affinity: after.affinity,
        )
      : NoteSelection.collapsed(insertionStart + text.length);
  final TextRange composingAfter = delta.composing;
  final MdRange? composing = _hasComposing(composingAfter)
      ? _nonEmpty(
          toSource(composingAfter.start, TextAffinity.downstream),
          toSource(composingAfter.end, TextAffinity.upstream),
        )
      : null;
  final bool isIme = composingBefore || composing != null;
  return Transaction(
    changes: changes,
    selection: selection,
    event: isIme
        ? TransactionEvent.inputIme
        : text.isEmpty
        ? TransactionEvent.inputDelete
        : TransactionEvent.inputType,
    addToHistory: !isIme,
    composing: composing,
  );
}

MdRange? _nonEmpty(int start, int end) =>
    end > start ? MdRange(start, end) : null;

MdRange _replacedSourceRange(
  EditorState state,
  VisibleText visible,
  int windowBase,
  TextEditingValue platformBefore,
  TextEditingDelta delta,
  _Replaced replaced,
) {
  final int start = replaced.start + windowBase;
  final int end = replaced.end + windowBase;
  if (start == end) {
    final int position = sourcePositionForVisible(
      state: state,
      visible: visible,
      visibleOffset: start,
      affinity: delta.selection.affinity,
    );
    return MdRange(position, position);
  }
  final TextSelection before = platformBefore.selection;
  if (before.isValid &&
      !before.isCollapsed &&
      before.start == replaced.start &&
      before.end == replaced.end) {
    final TextSelection stateSelection = visibleSelectionFor(
      visible: visible,
      selection: state.selection,
      windowBase: windowBase,
    );
    if (stateSelection.start == before.start &&
        stateSelection.end == before.end) {
      return MdRange(state.selection.start, state.selection.end);
    }
  }
  return sourceRangeForVisible(
    state: state,
    visible: visible,
    visibleRange: TextRange(start: start, end: end),
  );
}

List<MdRange> _splitAtTables(MdTree tree, MdRange range) {
  final List<MdRange> pieces = <MdRange>[];
  int at = range.start;
  for (final MdBlock table in tree.blocks) {
    final MdRange bounds = table.sourceRange;
    if (table.kind != MdBlockKind.table ||
        bounds.end <= range.start ||
        bounds.start >= range.end) {
      continue;
    }
    if (range.start <= bounds.start && bounds.end <= range.end) {
      continue;
    }
    if (at < bounds.start) {
      pieces.add(MdRange(at, bounds.start));
    }
    for (final MdBlock row in table.blocks) {
      for (final MdBlock cell in row.blocks) {
        final MdRange content = cell.contentRange;
        if (content.end < range.start || content.start > range.end) {
          continue;
        }
        pieces.add(_clampRange(range, content));
      }
    }
    at = bounds.end > at ? bounds.end : at;
  }
  if (at < range.end) {
    pieces.add(MdRange(at, range.end));
  }
  if (pieces.isEmpty) {
    pieces.add(MdRange(range.start, range.start));
  }
  return pieces;
}

MdRange _clampRange(MdRange range, MdRange bounds) {
  final int start = range.start < bounds.start
      ? bounds.start
      : range.start > bounds.end
      ? bounds.end
      : range.start;
  final int end = range.end > bounds.end
      ? bounds.end
      : range.end < start
      ? start
      : range.end;
  return MdRange(start, end);
}

MdRange _contentRangeAt(EditorState state, VisibleText visible, int offset) {
  final int? index = VisibleLineIndex(visible).lineAtVisible(offset);
  if (index == null) {
    return MdRange(0, state.source.length);
  }
  final _CellHit? cell = _cellAt(state, visible, offset);
  if (cell != null) {
    return cell.content;
  }
  final VisibleLine line = visible.lines[index];
  final bool hasBreak =
      line.spans.isNotEmpty &&
      line.spans.last.kind == VisibleSpanKind.lineBreak;
  final int first = line.visibleRange.start;
  final int last = hasBreak ? line.visibleRange.end - 1 : line.visibleRange.end;
  final int low = visible.map.visibleToSource(first).downstream;
  final int high = visible.map.visibleToSource(last).upstream;
  return MdRange(low, high < low ? low : high);
}

_CellHit? _cellAt(EditorState state, VisibleText visible, int offset) {
  final int? index = VisibleLineIndex(visible).lineAtVisible(offset);
  if (index == null) {
    return null;
  }
  final VisibleLine line = visible.lines[index];
  final MdBlock? table = state.tree.blockAt(line.sourceRange.start);
  if (table == null || table.kind != MdBlockKind.table) {
    return null;
  }
  for (final MdBlock row in table.blocks) {
    final int rowStart = row.sourceRange.start;
    if (rowStart < line.sourceRange.start || rowStart > line.sourceRange.end) {
      continue;
    }
    for (final MdBlock cell in row.blocks) {
      final MdRange content = cell.contentRange;
      if (visible.map.sourceToVisible(content.start) <= offset &&
          offset <= visible.map.sourceToVisible(content.end)) {
        return _CellHit(row, content);
      }
    }
    return null;
  }
  return null;
}

MdRange _widenOverAtomics(VisibleText visible, MdRange range) {
  final AtomicObject? first = visible.atomicAtVisible(range.start);
  final AtomicObject? last = visible.atomicAtVisible(range.end - 1);
  final int start = first != null && first.visibleOffset < range.start
      ? first.visibleOffset
      : range.start;
  final int end = last != null && last.visibleRange.end > range.end
      ? last.visibleRange.end
      : range.end;
  return MdRange(start, end);
}

MdRange _widenOverHiddenNodes(
  MdTree tree,
  VisibleText visible,
  MdRange visibleRange,
  MdRange sourceRange,
) {
  int start = sourceRange.start;
  int end = sourceRange.end;
  void visitInline(MdInline inline) {
    final MdRange bounds = inline.sourceRange;
    if (bounds.end < sourceRange.start || bounds.start > sourceRange.end) {
      return;
    }
    final MdRange content = inline.contentRange;
    if (inline.markerRanges.isNotEmpty &&
        inline.markerRanges.every((MdRange m) => _isHidden(visible, m))) {
      final int contentStart = visible.map.sourceToVisible(content.start);
      final int contentEnd = visible.map.sourceToVisible(content.end);
      if (contentStart < contentEnd &&
          visibleRange.start <= contentStart &&
          contentEnd <= visibleRange.end) {
        start = bounds.start < start ? bounds.start : start;
        end = bounds.end > end ? bounds.end : end;
      }
    }
    for (final MdInline child in inline.children) {
      visitInline(child);
    }
  }

  void visitBlock(MdBlock block) {
    final MdRange bounds = block.sourceRange;
    if (bounds.end < sourceRange.start || bounds.start > sourceRange.end) {
      return;
    }
    for (final MdInline inline in block.inlines) {
      visitInline(inline);
    }
    for (final MdBlock child in block.blocks) {
      visitBlock(child);
    }
  }

  for (final MdBlock block in tree.blocks) {
    visitBlock(block);
  }
  return MdRange(start, end);
}

bool _isHidden(VisibleText visible, MdRange marker) =>
    marker.isEmpty ||
    visible.map.sourceToVisible(marker.start) ==
        visible.map.sourceToVisible(marker.end);

MdRange _widenOverCrlf(String source, MdRange range) {
  final int start = _isInsideCrlf(source, range.start)
      ? range.start - 1
      : range.start;
  final int end = _isInsideCrlf(source, range.end) ? range.end + 1 : range.end;
  return MdRange(start, end);
}

bool _isInsideCrlf(String source, int offset) =>
    offset > 0 &&
    offset < source.length &&
    source.codeUnitAt(offset - 1) == _carriageReturn &&
    source.codeUnitAt(offset) == _lineFeed;

int _lineBreakLength(String source, int offset) {
  if (offset >= source.length) {
    return 0;
  }
  final int unit = source.codeUnitAt(offset);
  if (unit == _lineFeed) {
    return 1;
  }
  return unit == _carriageReturn &&
          offset + 1 < source.length &&
          source.codeUnitAt(offset + 1) == _lineFeed
      ? 2
      : 0;
}

bool _holdsOnlySeparators(VisibleText visible, int start, int end) {
  for (int offset = start; offset < end; offset++) {
    final AtomicObject? atomic = visible.atomicAtVisible(offset);
    if (atomic == null || atomic.kind != AtomicKind.tableSeparator) {
      return false;
    }
  }
  return end > start;
}

bool _breaksCell(String text) {
  for (int i = 0; i < text.length; i++) {
    final int unit = text.codeUnitAt(i);
    if (unit == _pipe || unit == _lineFeed || unit == _carriageReturn) {
      return true;
    }
  }
  return false;
}

int? _graphemeStartBefore(String text, int offset) {
  if (offset <= 0 || offset > text.length) {
    return null;
  }
  final CharacterRange range = CharacterRange.at(text, offset);
  return range.moveBack() ? range.stringBeforeLength : null;
}

int? _graphemeEndAfter(String text, int offset) {
  if (offset < 0 || offset >= text.length) {
    return null;
  }
  final CharacterRange range = CharacterRange.at(text, offset);
  return range.moveNext()
      ? range.stringBeforeLength + range.current.length
      : null;
}

AtomicObject? _photoAtomicFor(VisibleText visible, MdRange line) {
  final AtomicObject? atomic = visible.atomicAtSource(line.start);
  return atomic != null &&
          atomic.kind == AtomicKind.photo &&
          atomic.sourceRange == line
      ? atomic
      : null;
}

AtomicObject? _selectedPhotoAtomic(
  VisibleText visible,
  NoteSelection selection,
) {
  final int start = selection.start;
  final AtomicObject? containing = visible.atomicAtSource(start);
  final AtomicObject? ending = start > 0
      ? visible.atomicAtSource(start - 1)
      : null;
  final AtomicObject? photo =
      containing != null && containing.kind == AtomicKind.photo
      ? containing
      : ending != null &&
            ending.kind == AtomicKind.photo &&
            ending.sourceRange.end == start
      ? ending
      : null;
  if (photo == null) {
    return null;
  }
  final MdRange line = photo.sourceRange;
  if (selection.isCollapsed) {
    return photo;
  }
  if (start != line.start) {
    return null;
  }
  if (selection.end == line.end) {
    return photo;
  }
  final int breakAt = photo.visibleOffset + 1;
  final bool hasBreak =
      breakAt < visible.text.length &&
      visible.text.codeUnitAt(breakAt) == _lineFeed;
  return hasBreak &&
          visible.map.visibleToSource(breakAt + 1).upstream == selection.end
      ? photo
      : null;
}

int? _listMarkerContentStart(
  EditorState state,
  VisibleText visible,
  MdRange deleted,
) {
  final int? activeLine = visible.activeLine;
  if (activeLine == null || deleted.isEmpty) {
    return null;
  }
  final int? index = VisibleLineIndex(visible).lineForSource(activeLine);
  if (index == null) {
    return null;
  }
  final MdRange line = visible.lines[index].sourceRange;
  int? found;
  void visit(MdBlock block) {
    final MdRange bounds = block.sourceRange;
    if (found != null || bounds.end < line.start || bounds.start > line.end) {
      return;
    }
    if (block.kind == MdBlockKind.listItem && block.markerRanges.isNotEmpty) {
      final MdRange marker = block.markerRanges.first;
      if (marker.start >= line.start &&
          marker.start <= line.end &&
          deleted.start >= marker.start &&
          deleted.end <= marker.end) {
        found = block.blocks.isEmpty
            ? block.contentRange.start
            : block.blocks.first.contentRange.start;
        return;
      }
    }
    for (final MdBlock child in block.blocks) {
      visit(child);
    }
  }

  for (final MdBlock block in state.tree.blocks) {
    visit(block);
  }
  return found;
}
