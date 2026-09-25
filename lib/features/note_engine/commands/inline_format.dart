import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:flutter/widgets.dart' show Characters, CharacterRange;

enum InlineFormat { bold, italic, strikethrough, highlight, code, link }

Transaction? toggleInlineFormat(EditorState state, InlineFormat format) {
  final String source = state.source;
  final NoteSelection selection = state.selection;
  final MdTree tree = state.tree;

  final int? stepped = _stepOverClosingMarker(tree, format, selection);
  if (stepped != null) {
    return _transaction(
      ChangeSet.empty(source.length),
      NoteSelection.collapsed(stepped),
    );
  }
  final MdInline? node = _innermostNode(tree, format, selection);
  if (node != null) {
    return _removeMarkers(state, node);
  }
  if (format != InlineFormat.code &&
      _isStrictlyInsideCodeSpan(tree, selection)) {
    return null;
  }

  final MdSourceLines lines = MdSourceLines.split(source);
  if (!selection.isCollapsed) {
    final List<MdRange> parts = _selectedParts(
      source,
      lines,
      tree,
      selection.start,
      selection.end,
    );
    if (parts.any(
      (MdRange part) =>
          _isInsideLinkTarget(tree, part.start) ||
          _isInsideLinkTarget(tree, part.end),
    )) {
      return null;
    }
    if (parts.isNotEmpty) {
      return _wrapParts(state, format, parts);
    }
  }
  final int point = _movedPoint(lines, tree, selection.end);
  if (_isOpaqueLine(tree, lines.lines[lines.lineIndexAt(point)]) ||
      _isInsideLinkTarget(tree, point)) {
    return null;
  }
  return _emptyPairAt(state, format, point) ??
      _wrapWordAt(state, format, lines, point) ??
      _insertPairAt(state, format, point);
}

MdInlineKind _kindOf(InlineFormat format) => switch (format) {
  InlineFormat.bold => MdInlineKind.strong,
  InlineFormat.italic => MdInlineKind.emphasis,
  InlineFormat.strikethrough => MdInlineKind.strikethrough,
  InlineFormat.highlight => MdInlineKind.highlight,
  InlineFormat.code => MdInlineKind.codeSpan,
  InlineFormat.link => MdInlineKind.link,
};

final class _Pair {
  const _Pair(this.opening, this.closing);

  final String opening;
  final String closing;
}

_Pair _pairFor(InlineFormat format, String part) => switch (format) {
  InlineFormat.bold => const _Pair('**', '**'),
  InlineFormat.italic => const _Pair('*', '*'),
  InlineFormat.strikethrough => const _Pair('~~', '~~'),
  InlineFormat.highlight => const _Pair('==', '=='),
  InlineFormat.code => _codePair(part),
  InlineFormat.link => const _Pair('[', ']()'),
};

_Pair _codePair(String part) {
  int longest = 0;
  int run = 0;
  for (int i = 0; i < part.length; i++) {
    if (part.codeUnitAt(i) == _backtick) {
      run += 1;
      if (run > longest) {
        longest = run;
      }
    } else {
      run = 0;
    }
  }
  final String fence = '`' * (longest + 1);
  final bool padded =
      part.isNotEmpty &&
      (part.codeUnitAt(0) == _backtick ||
          part.codeUnitAt(part.length - 1) == _backtick);
  return padded ? _Pair('$fence ', ' $fence') : _Pair(fence, fence);
}

Iterable<MdBlock> _allBlocks(List<MdBlock> blocks) sync* {
  for (final MdBlock block in blocks) {
    yield block;
    yield* _allBlocks(block.blocks);
  }
}

Iterable<MdInline> _allInlines(List<MdInline> inlines) sync* {
  for (final MdInline inline in inlines) {
    yield inline;
    yield* _allInlines(inline.children);
  }
}

Iterable<MdInline> _inlinesAround(MdTree tree, int start, int end) sync* {
  for (final MdBlock block in _allBlocks(_blocksAround(tree, start, end))) {
    if (block.sourceRange.start <= end && block.sourceRange.end >= start) {
      yield* _allInlines(block.inlines);
    }
  }
}

List<MdBlock> _blocksAround(MdTree tree, int start, int end) => <MdBlock>[
  for (final MdBlock block in tree.blocks)
    if (block.sourceRange.start <= end && block.sourceRange.end >= start) block,
];

