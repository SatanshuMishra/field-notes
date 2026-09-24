import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';

Transaction? continueOnEnter(EditorState state) {
  final _Lines lines = _Lines(state);
  if (lines.headOnPhoto) {
    return null;
  }
  final NoteSelection selection = state.selection;
  final int caret = selection.start;
  final _Line line = lines.lineAt(lines.split.lineIndexAt(caret));

  final MdBlock? fence = line.innermost(MdBlockKind.fencedCode);
  if (fence != null) {
    final int indentStart = line.prefixEnd;
    int indentEnd = indentStart;
    while (indentEnd < caret &&
        _isSpaceOrTab(lines.source.codeUnitAt(indentEnd))) {
      indentEnd += 1;
    }
    return _insert(
      state,
      '\n${_continuation(lines.source, line.enclosing(fence))}'
      '${lines.source.substring(indentStart, indentEnd)}',
      TransactionEvent.inputType,
    );
  }

  if (selection.isCollapsed) {
    final _Item? empty = lines.emptyItemOn(line);
    if (empty != null && caret >= empty.markerStart) {
      if (empty.parent != null) {
        return _outdent(state, lines, empty);
      }
      return _replace(
        state,
        empty.markerStart,
        line.line.end,
        '',
        empty.markerStart,
        TransactionEvent.list,
      );
    }
  }

  final MdBlock? container = line.innermostContainer;
  if (container == null) {
    return null;
  }
  if (container.kind == MdBlockKind.listItem) {
    final _Item item = lines.treeItem(container, line.chain);
    if (item.firstLine == line.line.index && caret < item.contentStart) {
      return null;
    }
    return _insert(
      state,
      '\n${_continuation(lines.source, line.enclosing(container))}'
      '${item.ownIndentation}${item.nextMarker}',
      TransactionEvent.list,
    );
  }
  final MdRange? marker = line.markerOf(container);
  if (selection.isCollapsed &&
      marker != null &&
      _isBlankBetween(lines.source, marker.end, line.line.end)) {
    return _replace(
      state,
      marker.start,
      line.line.end,
      '',
      marker.start,
      TransactionEvent.list,
    );
  }
  return _insert(
    state,
    '\n${_continuation(lines.source, <MdBlock>[...line.enclosing(container), container])}',
    TransactionEvent.list,
  );
}

Transaction? insertLineBreakWithoutContinuation(EditorState state) {
  final _Lines lines = _Lines(state);
  if (lines.headOnPhoto) {
    return null;
  }
  final _Line line = lines.lineAt(
    lines.split.lineIndexAt(state.selection.start),
  );
  final MdBlock? item = line.innermost(MdBlockKind.listItem);
  if (item == null) {
    return _insert(state, '\n', TransactionEvent.inputType);
  }
  final MdSourceLine firstLine =
      lines.split.lines[lines.split.lineIndexAt(item.sourceRange.start)];
  final int column = item.markerRanges.first.end - firstLine.start;
  return _insert(state, '\n${' ' * column}', TransactionEvent.inputType);
}

