import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:flutter/widgets.dart' show Characters;

enum TableEdit {
  rowAbove,
  rowBelow,
  columnLeft,
  columnRight,
  deleteRow,
  deleteColumn,
  alignLeft,
  alignCentre,
  alignRight,
  deleteTable,
}

Transaction? replaceInCell(
  EditorState state,
  String text, {
  bool paste = false,
}) {
  final _Table? table = _Table.atHead(state);
  if (table == null) {
    return null;
  }
  return _replaceSelection(
    state,
    table,
    _escaped(text),
    paste ? TransactionEvent.inputPaste : TransactionEvent.inputType,
  );
}

Transaction? deleteInCell(EditorState state, {required bool forward}) {
  final _Table? table = _Table.atHead(state);
  if (table == null) {
    return null;
  }
  final NoteSelection selection = state.selection;
  if (!selection.isCollapsed) {
    return _replaceSelection(state, table, '', TransactionEvent.inputDelete);
  }
  final int caret = selection.head;
  final MdRange? content = table.contentAt(caret);
  if (content == null) {
    return null;
  }
  final String source = state.source;
  if (forward ? caret == content.end : caret == content.start) {
    return _noOp(state);
  }
  final int from;
  final int to;
  if (forward) {
    from = caret;
    to = caret + Characters(source.substring(caret, content.end)).first.length;
  } else {
    to = caret;
    from =
        caret - Characters(source.substring(content.start, caret)).last.length;
  }
  final MdRange widened = _widened(source, content, from, to);
  return Transaction(
    changes: ChangeSet.single(
      source.length,
      widened.start,
      widened.end,
      _guarded(source, content, widened, ''),
    ),
    selection: NoteSelection.collapsed(widened.start),
    event: TransactionEvent.inputDelete,
  );
}

Transaction? nextCell(EditorState state) {
  final _Table? table = _Table.atHead(state);
  final _Cell? cell = table?.cellAt(state.selection.head);
  if (table == null || cell == null) {
    return null;
  }
  if (cell.column + 1 < table.columns) {
    return table.moveTo(state, cell.row, cell.column + 1);
  }
  if (cell.row + 1 < table.rows.length) {
    return table.moveTo(state, cell.row + 1, 0);
  }
  return table.appendRow(state, 0);
}

Transaction? previousCell(EditorState state) {
  final _Table? table = _Table.atHead(state);
  final _Cell? cell = table?.cellAt(state.selection.head);
  if (table == null || cell == null) {
    return null;
  }
  if (cell.column > 0) {
    return table.moveTo(state, cell.row, cell.column - 1);
  }
  if (cell.row > 0) {
    return table.moveTo(state, cell.row - 1, table.columns - 1);
  }
  return _noOp(state);
}

Transaction? cellBelow(EditorState state) {
  final _Table? table = _Table.atHead(state);
  final _Cell? cell = table?.cellAt(state.selection.head);
  if (table == null || cell == null) {
    return null;
  }
  if (cell.row + 1 < table.rows.length) {
    return table.moveTo(state, cell.row + 1, cell.column);
  }
  return table.appendRow(state, cell.column);
}

