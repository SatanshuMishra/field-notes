import 'package:flutter/services.dart' show TextRange;

const int _carriageReturn = 0x0D;

final class CutBuffer {
  CutBuffer._();

  static final CutBuffer instance = CutBuffer._();

  String _text = '';

  String get text => _text;

  void store(String text) {
    if (text.isNotEmpty) {
      _text = text;
    }
  }
}

TextRange cutRangeToLineEnd(String text, int offset) {
  if (offset >= text.length) {
    return TextRange.collapsed(text.length);
  }
  final int feed = text.indexOf('\n', offset);
  if (feed < 0) {
    return TextRange(start: offset, end: text.length);
  }
  final int lineEnd =
      feed > offset && text.codeUnitAt(feed - 1) == _carriageReturn
      ? feed - 1
      : feed;
  if (lineEnd > offset) {
    return TextRange(start: offset, end: lineEnd);
  }
  return TextRange(start: offset, end: feed + 1);
}