Transaction? indentListItem(EditorState state) {
  final _Lines lines = _Lines(state);
  if (lines.headOnPhoto) {
    return null;
  }
  final NoteSelection selection = state.selection;
  final _Line line = lines.lineAt(lines.split.lineIndexAt(selection.start));
  final _Item? markerOnly = lines.markerOnlyItem(line);
  if (markerOnly != null) {
    return _noOp(state);
  }
  final MdBlock? innermost = line.innermost(MdBlockKind.listItem);
  if (innermost == null) {
    return null;
  }
  final _Item first = lines.treeItem(innermost, line.chain);
  final MdBlock list = first.list!;
  final int index = first.index;
  if (index == 0) {
    return _noOp(state);
  }
  final List<MdBlock> moved = <MdBlock>[
    for (int i = index; i < list.blocks.length; i++)
      if (i == index || _touches(selection, list.blocks[i].sourceRange.start))
        list.blocks[i],
  ];
  final MdBlock previous = list.blocks[index - 1];
  final int width = _contentWidth(previous);
  final List<MdBlock> ancestors = first.enclosing;
  final List<TextReplacement> replacements = <TextReplacement>[];
  final MdBlockData? listData = list.data;
  int? number;
  if (listData is MdOrderedListData) {
    final MdBlock? nested = previous.blocks.isEmpty
        ? null
        : previous.blocks.last;
    final MdBlockData? nestedData = nested?.data;
    number =
        nested != null &&
            nestedData is MdOrderedListData &&
            nestedData.delimiter == listData.delimiter
        ? nestedData.start + nested.blocks.length
        : 1;
  }
  for (final MdBlock item in moved) {
    final int firstLine = lines.split.lineIndexAt(item.sourceRange.start);
    final int lastLine = lines.split.lineIndexAt(item.sourceRange.end);
    for (int i = firstLine; i <= lastLine; i++) {
      final MdSourceLine subtreeLine = lines.split.lines[i];
      if (_isBlankBetween(lines.source, subtreeLine.start, subtreeLine.end)) {
        continue;
      }
      final int at = lines.lineAt(i).prefixEndWithin(ancestors);
      replacements.add(TextReplacement(at, at, ' ' * width));
    }
    if (number != null) {
      final MdRange digits = _digitsOf(lines.source, item);
      final String written = '$number';
      if (digits.sliceOf(lines.source) != written) {
        replacements.add(TextReplacement(digits.start, digits.end, written));
      }
      number += 1;
    }
  }
  replacements.sort(
    (TextReplacement a, TextReplacement b) => a.from.compareTo(b.from),
  );
  return _mapped(state, replacements);
}

Transaction? outdentListItem(EditorState state) {
  final _Lines lines = _Lines(state);
  if (lines.headOnPhoto) {
    return null;
  }
  final _Line line = lines.lineAt(
    lines.split.lineIndexAt(state.selection.start),
  );
  final _Item? markerOnly = lines.markerOnlyItem(line);
  final MdBlock? innermost = line.innermost(MdBlockKind.listItem);
  final _Item? item =
      markerOnly ??
      (innermost == null ? null : lines.treeItem(innermost, line.chain));
  if (item == null) {
    return null;
  }
  if (item.parent == null) {
    return _noOp(state);
  }
  return _outdent(state, lines, item);
}

Transaction? backspaceAtItemStart(EditorState state) {
  final _Lines lines = _Lines(state);
  final NoteSelection selection = state.selection;
  if (lines.headOnPhoto || !selection.isCollapsed) {
    return null;
  }
  final int caret = selection.start;
  final _Line line = lines.lineAt(lines.split.lineIndexAt(caret));
  final _Item? markerOnly = lines.markerOnlyItem(line);
  final List<_Item> candidates = <_Item>[
    ?markerOnly,
    for (final MdBlock block in line.chain.reversed)
      if (block.kind == MdBlockKind.listItem &&
          block.sourceRange.start >= line.line.start)
        lines.treeItem(block, line.chain),
  ];
  for (final _Item item in candidates) {
    if (item.contentStart == caret) {
      if (item.parent != null) {
        return _outdent(state, lines, item);
      }
      return _replace(
        state,
        item.markerStart,
        item.contentStart,
        '',
        item.markerStart,
        TransactionEvent.list,
      );
    }
  }
  final MdBlock? container = line.innermostContainer;
  if (container != null &&
      container.kind == MdBlockKind.blockQuote &&
      candidates.isEmpty) {
    final MdRange? marker = line.markerOf(container);
    if (marker != null && line.contentStart == caret) {
      final int start = lines.source.indexOf('>', marker.start);
      return _replace(
        state,
        start,
        marker.end,
        '',
        start,
        TransactionEvent.list,
      );
    }
  }
  return null;
}

Transaction _outdent(EditorState state, _Lines lines, _Item item) {
  final MdBlock parent = item.parent!;
  final int width = _contentWidth(parent);
  final MdRange? box = _taskBox(parent);
  final List<TextReplacement> replacements = <TextReplacement>[];
  for (int i = item.firstLine; i <= item.lastLine; i++) {
    final MdSourceLine line = lines.split.lines[i];
    for (final MdRange consumed in parent.markerRanges.skip(1)) {
      if (consumed == box ||
          consumed.start < line.start ||
          consumed.end > line.end) {
        continue;
      }
      int end = consumed.start;
      while (end < consumed.end &&
          end - consumed.start < width &&
          lines.source.codeUnitAt(end) == _space) {
        end += 1;
      }
      if (end > consumed.start) {
        replacements.add(TextReplacement(consumed.start, end, ''));
      }
      break;
    }
  }
  return _mapped(state, replacements);
}

