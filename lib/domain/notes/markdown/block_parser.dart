import 'blocks/block_quotes.dart';
import 'blocks/fenced_code.dart';
import 'blocks/list_items.dart';
import 'blocks/tables.dart';
import 'photo_line.dart';
import 'source_lines.dart';
import 'syntax_tree.dart';

const int _space = 0x20;
const int _tab = 0x09;
const int _hash = 0x23;
const int _dash = 0x2D;
const int _star = 0x2A;
const int _underscore = 0x5F;
const int _pipe = 0x7C;
const int _period = 0x2E;

final class MdBlockParser {
  const MdBlockParser({this.tables = true});

  final bool tables;

  List<MdBlock> parse(String source) =>
      _BlockParse(MdSourceLines.split(source), tables: tables).run();

  static List<MdRange> inlineSegments(
    MdSourceLines lines,
    MdBlock leaf,
    List<MdBlock> ancestors,
  ) {
    final MdRange content = leaf.contentRange;
    if (content.isEmpty) {
      return const <MdRange>[];
    }
    final List<MdRange> excluded = <MdRange>[
      for (final MdBlock node in <MdBlock>[...ancestors, leaf])
        ..._markersWithin(node.markerRanges, content),
    ]..sort((MdRange a, MdRange b) => a.start.compareTo(b.start));
    final List<MdRange> segments = <MdRange>[];
    int skipped = 0;
    for (
      int index = lines.lineIndexAt(content.start);
      index < lines.lines.length;
      index++
    ) {
      final MdSourceLine line = lines.lines[index];
      final int from = line.start > content.start ? line.start : content.start;
      final int to = line.end < content.end ? line.end : content.end;
      if (from < to) {
        while (skipped < excluded.length && excluded[skipped].end <= from) {
          skipped++;
        }
        int position = from;
        for (
          int scan = skipped;
          scan < excluded.length && excluded[scan].start < to;
          scan++
        ) {
          final MdRange marker = excluded[scan];
          if (marker.start > position) {
            segments.add(MdRange(position, marker.start));
          }
          if (marker.end > position) {
            position = marker.end;
          }
        }
        if (position < to) {
          segments.add(MdRange(position, to));
        }
      }
      if (line.breakEnd >= content.end) {
        break;
      }
    }
    return List<MdRange>.unmodifiable(segments);
  }
}

