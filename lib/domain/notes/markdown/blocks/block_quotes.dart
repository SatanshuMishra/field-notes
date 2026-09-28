import '../source_lines.dart';

abstract final class MdBlockQuotes {
  static MdLineCursor? consumeMarker(MdLineCursor cursor) {
    if (cursor.indentColumns > 3) {
      return null;
    }
    final MdLineCursor marker = cursor.skipSpaces();
    if (marker.codeUnit != 0x3E) {
      return null;
    }
    final MdLineCursor after = marker.advance(1);
    final int? next = after.codeUnit;
    return next == 0x20 || next == 0x09 ? after.consumeColumns(1) : after;
  }
}