Transaction? insertTable(EditorState state) {
  final String source = state.source;
  final MdTree tree = state.tree;
  final MdSourceLines lines = MdSourceLines.split(source);
  final String lineBreak = _lineBreak(source);
  final String table = <String>[
    _canonical(const <String>['', '', '']).text,
    _canonical(const <String>['---', '---', '---']).text,
    _canonical(const <String>['', '', '']).text,
  ].join(lineBreak);
  final int lineIndex = lines.lineIndexAt(state.selection.end);
  final MdSourceLine line = lines.lines[lineIndex];

  bool isBlankLine(int index) =>
      index < lines.lines.length &&
      _isBlank(source, lines.lines[index].start, lines.lines[index].end);

  bool followsContainer(int index) {
    if (index < 0 || isBlankLine(index)) {
      return false;
    }
    final MdSourceLine previous = lines.lines[index];
    final int? block = tree.blockIndexAt(previous.start);
    return block != null && _isContainer(tree.blocks[block]);
  }

  bool nonBlankAt(int index) =>
      index < lines.lines.length && !isBlankLine(index);

  final bool inNoBlock = tree.blocks.every(
    (MdBlock block) =>
        block.sourceRange.end < line.start ||
        block.sourceRange.start > line.end,
  );
  final int from;
  final int to;
  final String before;
  final String after;
  if (isBlankLine(lineIndex) && inNoBlock) {
    from = line.start;
    to = line.end;
    before = followsContainer(lineIndex - 1) ? lineBreak : '';
    after = nonBlankAt(lineIndex + 1) ? lineBreak : '';
  } else {
    final int found =
        tree.blockIndexAt(line.start) ??
        tree.blocks.lastIndexWhere(
          (MdBlock block) => block.sourceRange.start <= line.start,
        );
    final int index = found < 0 ? 0 : found;
    final MdBlock target = tree.blocks[index];
    final MdBlockData? data = target.data;
    final bool unclosed = data is MdFenceData && !data.isClosed;
    if (unclosed && index == 0) {
      from = 0;
      to = 0;
      before = '';
      after = lineBreak + (nonBlankAt(0) ? lineBreak : '');
    } else {
      final MdBlock anchor = unclosed ? tree.blocks[index - 1] : target;
      final int anchorLine = lines.lineIndexAt(anchor.sourceRange.end);
      from = anchor.sourceRange.end;
      to = from;
      before = lineBreak + (_isContainer(anchor) ? lineBreak : '');
      after = nonBlankAt(anchorLine + 1) ? lineBreak : '';
    }
  }
  return Transaction(
    changes: ChangeSet.single(source.length, from, to, '$before$table$after'),
    selection: NoteSelection.collapsed(from + before.length + 2),
    event: TransactionEvent.table,
  );
}

Transaction? editTable(EditorState state, TableEdit edit) {
  final _Table? table = _Table.atHead(state);
  if (table == null) {
    return null;
  }
  if (edit == TableEdit.deleteTable) {
    return table.delete(state);
  }
  final _Cell? cell = table.cellAt(state.selection.head);
  if (cell == null) {
    return null;
  }
  return switch (edit) {
    TableEdit.rowAbove =>
      cell.row == 0 ? null : table.insertRow(state, cell.row, cell.column),
    TableEdit.rowBelow => table.insertRow(state, cell.row + 1, cell.column),
    TableEdit.columnLeft => table.insertColumn(state, cell, cell.column),
    TableEdit.columnRight => table.insertColumn(state, cell, cell.column + 1),
    TableEdit.deleteRow => cell.row == 0 ? null : table.deleteRow(state, cell),
    TableEdit.deleteColumn =>
      table.columns == 1 ? null : table.deleteColumn(state, cell),
    TableEdit.alignLeft => table.align(state, cell, MdCellAlignment.left),
    TableEdit.alignCentre => table.align(state, cell, MdCellAlignment.centre),
    TableEdit.alignRight => table.align(state, cell, MdCellAlignment.right),
    TableEdit.deleteTable => table.delete(state),
  };
}

Transaction? _replaceSelection(
  EditorState state,
  _Table table,
  String text,
  TransactionEvent event,
) {
  final String source = state.source;
  final NoteSelection selection = state.selection;
  final _Cell? first = table.contentCellAt(selection.start);
  final _Cell? last = table.contentCellAt(selection.end);
  if (first == null || last == null) {
    return null;
  }
  final List<TextReplacement> replacements = <TextReplacement>[];
  int caret = 0;
  for (final _Cell cell in table.cellsBetween(first, last)) {
    final MdRange content = cell.content;
    final int from = content.start > selection.start
        ? content.start
        : selection.start;
    final int to = content.end < selection.end ? content.end : selection.end;
    final MdRange part = _widened(source, content, from, to);
    final bool isFirst = identical(cell, first);
    final String inserted = _guarded(
      source,
      content,
      part,
      isFirst ? text : '',
    );
    if (isFirst) {
      caret = part.start;
    }
    if (part.start < part.end || inserted.isNotEmpty) {
      replacements.add(TextReplacement(part.start, part.end, inserted));
    }
  }
  final ChangeSet changes = ChangeSet(
    length: source.length,
    replacements: replacements,
  );
  return Transaction(
    changes: changes,
    selection: NoteSelection.collapsed(
      changes.mapPosition(caret, side: MapSide.before) + text.length,
    ),
    event: event,
  );
}