MdInline? _innermostNode(
  MdTree tree,
  InlineFormat format,
  NoteSelection selection,
) {
  final MdInlineKind kind = _kindOf(format);
  MdInline? found;
  for (final MdInline inline in _inlinesAround(
    tree,
    selection.start,
    selection.end,
  )) {
    final bool isKind =
        inline.kind == kind ||
        (format == InlineFormat.link && inline.kind == MdInlineKind.autolink);
    final bool holds =
        isKind &&
        inline.sourceRange.start <= selection.start &&
        selection.end <= inline.sourceRange.end;
    if (holds &&
        (found == null ||
            inline.sourceRange.length < found.sourceRange.length)) {
      found = inline;
    }
  }
  return found;
}

int? _stepOverClosingMarker(
  MdTree tree,
  InlineFormat format,
  NoteSelection selection,
) {
  if (format == InlineFormat.link || !selection.isCollapsed) {
    return null;
  }
  final MdInlineKind kind = _kindOf(format);
  final int caret = selection.start;
  MdInline? exiting;
  MdInline? entering;
  for (final MdInline inline in _inlinesAround(tree, caret, caret)) {
    if (inline.kind != kind ||
        inline.markerRanges.length < 2 ||
        inline.contentRange.length == 0) {
      continue;
    }
    final MdRange closing = inline.markerRanges.last;
    if (closing.start == caret &&
        (exiting == null ||
            inline.sourceRange.length < exiting.sourceRange.length)) {
      exiting = inline;
    }
    if (closing.end == caret &&
        (entering == null ||
            inline.sourceRange.length < entering.sourceRange.length)) {
      entering = inline;
    }
  }
  if (exiting != null) {
    return exiting.markerRanges.last.end;
  }
  return entering?.markerRanges.last.start;
}

bool _isStrictlyInsideCodeSpan(MdTree tree, NoteSelection selection) {
  for (final MdInline inline in _inlinesAround(
    tree,
    selection.start,
    selection.end,
  )) {
    if (inline.kind == MdInlineKind.codeSpan &&
        inline.sourceRange.start < selection.start &&
        selection.end < inline.sourceRange.end) {
      return true;
    }
  }
  return false;
}

bool _isInsideLinkTarget(MdTree tree, int offset) {
  for (final MdInline inline in _inlinesAround(tree, offset, offset)) {
    final MdRange? target = switch (inline.kind) {
      MdInlineKind.link => inline.markerRanges.last,
      MdInlineKind.autolink => inline.sourceRange,
      _ => null,
    };
    if (target != null && target.start < offset && offset < target.end) {
      return true;
    }
  }
  return false;
}

Transaction _removeMarkers(EditorState state, MdInline node) {
  final ChangeSet changes = ChangeSet(
    length: state.source.length,
    replacements: <TextReplacement>[
      for (final MdRange marker in node.markerRanges)
        TextReplacement(marker.start, marker.end, ''),
    ],
  );
  return _transaction(
    changes,
    state.selection.mapped(changes, side: MapSide.before),
  );
}

List<MdRange> _pieces(MdSourceLines lines, MdTree tree, int from, int to) {
  final List<MdRange> pieces = <MdRange>[];
  for (final MdBlock block in _blocksAround(tree, from, to)) {
    if (block.kind == MdBlockKind.table) {
      for (final MdBlock row in block.blocks) {
        for (final MdBlock cell in row.blocks) {
          pieces.add(cell.contentRange);
        }
      }
    } else {
      _collectLeafPieces(lines, block, const <MdBlock>[], pieces);
    }
  }
  pieces.sort((MdRange a, MdRange b) => a.start.compareTo(b.start));
  return <MdRange>[
    for (final MdRange piece in pieces)
      if (piece.start <= to && piece.end >= from) piece,
  ];
}