Transaction _mapped(EditorState state, List<TextReplacement> replacements) {
  final ChangeSet changes = ChangeSet(
    length: state.source.length,
    replacements: replacements,
  );
  return Transaction(
    changes: changes,
    selection: state.selection.mapped(changes, side: MapSide.after),
    event: TransactionEvent.list,
  );
}

Transaction _insert(EditorState state, String text, TransactionEvent event) {
  final NoteSelection selection = state.selection;
  return _replace(
    state,
    selection.start,
    selection.end,
    text,
    selection.start + text.length,
    event,
  );
}

Transaction _replace(
  EditorState state,
  int from,
  int to,
  String text,
  int caret,
  TransactionEvent event,
) => Transaction(
  changes: ChangeSet.single(state.source.length, from, to, text),
  selection: NoteSelection.collapsed(caret),
  event: event,
);

Transaction _noOp(EditorState state) => Transaction(
  changes: ChangeSet.empty(state.source.length),
  selection: state.selection,
  event: TransactionEvent.list,
  addToHistory: false,
);

bool _touches(NoteSelection selection, int lineStart) => selection.isCollapsed
    ? lineStart <= selection.end
    : lineStart < selection.end;

String _continuation(String source, List<MdBlock> containers) => <String>[
  for (final MdBlock block in containers)
    if (block.kind == MdBlockKind.blockQuote)
      '> '
    else if (block.kind == MdBlockKind.listItem)
      ' ' * _contentWidth(block),
].join();

int _contentWidth(MdBlock item) {
  final MdRange first = item.markerRanges.first;
  return first.end - first.start;
}

MdRange? _taskBox(MdBlock item) {
  final MdBlockData? data = item.data;
  return data is MdListItemData ? data.taskBoxRange : null;
}

MdRange _digitsOf(String source, MdBlock item) {
  final MdRange first = item.markerRanges.first;
  int start = first.start;
  while (start < first.end && !_isDigit(source.codeUnitAt(start))) {
    start += 1;
  }
  int end = start;
  while (end < first.end && _isDigit(source.codeUnitAt(end))) {
    end += 1;
  }
  return MdRange(start, end);
}

bool _isBlankBetween(String source, int from, int to) {
  for (int i = from; i < to; i++) {
    if (!_isSpaceOrTab(source.codeUnitAt(i))) {
      return false;
    }
  }
  return true;
}

bool _isSpaceOrTab(int unit) => unit == _space || unit == _tab;

bool _isDigit(int unit) => unit >= _zero && unit <= _nine;

bool _containsIdentical(List<MdBlock> blocks, MdBlock block) =>
    blocks.any((MdBlock candidate) => identical(candidate, block));

final class _Item {
  const _Item({
    required this.source,
    required this.markerStart,
    required this.contentStart,
    required this.firstLine,
    required this.lastLine,
    required this.parent,
    required this.enclosing,
    this.block,
    this.list,
    this.index = 0,
  });

  final String source;
  final int markerStart;
  final int contentStart;
  final int firstLine;
  final int lastLine;
  final MdBlock? parent;
  final List<MdBlock> enclosing;
  final MdBlock? block;
  final MdBlock? list;
  final int index;

  String get ownIndentation {
    final MdBlock item = block!;
    return source.substring(item.markerRanges.first.start, markerStart);
  }

  String get nextMarker {
    final MdBlock item = block!;
    final MdRange first = item.markerRanges.first;
    int markerEnd = markerStart;
    while (markerEnd < first.end &&
        !_isSpaceOrTab(source.codeUnitAt(markerEnd))) {
      markerEnd += 1;
    }
    final String spacing = source.substring(markerEnd, first.end);
    final MdBlockData? data = list?.data;
    final String marker = data is MdOrderedListData
        ? '${data.start + index + 1}'
              '${data.delimiter == MdListDelimiter.paren ? ')' : '.'}'
        : source.substring(markerStart, markerEnd);
    final String box = _taskBox(item) == null ? '' : '[ ] ';
    return '$marker${spacing.isEmpty ? ' ' : spacing}$box';
  }
}

final class _Lines {
  _Lines(EditorState state)
    : source = state.source,
      tree = state.tree,
      headOffset = state.selection.head,
      split = MdSourceLines.split(state.source);

