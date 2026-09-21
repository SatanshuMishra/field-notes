import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:field_notes/domain/notes/notes.dart';

import '../model/photo_placement.dart';

const int _newline = 0x0A;
const int _carriageReturn = 0x0D;
const int _space = 0x20;
const int _tab = 0x09;
const String _photoTokenMarker = '](photo/';

@immutable
final class NotePhotoLine {
  const NotePhotoLine({
    required this.ordinal,
    required this.block,
    required this.lineStart,
    required this.lineEnd,
    required this.breakEnd,
  });

  final int ordinal;
  final PhotoBlock block;
  final int lineStart;
  final int lineEnd;
  final int breakEnd;

  String get reference => block.reference;

  String get caption => block.caption;

  PhotoPlacement get placement => block.placement;

  SourceRange get token => block.markerRanges.first;

  bool containsOffset(int offset) => offset >= lineStart && offset <= lineEnd;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotePhotoLine &&
          ordinal == other.ordinal &&
          lineStart == other.lineStart &&
          lineEnd == other.lineEnd &&
          breakEnd == other.breakEnd &&
          block.sourceRange == other.block.sourceRange;

  @override
  int get hashCode =>
      Object.hash(ordinal, lineStart, lineEnd, breakEnd, block.sourceRange);

  @override
  String toString() => 'NotePhotoLine($ordinal, $reference, '
      '[$lineStart, $lineEnd))';
}

@immutable
final class RemovedPhotoLine {
  const RemovedPhotoLine({
    required this.text,
    required this.offset,
    required this.before,
    required this.after,
  });

  final String text;
  final int offset;
  final TextEditingValue before;
  final String after;
}

typedef PhotoLineRemoval = ({TextEditingValue value, RemovedPhotoLine removed});

List<NotePhotoLine> notePhotoLines(String source) {
  if (!source.contains(_photoTokenMarker)) {
    return const <NotePhotoLine>[];
  }
  final List<NotePhotoLine> lines = <NotePhotoLine>[];
  for (final NoteBlock block in parseNote(source)) {
    if (block is! PhotoBlock) {
      continue;
    }
    final int token = block.markerRanges.first.start;
    final int start = _lineStartAt(source, token);
    final int end = _lineEndAt(source, token);
    lines.add(
      NotePhotoLine(
        ordinal: lines.length,
        block: block,
        lineStart: start,
        lineEnd: end,
        breakEnd: end < source.length ? end + 1 : end,
      ),
    );
  }
  return List<NotePhotoLine>.unmodifiable(lines);
}

int? photoLineIndexAtCaret(String source, TextSelection selection) =>
    photoLineIndexIn(notePhotoLines(source), selection);

int? photoLineIndexIn(List<NotePhotoLine> lines, TextSelection selection) {
  if (!selection.isValid) {
    return null;
  }
  final int caret = selection.extentOffset;
  for (final NotePhotoLine line in lines) {
    if (line.containsOffset(caret)) {
      return line.ordinal;
    }
  }
  return null;
}

NotePhotoLine? photoLineAtCaret(TextEditingValue value) {
  final int? ordinal = photoLineIndexAtCaret(value.text, value.selection);
  return ordinal == null ? null : notePhotoLines(value.text)[ordinal];
}

TextEditingValue insertPhotoLinesAtCaret(
  TextEditingValue value,
  List<String> references,
) {
  if (references.isEmpty) {
    return value;
  }
  final String text = value.text;
  final String lines = <String>[
    for (final String reference in references)
      photoLineFor(reference: reference),
  ].join('\n');
  final TextSelection selection = value.selection;
  final int caret =
      selection.isValid ? math.min(selection.end, text.length) : text.length;
  final int lineStart = _lineStartAt(text, caret);
  final int lineEnd = _lineEndAt(text, caret);
  final String tail = lineEnd == text.length ? '\n' : '';
  if (_isBlank(text, lineStart, lineEnd)) {
    return _inserted(
      text,
      lineStart,
      lineEnd,
      '$lines$tail',
      caret: lineStart + lines.length + 1,
    );
  }
  if (caret == lineStart) {
    return _inserted(
      text,
      lineStart,
      lineStart,
      '$lines\n',
      caret: lineStart + lines.length + 1,
    );
  }
  return _inserted(
    text,
    lineEnd,
    lineEnd,
    '\n$lines$tail',
    caret: lineEnd + lines.length + 2,
  );
}