void _collectLeafPieces(
  MdSourceLines lines,
  MdBlock block,
  List<MdBlock> ancestors,
  List<MdRange> pieces,
) {
  if (block.kind == MdBlockKind.heading ||
      block.kind == MdBlockKind.paragraph) {
    final List<MdRange> hardBreaks = <MdRange>[
      for (final MdInline inline in _allInlines(block.inlines))
        if (inline.kind == MdInlineKind.hardBreak &&
            inline.markerRanges.isNotEmpty)
          inline.markerRanges.first,
    ];
    for (final MdRange segment in MdBlockParser.inlineSegments(
      lines,
      block,
      ancestors,
    )) {
      MdRange piece = segment;
      for (final MdRange hardBreak in hardBreaks) {
        if (hardBreak.end == segment.end && hardBreak.start >= segment.start) {
          piece = MdRange(segment.start, hardBreak.start);
        }
      }
      pieces.add(piece);
    }
    return;
  }
  final List<MdBlock> inner = <MdBlock>[...ancestors, block];
  for (final MdBlock child in block.blocks) {
    _collectLeafPieces(lines, child, inner, pieces);
  }
}

List<MdRange> _selectedParts(
  String source,
  MdSourceLines lines,
  MdTree tree,
  int start,
  int end,
) {
  final List<MdRange> parts = <MdRange>[];
  for (final MdRange piece in _pieces(lines, tree, start, end)) {
    int from = piece.start > start ? piece.start : start;
    int to = piece.end < end ? piece.end : end;
    while (from < to && _isSpaceOrTab(source.codeUnitAt(from))) {
      from += 1;
    }
    while (to > from && _isSpaceOrTab(source.codeUnitAt(to - 1))) {
      to -= 1;
    }
    if (from < to) {
      parts.add(MdRange(from, to));
    }
  }
  return parts;
}

Transaction _wrapParts(
  EditorState state,
  InlineFormat format,
  List<MdRange> parts,
) {
  final String source = state.source;
  final ChangeSet changes = ChangeSet(
    length: source.length,
    replacements: <TextReplacement>[
      for (final MdRange part in parts) ..._wrapping(format, source, part),
    ],
  );
  final NoteSelection selection = state.selection;
  if (format == InlineFormat.link) {
    return _transaction(
      changes,
      NoteSelection.collapsed(
        changes.mapPosition(parts.first.end, side: MapSide.before) + 2,
      ),
    );
  }
  final int start = changes.mapPosition(selection.start, side: MapSide.after);
  final int end = changes.mapPosition(selection.end, side: MapSide.before);
  final bool anchorFirst = selection.anchor <= selection.head;
  return _transaction(
    changes,
    NoteSelection(
      anchor: anchorFirst ? start : end,
      head: anchorFirst ? end : start,
      affinity: selection.affinity,
    ),
  );
}

List<TextReplacement> _wrapping(
  InlineFormat format,
  String source,
  MdRange part,
) {
  final _Pair pair = _pairFor(format, part.sliceOf(source));
  return <TextReplacement>[
    TextReplacement(part.start, part.start, pair.opening),
    TextReplacement(part.end, part.end, pair.closing),
  ];
}

int _movedPoint(MdSourceLines lines, MdTree tree, int point) {
  final MdSourceLine line = lines.lines[lines.lineIndexAt(point)];
  final List<MdRange> pieces = <MdRange>[
    for (final MdRange piece in _pieces(lines, tree, line.start, line.end))
      if (piece.start >= line.start && piece.end <= line.end) piece,
  ];
  if (pieces.isEmpty) {
    return point;
  }
  if (point < pieces.first.start) {
    return pieces.first.start;
  }
  if (point > pieces.last.end && _clampsAtEnd(tree, line)) {
    return pieces.last.end;
  }
  return point;
}

bool _clampsAtEnd(MdTree tree, MdSourceLine line) {
  for (final MdBlock block in _allBlocks(
    _blocksAround(tree, line.start, line.end),
  )) {
    final bool onLine =
        block.sourceRange.start <= line.end &&
        block.sourceRange.end >= line.start;
    if (onLine &&
        (block.kind == MdBlockKind.heading ||
            block.kind == MdBlockKind.tableRow)) {
      return true;
    }
  }
  return false;
}

bool _isOpaqueLine(MdTree tree, MdSourceLine line) {
  for (final MdBlock block in _allBlocks(
    _blocksAround(tree, line.start, line.end),
  )) {
    final bool onLine =
        block.sourceRange.start <= line.end &&
        block.sourceRange.end >= line.start;
    if (!onLine) {
      continue;
    }
    switch (block.kind) {
      case MdBlockKind.fencedCode ||
          MdBlockKind.photoLine ||
          MdBlockKind.thematicBreak:
        return true;
      case MdBlockKind.table:
        for (final MdRange delimiter in block.markerRanges) {
          if (delimiter.start <= line.end && delimiter.end >= line.start) {
            return true;
          }
        }
      default:
        break;
    }
  }
  return false;
}