  final String source;
  final MdTree tree;
  final int headOffset;
  final MdSourceLines split;

  bool get headOnPhoto => lineAt(
    split.lineIndexAt(headOffset),
  ).chain.any((MdBlock block) => block.kind == MdBlockKind.photoLine);

  _Line lineAt(int index) {
    final MdSourceLine line = split.lines[index];
    final List<MdBlock> chain = <MdBlock>[];
    List<MdBlock> level = tree.blocks;
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
    return _Line(source, line, chain);
  }

  _Item treeItem(MdBlock item, List<MdBlock> chain) {
    final int at = chain.indexWhere((MdBlock block) => identical(block, item));
    final MdBlock list = chain[at - 1];
    final List<MdBlock> enclosing = <MdBlock>[
      for (final MdBlock block in chain.take(at - 1))
        if (block.kind == MdBlockKind.blockQuote ||
            block.kind == MdBlockKind.listItem)
          block,
    ];
    final MdBlock? parent =
        at >= 2 && chain[at - 2].kind == MdBlockKind.listItem
        ? chain[at - 2]
        : null;
    final MdRange first = item.markerRanges.first;
    int markerStart = first.start;
    while (markerStart < first.end &&
        _isSpaceOrTab(source.codeUnitAt(markerStart))) {
      markerStart += 1;
    }
    final int firstLine = split.lineIndexAt(item.sourceRange.start);
    final MdSourceLine line = split.lines[firstLine];
    int contentStart = _taskBox(item)?.end ?? first.end;
    while (contentStart < line.end &&
        _isSpaceOrTab(source.codeUnitAt(contentStart))) {
      contentStart += 1;
    }
    return _Item(
      source: source,
      markerStart: markerStart,
      contentStart: contentStart,
      firstLine: firstLine,
      lastLine: split.lineIndexAt(item.sourceRange.end),
      parent: parent,
      enclosing: enclosing,
      block: item,
      list: list,
      index: list.blocks.indexWhere((MdBlock block) => identical(block, item)),
    );
  }

  _Item? emptyItemOn(_Line line) {
    final _Item? markerOnly = markerOnlyItem(line);
    if (markerOnly != null) {
      return markerOnly;
    }
    for (final MdBlock block in line.chain.reversed) {
      if (block.kind != MdBlockKind.listItem ||
          block.sourceRange.start < line.line.start) {
        continue;
      }
      final int contentFrom =
          _taskBox(block)?.end ?? block.markerRanges.first.end;
      final bool isEmpty =
          block.sourceRange.end <= line.line.end &&
          _isBlankBetween(source, contentFrom, line.line.end);
      return isEmpty ? treeItem(block, line.chain) : null;
    }
    return null;
  }

  _Item? markerOnlyItem(_Line line) {
    if (line.chain.isEmpty ||
        line.chain.last.kind != MdBlockKind.paragraph ||
        line.chain.last.sourceRange.start >= line.line.start) {
      return null;
    }
    final int markerStart = _markerOnlyStart(line.prefixEnd, line.line.end);
    if (markerStart < 0) {
      return null;
    }
    MdBlock? parent;
    for (final _PrefixEntry entry in line.prefix) {
      if (entry.container.kind == MdBlockKind.listItem) {
        parent = entry.container;
      }
    }
    final int parentAt = parent == null
        ? -1
        : line.chain.indexWhere((MdBlock block) => identical(block, parent));
    return _Item(
      source: source,
      markerStart: markerStart,
      contentStart: line.line.end,
      firstLine: line.line.index,
      lastLine: line.line.index,
      parent: parent,
      enclosing: <MdBlock>[
        for (final MdBlock block in line.chain.take(parentAt + 1))
          if (block.kind == MdBlockKind.blockQuote ||
              block.kind == MdBlockKind.listItem)
            block,
      ],
    );
  }

