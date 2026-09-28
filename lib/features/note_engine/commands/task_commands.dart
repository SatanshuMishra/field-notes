import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';

Transaction? toggleTaskAt(EditorState state, int offset) {
  final MdSourceLines lines = MdSourceLines.split(state.source);
  final _Line line = _Line.at(state, lines, lines.lineIndexAt(offset));
  final MdRange? box = line.startingItem == null
      ? null
      : _taskBox(line.startingItem!);
  if (box == null) {
    return null;
  }
  final int at = box.start + 1;
  final int unit = state.source.codeUnitAt(at);
  final String written = unit == _space || unit == _tab ? 'x' : ' ';
  return Transaction(
    changes: ChangeSet.single(state.source.length, at, at + 1, written),
    selection: state.selection,
    event: TransactionEvent.list,
  );
}

Transaction? toggleTaskOnCaretLine(EditorState state) {
  final MdSourceLines lines = MdSourceLines.split(state.source);
  final _Line line = _Line.at(
    state,
    lines,
    lines.lineIndexAt(state.selection.head),
  );
  final MdBlock? item = line.startingItem;
  if (item != null) {
    if (_taskBox(item) != null) {
      return toggleTaskAt(state, line.line.start);
    }
    final MdRange marker = item.markerRanges.first;
    final bool bare =
        marker.end == line.line.end &&
        !_isSpaceOrTab(state.source.codeUnitAt(marker.end - 1));
    return _insert(state, marker.end, bare ? ' [ ] ' : '[ ] ');
  }
  if (line.isBlank) {
    return _insert(state, line.contentStart, '- [ ] ');
  }
  final MdBlock? leaf = line.chain.isEmpty ? null : line.chain.last;
  final bool continuesItem = line.chain.any(
    (MdBlock block) => block.kind == MdBlockKind.listItem,
  );
  if (leaf == null || leaf.kind != MdBlockKind.paragraph || continuesItem) {
    return null;
  }
  return _insert(state, line.contentStart, '- [ ] ');
}

Transaction _insert(EditorState state, int at, String text) {
  final ChangeSet changes = ChangeSet.single(state.source.length, at, at, text);
  return Transaction(
    changes: changes,
    selection: state.selection.mapped(changes, side: MapSide.after),
    event: TransactionEvent.list,
  );
}

MdRange? _taskBox(MdBlock item) {
  final MdBlockData? data = item.data;
  return data is MdListItemData ? data.taskBoxRange : null;
}

bool _isSpaceOrTab(int unit) => unit == _space || unit == _tab;

final class _Line {
  factory _Line.at(EditorState state, MdSourceLines lines, int index) {
    final String source = state.source;
    final MdSourceLine line = lines.lines[index];
    final List<MdBlock> chain = <MdBlock>[];
    List<MdBlock> level = state.tree.blocks;
    while (true) {
      MdBlock? found;
      for (final MdBlock block in level) {
        if (block.sourceRange.start > line.end) {
          break;
        }
        if (block.sourceRange.end >= line.start) {
          found = block;
          break;
        }
      }
      if (found == null) {
        break;
      }
      chain.add(found);
      level = found.blocks;
    }
    int prefixEnd = line.start;
    MdBlock? startingItem;
    for (final MdBlock block in chain) {
      if (block.kind == MdBlockKind.listItem &&
          block.sourceRange.start >= line.start) {
        startingItem = block;
        continue;
      }
      if (startingItem != null ||
          (block.kind != MdBlockKind.blockQuote &&
              block.kind != MdBlockKind.listItem)) {
        continue;
      }
      MdRange? marker;
      for (final MdRange range in block.markerRanges) {
        if (range.start == prefixEnd && range.end <= line.end) {
          marker = range;
          break;
        }
      }
      if (marker == null) {
        break;
      }
      prefixEnd = marker.end;
    }
    int contentStart = prefixEnd;
    while (contentStart < line.end &&
        _isSpaceOrTab(source.codeUnitAt(contentStart))) {
      contentStart += 1;
    }
    final bool opaque = chain.any(
      (MdBlock block) =>
          block.kind == MdBlockKind.fencedCode ||
          block.kind == MdBlockKind.photoLine ||
          block.kind == MdBlockKind.thematicBreak ||
          block.kind == MdBlockKind.table,
    );
    return _Line._(
      line: line,
      chain: chain,
      contentStart: contentStart,
      startingItem: startingItem,
      isBlank: !opaque && contentStart == line.end,
    );
  }

  const _Line._({
    required this.line,
    required this.chain,
    required this.contentStart,
    required this.startingItem,
    required this.isBlank,
  });

  final MdSourceLine line;
  final List<MdBlock> chain;
  final int contentStart;
  final MdBlock? startingItem;
  final bool isBlank;
}

const int _space = 0x20;
const int _tab = 0x09;
