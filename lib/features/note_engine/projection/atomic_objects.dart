import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/projection/offset_map_builder.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:field_notes/features/note_engine/projection/visible_text_builder.dart';

const String _objectReplacement = '\uFFFC';
const String _unchecked = '\u2610 ';
const String _checked = '\u2611 ';
const String _cellSeparator = '\t';

final class NoteVisibleProjector implements VisibleProjector {
  const NoteVisibleProjector({this.builder = const VisibleTextBuilder()});

  final VisibleTextBuilder builder;

  @override
  VisibleText project(
    String source,
    MdTree tree,
    int? activeLine, {
    int? activeCell,
  }) {
    final _Lines lines = _Lines(
      source,
      builder.projectLines(source, tree, activeLine),
      activeLine,
      activeCell,
    );
    for (final MdBlock block in tree.blocks) {
      switch (block.kind) {
        case MdBlockKind.photoLine:
          lines.splice(
            block.sourceRange.start,
            block.sourceRange.end,
            _objectReplacement,
            AtomicKind.photo,
          );
        case MdBlockKind.table:
          lines.projectTable(block);
        default:
          lines.visitBlock(block);
      }
    }
    return builder.assemble(source, lines.lines, activeLine: activeLine);
  }
}

final class _Lines {
  _Lines(
    this.source,
    List<ProjectedLine> projected,
    this.activeLine,
    this.activeCell,
  ) : lines = List<ProjectedLine>.of(projected);

  final String source;
  final List<ProjectedLine> lines;
  final int? activeLine;
  final int? activeCell;

  void visitBlock(MdBlock block) {
    if (block.kind == MdBlockKind.thematicBreak) {
      final int line = _lineAt(block.sourceRange.start);
      if (line != activeLine) {
        splice(
          block.sourceRange.start,
          block.sourceRange.end,
          _objectReplacement,
          AtomicKind.divider,
        );
      }
      return;
    }
    final MdBlockData? data = block.data;
    if (data is MdListItemData && data.taskState != MdTaskState.none) {
      _projectCheckbox(block, data);
    }
    for (final MdBlock child in block.blocks) {
      visitBlock(child);
    }
  }

  void _projectCheckbox(MdBlock item, MdListItemData data) {
    final MdRange box = data.taskBoxRange!;
    final MdBlock? first = item.blocks.isEmpty ? null : item.blocks.first;
    final int contentStart =
        first != null &&
            first.kind == MdBlockKind.paragraph &&
            first.contentRange.start > box.end
        ? first.contentRange.start
        : box.end;
    final ProjectedLine line = lines[_lineAt(box.start)];
    splice(
      box.start,
      contentStart < line.end ? contentStart : line.end,
      data.taskState == MdTaskState.checked ? _checked : _unchecked,
      AtomicKind.checkbox,
    );
  }

  void splice(int start, int end, String text, AtomicKind kind) {
    final int index = _lineAt(start);
    final ProjectedLine line = lines[index];
    if (line.removed || end <= start) {
      return;
    }
    lines[index] = _withPieces(
      line,
      spliceAtomicPiece(
        line.pieces,
        ProjectedPiece(
          sourceStart: start,
          sourceEnd: end,
          text: text,
          atomic: kind,
        ),
      ),
    );
  }

  void projectTable(MdBlock table) {
    if (table.blocks.isEmpty) {
      return;
    }
    final int header = _lineAt(table.blocks.first.sourceRange.start);
    if (header + 1 < lines.length) {
      final ProjectedLine delimiter = lines[header + 1];
      lines[header + 1] = ProjectedLine(
        index: delimiter.index,
        start: delimiter.start,
        end: delimiter.end,
        breakEnd: delimiter.breakEnd,
        pieces: List<ProjectedPiece>.unmodifiable(<ProjectedPiece>[
          if (delimiter.end > delimiter.start)
            ProjectedPiece(
              sourceStart: delimiter.start,
              sourceEnd: delimiter.end,
              text: '',
            ),
        ]),
        removed: true,
      );
    }
    for (final MdBlock row in table.blocks) {
      final int index = _lineAt(row.sourceRange.start);
      lines[index] = _withPieces(
        lines[index],
        _rowPieces(lines[index], row, index == activeLine),
      );
    }
  }

  List<ProjectedPiece> _rowPieces(
    ProjectedLine line,
    MdBlock row,
    bool isActiveRow,
  ) {
    final List<MdBlock> cells = row.blocks;
    final List<ProjectedPiece> pieces = <ProjectedPiece>[];
    int at = line.start;
    for (int i = 0; i < cells.length; i++) {
      final MdRange content = cells[i].contentRange;
      if (i > 0 && content.start > at) {
        pieces.add(
          ProjectedPiece(
            sourceStart: at,
            sourceEnd: content.start,
            text: _cellSeparator,
            atomic: AtomicKind.tableSeparator,
          ),
        );
      } else if (content.start > at) {
        pieces.add(
          ProjectedPiece(sourceStart: at, sourceEnd: content.start, text: ''),
        );
      }
      pieces.addAll(
        splitByMarkers(
          source,
          content.start,
          content.end,
          _cellMarkers(cells[i]),
          active: isActiveRow && i == activeCell,
        ),
      );
      at = content.end;
    }
    if (line.end > at) {
      pieces.add(
        ProjectedPiece(sourceStart: at, sourceEnd: line.end, text: ''),
      );
    }
    return pieces;
  }

  ProjectedLine _withPieces(ProjectedLine line, List<ProjectedPiece> pieces) =>
      ProjectedLine(
        index: line.index,
        start: line.start,
        end: line.end,
        breakEnd: line.breakEnd,
        pieces: List<ProjectedPiece>.unmodifiable(pieces),
        removed: line.removed,
      );

  int _lineAt(int offset) {
    int low = 0;
    int high = lines.length - 1;
    while (low < high) {
      final int mid = (low + high + 1) >> 1;
      if (lines[mid].start <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }
}

List<MdRange> _cellMarkers(MdBlock cell) => <MdRange>[
  ...cell.markerRanges,
  for (final MdInline inline in cell.inlines) ..._inlineMarkers(inline),
];

Iterable<MdRange> _inlineMarkers(MdInline inline) sync* {
  yield* inline.markerRanges;
  for (final MdInline child in inline.children) {
    yield* _inlineMarkers(child);
  }
}
