const int _lineFeed = 0x0A;
const int _carriageReturn = 0x0D;
const int _space = 0x20;
const int _tab = 0x09;

final class MdSourceLine {
  const MdSourceLine({
    required this.index,
    required this.start,
    required this.end,
    required this.breakEnd,
  });

  final int index;
  final int start;
  final int end;
  final int breakEnd;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdSourceLine &&
          index == other.index &&
          start == other.start &&
          end == other.end &&
          breakEnd == other.breakEnd;

  @override
  int get hashCode => Object.hash(index, start, end, breakEnd);

  @override
  String toString() => 'MdSourceLine($index: $start, $end, $breakEnd)';
}

final class MdSourceLines {
  MdSourceLines._(this.source, List<MdSourceLine> lines)
    : lines = List<MdSourceLine>.unmodifiable(lines);

  factory MdSourceLines.split(String source) {
    final int length = source.length;
    final List<MdSourceLine> lines = <MdSourceLine>[];
    int start = 0;
    int offset = 0;
    while (offset < length) {
      final int unit = source.codeUnitAt(offset);
      final bool isCrLf =
          unit == _carriageReturn &&
          offset + 1 < length &&
          source.codeUnitAt(offset + 1) == _lineFeed;
      if (unit == _lineFeed || isCrLf) {
        final int breakEnd = offset + (isCrLf ? 2 : 1);
        lines.add(
          MdSourceLine(
            index: lines.length,
            start: start,
            end: offset,
            breakEnd: breakEnd,
          ),
        );
        start = breakEnd;
        offset = breakEnd;
      } else {
        offset++;
      }
    }
    lines.add(
      MdSourceLine(
        index: lines.length,
        start: start,
        end: length,
        breakEnd: length,
      ),
    );
    return MdSourceLines._(source, lines);
  }

  final String source;
  final List<MdSourceLine> lines;

  int lineIndexAt(int offset) {
    if (offset < 0 || offset > source.length) {
      throw RangeError.range(offset, 0, source.length, 'offset');
    }
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

final class MdLineCursor {
  const MdLineCursor._(
    this._lines,
    this.line,
    this.offset,
    this.column,
    this.virtualColumns,
  );

  factory MdLineCursor.atLine(MdSourceLines lines, int lineIndex) {
    final MdSourceLine line = lines.lines[lineIndex];
    return MdLineCursor._(lines, line, line.start, 0, 0);
  }

  final MdSourceLines _lines;
  final MdSourceLine line;
  final int offset;
  final int column;
  final int virtualColumns;

  String get source => _lines.source;

  int? get codeUnit =>
      offset < line.end ? _lines.source.codeUnitAt(offset) : null;

  int get indentColumns {
    final String source = _lines.source;
    int at = offset;
    int reached = column + virtualColumns;
    while (at < line.end) {
      final int unit = source.codeUnitAt(at);
      if (unit == _space) {
        reached++;
      } else if (unit == _tab) {
        reached += 4 - reached % 4;
      } else {
        break;
      }
      at++;
    }
    return reached - column;
  }

  bool get restIsBlank {
    final String source = _lines.source;
    for (int at = offset; at < line.end; at++) {
      final int unit = source.codeUnitAt(at);
      if (unit != _space && unit != _tab) {
        return false;
      }
    }
    return true;
  }

  MdLineCursor advance(int codeUnits) {
    final String source = _lines.source;
    final int target = offset + codeUnits > line.end
        ? line.end
        : offset + codeUnits;
    int at = offset;
    int reached = column + virtualColumns;
    while (at < target) {
      reached += source.codeUnitAt(at) == _tab ? 4 - reached % 4 : 1;
      at++;
    }
    return MdLineCursor._(_lines, line, at, reached, 0);
  }

  MdLineCursor consumeColumns(int columns) {
    final String source = _lines.source;
    int remaining = columns;
    int at = offset;
    int reached = column;
    int pending = virtualColumns;
    if (pending > 0 && remaining > 0) {
      final int taken = pending < remaining ? pending : remaining;
      reached += taken;
      pending -= taken;
      remaining -= taken;
    }
    while (remaining > 0 && at < line.end) {
      final int unit = source.codeUnitAt(at);
      if (unit == _space) {
        at++;
        reached++;
        remaining--;
      } else if (unit == _tab) {
        final int width = 4 - reached % 4;
        at++;
        if (width <= remaining) {
          reached += width;
          remaining -= width;
        } else {
          reached += remaining;
          pending = width - remaining;
          remaining = 0;
        }
      } else {
        break;
      }
    }
    return MdLineCursor._(_lines, line, at, reached, pending);
  }

  MdLineCursor skipSpaces() {
    final String source = _lines.source;
    int at = offset;
    int reached = column + virtualColumns;
    while (at < line.end) {
      final int unit = source.codeUnitAt(at);
      if (unit == _space) {
        reached++;
      } else if (unit == _tab) {
        reached += 4 - reached % 4;
      } else {
        break;
      }
      at++;
    }
    return MdLineCursor._(_lines, line, at, reached, 0);
  }
}
