import '../syntax_tree.dart';

final class MdAutolinkScan {
  const MdAutolinkScan({required this.end, required this.kind});

  final int end;
  final MdAutolinkKind kind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdAutolinkScan && end == other.end && kind == other.kind;

  @override
  int get hashCode => Object.hash(end, kind);

  @override
  String toString() => 'MdAutolinkScan($end, ${kind.name})';
}

final class MdLinkTailScan {
  const MdLinkTailScan({
    required this.end,
    required this.destination,
    required this.destinationRange,
    this.title,
    this.titleRange,
  });

  final int end;
  final String destination;
  final MdRange destinationRange;
  final String? title;
  final MdRange? titleRange;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdLinkTailScan &&
          end == other.end &&
          destination == other.destination &&
          destinationRange == other.destinationRange &&
          title == other.title &&
          titleRange == other.titleRange;

  @override
  int get hashCode =>
      Object.hash(end, destination, destinationRange, title, titleRange);

  @override
  String toString() =>
      "MdLinkTailScan($end, '$destination' $destinationRange"
      "${title == null ? '' : ", title: '$title' $titleRange"})";
}

abstract final class MdLinks {
  static MdAutolinkScan? autolink(String text, int start) {
    if (start >= text.length || text.codeUnitAt(start) != _lessThan) {
      return null;
    }
    final int? uriEnd = _uriEnd(text, start + 1);
    if (uriEnd != null) {
      return MdAutolinkScan(end: uriEnd, kind: MdAutolinkKind.uri);
    }
    final Match? email = _email.matchAsPrefix(text, start + 1);
    if (email != null) {
      return MdAutolinkScan(end: email.end, kind: MdAutolinkKind.email);
    }
    return null;
  }

  static MdLinkTailScan? linkTail(String text, int start) {
    if (start >= text.length || text.codeUnitAt(start) != _openParen) {
      return null;
    }
    final int length = text.length;
    int position = _skipSpace(text, start + 1);
    final _Destination? destination = _destination(text, position);
    if (destination == null) {
      return null;
    }
    position = destination.end;
    final int beforeTitle = position;
    position = _skipSpace(text, position);
    final _Title? title = position > beforeTitle
        ? _title(text, position)
        : null;
    if (title != null) {
      position = _skipSpace(text, title.end);
    }
    if (position >= length || text.codeUnitAt(position) != _closeParen) {
      return null;
    }
    return MdLinkTailScan(
      end: position + 1,
      destination: _unescape(
        text,
        destination.range.start,
        destination.range.end,
      ),
      destinationRange: destination.range,
      title: title == null
          ? null
          : _unescape(text, title.range.start, title.range.end),
      titleRange: title?.range,
    );
  }

  static int? _uriEnd(String text, int start) {
    final int length = text.length;
    int position = start;
    if (position >= length || !_isAsciiLetter(text.codeUnitAt(position))) {
      return null;
    }
    position += 1;
    while (position < length && _isSchemeUnit(text.codeUnitAt(position))) {
      position += 1;
    }
    final int schemeLength = position - start;
    if (schemeLength < 2 || schemeLength > 32) {
      return null;
    }
    if (position >= length || text.codeUnitAt(position) != _colon) {
      return null;
    }
    position += 1;
    while (position < length) {
      final int unit = text.codeUnitAt(position);
      if (unit == _greaterThan) {
        return position + 1;
      }
      if (_isAsciiControl(unit) || unit == _space || unit == _lessThan) {
        return null;
      }
      position += 1;
    }
    return null;
  }

  static int _skipSpace(String text, int start) {
    final int length = text.length;
    int position = start;
    bool sawLineBreak = false;
    while (position < length) {
      final int unit = text.codeUnitAt(position);
      if (unit == _space || unit == _tab) {
        position += 1;
      } else if (unit == _lineFeed && !sawLineBreak) {
        sawLineBreak = true;
        position += 1;
      } else {
        break;
      }
    }
    return position;
  }

