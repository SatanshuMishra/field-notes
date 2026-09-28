import '../syntax_tree.dart';

const int _space = 0x20;
const int _tab = 0x09;
const int _pipe = 0x7C;
const int _backslash = 0x5C;
const int _colon = 0x3A;
const int _dash = 0x2D;

final class MdTableCellSpan {
  const MdTableCellSpan({required this.source, required this.content});

  final MdRange source;
  final MdRange content;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdTableCellSpan &&
          source == other.source &&
          content == other.content;

  @override
  int get hashCode => Object.hash(source, content);

  @override
  String toString() => 'MdTableCellSpan($source, content: $content)';
}

abstract final class MdTables {
  static List<MdTableCellSpan> splitRow(String source, MdRange line) {
    int textStart = line.start;
    while (textStart < line.end &&
        _isSpaceOrTab(source.codeUnitAt(textStart))) {
      textStart++;
    }
    int textEnd = line.end;
    while (textEnd > textStart &&
        _isSpaceOrTab(source.codeUnitAt(textEnd - 1))) {
      textEnd--;
    }
    if (textStart == textEnd) {
      return const <MdTableCellSpan>[];
    }
    final int cellsStart = source.codeUnitAt(textStart) == _pipe
        ? textStart + 1
        : textStart;
    final bool closingPipe =
        textEnd - 1 >= cellsStart &&
        source.codeUnitAt(textEnd - 1) == _pipe &&
        source.codeUnitAt(textEnd - 2) != _backslash;
    if (!closingPipe && cellsStart >= textEnd) {
      return const <MdTableCellSpan>[];
    }
    final int cellsEnd = closingPipe ? textEnd - 1 : line.end;
    final List<MdTableCellSpan> cells = <MdTableCellSpan>[];
    int cellStart = cellsStart;
    for (int at = cellsStart; at < cellsEnd; at++) {
      if (source.codeUnitAt(at) == _pipe &&
          source.codeUnitAt(at - 1) != _backslash) {
        cells.add(_cell(source, cellStart, at));
        cellStart = at + 1;
      }
    }
    cells.add(_cell(source, cellStart, cellsEnd));
    return List<MdTableCellSpan>.unmodifiable(cells);
  }

  static List<MdCellAlignment>? delimiterAlignments(
    String source,
    MdRange line,
  ) {
    int column = 0;
    int at = line.start;
    bool hasPipe = false;
    while (at < line.end && _isSpaceOrTab(source.codeUnitAt(at))) {
      column += source.codeUnitAt(at) == _tab ? 4 - column % 4 : 1;
      at++;
    }
    if (column > 3) {
      return null;
    }
    for (int scan = at; scan < line.end; scan++) {
      if (source.codeUnitAt(scan) == _pipe) {
        hasPipe = true;
        break;
      }
    }
    if (!hasPipe) {
      return null;
    }
    final List<MdTableCellSpan> cells = splitRow(source, line);
    if (cells.isEmpty) {
      return null;
    }
    final List<MdCellAlignment> alignments = <MdCellAlignment>[];
    for (final MdTableCellSpan cell in cells) {
      final MdCellAlignment? alignment = _alignment(source, cell.content);
      if (alignment == null) {
        return null;
      }
      alignments.add(alignment);
    }
    return List<MdCellAlignment>.unmodifiable(alignments);
  }

  static List<MdRange> pipeEscapes(String source, MdRange content) =>
      List<MdRange>.unmodifiable(<MdRange>[
        for (int at = content.start; at + 1 < content.end; at++)
          if (source.codeUnitAt(at) == _backslash &&
              source.codeUnitAt(at + 1) == _pipe)
            MdRange(at, at + 1),
      ]);
}

MdTableCellSpan _cell(String source, int start, int end) {
  int contentStart = start;
  while (contentStart < end && _isSpaceOrTab(source.codeUnitAt(contentStart))) {
    contentStart++;
  }
  if (contentStart == end) {
    final int empty = start < end ? start + 1 : start;
    return MdTableCellSpan(
      source: MdRange(start, end),
      content: MdRange(empty, empty),
    );
  }
  int contentEnd = end;
  while (_isSpaceOrTab(source.codeUnitAt(contentEnd - 1))) {
    contentEnd--;
  }
  return MdTableCellSpan(
    source: MdRange(start, end),
    content: MdRange(contentStart, contentEnd),
  );
}

MdCellAlignment? _alignment(String source, MdRange content) {
  int start = content.start;
  int end = content.end;
  if (start == end) {
    return null;
  }
  final bool left = source.codeUnitAt(start) == _colon;
  if (left) {
    start++;
  }
  final bool right = end > start && source.codeUnitAt(end - 1) == _colon;
  if (right) {
    end--;
  }
  if (start == end) {
    return null;
  }
  for (int at = start; at < end; at++) {
    if (source.codeUnitAt(at) != _dash) {
      return null;
    }
  }
  return switch ((left, right)) {
    (true, true) => MdCellAlignment.centre,
    (true, false) => MdCellAlignment.left,
    (false, true) => MdCellAlignment.right,
    (false, false) => MdCellAlignment.none,
  };
}

bool _isSpaceOrTab(int unit) => unit == _space || unit == _tab;
