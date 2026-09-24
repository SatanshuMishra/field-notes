import '../syntax_tree.dart';

final class MdDelimiterRun {
  const MdDelimiterRun({
    required this.character,
    required this.start,
    required this.end,
    required this.canOpen,
    required this.canClose,
  });

  final int character;
  final int start;
  final int end;
  final bool canOpen;
  final bool canClose;

  int get length => end - start;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdDelimiterRun &&
          character == other.character &&
          start == other.start &&
          end == other.end &&
          canOpen == other.canOpen &&
          canClose == other.canClose;

  @override
  int get hashCode => Object.hash(character, start, end, canOpen, canClose);

  @override
  String toString() =>
      "MdDelimiterRun('${String.fromCharCode(character)}' $start-$end, "
      'canOpen: $canOpen, canClose: $canClose)';
}

final class MdDelimiterMatch {
  const MdDelimiterMatch({
    required this.kind,
    required this.opener,
    required this.closer,
  });

  final MdInlineKind kind;
  final MdRange opener;
  final MdRange closer;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdDelimiterMatch &&
          kind == other.kind &&
          opener == other.opener &&
          closer == other.closer;

  @override
  int get hashCode => Object.hash(kind, opener, closer);

  @override
  String toString() => 'MdDelimiterMatch(${kind.name}, $opener, $closer)';
}

abstract final class MdDelimiters {
  static MdDelimiterRun runAt(String text, int start) {
    final int character = text.codeUnitAt(start);
    if (!_isDelimiterCharacter(character)) {
      throw ArgumentError.value(start, 'start', 'not at a delimiter character');
    }
    int end = start + 1;
    while (end < text.length && text.codeUnitAt(end) == character) {
      end += 1;
    }
    final bool isExact = end - start == 2;
    if ((character == _tilde || character == _equals) && !isExact) {
      return MdDelimiterRun(
        character: character,
        start: start,
        end: end,
        canOpen: false,
        canClose: false,
      );
    }
    final int? before = _codePointBefore(text, start);
    final int? after = _codePointAt(text, end);
    final bool beforeIsSpace = before == null || _isWhitespace(before);
    final bool afterIsSpace = after == null || _isWhitespace(after);
    final bool beforeIsPunctuation = before != null && _isPunctuation(before);
    final bool afterIsPunctuation = after != null && _isPunctuation(after);
    final bool leftFlanking =
        !afterIsSpace &&
        (!afterIsPunctuation || beforeIsSpace || beforeIsPunctuation);
    final bool rightFlanking =
        !beforeIsSpace &&
        (!beforeIsPunctuation || afterIsSpace || afterIsPunctuation);
    final bool canOpen = character == _underscore
        ? leftFlanking && (!rightFlanking || beforeIsPunctuation)
        : leftFlanking;
    final bool canClose = character == _underscore
        ? rightFlanking && (!leftFlanking || afterIsPunctuation)
        : rightFlanking;
    return MdDelimiterRun(
      character: character,
      start: start,
      end: end,
      canOpen: canOpen,
      canClose: canClose,
    );
  }

  static List<MdDelimiterMatch> resolve(List<MdDelimiterRun> runs) {
    final int count = runs.length;
    final List<int> remaining = <int>[
      for (final MdDelimiterRun run in runs) run.length,
    ];
    final List<int> usedAtFront = List<int>.filled(count, 0);
    final List<int> usedAtBack = List<int>.filled(count, 0);
    final List<int> previous = <int>[for (int i = 0; i < count; i++) i - 1];
    final List<int> next = <int>[
      for (int i = 0; i < count; i++) i + 1 < count ? i + 1 : -1,
    ];
    final Map<int, int> openersBottom = <int, int>{};
    final List<MdDelimiterMatch> matches = <MdDelimiterMatch>[];

    void remove(int index) {
      final int before = previous[index];
      final int after = next[index];
      if (before >= 0) {
        next[before] = after;
      }
      if (after >= 0) {
        previous[after] = before;
      }
    }

    int closer = count > 0 ? 0 : -1;
    while (closer >= 0) {
      final MdDelimiterRun closerRun = runs[closer];
      if (!closerRun.canClose) {
        closer = next[closer];
        continue;
      }
      final int key = _bottomKey(closerRun);
      final int bottom = openersBottom[key] ?? -1;
      int opener = previous[closer];
      bool found = false;
      while (opener > bottom) {
        final MdDelimiterRun openerRun = runs[opener];
        if (openerRun.character == closerRun.character &&
            openerRun.canOpen &&
            !_isOddMatch(openerRun, closerRun)) {
          found = true;
          break;
        }
        opener = previous[opener];
      }
      if (!found) {
        openersBottom[key] = previous[closer];
        final int following = next[closer];
        if (!closerRun.canOpen) {
          remove(closer);
        }
        closer = following;
        continue;
      }
      final MdDelimiterRun openerRun = runs[opener];
      final bool isEmphasisCharacter =
          closerRun.character == _asterisk ||
          closerRun.character == _underscore;
      final int used = !isEmphasisCharacter
          ? 2
          : remaining[opener] >= 2 && remaining[closer] >= 2
          ? 2
          : 1;
      final int openerEnd = openerRun.end - usedAtBack[opener];
      final int closerStart = closerRun.start + usedAtFront[closer];
      remaining[opener] = remaining[opener] - used;
      remaining[closer] = remaining[closer] - used;
      usedAtBack[opener] = usedAtBack[opener] + used;
      usedAtFront[closer] = usedAtFront[closer] + used;
      matches.add(
        MdDelimiterMatch(
          kind: _kindFor(closerRun.character, used),
          opener: MdRange(openerEnd - used, openerEnd),
          closer: MdRange(closerStart, closerStart + used),
        ),
      );
      int between = next[opener];
      while (between >= 0 && between != closer) {
        final int following = next[between];
        remove(between);
        between = following;
      }
      if (remaining[opener] == 0) {
        remove(opener);
      }
      if (remaining[closer] == 0) {
        final int following = next[closer];
        remove(closer);
        closer = following;
      }
    }
    return List<MdDelimiterMatch>.unmodifiable(matches);
  }