Transaction? _emptyPairAt(EditorState state, InlineFormat format, int point) {
  final String source = state.source;
  final int length = source.length;
  if (format == InlineFormat.link) {
    final bool isPair =
        point >= 1 &&
        point + 3 <= length &&
        source.codeUnitAt(point - 1) == _openBracket &&
        source.substring(point, point + 3) == ']()';
    return isPair ? _deletion(state, point - 1, point + 3) : null;
  }
  final (int unit, int half) = switch (format) {
    InlineFormat.bold => (_star, 2),
    InlineFormat.italic => (_star, 1),
    InlineFormat.strikethrough => (_tilde, 2),
    InlineFormat.highlight => (_equals, 2),
    InlineFormat.code || InlineFormat.link => (_backtick, 1),
  };
  int before = 0;
  while (point - before - 1 >= 0 &&
      source.codeUnitAt(point - before - 1) == unit) {
    before += 1;
  }
  int after = 0;
  while (point + after < length && source.codeUnitAt(point + after) == unit) {
    after += 1;
  }
  return before == half && after == half
      ? _deletion(state, point - half, point + half)
      : null;
}

Transaction _deletion(EditorState state, int from, int to) => _transaction(
  ChangeSet.single(state.source.length, from, to, ''),
  NoteSelection.collapsed(from),
);

Transaction? _wrapWordAt(
  EditorState state,
  InlineFormat format,
  MdSourceLines lines,
  int point,
) {
  final String source = state.source;
  final MdSourceLine line = lines.lines[lines.lineIndexAt(point)];
  MdRange? piece;
  for (final MdRange candidate in _pieces(
    lines,
    state.tree,
    line.start,
    line.end,
  )) {
    if (candidate.start <= point && point <= candidate.end) {
      piece = candidate;
    }
  }
  if (piece == null) {
    return null;
  }
  final List<int> bounds = <int>[piece.start];
  final List<bool> isWord = <bool>[];
  final CharacterRange graphemes = Characters(piece.sliceOf(source)).iterator;
  while (graphemes.moveNext()) {
    final String grapheme = graphemes.current;
    bounds.add(bounds.last + grapheme.length);
    isWord.add(
      _wordCharacter.hasMatch(String.fromCharCode(grapheme.runes.first)),
    );
  }
  final int at = bounds.indexOf(point);
  if (at <= 0 || at >= isWord.length || !isWord[at - 1] || !isWord[at]) {
    return null;
  }
  int first = at - 1;
  while (first > 0 && isWord[first - 1]) {
    first -= 1;
  }
  int last = at;
  while (last + 1 < isWord.length && isWord[last + 1]) {
    last += 1;
  }
  final int wordStart = bounds[first];
  final int wordEnd = bounds[last + 1];
  final MdRange word = MdRange(wordStart, wordEnd);
  final _Pair pair = _pairFor(format, word.sliceOf(source));
  final ChangeSet changes = ChangeSet(
    length: source.length,
    replacements: _wrapping(format, source, word),
  );
  final int caret = format == InlineFormat.link
      ? wordEnd + pair.opening.length + 2
      : point + pair.opening.length;
  return _transaction(changes, NoteSelection.collapsed(caret));
}

Transaction _insertPairAt(EditorState state, InlineFormat format, int point) {
  final _Pair pair = _pairFor(format, '');
  return _transaction(
    ChangeSet.single(
      state.source.length,
      point,
      point,
      pair.opening + pair.closing,
    ),
    NoteSelection.collapsed(point + pair.opening.length),
  );
}

Transaction _transaction(ChangeSet changes, NoteSelection selection) =>
    Transaction(
      changes: changes,
      selection: selection,
      event: TransactionEvent.format,
    );

bool _isSpaceOrTab(int unit) => unit == _space || unit == _tab;

final RegExp _wordCharacter = RegExp(r'[\p{L}\p{M}\p{N}]', unicode: true);

const int _space = 0x20;
const int _tab = 0x09;
const int _star = 0x2A;
const int _tilde = 0x7E;
const int _equals = 0x3D;
const int _backtick = 0x60;
const int _openBracket = 0x5B;