MdRange _widened(String source, MdRange content, int from, int to) {
  int start = from;
  int end = to;
  for (final MdRange escape in MdTables.pipeEscapes(source, content)) {
    final int pipe = escape.end;
    if (start == pipe && end == pipe) {
      start = pipe + 1;
      end = pipe + 1;
    } else {
      if (start == pipe && end > pipe) {
        start = escape.start;
      }
      if (end == pipe && start < pipe) {
        end = pipe + 1;
      }
    }
  }
  return MdRange(start, end);
}

String _escaped(String text) =>
    text.replaceAll('\r\n', ' ').replaceAll('\n', ' ').replaceAll('|', r'\|');

String _guarded(String source, MdRange content, MdRange part, String text) {
  final bool closesOnPipe =
      part.end == content.end &&
      content.end < source.length &&
      source.codeUnitAt(content.end) == _pipe;
  if (!closesOnPipe) {
    return text;
  }
  final int? last = text.isNotEmpty
      ? text.codeUnitAt(text.length - 1)
      : part.start > content.start
      ? source.codeUnitAt(part.start - 1)
      : null;
  return last == _backslash ? '$text ' : text;
}

Transaction _noOp(EditorState state) => Transaction(
  changes: ChangeSet.empty(state.source.length),
  selection: state.selection,
  event: TransactionEvent.table,
  addToHistory: false,
);

String _lineBreak(String source) {
  final int lineFeed = source.indexOf('\n');
  return lineFeed > 0 && source.codeUnitAt(lineFeed - 1) == _carriageReturn
      ? '\r\n'
      : '\n';
}

bool _isBlank(String source, int from, int to) {
  for (int i = from; i < to; i++) {
    final int unit = source.codeUnitAt(i);
    if (unit != _space && unit != _tab) {
      return false;
    }
  }
  return true;
}

bool _isContainer(MdBlock block) =>
    block.kind == MdBlockKind.bulletList ||
    block.kind == MdBlockKind.orderedList ||
    block.kind == MdBlockKind.blockQuote ||
    block.kind == MdBlockKind.table;

int _lineBreakCount(String source, int from, int to) {
  int count = 0;
  for (int i = from; i < to; i++) {
    if (source.codeUnitAt(i) == _lineFeed) {
      count += 1;
    }
  }
  return count;
}

final class _Written {
  const _Written(this.text, this.contentStarts);

  final String text;
  final List<int> contentStarts;

  int contentEnd(List<String> cells, int column) =>
      contentStarts[column] + cells[column].length;
}

_Written _canonical(List<String> cells) {
  final StringBuffer buffer = StringBuffer('|');
  final List<int> starts = <int>[];
  for (final String cell in cells) {
    buffer.write(' ');
    starts.add(buffer.length);
    buffer
      ..write(cell)
      ..write(' |');
  }
  return _Written(buffer.toString(), List<int>.unmodifiable(starts));
}

String _delimiterCell(MdCellAlignment alignment) => switch (alignment) {
  MdCellAlignment.none => '---',
  MdCellAlignment.left => ':---',
  MdCellAlignment.centre => ':---:',
  MdCellAlignment.right => '---:',
};

final class _Cell {
  const _Cell(this.row, this.column, this.content);

  final int row;
  final int column;
  final MdRange content;
}