TextEditingValue selectPhotoLine(TextEditingValue value, NotePhotoLine line) {
  _assertCurrent(value, line);
  return TextEditingValue(
    text: value.text,
    selection: TextSelection.collapsed(offset: line.token.end),
  );
}

TextEditingValue setPhotoSide(
  TextEditingValue value,
  NotePhotoLine line,
  PhotoSide side,
) {
  return _rewrite(
    value,
    line,
    placement: line.placement.copyWith(side: side),
  );
}

TextEditingValue setPhotoSize(
  TextEditingValue value,
  NotePhotoLine line,
  PhotoSize size,
) {
  return _rewrite(
    value,
    line,
    placement: line.placement.copyWith(size: size),
  );
}

TextEditingValue setPhotoCaption(
  TextEditingValue value,
  NotePhotoLine line,
  String caption,
) {
  return _rewrite(value, line, caption: sanitizePhotoCaption(caption).trim());
}

TextEditingValue replacePhotoReference(
  TextEditingValue value,
  NotePhotoLine line,
  String reference,
) {
  return _rewrite(value, line, reference: reference);
}

bool canMovePhotoUp(String source, NotePhotoLine line) {
  final int? index = _unitIndexOf(_moveUnits(source), line);
  return index != null && index > 0;
}

bool canMovePhotoDown(String source, NotePhotoLine line) {
  final List<SourceRange> units = _moveUnits(source);
  final int? index = _unitIndexOf(units, line);
  return index != null && index < units.length - 1;
}

TextEditingValue movePhotoUp(TextEditingValue value, NotePhotoLine line) {
  _assertCurrent(value, line);
  final List<SourceRange> units = _moveUnits(value.text);
  final int? index = _unitIndexOf(units, line);
  if (index == null || index == 0) {
    return value;
  }
  return _swap(value, units[index - 1], units[index]);
}

TextEditingValue movePhotoDown(TextEditingValue value, NotePhotoLine line) {
  _assertCurrent(value, line);
  final List<SourceRange> units = _moveUnits(value.text);
  final int? index = _unitIndexOf(units, line);
  if (index == null || index >= units.length - 1) {
    return value;
  }
  return _swap(value, units[index], units[index + 1]);
}

PhotoLineRemoval removePhotoLine(TextEditingValue value, NotePhotoLine line) {
  _assertCurrent(value, line);
  final String text = value.text;
  int start = line.lineStart;
  final int end = line.breakEnd;
  if (line.breakEnd == line.lineEnd && line.lineStart > 0) {
    start = line.lineStart - 1;
    if (start > 0 && text.codeUnitAt(start - 1) == _carriageReturn) {
      start--;
    }
  }
  final String rest = text.replaceRange(start, end, '');
  return (
    value: TextEditingValue(
      text: rest,
      selection: _mapSelection(
        value.selection,
        _replacementMap(start, end, 0),
        rest.length,
      ),
    ),
    removed: RemovedPhotoLine(
      text: text.substring(start, end),
      offset: start,
      before: value,
      after: rest,
    ),
  );
}

TextEditingValue restorePhotoLine(
  TextEditingValue value,
  RemovedPhotoLine removed,
) {
  if (value.text == removed.after) {
    return removed.before;
  }
  final String text = value.text;
  final String line = _bareLine(removed.text);
  final int at = removed.offset.clamp(0, text.length);
  final int lineStart = _lineStartAt(text, at);
  final int insertAt = at == lineStart ? at : _lineEndAt(text, at);
  final String insert = at == lineStart ? '$line\n' : '\n$line';
  return TextEditingValue(
    text: text.replaceRange(insertAt, insertAt, insert),
    selection: _mapSelection(
      value.selection,
      _replacementMap(insertAt, insertAt, insert.length),
      text.length + insert.length,
    ),
  );
}

String _bareLine(String removed) {
  String line = removed;
  if (line.startsWith('\r\n')) {
    line = line.substring(2);
  } else if (line.startsWith('\n')) {
    line = line.substring(1);
  }
  if (line.endsWith('\n')) {
    line = line.substring(0, line.length - 1);
  }
  return line;
}

