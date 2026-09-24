import '../source_lines.dart';
import '../syntax_tree.dart';

const int _space = 0x20;
const int _tab = 0x09;
const int _dash = 0x2D;
const int _plus = 0x2B;
const int _star = 0x2A;
const int _period = 0x2E;
const int _paren = 0x29;
const int _zero = 0x30;
const int _nine = 0x39;
const int _openBracket = 0x5B;
const int _closeBracket = 0x5D;
const int _lowerX = 0x78;
const int _upperX = 0x58;

final class MdListMarker {
  const MdListMarker({
    required this.ordered,
    required this.character,
    required this.start,
    required this.range,
    required this.contentColumn,
    required this.startsBlank,
  });

  final bool ordered;
  final int character;
  final int start;
  final MdRange range;
  final int contentColumn;
  final bool startsBlank;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdListMarker &&
          ordered == other.ordered &&
          character == other.character &&
          start == other.start &&
          range == other.range &&
          contentColumn == other.contentColumn &&
          startsBlank == other.startsBlank;

  @override
  int get hashCode =>
      Object.hash(ordered, character, start, range, contentColumn, startsBlank);

  @override
  String toString() =>
      'MdListMarker(${ordered ? '$start' : ''}'
      '${String.fromCharCode(character)} $range, '
      'content column: $contentColumn'
      '${startsBlank ? ', starts blank' : ''})';
}

abstract final class MdListItems {
  static MdListMarker? markerAt(MdLineCursor cursor) {
    if (cursor.indentColumns > 3) {
      return null;
    }
    final MdLineCursor marker = cursor.skipSpaces();
    final String source = cursor.source;
    final int lineEnd = cursor.line.end;
    final int? first = marker.codeUnit;
    if (first == null) {
      return null;
    }
    final bool ordered;
    final int character;
    final int number;
    final int markerEnd;
    if (first == _dash || first == _plus || first == _star) {
      ordered = false;
      character = first;
      number = 0;
      markerEnd = marker.offset + 1;
    } else {
      int at = marker.offset;
      while (at < lineEnd &&
          at - marker.offset <= 9 &&
          _isDigit(source.codeUnitAt(at))) {
        at++;
      }
      final int digits = at - marker.offset;
      if (digits == 0 || digits > 9 || at >= lineEnd) {
        return null;
      }
      final int delimiter = source.codeUnitAt(at);
      if (delimiter != _period && delimiter != _paren) {
        return null;
      }
      ordered = true;
      character = delimiter;
      number = int.parse(source.substring(marker.offset, at));
      markerEnd = at + 1;
    }
    final MdLineCursor after = marker.advance(markerEnd - marker.offset);
    final int? next = after.codeUnit;
    if (next != null && next != _space && next != _tab) {
      return null;
    }
    final bool startsBlank = after.restIsBlank;
    final int spaces = after.indentColumns;
    return MdListMarker(
      ordered: ordered,
      character: character,
      start: number,
      range: MdRange(cursor.offset, markerEnd),
      contentColumn: startsBlank || spaces >= 5
          ? after.column + 1
          : after.column + spaces,
      startsBlank: startsBlank,
    );
  }

  static MdTaskState taskStateAt(String source, int offset, int end) {
    if (offset + 3 >= end ||
        source.codeUnitAt(offset) != _openBracket ||
        source.codeUnitAt(offset + 2) != _closeBracket) {
      return MdTaskState.none;
    }
    final int after = source.codeUnitAt(offset + 3);
    if (after != _space && after != _tab) {
      return MdTaskState.none;
    }
    return switch (source.codeUnitAt(offset + 1)) {
      _lowerX || _upperX => MdTaskState.checked,
      _space || _tab => MdTaskState.unchecked,
      _ => MdTaskState.none,
    };
  }

  static bool isLoose(MdBlock list, MdSourceLines lines) =>
      _separated(list.blocks, lines) ||
      list.blocks.any((MdBlock item) => _separated(item.blocks, lines));

  static bool _separated(List<MdBlock> blocks, MdSourceLines lines) {
    for (int i = 1; i < blocks.length; i++) {
      final int previousLine = lines.lineIndexAt(blocks[i - 1].sourceRange.end);
      if (lines.lineIndexAt(blocks[i].sourceRange.start) - previousLine > 1) {
        return true;
      }
    }
    return false;
  }
}

bool _isDigit(int unit) => unit >= _zero && unit <= _nine;