final class _Row {
  const _Row(this.line, this.block);

  final MdSourceLine line;
  final MdBlock block;
}

final class _Table {
  const _Table({
    required this.source,
    required this.block,
    required this.lines,
    required this.rows,
    required this.delimiter,
    required this.alignments,
  });

  static _Table? atHead(EditorState state) {
    final int head = state.selection.head;
    MdBlock? found;
    for (final MdBlock block in state.tree.blocks) {
      if (block.kind == MdBlockKind.table &&
          block.sourceRange.start <= head &&
          head <= block.sourceRange.end) {
        found = block;
      }
    }
    if (found == null || found.markerRanges.isEmpty) {
      return null;
    }
    final String source = state.source;
    final MdSourceLines lines = MdSourceLines.split(source);
    final MdSourceLine delimiter =
        lines.lines[lines.lineIndexAt(found.markerRanges.first.start)];
    final List<_Row> rows = <_Row>[
      for (final MdBlock row in found.blocks)
        _Row(lines.lines[lines.lineIndexAt(row.sourceRange.start)], row),
    ];
    final int columns = rows.first.block.blocks.length;
    final List<MdCellAlignment> read =
        MdTables.delimiterAlignments(
          source,
          MdRange(delimiter.start, delimiter.end),
        ) ??
        const <MdCellAlignment>[];
    return _Table(
      source: source,
      block: found,
      lines: lines,
      rows: rows,
      delimiter: delimiter,
      alignments: <MdCellAlignment>[
        for (int i = 0; i < columns; i++)
          i < read.length ? read[i] : MdCellAlignment.none,
      ],
    );
  }

  final String source;
  final MdBlock block;
  final MdSourceLines lines;
  final List<_Row> rows;
  final MdSourceLine delimiter;
  final List<MdCellAlignment> alignments;

  int get columns => alignments.length;

  String get lineBreak => _lineBreak(source);

  int? _rowIndexAt(int offset) {
    for (int i = 0; i < rows.length; i++) {
      final MdSourceLine line = rows[i].line;
      if (line.start <= offset && offset <= line.end) {
        return i;
      }
    }
    return null;
  }

  _Cell? cellAt(int offset) {
    final int? row = _rowIndexAt(offset);
    if (row == null) {
      return null;
    }
    _Cell? found;
    final List<MdBlock> cells = rows[row].block.blocks;
    for (int i = 0; i < cells.length; i++) {
      final MdRange range = cells[i].sourceRange;
      if (range.start <= offset && offset <= range.end) {
        found = _Cell(row, i, cells[i].contentRange);
      }
    }
    return found;
  }

  _Cell? contentCellAt(int offset) {
    final int? row = _rowIndexAt(offset);
    if (row == null) {
      return null;
    }
    final List<MdBlock> cells = rows[row].block.blocks;
    for (int i = 0; i < cells.length; i++) {
      final MdRange content = cells[i].contentRange;
      if (content.start <= offset && offset <= content.end) {
        return _Cell(row, i, content);
      }
    }
    return null;
  }

  MdRange? contentAt(int offset) => contentCellAt(offset)?.content;

  List<_Cell> cellsBetween(_Cell first, _Cell last) => <_Cell>[
    first,
    for (int row = first.row; row <= last.row; row++)
      for (int column = 0; column < rows[row].block.blocks.length; column++)
        if ((row > first.row || column > first.column) &&
            (row < last.row || column <= last.column))
          _Cell(row, column, rows[row].block.blocks[column].contentRange),
  ];

  List<String> cellTexts(int row) {
    final MdSourceLine line = rows[row].line;
    return <String>[
      for (final MdTableCellSpan span in MdTables.splitRow(
        source,
        MdRange(line.start, line.end),
      ))
        span.content.sliceOf(source),
    ];
  }

  List<String> padded(int row) {
    final List<String> texts = cellTexts(row);
    return <String>[...texts, for (int i = texts.length; i < columns; i++) ''];
  }

