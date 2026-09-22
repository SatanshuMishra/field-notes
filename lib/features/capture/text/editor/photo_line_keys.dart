import 'package:flutter/services.dart';

import 'package:field_notes/features/notes/notes.dart';

const int _carriageReturn = 0x0D;

NotePhotoLine? photoLineHolding(List<NotePhotoLine> lines, int offset) {
  for (final NotePhotoLine line in lines) {
    if (line.containsOffset(offset)) {
      return line;
    }
  }
  return null;
}

bool selectionTouchesPhoto(NotePhotoLine line, TextSelection selection) {
  if (!selection.isValid) {
    return false;
  }
  if (selection.isCollapsed) {
    return line.containsOffset(selection.baseOffset);
  }
  return selection.start <= line.lineEnd && selection.end > line.lineStart;
}

int _breakBefore(String text, NotePhotoLine line) {
  if (line.lineStart == 0) {
    return 0;
  }
  final int newline = line.lineStart - 1;
  if (newline > 0 && text.codeUnitAt(newline - 1) == _carriageReturn) {
    return newline - 1;
  }
  return newline;
}

int _offsetAfter(NotePhotoLine line) =>
    line.breakEnd > line.lineEnd ? line.breakEnd : line.lineEnd;

int _offsetBefore(String text, NotePhotoLine line) =>
    line.lineStart == 0 ? 0 : _breakBefore(text, line);

TextEditingValue? photoAwareDelete(
  TextEditingValue value, {
  required bool forward,
}) {
  final TextSelection selection = value.selection;
  if (!selection.isValid || !selection.isCollapsed) {
    return null;
  }
  final List<NotePhotoLine> lines = notePhotoLines(value.text);
  if (lines.isEmpty) {
    return null;
  }
  final int caret = selection.baseOffset;
  final NotePhotoLine? holding = photoLineHolding(lines, caret);
  if (holding != null) {
    return removePhotoLine(value, holding).value;
  }
  for (final NotePhotoLine line in lines) {
    if (!forward && line.breakEnd > line.lineEnd && caret == line.breakEnd) {
      return selectPhotoLine(value, line);
    }
    if (forward &&
        line.lineStart > 0 &&
        caret == _breakBefore(value.text, line)) {
      return selectPhotoLine(value, line);
    }
  }
  return null;
}

TextEditingValue? photoAwareStep(
  TextEditingValue value, {
  required bool forward,
  required bool collapse,
}) {
  final TextSelection selection = value.selection;
  if (!selection.isValid || (collapse && !selection.isCollapsed)) {
    return null;
  }
  final List<NotePhotoLine> lines = notePhotoLines(value.text);
  final NotePhotoLine? line = photoLineHolding(lines, selection.extentOffset);
  if (line == null) {
    return null;
  }
  final int target =
      forward ? _offsetAfter(line) : _offsetBefore(value.text, line);
  return value.copyWith(
    selection: collapse
        ? TextSelection.collapsed(offset: target)
        : selection.extendTo(TextPosition(offset: target)),
    composing: TextRange.empty,
  );
}

TextEditingValue? deselectPhoto(TextEditingValue value) {
  final TextSelection selection = value.selection;
  if (!selection.isValid || !selection.isCollapsed) {
    return null;
  }
  final List<NotePhotoLine> lines = notePhotoLines(value.text);
  final NotePhotoLine? line = photoLineHolding(lines, selection.baseOffset);
  if (line == null) {
    return null;
  }
  final int target = line.breakEnd > line.lineEnd
      ? line.breakEnd
      : _offsetBefore(value.text, line);
  if (line.containsOffset(target)) {
    return null;
  }
  return value.copyWith(
    selection: TextSelection.collapsed(offset: target),
    composing: TextRange.empty,
  );
}

class PhotoLineGuard extends TextInputFormatter {
  const PhotoLineGuard();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String before = oldValue.text;
    final String after = newValue.text;
    final TextSelection old = oldValue.selection;
    if (before == after || !old.isValid) {
      return newValue;
    }
    final List<NotePhotoLine> lines = notePhotoLines(before);
    if (lines.isEmpty) {
      return newValue;
    }
    final int start = old.start;
    final int end = old.end;
    final int insertedLength = after.length - (before.length - (end - start));
    if (insertedLength < 0 ||
        !after.startsWith(before.substring(0, start)) ||
        !after.endsWith(before.substring(end)) ||
        start + insertedLength > after.length) {
      return newValue;
    }
    final String inserted = after.substring(start, start + insertedLength);
    if (old.isCollapsed) {
      final NotePhotoLine? line = photoLineHolding(lines, start);
      if (line == null || inserted.isEmpty) {
        return newValue;
      }
      return _insertAfter(before, line, inserted, start, newValue.composing);
    }
    return _replaceKeepingPhotos(before, lines, start, end, inserted) ??
        newValue;
  }

  TextEditingValue _insertAfter(
    String text,
    NotePhotoLine line,
    String inserted,
    int typedAt,
    TextRange composing,
  ) {
    final int at = line.lineEnd;
    final String added = inserted == '\n' ? '\n' : '\n$inserted';
    final int caret = at + added.length;
    final int shift = at + 1 - typedAt;
    return TextEditingValue(
      text: text.replaceRange(at, at, added),
      selection: TextSelection.collapsed(offset: caret),
      composing: composing.isValid && inserted != '\n'
          ? TextRange(
              start: composing.start + shift,
              end: composing.end + shift,
            )
          : TextRange.empty,
    );
  }

  TextEditingValue? _replaceKeepingPhotos(
    String text,
    List<NotePhotoLine> lines,
    int start,
    int end,
    String inserted,
  ) {
    int from = start;
    int to = end;
    for (final NotePhotoLine line in lines) {
      final bool overlaps = from < line.lineEnd && to > line.lineStart;
      if (overlaps) {
        if (from > line.lineStart) {
          from = line.lineStart;
        }
        if (to < line.lineEnd) {
          to = line.lineEnd;
        }
        continue;
      }
      if (from == line.lineEnd && to > line.lineEnd) {
        from = _offsetAfter(line) <= to ? _offsetAfter(line) : to;
      }
      if (to == line.lineStart && from < line.lineStart) {
        final int keep = _breakBefore(text, line);
        to = keep >= from ? keep : from;
      }
    }
    if (from == start && to == end) {
      return null;
    }
    final String replaced = text.replaceRange(from, to, inserted);
    return TextEditingValue(
      text: replaced,
      selection: TextSelection.collapsed(offset: from + inserted.length),
    );
  }
}
