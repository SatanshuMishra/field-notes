import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';

const int _lineFeed = 0x0A;

final class ActiveLine {
  const ActiveLine({required this.line, this.cell});

  final int line;
  final int? cell;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveLine && line == other.line && cell == other.cell;

  @override
  int get hashCode => Object.hash(line, cell);

  @override
  String toString() =>
      cell == null ? 'ActiveLine($line)' : 'ActiveLine($line, cell: $cell)';
}

ActiveLine activeLineAt(String source, MdTree tree, NoteSelection selection) {
  final int head = _checkedHead(source, tree, selection);
  int line = 0;
  for (int at = 0; at < head; at++) {
    if (source.codeUnitAt(at) == _lineFeed) {
      line++;
    }
  }
  return ActiveLine(line: line, cell: _cellAt(tree, head));
}

ActiveLine? nextActiveLine({
  required ActiveLine? previous,
  required String source,
  required MdTree tree,
  required NoteSelection selection,
  required bool focused,
  required bool composing,
  required bool dragging,
}) {
  _checkedHead(source, tree, selection);
  if (!focused) {
    return null;
  }
  if (composing || dragging) {
    return previous;
  }
  return activeLineAt(source, tree, selection);
}

int _checkedHead(String source, MdTree tree, NoteSelection selection) {
  if (tree.sourceLength != source.length) {
    throw ArgumentError.value(
      tree.sourceLength,
      'tree.sourceLength',
      'must equal source.length ${source.length}',
    );
  }
  final int head = selection.head;
  if (head < 0 || head > source.length) {
    throw ArgumentError.value(
      head,
      'selection.head',
      'must lie in [0, ${source.length}]',
    );
  }
  return head;
}

int? _cellAt(MdTree tree, int head) {
  final MdBlock? block = tree.blockAt(head);
  if (block == null || block.kind != MdBlockKind.table) {
    return null;
  }
  for (final MdBlock row in block.blocks) {
    final MdRange range = row.sourceRange;
    if (range.start <= head && head <= range.end) {
      int cell = 0;
      for (int i = 0; i < row.blocks.length; i++) {
        if (row.blocks[i].sourceRange.start <= head) {
          cell = i;
        }
      }
      return cell;
    }
  }
  return null;
}