  List<String> get delimiterTexts => <String>[
    for (final MdCellAlignment alignment in alignments)
      _delimiterCell(alignment),
  ];

  List<String> get emptyRow => <String>[for (int i = 0; i < columns; i++) ''];

  Transaction moveTo(EditorState state, int row, int column) {
    final List<MdBlock> cells = rows[row].block.blocks;
    if (column < cells.length) {
      return Transaction(
        changes: ChangeSet.empty(source.length),
        selection: NoteSelection.collapsed(cells[column].contentRange.end),
        event: TransactionEvent.table,
        addToHistory: false,
      );
    }
    final MdSourceLine line = rows[row].line;
    final List<String> texts = padded(row);
    final _Written written = _canonical(texts);
    return Transaction(
      changes: ChangeSet.single(
        source.length,
        line.start,
        line.end,
        written.text,
      ),
      selection: NoteSelection.collapsed(
        line.start + written.contentEnd(texts, column),
      ),
      event: TransactionEvent.table,
    );
  }

  Transaction appendRow(EditorState state, int column) {
    final int end = block.sourceRange.end;
    final _Written written = _canonical(emptyRow);
    return Transaction(
      changes: ChangeSet.single(
        source.length,
        end,
        end,
        '$lineBreak${written.text}',
      ),
      selection: NoteSelection.collapsed(
        end + lineBreak.length + written.contentStarts[column],
      ),
      event: TransactionEvent.table,
    );
  }

  Transaction insertRow(EditorState state, int index, int column) {
    final _Written written = _canonical(emptyRow);
    if (index == 1 || index > rows.length - 1) {
      final int at = index == 1 ? delimiter.end : rows[index - 1].line.end;
      return Transaction(
        changes: ChangeSet.single(
          source.length,
          at,
          at,
          '$lineBreak${written.text}',
        ),
        selection: NoteSelection.collapsed(
          at + lineBreak.length + written.contentStarts[column],
        ),
        event: TransactionEvent.table,
      );
    }
    final int at = rows[index].line.start;
    return Transaction(
      changes: ChangeSet.single(
        source.length,
        at,
        at,
        '${written.text}$lineBreak',
      ),
      selection: NoteSelection.collapsed(at + written.contentStarts[column]),
      event: TransactionEvent.table,
    );
  }

  Transaction insertColumn(EditorState state, _Cell cell, int at) {
    List<String> withColumn(List<String> texts, String inserted) => <String>[
      ...texts.take(at),
      inserted,
      ...texts.skip(at),
    ];
    return _rewriteAll(
      cell,
      at,
      (int row) => withColumn(padded(row), ''),
      withColumn(delimiterTexts, '---'),
    );
  }

  Transaction deleteColumn(EditorState state, _Cell cell) {
    List<String> without(List<String> texts) => <String>[
      for (int i = 0; i < texts.length; i++)
        if (i != cell.column) texts[i],
    ];
    final int target = cell.column < columns - 1
        ? cell.column
        : cell.column - 1;
    return _rewriteAll(
      cell,
      target,
      (int row) => without(padded(row)),
      without(delimiterTexts),
    );
  }

  Transaction _rewriteAll(
    _Cell cell,
    int targetColumn,
    List<String> Function(int row) rowTexts,
    List<String> delimiterRow,
  ) {
    final List<TextReplacement> replacements = <TextReplacement>[];
    int caret = 0;
    int shift = 0;
    for (int row = 0; row < rows.length; row++) {
      final MdSourceLine line = rows[row].line;
      final List<String> texts = rowTexts(row);
      final _Written written = _canonical(texts);
      if (row == cell.row) {
        caret = line.start + shift + written.contentEnd(texts, targetColumn);
      }
      replacements.add(TextReplacement(line.start, line.end, written.text));
      shift += written.text.length - (line.end - line.start);
      if (row == 0) {
        final String text = _canonical(delimiterRow).text;
        replacements.add(TextReplacement(delimiter.start, delimiter.end, text));
        shift += text.length - (delimiter.end - delimiter.start);
      }
    }
    return Transaction(
      changes: ChangeSet(length: source.length, replacements: replacements),
      selection: NoteSelection.collapsed(caret),
      event: TransactionEvent.table,
    );
  }