  static bool _isOddMatch(MdDelimiterRun opener, MdDelimiterRun closer) {
    if (closer.character != _asterisk && closer.character != _underscore) {
      return false;
    }
    return (closer.canOpen || opener.canClose) &&
        closer.length % 3 != 0 &&
        (opener.length + closer.length) % 3 == 0;
  }

  static int _bottomKey(MdDelimiterRun closer) {
    if (closer.character != _asterisk && closer.character != _underscore) {
      return closer.character * 8;
    }
    return closer.character * 8 + (closer.canOpen ? 3 : 0) + closer.length % 3;
  }

  static MdInlineKind _kindFor(int character, int used) => switch (character) {
    _tilde => MdInlineKind.strikethrough,
    _equals => MdInlineKind.highlight,
    _ => used == 2 ? MdInlineKind.strong : MdInlineKind.emphasis,
  };

  static bool _isDelimiterCharacter(int unit) =>
      unit == _asterisk ||
      unit == _underscore ||
      unit == _tilde ||
      unit == _equals;

  static int? _codePointBefore(String text, int offset) {
    if (offset <= 0) {
      return null;
    }
    final int low = text.codeUnitAt(offset - 1);
    if (_isLowSurrogate(low) && offset >= 2) {
      final int high = text.codeUnitAt(offset - 2);
      if (_isHighSurrogate(high)) {
        return _join(high, low);
      }
    }
    return low;
  }

  static int? _codePointAt(String text, int offset) {
    if (offset >= text.length) {
      return null;
    }
    final int high = text.codeUnitAt(offset);
    if (_isHighSurrogate(high) && offset + 1 < text.length) {
      final int low = text.codeUnitAt(offset + 1);
      if (_isLowSurrogate(low)) {
        return _join(high, low);
      }
    }
    return high;
  }

  static bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

  static bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

  static int _join(int high, int low) =>
      0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00);

  static bool _isWhitespace(int codePoint) =>
      codePoint == 0x09 ||
      codePoint == 0x0A ||
      codePoint == 0x0C ||
      codePoint == 0x0D ||
      codePoint == 0x20 ||
      codePoint == 0xA0 ||
      codePoint == 0x1680 ||
      (codePoint >= 0x2000 && codePoint <= 0x200A) ||
      codePoint == 0x202F ||
      codePoint == 0x205F ||
      codePoint == 0x3000;

  static bool _isPunctuation(int codePoint) {
    if (codePoint < 0x80) {
      return (codePoint >= 0x21 && codePoint <= 0x2F) ||
          (codePoint >= 0x3A && codePoint <= 0x40) ||
          (codePoint >= 0x5B && codePoint <= 0x60) ||
          (codePoint >= 0x7B && codePoint <= 0x7E);
    }
    return _punctuation.hasMatch(String.fromCharCode(codePoint));
  }

  static final RegExp _punctuation = RegExp(r'^[\p{P}\p{S}]$', unicode: true);

  static const int _asterisk = 0x2A;
  static const int _equals = 0x3D;
  static const int _underscore = 0x5F;
  static const int _tilde = 0x7E;
}