  int _markerOnlyStart(int from, int to) {
    int at = from;
    int spaces = 0;
    while (at < to && source.codeUnitAt(at) == _space && spaces < 3) {
      at += 1;
      spaces += 1;
    }
    if (at >= to) {
      return -1;
    }
    final int markerStart = at;
    final int unit = source.codeUnitAt(at);
    if (unit == _dash || unit == _plus || unit == _star) {
      at += 1;
    } else {
      int digits = 0;
      while (at < to && _isDigit(source.codeUnitAt(at)) && digits < 9) {
        at += 1;
        digits += 1;
      }
      if (digits == 0 ||
          at >= to ||
          (source.codeUnitAt(at) != _period &&
              source.codeUnitAt(at) != _closeParen)) {
        return -1;
      }
      at += 1;
    }
    if (at == to) {
      return markerStart;
    }
    if (!_isSpaceOrTab(source.codeUnitAt(at))) {
      return -1;
    }
    while (at < to && _isSpaceOrTab(source.codeUnitAt(at))) {
      at += 1;
    }
    if (at + 3 <= to &&
        source.codeUnitAt(at) == _openBracket &&
        source.codeUnitAt(at + 2) == _closeBracket &&
        _isBoxState(source.codeUnitAt(at + 1))) {
      at += 3;
      while (at < to && _isSpaceOrTab(source.codeUnitAt(at))) {
        at += 1;
      }
    }
    return at == to ? markerStart : -1;
  }
}

bool _isBoxState(int unit) =>
    unit == _space || unit == _tab || unit == _lowerX || unit == _upperX;

final class _PrefixEntry {
  const _PrefixEntry(this.container, this.marker);

  final MdBlock container;
  final MdRange marker;
}

final class _Line {
  factory _Line(String source, MdSourceLine line, List<MdBlock> chain) {
    final List<_PrefixEntry> prefix = <_PrefixEntry>[];
    int prefixEnd = line.start;
    for (final MdBlock block in chain) {
      if (block.kind == MdBlockKind.listItem &&
          block.sourceRange.start >= line.start) {
        break;
      }
      if (block.kind != MdBlockKind.blockQuote &&
          block.kind != MdBlockKind.listItem) {
        continue;
      }
      MdRange? marker;
      for (final MdRange range in block.markerRanges) {
        if (range.start >= prefixEnd && range.end <= line.end) {
          marker = range;
          break;
        }
      }
      if (marker == null || marker.start != prefixEnd) {
        break;
      }
      prefix.add(_PrefixEntry(block, marker));
      prefixEnd = marker.end;
    }
    int contentStart = prefixEnd;
    while (contentStart < line.end &&
        _isSpaceOrTab(source.codeUnitAt(contentStart))) {
      contentStart += 1;
    }
    return _Line._(line, chain, prefix, prefixEnd, contentStart);
  }

  const _Line._(
    this.line,
    this.chain,
    this.prefix,
    this.prefixEnd,
    this.contentStart,
  );

  final MdSourceLine line;
  final List<MdBlock> chain;
  final List<_PrefixEntry> prefix;
  final int prefixEnd;
  final int contentStart;

  MdBlock? innermost(MdBlockKind kind) {
    for (final MdBlock block in chain.reversed) {
      if (block.kind == kind) {
        return block;
      }
    }
    return null;
  }

  MdBlock? get innermostContainer {
    for (final MdBlock block in chain.reversed) {
      if (block.kind == MdBlockKind.listItem ||
          block.kind == MdBlockKind.blockQuote) {
        return block;
      }
    }
    return null;
  }

  List<MdBlock> enclosing(MdBlock block) {
    final int at = chain.indexWhere(
      (MdBlock candidate) => identical(candidate, block),
    );
    return <MdBlock>[
      for (final MdBlock candidate in chain.take(at))
        if (candidate.kind == MdBlockKind.blockQuote ||
            candidate.kind == MdBlockKind.listItem)
          candidate,
    ];
  }

  MdRange? markerOf(MdBlock container) {
    for (final _PrefixEntry entry in prefix) {
      if (identical(entry.container, container)) {
        return entry.marker;
      }
    }
    return null;
  }

  int prefixEndWithin(List<MdBlock> containers) {
    int at = line.start;
    for (final _PrefixEntry entry in prefix) {
      if (!_containsIdentical(containers, entry.container)) {
        break;
      }
      at = entry.marker.end;
    }
    return at;
  }
}

const int _space = 0x20;
const int _tab = 0x09;
const int _zero = 0x30;
const int _nine = 0x39;
const int _dash = 0x2D;
const int _plus = 0x2B;
const int _star = 0x2A;
const int _period = 0x2E;
const int _closeParen = 0x29;
const int _openBracket = 0x5B;
const int _closeBracket = 0x5D;
const int _lowerX = 0x78;
const int _upperX = 0x58;
