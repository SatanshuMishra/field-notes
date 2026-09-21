import 'dart:math' as math;

import 'package:flutter/widgets.dart';

const String boldMarker = '**';
const String italicMarker = '_';
const String headingPrefix = '## ';
const String bulletPrefix = '- ';
const String quotePrefix = '> ';

final RegExp _headingMatch = RegExp(r'^ {0,3}#{1,3}[ \t]+');
final RegExp _bulletMatch = RegExp(r'^ {0,3}[-*+][ \t]+');
final RegExp _quoteMatch = RegExp(r'^ {0,3}>[ \t]?');

TextEditingValue toggleBold(TextEditingValue value) =>
    _toggleWrap(value, boldMarker);

TextEditingValue toggleItalic(TextEditingValue value) =>
    _toggleWrap(value, italicMarker);

TextEditingValue toggleHeading(TextEditingValue value) =>
    _toggleLinePrefix(value, headingPrefix, _headingMatch);

TextEditingValue toggleBullet(TextEditingValue value) =>
    _toggleLinePrefix(value, bulletPrefix, _bulletMatch);

TextEditingValue toggleQuote(TextEditingValue value) =>
    _toggleLinePrefix(value, quotePrefix, _quoteMatch);

TextEditingValue toggleLink(TextEditingValue value) {
  final String text = value.text;
  final TextSelection selection = _selectionOf(value);
  final int start = selection.start;
  final int end = selection.end;
  if (start > 0 &&
      text.startsWith('[', start - 1) &&
      text.startsWith('](', end)) {
    final int close = text.indexOf(')', end + 2);
    if (close != -1 && !text.substring(end + 2, close).contains('\n')) {
      return TextEditingValue(
        text: text.substring(0, start - 1) +
            text.substring(start, end) +
            text.substring(close + 1),
        selection: TextSelection(
          baseOffset: start - 1,
          extentOffset: end - 1,
        ),
      );
    }
  }
  final String label = text.substring(start, end);
  return TextEditingValue(
    text: '${text.substring(0, start)}[$label]()${text.substring(end)}',
    selection: TextSelection.collapsed(
      offset: start == end ? start + 1 : end + 3,
    ),
  );
}

TextEditingValue _toggleWrap(TextEditingValue value, String marker) {
  final String text = value.text;
  final TextSelection selection = _selectionOf(value);
  final int start = selection.start;
  final int end = selection.end;
  final int width = marker.length;
  if (start - width >= 0 &&
      end + width <= text.length &&
      text.substring(start - width, start) == marker &&
      text.substring(end, end + width) == marker) {
    return TextEditingValue(
      text: text.substring(0, start - width) +
          text.substring(start, end) +
          text.substring(end + width),
      selection: TextSelection(
        baseOffset: start - width,
        extentOffset: end - width,
      ),
    );
  }
  if (end - start >= 2 * width &&
      text.substring(start, start + width) == marker &&
      text.substring(end - width, end) == marker) {
    return TextEditingValue(
      text: text.substring(0, start) +
          text.substring(start + width, end - width) +
          text.substring(end),
      selection: TextSelection(
        baseOffset: start,
        extentOffset: end - 2 * width,
      ),
    );
  }
  return TextEditingValue(
    text: '${text.substring(0, start)}$marker'
        '${text.substring(start, end)}$marker${text.substring(end)}',
    selection: TextSelection(
      baseOffset: start + width,
      extentOffset: end + width,
    ),
  );
}

TextEditingValue _toggleLinePrefix(
  TextEditingValue value,
  String prefix,
  RegExp present,
) {
  final String text = value.text;
  final TextSelection selection = _selectionOf(value);
  final int start = selection.start;
  final int end = selection.end;
  final int regionStart = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
  final int newline = text.indexOf('\n', end);
  final int regionEnd = newline == -1 ? text.length : newline;
  final List<String> lines = text.substring(regionStart, regionEnd).split('\n');
  final bool removing = lines.every(present.hasMatch);

  final StringBuffer rebuilt = StringBuffer();
  int oldCursor = regionStart;
  int newCursor = regionStart;
  int newStart = start;
  int newEnd = end;
  bool startMapped = false;
  bool endMapped = false;

  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i];
    final String replaced =
        removing ? line.replaceFirst(present, '') : '$prefix$line';
    final int shift = replaced.length - line.length;
    int mapped(int offset) {
      final int within = math.max(0, math.min(offset - oldCursor, line.length));
      return newCursor + math.max(0, math.min(within + shift, replaced.length));
    }

    if (!startMapped && start <= oldCursor + line.length) {
      newStart = mapped(start);
      startMapped = true;
    }
    if (!endMapped && end <= oldCursor + line.length) {
      newEnd = mapped(end);
      endMapped = true;
    }
    rebuilt.write(replaced);
    if (i < lines.length - 1) {
      rebuilt.write('\n');
    }
    oldCursor += line.length + 1;
    newCursor += replaced.length + 1;
  }

  return TextEditingValue(
    text: text.substring(0, regionStart) +
        rebuilt.toString() +
        text.substring(regionEnd),
    selection: TextSelection(baseOffset: newStart, extentOffset: newEnd),
  );
}

TextSelection _selectionOf(TextEditingValue value) {
  final TextSelection selection = value.selection;
  if (!selection.isValid) {
    return TextSelection.collapsed(offset: value.text.length);
  }
  final int length = value.text.length;
  return TextSelection(
    baseOffset: math.min(selection.start, length),
    extentOffset: math.min(selection.end, length),
  );
}