  Transaction deleteRow(EditorState state, _Cell cell) {
    final MdSourceLine line = rows[cell.row].line;
    final MdSourceLine previous = lines.lines[line.index - 1];
    final TextReplacement removal = TextReplacement(previous.end, line.end, '');
    final int targetRow = cell.row + 1 < rows.length
        ? cell.row + 1
        : cell.row - 1;
    final List<MdBlock> cells = rows[targetRow].block.blocks;
    if (cell.column < cells.length) {
      final ChangeSet changes = ChangeSet(
        length: source.length,
        replacements: <TextReplacement>[removal],
      );
      return Transaction(
        changes: changes,
        selection: NoteSelection.collapsed(
          changes.mapPosition(
            cells[cell.column].contentRange.end,
            side: MapSide.before,
          ),
        ),
        event: TransactionEvent.table,
      );
    }
    final MdSourceLine target = rows[targetRow].line;
    final List<String> texts = padded(targetRow);
    final _Written written = _canonical(texts);
    final TextReplacement padding = TextReplacement(
      target.start,
      target.end,
      written.text,
    );
    final ChangeSet changes = ChangeSet(
      length: source.length,
      replacements: targetRow < cell.row
          ? <TextReplacement>[padding, removal]
          : <TextReplacement>[removal, padding],
    );
    return Transaction(
      changes: changes,
      selection: NoteSelection.collapsed(
        changes.mapPosition(target.start, side: MapSide.before) +
            written.contentEnd(texts, cell.column),
      ),
      event: TransactionEvent.table,
    );
  }

  Transaction? align(EditorState state, _Cell cell, MdCellAlignment alignment) {
    if (alignments[cell.column] == alignment) {
      return null;
    }
    final List<String> texts = <String>[
      for (int i = 0; i < columns; i++)
        _delimiterCell(i == cell.column ? alignment : alignments[i]),
    ];
    final ChangeSet changes = ChangeSet.single(
      source.length,
      delimiter.start,
      delimiter.end,
      _canonical(texts).text,
    );
    return Transaction(
      changes: changes,
      selection: state.selection.mapped(changes, side: MapSide.before),
      event: TransactionEvent.table,
    );
  }

  Transaction delete(EditorState state) {
    final List<MdBlock> blocks = state.tree.blocks;
    final int index = blocks.indexWhere(
      (MdBlock candidate) => identical(candidate, block),
    );
    final MdRange range = block.sourceRange;
    final int? previousEnd = index > 0
        ? blocks[index - 1].sourceRange.end
        : null;
    final int? nextStart = index + 1 < blocks.length
        ? blocks[index + 1].sourceRange.start
        : null;
    final int from;
    final int to;
    if (previousEnd == null && nextStart == null) {
      from = range.start;
      to = range.end;
    } else if (previousEnd == null) {
      from = range.start;
      to = nextStart!;
    } else if (nextStart == null) {
      from = previousEnd;
      to = range.end;
    } else {
      final int before = _lineBreakCount(source, previousEnd, range.start);
      final int after = _lineBreakCount(source, range.end, nextStart);
      if (before == 1 && after == 1) {
        from = range.start;
        to = range.end;
      } else if (before >= after) {
        from = range.start;
        to = nextStart;
      } else {
        from = previousEnd;
        to = range.end;
      }
    }
    return Transaction(
      changes: ChangeSet.single(source.length, from, to, ''),
      selection: NoteSelection.collapsed(from),
      event: TransactionEvent.table,
    );
  }
}

const int _space = 0x20;
const int _tab = 0x09;
const int _lineFeed = 0x0A;
const int _carriageReturn = 0x0D;
const int _pipe = 0x7C;
const int _backslash = 0x5C;
