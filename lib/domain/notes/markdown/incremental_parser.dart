import 'note_tree.dart';
import 'syntax_tree.dart';

const int _lineFeed = 0x0A;
const int _carriageReturn = 0x0D;
const int _space = 0x20;
const int _tab = 0x09;
const int _composingMask = 0xE000;

final class MdEdit {
  const MdEdit({
    required this.start,
    required this.end,
    required this.inserted,
  });

  final int start;
  final int end;
  final String inserted;

  int get newEnd => start + inserted.length;

  int get lengthDelta => inserted.length - (end - start);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdEdit &&
          start == other.start &&
          end == other.end &&
          inserted == other.inserted;

  @override
  int get hashCode => Object.hash(start, end, inserted);

  @override
  String toString() => 'MdEdit($start, $end, ${_quoted(inserted)})';
}

final class MdReparse {
  const MdReparse({
    required this.tree,
    required this.reparsedFrom,
    required this.reparsedTo,
  });

  final MdTree tree;
  final int reparsedFrom;
  final int reparsedTo;

  List<MdBlock> get reparsedBlocks {
    final List<MdBlock> blocks = tree.blocks;
    final int first = _firstStartingAtOrAfter(blocks, reparsedFrom);
    final int last = _firstStartingAtOrAfter(blocks, reparsedTo);
    return List<MdBlock>.unmodifiable(blocks.sublist(first, last));
  }

  @override
  String toString() => 'MdReparse($reparsedFrom, $reparsedTo, $tree)';
}

final class MdIncrementalParser {
  const MdIncrementalParser({this.tables = true});

  final bool tables;

  MdReparse reparse(
    MdTree old,
    String oldSource,
    String newSource,
    MdEdit edit, {
    MdRange? composing,
    MdRange? previousComposing,
  }) {
    _check(old, oldSource, newSource, edit, composing, previousComposing);
    final int delta = edit.lengthDelta;
    final List<MdBlock> oldBlocks = old.blocks;

    int effectiveStart = edit.start;
    int effectiveEnd = edit.end;
    if (previousComposing != null) {
      effectiveStart = _min(effectiveStart, previousComposing.start);
      effectiveEnd = _max(effectiveEnd, previousComposing.end);
    }
    if (composing != null) {
      effectiveStart = _min(
        effectiveStart,
        _mapBack(composing.start, edit, true),
      );
      effectiveEnd = _max(effectiveEnd, _mapBack(composing.end, edit, false));
    }

    final int startLine = _lineStartAt(oldSource, effectiveStart);
    final int holder = _lastStartingAtOrBefore(oldBlocks, startLine);
    final int kept = holder >= 1
        ? _freshStartAtOrBefore(oldSource, oldBlocks, holder - 1)
        : 0;
    final int start = holder >= 1 ? oldBlocks[kept].sourceRange.start : 0;

    final int endLineBreak = oldSource.indexOf('\n', effectiveEnd);
    final int firstCandidate = endLineBreak < 0
        ? oldBlocks.length
        : _firstStartingAtOrAfter(oldBlocks, endLineBreak + 1);

    final int newLength = newSource.length;
    int windowEnd = firstCandidate < oldBlocks.length
        ? _lookaheadEnd(
            newSource,
            oldBlocks[firstCandidate].sourceRange.start + delta,
          )
        : newLength;
    while (true) {
      final MdTree window = parseNoteTree(
        _parseText(newSource, start, windowEnd, composing),
        tables: tables,
      );
      final bool reachesEnd = windowEnd == newLength;
      for (int c = firstCandidate; c < oldBlocks.length; c++) {
        final int at = oldBlocks[c].sourceRange.start + delta;
        if (at >= windowEnd) {
          break;
        }
        final int local = _indexStartingAt(window.blocks, at - start);
        if (local < 0) {
          continue;
        }
        if (!reachesEnd && !_hasBreakBefore(newSource, at, windowEnd)) {
          continue;
        }
        return MdReparse(
          tree: MdTree(
            sourceLength: newLength,
            blocks: <MdBlock>[
              ...oldBlocks.take(kept),
              for (final MdBlock block in window.blocks.take(local))
                _shift(block, start),
              for (final MdBlock block in oldBlocks.skip(c))
                _shift(block, delta),
            ],
          ),
          reparsedFrom: start,
          reparsedTo: at,
        );
      }
      if (reachesEnd) {
        return MdReparse(
          tree: MdTree(
            sourceLength: newLength,
            blocks: <MdBlock>[
              ...oldBlocks.take(kept),
              for (final MdBlock block in window.blocks) _shift(block, start),
            ],
          ),
          reparsedFrom: start,
          reparsedTo: newLength,
        );
      }
      windowEnd = _nextWindowEnd(
        newSource,
        oldBlocks,
        firstCandidate,
        delta,
        start + 2 * (windowEnd - start),
      );
    }
  }

  void _check(
    MdTree old,
    String oldSource,
    String newSource,
    MdEdit edit,
    MdRange? composing,
    MdRange? previousComposing,
  ) {
    if (old.sourceLength != oldSource.length) {
      throw ArgumentError.value(
        old.sourceLength,
        'old.sourceLength',
        'must equal the old source length ${oldSource.length}',
      );
    }
    if (edit.start < 0 ||
        edit.end < edit.start ||
        edit.end > oldSource.length) {
      throw ArgumentError.value(
        edit,
        'edit',
        'must lie inside the old source of length ${oldSource.length}',
      );
    }
    if (newSource.length != oldSource.length + edit.lengthDelta) {
      throw ArgumentError.value(
        newSource.length,
        'newSource.length',
        'must equal ${oldSource.length + edit.lengthDelta}',
      );
    }
    if (!newSource.startsWith(edit.inserted, edit.start)) {
      throw ArgumentError.value(
        edit,
        'edit',
        'inserted text must appear in the new source at ${edit.start}',
      );
    }
    if (composing != null && !_fits(composing, newSource.length)) {
      throw ArgumentError.value(
        composing,
        'composing',
        'must lie inside the new source of length ${newSource.length}',
      );
    }
    if (previousComposing != null &&
        !_fits(previousComposing, oldSource.length)) {
      throw ArgumentError.value(
        previousComposing,
        'previousComposing',
        'must lie inside the old source of length ${oldSource.length}',
      );
    }
  }