TextEditingValue _rewrite(
  TextEditingValue value,
  NotePhotoLine line, {
  String? caption,
  String? reference,
  PhotoPlacement? placement,
}) {
  _assertCurrent(value, line);
  final SourceRange token = line.token;
  final String replacement = photoLineFor(
    reference: reference ?? line.reference,
    caption: caption ?? line.caption,
    placement: placement ?? line.placement,
  );
  final String text = value.text.replaceRange(
    token.start,
    token.end,
    replacement,
  );
  return TextEditingValue(
    text: text,
    selection: _mapSelection(
      value.selection,
      _replacementMap(token.start, token.end, replacement.length),
      text.length,
    ),
  );
}

TextEditingValue _inserted(
  String text,
  int start,
  int end,
  String insert, {
  required int caret,
}) {
  final String next = text.replaceRange(start, end, insert);
  return TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: math.min(caret, next.length)),
  );
}

TextEditingValue _swap(TextEditingValue value, SourceRange a, SourceRange b) {
  final String text = value.text;
  final String first = a.sliceOf(text);
  final String second = b.sliceOf(text);
  final String gap = text.substring(a.end, b.start);
  final String next = text.replaceRange(a.start, b.end, '$second$gap$first');
  final int gapStart = a.start + second.length;
  final int firstStart = gapStart + gap.length;
  int map(int offset) {
    if (offset < a.start || offset > b.end) {
      return offset;
    }
    if (offset >= b.start) {
      return a.start + offset - b.start;
    }
    if (offset <= a.end) {
      return firstStart + offset - a.start;
    }
    return gapStart + offset - a.end;
  }

  return TextEditingValue(
    text: next,
    selection: _mapSelection(value.selection, map, next.length),
  );
}

List<SourceRange> _moveUnits(String source) {
  final List<SourceRange> fences = <SourceRange>[
    for (final NoteBlock block in parseNote(source))
      if (block is CodeBlock) _fenceSpan(source, block),
  ];
  final List<SourceRange> units = <SourceRange>[];
  int fence = 0;
  int start = 0;
  while (true) {
    final int end;
    if (fence < fences.length && fences[fence].start == start) {
      units.add(fences[fence]);
      end = fences[fence].end;
      fence++;
    } else {
      end = _lineEndAt(source, start);
      if (!_isBlank(source, start, end)) {
        units.add(SourceRange(start, end));
      }
    }
    if (end >= source.length) {
      return units;
    }
    start = end + 1;
  }
}

SourceRange _fenceSpan(String source, CodeBlock block) {
  final int start = block.markerRanges.first.start;
  final int anchor = block.markerRanges.length > 1
      ? block.markerRanges.last.start
      : block.contentRange.isEmpty
          ? start
          : block.contentRange.end - 1;
  return SourceRange(start, _lineEndAt(source, anchor));
}

int? _unitIndexOf(List<SourceRange> units, NotePhotoLine line) {
  for (int i = 0; i < units.length; i++) {
    if (units[i].start == line.lineStart) {
      return i;
    }
  }
  return null;
}

int Function(int) _replacementMap(int start, int end, int length) {
  return (int offset) {
    if (offset <= start) {
      return offset;
    }
    if (offset >= end) {
      return offset + length - (end - start);
    }
    return start + math.min(offset - start, length);
  };
}

TextSelection _mapSelection(
  TextSelection selection,
  int Function(int) map,
  int length,
) {
  if (!selection.isValid) {
    return selection;
  }
  return selection.copyWith(
    baseOffset: map(selection.baseOffset).clamp(0, length),
    extentOffset: map(selection.extentOffset).clamp(0, length),
  );
}

int _lineStartAt(String text, int offset) =>
    offset <= 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;

int _lineEndAt(String text, int offset) {
  final int newline = text.indexOf('\n', offset);
  return newline == -1 ? text.length : newline;
}

bool _isBlank(String text, int start, int end) {
  for (int i = start; i < end; i++) {
    final int unit = text.codeUnitAt(i);
    if (unit != _space &&
        unit != _tab &&
        unit != _carriageReturn &&
        unit != _newline) {
      return false;
    }
  }
  return true;
}

void _assertCurrent(TextEditingValue value, NotePhotoLine line) {
  assert(
    line.token.end <= value.text.length &&
        value.text
            .substring(line.token.start, line.token.end)
            .startsWith('!['),
    'NotePhotoLine $line does not describe this value',
  );
}