  static _Destination? _destination(String text, int start) {
    final int length = text.length;
    if (start < length && text.codeUnitAt(start) == _lessThan) {
      int position = start + 1;
      while (position < length) {
        final int unit = text.codeUnitAt(position);
        if (unit == _greaterThan) {
          return _Destination(MdRange(start + 1, position), position + 1);
        }
        if (unit == _lineFeed || unit == _lessThan) {
          return null;
        }
        position += _isEscape(text, position) ? 2 : 1;
      }
      return null;
    }
    int position = start;
    int depth = 0;
    while (position < length) {
      final int unit = text.codeUnitAt(position);
      if (_isEscape(text, position)) {
        position += 2;
      } else if (unit == _openParen) {
        depth += 1;
        if (depth > _maxParenDepth) {
          return null;
        }
        position += 1;
      } else if (unit == _closeParen) {
        if (depth == 0) {
          break;
        }
        depth -= 1;
        position += 1;
      } else if (unit == _space || _isAsciiControl(unit)) {
        break;
      } else {
        position += 1;
      }
    }
    if (depth != 0) {
      return null;
    }
    if (position == start &&
        (position >= length || text.codeUnitAt(position) != _closeParen)) {
      return null;
    }
    return _Destination(MdRange(start, position), position);
  }

  static _Title? _title(String text, int start) {
    final int length = text.length;
    if (start >= length) {
      return null;
    }
    final int opener = text.codeUnitAt(start);
    final int closer = switch (opener) {
      _doubleQuote => _doubleQuote,
      _singleQuote => _singleQuote,
      _openParen => _closeParen,
      _ => -1,
    };
    if (closer < 0) {
      return null;
    }
    int position = start + 1;
    while (position < length) {
      final int unit = text.codeUnitAt(position);
      if (unit == closer) {
        return _Title(MdRange(start + 1, position), position + 1);
      }
      if (unit == 0 || (opener == _openParen && unit == _openParen)) {
        return null;
      }
      position += _isEscape(text, position) ? 2 : 1;
    }
    return null;
  }

  static String _unescape(String text, int start, int end) {
    final StringBuffer buffer = StringBuffer();
    int position = start;
    while (position < end) {
      if (position + 1 < end && _isEscape(text, position)) {
        buffer.writeCharCode(text.codeUnitAt(position + 1));
        position += 2;
      } else {
        buffer.writeCharCode(text.codeUnitAt(position));
        position += 1;
      }
    }
    return buffer.toString();
  }

  static bool _isEscape(String text, int position) =>
      text.codeUnitAt(position) == _backslash &&
      position + 1 < text.length &&
      _isAsciiPunctuation(text.codeUnitAt(position + 1));

  static bool _isAsciiLetter(int unit) =>
      (unit >= 0x41 && unit <= 0x5A) || (unit >= 0x61 && unit <= 0x7A);

  static bool _isSchemeUnit(int unit) =>
      _isAsciiLetter(unit) ||
      (unit >= 0x30 && unit <= 0x39) ||
      unit == 0x2B ||
      unit == 0x2E ||
      unit == 0x2D;

  static bool _isAsciiControl(int unit) => unit < 0x20 || unit == 0x7F;

  static bool _isAsciiPunctuation(int unit) =>
      (unit >= 0x21 && unit <= 0x2F) ||
      (unit >= 0x3A && unit <= 0x40) ||
      (unit >= 0x5B && unit <= 0x60) ||
      (unit >= 0x7B && unit <= 0x7E);

  static final RegExp _email = RegExp(
    r"[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*>",
  );

  static const int _maxParenDepth = 32;
  static const int _tab = 0x09;
  static const int _lineFeed = 0x0A;
  static const int _space = 0x20;
  static const int _doubleQuote = 0x22;
  static const int _singleQuote = 0x27;
  static const int _openParen = 0x28;
  static const int _closeParen = 0x29;
  static const int _colon = 0x3A;
  static const int _lessThan = 0x3C;
  static const int _greaterThan = 0x3E;
  static const int _backslash = 0x5C;
}

final class _Destination {
  const _Destination(this.range, this.end);

  final MdRange range;
  final int end;
}

final class _Title {
  const _Title(this.range, this.end);

  final MdRange range;
  final int end;
}