  int _nextWindowEnd(
    String source,
    List<MdBlock> oldBlocks,
    int firstCandidate,
    int delta,
    int target,
  ) {
    int low = firstCandidate;
    int high = oldBlocks.length;
    while (low < high) {
      final int mid = (low + high) >> 1;
      if (oldBlocks[mid].sourceRange.start + delta < target) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low < oldBlocks.length
        ? _lookaheadEnd(source, oldBlocks[low].sourceRange.start + delta)
        : source.length;
  }
}

bool _fits(MdRange range, int length) =>
    range.start >= 0 && range.end >= range.start && range.end <= length;

int _min(int a, int b) => a < b ? a : b;

int _max(int a, int b) => a > b ? a : b;

int _mapBack(int offset, MdEdit edit, bool isStart) {
  if (offset <= edit.start) {
    return offset;
  }
  if (offset >= edit.newEnd) {
    return offset - edit.lengthDelta;
  }
  return isStart ? edit.start : edit.end;
}

MdBlock _shift(MdBlock block, int delta) =>
    delta == 0 ? block : block.shifted(delta);

int _lineStartAt(String source, int offset) =>
    offset == 0 ? 0 : source.lastIndexOf('\n', offset - 1) + 1;

int _contentEndAt(String source, int lineStart) {
  final int lineFeed = source.indexOf('\n', lineStart);
  if (lineFeed < 0) {
    return source.length;
  }
  return lineFeed > lineStart &&
          source.codeUnitAt(lineFeed - 1) == _carriageReturn
      ? lineFeed - 1
      : lineFeed;
}

int _lookaheadEnd(String source, int lineStart) {
  final int lineFeed = source.indexOf('\n', lineStart);
  return lineFeed < 0 ? source.length : _contentEndAt(source, lineFeed + 1);
}

bool _followsBlankLine(String source, int offset) {
  final int lineStart = _lineStartAt(source, offset);
  if (lineStart == 0) {
    return true;
  }
  final int previousStart = _lineStartAt(source, lineStart - 1);
  final int previousEnd = _contentEndAt(source, previousStart);
  for (int at = previousStart; at < previousEnd; at++) {
    final int unit = source.codeUnitAt(at);
    if (unit != _space && unit != _tab) {
      return false;
    }
  }
  return true;
}

bool _mayJoinPreviousLine(String source, MdBlockKind kind, int at) =>
    kind == MdBlockKind.table && !_followsBlankLine(source, at);

int _freshStartAtOrBefore(String source, List<MdBlock> blocks, int index) =>
    index >= 1 &&
        _mayJoinPreviousLine(
          source,
          blocks[index].kind,
          blocks[index].sourceRange.start,
        )
    ? _freshStartAtOrBefore(source, blocks, index - 1)
    : index;

bool _hasBreakBefore(String source, int from, int limit) {
  final int lineFeed = source.indexOf('\n', from);
  return lineFeed >= 0 && lineFeed < limit;
}

String _parseText(String source, int start, int end, MdRange? composing) {
  if (composing == null ||
      composing.end <= start ||
      composing.start >= end ||
      composing.isEmpty) {
    return source.substring(start, end);
  }
  final int maskStart = _max(composing.start, start);
  final int maskEnd = _min(composing.end, end);
  final List<int> masked = <int>[
    for (int at = maskStart; at < maskEnd; at++)
      switch (source.codeUnitAt(at)) {
        _lineFeed => _lineFeed,
        _carriageReturn => _carriageReturn,
        _ => _composingMask,
      },
  ];
  return '${source.substring(start, maskStart)}'
      '${String.fromCharCodes(masked)}'
      '${source.substring(maskEnd, end)}';
}

int _lastStartingAtOrBefore(List<MdBlock> blocks, int offset) {
  int low = 0;
  int high = blocks.length - 1;
  int found = -1;
  while (low <= high) {
    final int mid = (low + high) >> 1;
    if (blocks[mid].sourceRange.start <= offset) {
      found = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return found;
}

int _firstStartingAtOrAfter(List<MdBlock> blocks, int offset) {
  int low = 0;
  int high = blocks.length;
  while (low < high) {
    final int mid = (low + high) >> 1;
    if (blocks[mid].sourceRange.start < offset) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low;
}

int _indexStartingAt(List<MdBlock> blocks, int offset) {
  final int index = _firstStartingAtOrAfter(blocks, offset);
  return index < blocks.length && blocks[index].sourceRange.start == offset
      ? index
      : -1;
}

String _quoted(String text) {
  final StringBuffer buffer = StringBuffer("'");
  for (final int unit in text.codeUnits) {
    buffer.write(switch (unit) {
      _lineFeed => r'\n',
      _carriageReturn => r'\r',
      _tab => r'\t',
      0x5C => r'\\',
      0x27 => r"\'",
      _ => String.fromCharCode(unit),
    });
  }
  buffer.write("'");
  return buffer.toString();
}
