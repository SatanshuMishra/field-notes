import '../source_lines.dart';
import '../syntax_tree.dart';

const int _backtick = 0x60;
const int _tilde = 0x7E;
const int _backslash = 0x5C;

final class MdFence {
  const MdFence({
    required this.character,
    required this.length,
    required this.indent,
    required this.infoRange,
  });

  final int character;
  final int length;
  final int indent;
  final MdRange infoRange;

  static MdFence? open(MdLineCursor cursor) {
    final int indent = cursor.indentColumns;
    if (indent > 3) {
      return null;
    }
    final MdLineCursor run = cursor.skipSpaces();
    final int? character = run.codeUnit;
    if (character != _backtick && character != _tilde) {
      return null;
    }
    final String source = run.source;
    final int lineEnd = run.line.end;
    int runEnd = run.offset;
    while (runEnd < lineEnd && source.codeUnitAt(runEnd) == character) {
      runEnd++;
    }
    final int length = runEnd - run.offset;
    if (length < 3) {
      return null;
    }
    int infoStart = runEnd;
    while (infoStart < lineEnd && _isSpaceOrTab(source.codeUnitAt(infoStart))) {
      infoStart++;
    }
    int infoEnd = lineEnd;
    while (infoEnd > infoStart &&
        _isSpaceOrTab(source.codeUnitAt(infoEnd - 1))) {
      infoEnd--;
    }
    if (character == _backtick) {
      for (int at = infoStart; at < infoEnd; at++) {
        if (source.codeUnitAt(at) == _backtick) {
          return null;
        }
      }
    }
    return MdFence(
      character: character!,
      length: length,
      indent: indent,
      infoRange: infoStart == infoEnd
          ? MdRange(runEnd, runEnd)
          : MdRange(infoStart, infoEnd),
    );
  }

  bool closes(MdLineCursor cursor) {
    if (cursor.indentColumns > 3) {
      return false;
    }
    final MdLineCursor run = cursor.skipSpaces();
    final String source = run.source;
    final int lineEnd = run.line.end;
    int runEnd = run.offset;
    while (runEnd < lineEnd && source.codeUnitAt(runEnd) == character) {
      runEnd++;
    }
    if (runEnd - run.offset < length) {
      return false;
    }
    return run.advance(runEnd - run.offset).restIsBlank;
  }

  String info(String source) {
    final String raw = infoRange.sliceOf(source);
    final StringBuffer buffer = StringBuffer();
    int at = 0;
    while (at < raw.length) {
      final int unit = raw.codeUnitAt(at);
      if (unit == _backslash &&
          at + 1 < raw.length &&
          _isAsciiPunctuation(raw.codeUnitAt(at + 1))) {
        buffer.writeCharCode(raw.codeUnitAt(at + 1));
        at += 2;
      } else {
        buffer.writeCharCode(unit);
        at++;
      }
    }
    return buffer.toString();
  }

  static MdFence ofBlock(MdBlock block, MdSourceLines lines) {
    final int start = block.sourceRange.start;
    final MdLineCursor lineStart = MdLineCursor.atLine(
      lines,
      lines.lineIndexAt(start),
    );
    final MdFence? fence = open(lineStart.advance(start - lineStart.offset));
    if (block.kind != MdBlockKind.fencedCode || fence == null) {
      throw ArgumentError.value(block, 'block', 'is not a fenced code block');
    }
    return fence;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdFence &&
          character == other.character &&
          length == other.length &&
          indent == other.indent &&
          infoRange == other.infoRange;

  @override
  int get hashCode => Object.hash(character, length, indent, infoRange);

  @override
  String toString() =>
      'MdFence(${String.fromCharCode(character) * length}, '
      'indent: $indent, info: $infoRange)';
}

bool _isSpaceOrTab(int unit) => unit == 0x20 || unit == 0x09;

bool _isAsciiPunctuation(int unit) =>
    (unit >= 0x21 && unit <= 0x2F) ||
    (unit >= 0x3A && unit <= 0x40) ||
    (unit >= 0x5B && unit <= 0x60) ||
    (unit >= 0x7B && unit <= 0x7E);