Iterable<MdRange> _markersWithin(List<MdRange> markers, MdRange content) sync* {
  int low = 0;
  int high = markers.length;
  while (low < high) {
    final int mid = (low + high) >> 1;
    if (markers[mid].end <= content.start) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  for (
    int index = low;
    index < markers.length && markers[index].start < content.end;
    index++
  ) {
    yield markers[index];
  }
}

enum _Start { none, container, leaf }

typedef _BlockStart = _Start Function(_BlockParse parse);

const List<_BlockStart> _blockStarts = <_BlockStart>[
  _startBlockQuote,
  _startAtxHeading,
  _startFencedCode,
  _startThematicBreak,
  _startPhotoLine,
  _startListItem,
  _startTable,
];

_Start _startBlockQuote(_BlockParse parse) {
  final MdLineCursor? after = MdBlockQuotes.consumeMarker(parse.cursor);
  if (after == null) {
    return _Start.none;
  }
  parse.closeUnmatched();
  final _Quote quote = _Quote(parse.cursor.offset, parse.line.end);
  quote.markers.add(MdRange(parse.cursor.offset, after.offset));
  parse.open(quote);
  parse.cursor = after;
  parse.quoteOrItemOnLine = true;
  return _Start.container;
}

_Start _startAtxHeading(_BlockParse parse) {
  final MdBlock? heading = _atxHeading(parse.source, parse.cursor);
  if (heading == null) {
    return _Start.none;
  }
  parse.closeUnmatched();
  parse.addLeaf(heading);
  return _Start.leaf;
}

_Start _startFencedCode(_BlockParse parse) {
  final MdFence? fence = MdFence.open(parse.cursor);
  if (fence == null) {
    return _Start.none;
  }
  parse.closeUnmatched();
  parse.open(_Fence(fence, MdRange(parse.cursor.offset, parse.line.end)));
  return _Start.leaf;
}

_Start _startThematicBreak(_BlockParse parse) {
  if (!_isThematicBreak(parse.source, parse.cursor)) {
    return _Start.none;
  }
  final int start = parse.cursor.offset;
  final int end = parse.line.end;
  parse.closeUnmatched();
  parse.addLeaf(
    MdBlock(
      kind: MdBlockKind.thematicBreak,
      sourceRange: MdRange(start, end),
      contentRange: MdRange(end, end),
      markerRanges: <MdRange>[MdRange(start, end)],
    ),
  );
  return _Start.leaf;
}

_Start _startPhotoLine(_BlockParse parse) {
  if (parse.quoteOrItemOnLine) {
    return _Start.none;
  }
  final MdSourceLine line = parse.line;
  final MdPhotoLine? photo = MdPhotoLine.match(
    parse.source,
    line.start,
    line.end,
  );
  if (photo == null) {
    return _Start.none;
  }
  parse.closeAll();
  final MdRange caption = photo.captionRange;
  parse.addLeaf(
    MdBlock(
      kind: MdBlockKind.photoLine,
      sourceRange: MdRange(line.start, line.end),
      contentRange: caption,
      markerRanges: <MdRange>[
        MdRange(line.start, caption.start),
        MdRange(caption.end, line.end),
      ],
      data: photo.data,
    ),
  );
  return _Start.leaf;
}

_Start _startListItem(_BlockParse parse) {
  final MdLineCursor cursor = parse.cursor;
  final MdListMarker? marker = MdListItems.markerAt(cursor);
  if (marker == null) {
    return _Start.none;
  }
  if (parse.paragraphIsOpenTip &&
      (marker.startsBlank || (marker.ordered && marker.start != 1))) {
    return _Start.none;
  }
  parse.closeUnmatched();
  final MdLineCursor afterMarker = cursor.advance(
    marker.range.end - cursor.offset,
  );
  final MdLineCursor content = marker.startsBlank
      ? afterMarker.advance(parse.line.end - afterMarker.offset)
      : afterMarker.consumeColumns(marker.contentColumn - afterMarker.column);
  final _Builder top = parse.stack.last;
  if (top is! _List || !top.accepts(marker)) {
    parse.open(_List(marker));
  }
  parse.open(
    _Item(
      marker: marker,
      firstMarker: MdRange(marker.range.start, content.offset),
      contentOffset: marker.contentColumn - cursor.column,
      end: parse.line.end,
    ),
  );
  parse.cursor = content;
  parse.quoteOrItemOnLine = true;
  return _Start.container;
}

_Start _startTable(_BlockParse parse) {
  final List<_Builder> stack = parse.stack;
  if (!parse.tables ||
      stack.length != 2 ||
      !parse.paragraphIsOpenTip ||
      parse.cursor.indentColumns > 3) {
    return _Start.none;
  }
  final String source = parse.source;
  final MdSourceLine line = parse.line;
  final List<MdCellAlignment>? alignments = MdTables.delimiterAlignments(
    source,
    MdRange(line.start, line.end),
  );
  if (alignments == null) {
    return _Start.none;
  }
  final _Paragraph paragraph = stack.last as _Paragraph;
  final MdSourceLine header =
      parse.lines.lines[parse.lines.lineIndexAt(paragraph.lines.last.start)];
  final MdRange headerRange = MdRange(header.start, header.end);
  if (!_holdsPipe(source, headerRange) ||
      MdTables.splitRow(source, headerRange).length != alignments.length) {
    return _Start.none;
  }
  if (paragraph.lines.length == 1) {
    stack.removeLast();
  } else {
    paragraph.lines.removeLast();
    parse.closeTop();
  }
  parse.open(_Table(header, line, alignments));
  return _Start.leaf;
}

bool _holdsPipe(String source, MdRange range) {
  for (int at = range.start; at < range.end; at++) {
    if (source.codeUnitAt(at) == _pipe) {
      return true;
    }
  }
  return false;
}

MdBlock? _atxHeading(String source, MdLineCursor cursor) {
  if (cursor.indentColumns > 3) {
    return null;
  }
  final int lineEnd = cursor.line.end;
  final int hashesStart = cursor.skipSpaces().offset;
  int at = hashesStart;
  while (at < lineEnd && source.codeUnitAt(at) == _hash) {
    at++;
  }
  final int level = at - hashesStart;
  if (level < 1 || level > 6) {
    return null;
  }
  if (at < lineEnd && !_isSpaceOrTab(source.codeUnitAt(at))) {
    return null;
  }
  int contentStart = at;
  while (contentStart < lineEnd &&
      _isSpaceOrTab(source.codeUnitAt(contentStart))) {
    contentStart++;
  }
  int contentEnd = _trimEnd(source, contentStart, lineEnd);
  int closing = contentEnd;
  while (closing > contentStart && source.codeUnitAt(closing - 1) == _hash) {
    closing--;
  }
  if (closing < contentEnd) {
    if (closing == contentStart) {
      contentEnd = contentStart;
    } else if (_isSpaceOrTab(source.codeUnitAt(closing - 1))) {
      contentEnd = _trimEnd(source, contentStart, closing);
    }
  }
  return MdBlock(
    kind: MdBlockKind.heading,
    sourceRange: MdRange(cursor.offset, lineEnd),
    contentRange: MdRange(contentStart, contentEnd),
    markerRanges: <MdRange>[
      MdRange(cursor.offset, contentStart),
      if (contentEnd < lineEnd) MdRange(contentEnd, lineEnd),
    ],
    data: MdHeadingData(level),
  );
}

bool _isThematicBreak(String source, MdLineCursor cursor) {
  if (cursor.indentColumns > 3) {
    return false;
  }
  final MdLineCursor start = cursor.skipSpaces();
  final int? character = start.codeUnit;
  if (character != _dash && character != _star && character != _underscore) {
    return false;
  }
  int count = 0;
  for (int at = start.offset; at < cursor.line.end; at++) {
    final int unit = source.codeUnitAt(at);
    if (unit == character) {
      count++;
    } else if (!_isSpaceOrTab(unit)) {
      return false;
    }
  }
  return count >= 3;
}

int _trimEnd(String source, int start, int end) {
  int trimmed = end;
  while (trimmed > start && _isSpaceOrTab(source.codeUnitAt(trimmed - 1))) {
    trimmed--;
  }
  return trimmed;
}

bool _isSpaceOrTab(int unit) => unit == _space || unit == _tab;

sealed class _Builder {
  _Builder(this.start);

  final int start;
}

sealed class _Container extends _Builder {
  _Container(super.start, this.end);

  final List<MdBlock> blocks = <MdBlock>[];
  final List<MdRange> blanks = <MdRange>[];
  int end;
  bool hasChild = false;

  bool acceptsItem(bool item);
}

final class _Document extends _Container {
  _Document(int length) : super(0, length);

  @override
  bool acceptsItem(bool item) => !item;
}

final class _Quote extends _Container {
  _Quote(super.start, super.end);

  final List<MdRange> markers = <MdRange>[];

  @override
  bool acceptsItem(bool item) => !item;
}

final class _List extends _Container {
  _List(this.marker) : super(marker.range.start, marker.range.end);

  final MdListMarker marker;

  bool accepts(MdListMarker other) =>
      other.ordered == marker.ordered && other.character == marker.character;

  @override
  bool acceptsItem(bool item) => item;
}

final class _Item extends _Container {
  _Item({
    required this.marker,
    required this.firstMarker,
    required this.contentOffset,
    required int end,
  }) : super(marker.range.start, end);

  final MdListMarker marker;
  final MdRange firstMarker;
  final int contentOffset;
  final List<MdRange> markers = <MdRange>[];
  MdRange? taskWhitespace;
  MdRange? taskBox;
  MdTaskState taskState = MdTaskState.none;

  @override
  bool acceptsItem(bool item) => !item;
}

final class _ParagraphLine {
  const _ParagraphLine(this.start, this.text, this.end);

  final int start;
  final int text;
  final int end;
}

final class _Paragraph extends _Builder {
  _Paragraph(_ParagraphLine first) : super(first.start) {
    lines.add(first);
  }

  final List<_ParagraphLine> lines = <_ParagraphLine>[];
}

final class _FenceLine {
  const _FenceLine(this.start, this.end, this.removed);

  final int start;
  final int end;
  final MdRange? removed;
}

final class _Fence extends _Builder {
  _Fence(this.fence, this.opening) : super(opening.start);

  final MdFence fence;
  final MdRange opening;
  final List<_FenceLine> lines = <_FenceLine>[];
  MdRange? closing;
}

final class _Table extends _Builder {
  _Table(this.header, this.delimiter, this.alignments) : super(header.start);

  final MdSourceLine header;
  final MdSourceLine delimiter;
  final List<MdCellAlignment> alignments;
  final List<MdSourceLine> rows = <MdSourceLine>[];
}

final class _BlockParse {
  _BlockParse(this.lines, {required this.tables})
    : source = lines.source,
      document = _Document(lines.source.length) {
    stack.add(document);
  }

  final MdSourceLines lines;
  final String source;
  final bool tables;
  final _Document document;
  final List<_Builder> stack = <_Builder>[];
  late MdSourceLine line;
  late MdLineCursor cursor;
  int matched = 1;
  bool quoteOrItemOnLine = false;
  bool blankInItem = false;

  bool get paragraphIsOpenTip =>
      matched == stack.length && stack.last is _Paragraph;

  List<MdBlock> run() {
    for (final MdSourceLine next in lines.lines) {
      _addLine(next);
    }
    closeAll();
    return List<MdBlock>.unmodifiable(document.blocks);
  }

  void _addLine(MdSourceLine next) {
    line = next;
    cursor = MdLineCursor.atLine(lines, next.index);
    matched = 1;
    quoteOrItemOnLine = false;
    blankInItem = false;
    while (matched < stack.length && _continues(stack[matched])) {
      matched++;
    }
    final _Builder tip = stack.last;
    if (tip is _Fence && matched == stack.length) {
      _addFenceLine(tip);
      return;
    }
    _Start result = _Start.container;
    while (result == _Start.container) {
      result = _Start.none;
      for (final _BlockStart start in _blockStarts) {
        result = start(this);
        if (result != _Start.none) {
          break;
        }
      }
    }
    if (result == _Start.leaf) {
      return;
    }
    final bool blank = cursor.restIsBlank;
    final _Builder last = stack.last;
    if (matched < stack.length && !blank && last is _Paragraph) {
      last.lines.add(_paragraphLine());
      for (final _Builder open in stack) {
        if (open is _Quote) {
          open.end = line.end;
        } else if (open is _Item) {
          open.end = line.end;
        }
      }
      return;
    }
    closeUnmatched();
    final _Builder top = stack.last;
    if (blank) {
      if (cursor.offset < line.end && top is _Container) {
        top.blanks.add(MdRange(cursor.offset, line.end));
      }
    } else if (top is _Paragraph) {
      top.lines.add(_paragraphLine());
    } else if (top is _Table) {
      top.rows.add(line);
    } else {
      open(_Paragraph(_paragraphLine()));
    }
  }

  bool _continues(_Builder open) {
    switch (open) {
      case _Quote():
        final MdLineCursor? after = MdBlockQuotes.consumeMarker(cursor);
        if (after == null) {
          return false;
        }
        open.markers.add(MdRange(cursor.offset, after.offset));
        open.end = line.end;
        cursor = after;
        quoteOrItemOnLine = true;
        return true;
      case _Item():
        if (cursor.restIsBlank) {
          if (open.marker.startsBlank && !open.hasChild) {
            return false;
          }
          quoteOrItemOnLine = true;
          blankInItem = true;
          return true;
        }
        if (cursor.indentColumns < open.contentOffset) {
          return false;
        }
        final MdLineCursor after = cursor.consumeColumns(open.contentOffset);
        if (after.offset > cursor.offset) {
          open.markers.add(MdRange(cursor.offset, after.offset));
        }
        open.end = line.end;
        cursor = after;
        quoteOrItemOnLine = true;
        return true;
      case _List() || _Fence():
        return true;
      case _Paragraph() || _Table():
        return !cursor.restIsBlank;
      case _Document():
        return true;
    }
  }

  void _addFenceLine(_Fence fence) {
    if (fence.fence.closes(cursor)) {
      fence.closing = MdRange(cursor.offset, line.end);
      closeTop();
      return;
    }
    if (blankInItem) {
      if (cursor.offset < line.end) {
        (stack[stack.length - 2] as _Container).blanks.add(
          MdRange(cursor.offset, line.end),
        );
      }
      fence.lines.add(_FenceLine(line.end, line.end, null));
      return;
    }
    final MdLineCursor after = cursor.consumeColumns(fence.fence.indent);
    fence.lines.add(
      _FenceLine(
        after.offset,
        line.end,
        after.offset > cursor.offset
            ? MdRange(cursor.offset, after.offset)
            : null,
      ),
    );
  }

  _ParagraphLine _paragraphLine() =>
      _ParagraphLine(cursor.offset, cursor.skipSpaces().offset, line.end);

  void closeUnmatched() {
    while (stack.length > matched) {
      closeTop();
    }
  }

  void closeAll() {
    while (stack.length > 1) {
      closeTop();
    }
    matched = 1;
  }

  void open(_Builder child) {
    final bool item = child is _Item;
    while (true) {
      final _Builder top = stack.last;
      if (top is _Container && top.acceptsItem(item)) {
        top.hasChild = true;
        break;
      }
      closeTop();
    }
    stack.add(child);
    matched = stack.length;
  }

  void addLeaf(MdBlock block) {
    while (true) {
      final _Builder top = stack.last;
      if (top is _Container && top.acceptsItem(false)) {
        top.hasChild = true;
        top.blocks.add(block);
        break;
      }
      closeTop();
    }
    matched = stack.length;
  }

  void closeTop() {
    final _Builder closing = stack.removeLast();
    final _Container parent = stack.last as _Container;
    final MdBlock block = switch (closing) {
      _Paragraph() => _buildParagraph(closing, parent),
      _Fence() => _buildFence(closing, parent),
      _Table() => _buildTable(closing),
      _Quote() => _buildQuote(closing, parent),
      _List() => _buildList(closing, parent),
      _Item() => _buildItem(closing, parent),
      _Document() => throw StateError('the document never closes'),
    };
    parent.blocks.add(block);
  }

  List<MdRange> _claimBlanks(
    _Container container,
    MdRange source,
    _Container parent,
  ) {
    final List<MdRange> claimed = <MdRange>[];
    for (final MdRange blank in container.blanks) {
      if (blank.start >= source.start && blank.end <= source.end) {
        claimed.add(blank);
      } else {
        parent.blanks.add(blank);
      }
    }
    return claimed;
  }

  MdBlock _buildParagraph(_Paragraph paragraph, _Container parent) {
    List<_ParagraphLine> paragraphLines = paragraph.lines;
    if (parent is _Item && parent.blocks.isEmpty) {
      final _ParagraphLine first = paragraphLines.first;
      final MdTaskState state = MdListItems.taskStateAt(
        source,
        first.text,
        first.end,
      );
      if (state != MdTaskState.none) {
        final int afterBox = first.text + 3;
        int text = afterBox;
        while (text < first.end && _isSpaceOrTab(source.codeUnitAt(text))) {
          text++;
        }
        parent.taskState = state;
        parent.taskBox = MdRange(first.text, afterBox);
        if (first.text > first.start) {
          parent.taskWhitespace = MdRange(first.start, first.text);
        }
        paragraphLines = <_ParagraphLine>[
          _ParagraphLine(afterBox, text, first.end),
          ...paragraphLines.skip(1),
        ];
      }
    }
    final _ParagraphLine first = paragraphLines.first;
    final _ParagraphLine last = paragraphLines.last;
    final int contentStart = paragraphLines
        .firstWhere(
          (_ParagraphLine candidate) => candidate.text < candidate.end,
          orElse: () => first,
        )
        .text;
    final int contentEnd = _trimEnd(source, last.text, last.end);
    return MdBlock(
      kind: MdBlockKind.paragraph,
      sourceRange: MdRange(first.start, last.end),
      contentRange: MdRange(contentStart, contentEnd),
      markerRanges: <MdRange>[
        for (final _ParagraphLine paragraphLine in paragraphLines)
          if (paragraphLine.text > paragraphLine.start)
            MdRange(paragraphLine.start, paragraphLine.text),
        if (contentEnd < last.end) MdRange(contentEnd, last.end),
      ],
    );
  }

  MdBlock _buildFence(_Fence fence, _Container parent) {
    final MdRange? closing = fence.closing;
    final List<_FenceLine> kept = closing != null
        ? fence.lines
        : fence.lines
              .takeWhile((_FenceLine content) => content.start <= parent.end)
              .toList();
    final int end =
        closing?.end ?? (kept.isEmpty ? fence.opening.end : kept.last.end);
    final MdFence opening = fence.fence;
    return MdBlock(
      kind: MdBlockKind.fencedCode,
      sourceRange: MdRange(fence.start, end),
      contentRange: kept.isEmpty
          ? MdRange(fence.opening.end, fence.opening.end)
          : MdRange(kept.first.start, kept.last.end),
      markerRanges: <MdRange>[
        fence.opening,
        for (final _FenceLine content in kept) ?content.removed,
        ?closing,
      ],
      data: MdFenceData(
        fence: String.fromCharCode(opening.character) * opening.length,
        info: opening.info(source),
        isClosed: closing != null,
      ),
    );
  }

  MdBlock _buildQuote(_Quote quote, _Container parent) {
    final MdRange sourceRange = MdRange(quote.start, quote.end);
    final List<MdBlock> children = quote.blocks;
    final int emptyContent = quote.markers.first.end;
    return MdBlock(
      kind: MdBlockKind.blockQuote,
      sourceRange: sourceRange,
      contentRange: children.isEmpty
          ? MdRange(emptyContent, emptyContent)
          : MdRange(
              children.first.sourceRange.start,
              children.last.sourceRange.end,
            ),
      markerRanges: _sorted(<MdRange>[
        ...quote.markers,
        ..._claimBlanks(quote, sourceRange, parent),
      ]),
      blocks: children,
    );
  }

  MdBlock _buildItem(_Item item, _Container parent) {
    final MdRange sourceRange = MdRange(item.start, item.end);
    final List<MdBlock> children = item.blocks;
    final int emptyContent = item.firstMarker.end;
    final MdRange? whitespace = item.taskWhitespace;
    final MdRange? box = item.taskBox;
    return MdBlock(
      kind: MdBlockKind.listItem,
      sourceRange: sourceRange,
      contentRange: children.isEmpty
          ? MdRange(emptyContent, emptyContent)
          : MdRange(
              children.first.sourceRange.start,
              children.last.sourceRange.end,
            ),
      markerRanges: _sorted(<MdRange>[
        item.firstMarker,
        ?whitespace,
        ?box,
        ...item.markers,
        ..._claimBlanks(item, sourceRange, parent),
      ]),
      blocks: children,
      data: MdListItemData(taskState: item.taskState, taskBoxRange: box),
    );
  }

  MdBlock _buildList(_List list, _Container parent) {
    final List<MdBlock> items = list.blocks;
    final MdRange sourceRange = MdRange(
      items.first.sourceRange.start,
      items.last.sourceRange.end,
    );
    final bool isTight =
        !_separated(items) &&
        !items.any((MdBlock item) => _separated(item.blocks));
    final MdListMarker marker = list.marker;
    return MdBlock(
      kind: marker.ordered ? MdBlockKind.orderedList : MdBlockKind.bulletList,
      sourceRange: sourceRange,
      contentRange: sourceRange,
      markerRanges: _sorted(_claimBlanks(list, sourceRange, parent)),
      blocks: items,
      data: marker.ordered
          ? MdOrderedListData(
              start: marker.start,
              delimiter: marker.character == _period
                  ? MdListDelimiter.period
                  : MdListDelimiter.paren,
              isTight: isTight,
            )
          : MdBulletListData(
              bullet: String.fromCharCode(marker.character),
              isTight: isTight,
            ),
    );
  }

  bool _separated(List<MdBlock> blocks) {
    for (int i = 1; i < blocks.length; i++) {
      final int previous = lines.lineIndexAt(blocks[i - 1].sourceRange.end);
      if (lines.lineIndexAt(blocks[i].sourceRange.start) - previous > 1) {
        return true;
      }
    }
    return false;
  }

  MdBlock _buildTable(_Table table) {
    final List<MdSourceLine> rowLines = <MdSourceLine>[
      table.header,
      ...table.rows,
    ];
    final MdSourceLine last = rowLines.last;
    final int end = table.rows.isEmpty ? table.delimiter.end : last.end;
    return MdBlock(
      kind: MdBlockKind.table,
      sourceRange: MdRange(table.header.start, end),
      contentRange: MdRange(table.header.start, last.end),
      markerRanges: <MdRange>[
        MdRange(table.delimiter.start, table.delimiter.end),
      ],
      blocks: <MdBlock>[
        for (final MdSourceLine rowLine in rowLines)
          _buildRow(rowLine, table.alignments),
      ],
    );
  }

  MdBlock _buildRow(MdSourceLine rowLine, List<MdCellAlignment> alignments) {
    final MdRange range = MdRange(rowLine.start, rowLine.end);
    final List<MdTableCellSpan> spans = MdTables.splitRow(source, range);
    final List<MdRange> markers = <MdRange>[];
    final List<MdBlock> cells = <MdBlock>[];
    int position = range.start;
    for (int column = 0; column < spans.length; column++) {
      final MdTableCellSpan span = spans[column];
      markers.addAll(_gapMarkers(position, span.source.start));
      if (column < alignments.length) {
        cells.add(_buildCell(span, alignments[column]));
      } else if (!span.source.isEmpty) {
        markers.add(span.source);
      }
      position = span.source.end;
    }
    markers.addAll(_gapMarkers(position, range.end));
    return MdBlock(
      kind: MdBlockKind.tableRow,
      sourceRange: range,
      contentRange: range,
      markerRanges: markers,
      blocks: cells,
    );
  }

  List<MdRange> _gapMarkers(int start, int end) {
    final List<MdRange> markers = <MdRange>[];
    int at = start;
    while (at < end) {
      if (source.codeUnitAt(at) == _pipe) {
        markers.add(MdRange(at, at + 1));
        at++;
      } else {
        final int runStart = at;
        while (at < end && source.codeUnitAt(at) != _pipe) {
          at++;
        }
        markers.add(MdRange(runStart, at));
      }
    }
    return markers;
  }

  MdBlock _buildCell(MdTableCellSpan span, MdCellAlignment alignment) {
    final MdRange content = span.content;
    return MdBlock(
      kind: MdBlockKind.tableCell,
      sourceRange: span.source,
      contentRange: content,
      markerRanges: <MdRange>[
        if (content.start > span.source.start)
          MdRange(span.source.start, content.start),
        ...MdTables.pipeEscapes(source, content),
        if (content.end < span.source.end)
          MdRange(content.end, span.source.end),
      ],
      data: MdTableCellData(alignment: alignment),
    );
  }
}

List<MdRange> _sorted(List<MdRange> ranges) =>
    <MdRange>[...ranges]
      ..sort((MdRange a, MdRange b) => a.start.compareTo(b.start));
