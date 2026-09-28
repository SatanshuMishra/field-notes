import 'inline/delimiters.dart';
import 'inline/links.dart';
import 'syntax_tree.dart';

final class MdInlineParser {
  const MdInlineParser();

  List<MdInline> parse(String source, List<MdRange> segments) {
    final _LogicalText logical = _LogicalText.build(source, segments);
    if (logical.text.isEmpty) {
      return const <MdInline>[];
    }
    return _Scanner(logical).scan();
  }
}

final class _LogicalText {
  const _LogicalText({
    required this.text,
    required this.starts,
    required this.ends,
    required this.end,
    required this.breaks,
  });

  factory _LogicalText.build(String source, List<MdRange> segments) {
    final List<int> units = <int>[];
    final List<int> starts = <int>[];
    final List<int> ends = <int>[];
    int? previousEnd;
    for (final MdRange segment in segments) {
      if (segment.start < 0 ||
          segment.end < segment.start ||
          segment.end > source.length) {
        throw ArgumentError.value(
          segment,
          'segments',
          'a segment lies outside the source',
        );
      }
      final int? gapStart = previousEnd;
      if (gapStart != null) {
        if (segment.start < gapStart) {
          throw ArgumentError.value(
            segment,
            'segments',
            'segments overlap or are out of order',
          );
        }
        final int breakLength = _lineBreakLength(
          source,
          gapStart,
          segment.start,
        );
        for (int i = gapStart + breakLength; i < segment.start; i++) {
          if (source.codeUnitAt(i) == _lineFeed) {
            throw ArgumentError.value(
              segment,
              'segments',
              'a gap holds a line feed that is not its one leading line break',
            );
          }
        }
        if (breakLength > 0) {
          units.add(_lineFeed);
          starts.add(gapStart);
          ends.add(gapStart + breakLength);
        }
      }
      for (int i = segment.start; i < segment.end; i++) {
        units.add(source.codeUnitAt(i));
        starts.add(i);
        ends.add(i + 1);
      }
      previousEnd = segment.end;
    }
    final List<int> breaks = <int>[
      for (int p = 1; p < starts.length; p++)
        if (starts[p] != ends[p - 1]) p,
    ];
    return _LogicalText(
      text: String.fromCharCodes(units),
      starts: List<int>.unmodifiable(starts),
      ends: List<int>.unmodifiable(ends),
      end: previousEnd ?? 0,
      breaks: List<int>.unmodifiable(breaks),
    );
  }

  final String text;
  final List<int> starts;
  final List<int> ends;
  final int end;
  final List<int> breaks;

  MdRange map(int start, int end) {
    final int sourceStart = start < starts.length ? starts[start] : this.end;
    if (end <= start) {
      return MdRange(sourceStart, sourceStart);
    }
    return MdRange(sourceStart, ends[end - 1]);
  }

  List<MdInline> textNodes(int start, int end) {
    final List<MdInline> nodes = <MdInline>[];
    int low = 0;
    int high = breaks.length;
    while (low < high) {
      final int middle = (low + high) >> 1;
      if (breaks[middle] <= start) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    int pieceStart = start;
    for (int i = low; i < breaks.length && breaks[i] < end; i++) {
      nodes.add(_text(pieceStart, breaks[i]));
      pieceStart = breaks[i];
    }
    nodes.add(_text(pieceStart, end));
    return nodes;
  }

  MdInline _text(int start, int end) {
    final MdRange range = map(start, end);
    return MdInline(
      kind: MdInlineKind.text,
      sourceRange: range,
      contentRange: range,
    );
  }

  static int _lineBreakLength(String source, int start, int end) {
    if (start < end && source.codeUnitAt(start) == _lineFeed) {
      return 1;
    }
    if (start + 1 < end &&
        source.codeUnitAt(start) == _carriageReturn &&
        source.codeUnitAt(start + 1) == _lineFeed) {
      return 2;
    }
    return 0;
  }
}

sealed class _Item {
  const _Item();
}

final class _TextItem extends _Item {
  const _TextItem(this.start, this.end);

  final int start;
  final int end;
}

final class _NodeItem extends _Item {
  const _NodeItem(this.node);

  final MdInline node;
}

final class _DelimiterItem extends _Item {
  const _DelimiterItem(this.run);

  final MdDelimiterRun run;
}

final class _Bracket {
  const _Bracket({required this.itemIndex, required this.position});

  final int itemIndex;
  final int position;
}

final class _UsedDelimiter {
  const _UsedDelimiter({
    required this.range,
    required this.match,
    required this.isOpener,
  });

  final MdRange range;
  final int match;
  final bool isOpener;
}

final class _Frame {
  _Frame(this.match);

  final int match;
  final List<_Item> items = <_Item>[];
}

final class _Scanner {
  _Scanner(this.logical)
    : text = logical.text,
      _backtickRuns = _collectBacktickRuns(logical.text);

  final _LogicalText logical;
  final String text;
  final Map<int, List<int>> _backtickRuns;
  final Map<int, int> _backtickCursors = <int, int>{};
  final List<_Item> _items = <_Item>[];
  final List<_Bracket> _brackets = <_Bracket>[];
  int _activeBrackets = 0;

  List<MdInline> scan() {
    final int length = text.length;
    int position = 0;
    while (position < length) {
      position = switch (text.codeUnitAt(position)) {
        _backslash => _backslashAt(position),
        _backtick => _backticksAt(position),
        _lineFeed => _lineBreakAt(position),
        _lessThan => _lessThanAt(position),
        _openBracket => _openBracketAt(position),
        _closeBracket => _closeBracketAt(position),
        _asterisk ||
        _underscore ||
        _tilde ||
        _equals => _delimitersAt(position),
        _ => _textAt(position),
      };
    }
    return List<MdInline>.unmodifiable(_resolve(_items));
  }

  int _textAt(int position) {
    int end = position + 1;
    while (end < text.length && !_isSpecial(text.codeUnitAt(end))) {
      end += 1;
    }
    return _literal(position, end);
  }

  int _literal(int start, int end) {
    _items.add(_TextItem(start, end));
    return end;
  }

  int _node(
    MdInlineKind kind,
    int start,
    int end,
    int contentStart,
    int contentEnd,
    List<MdRange> markers, {
    List<MdInline> children = const <MdInline>[],
    MdInlineData? data,
  }) {
    _items.add(
      _NodeItem(
        MdInline(
          kind: kind,
          sourceRange: logical.map(start, end),
          contentRange: logical.map(contentStart, contentEnd),
          markerRanges: <MdRange>[
            for (final MdRange marker in markers)
              logical.map(marker.start, marker.end),
          ],
          children: children,
          data: data,
        ),
      ),
    );
    return end;
  }

  int _backslashAt(int position) {
    if (position + 1 >= text.length) {
      return _literal(position, position + 1);
    }
    final int following = text.codeUnitAt(position + 1);
    if (following == _lineFeed) {
      return _node(
        MdInlineKind.hardBreak,
        position,
        position + 2,
        position + 1,
        position + 2,
        <MdRange>[MdRange(position, position + 1)],
      );
    }
    if (_isAsciiPunctuation(following)) {
      return _node(
        MdInlineKind.escape,
        position,
        position + 2,
        position + 1,
        position + 2,
        <MdRange>[MdRange(position, position + 1)],
      );
    }
    return _literal(position, position + 1);
  }

  int _backticksAt(int position) {
    int openerEnd = position + 1;
    while (openerEnd < text.length && text.codeUnitAt(openerEnd) == _backtick) {
      openerEnd += 1;
    }
    final int width = openerEnd - position;
    final int? closer = _closingRun(width, openerEnd);
    if (closer == null) {
      return _literal(position, openerEnd);
    }
    final int strip = _stripsSpaces(openerEnd, closer) ? 1 : 0;
    return _node(
      MdInlineKind.codeSpan,
      position,
      closer + width,
      openerEnd + strip,
      closer - strip,
      <MdRange>[
        MdRange(position, openerEnd + strip),
        MdRange(closer - strip, closer + width),
      ],
    );
  }

  int? _closingRun(int width, int from) {
    final List<int>? runs = _backtickRuns[width];
    if (runs == null) {
      return null;
    }
    int cursor = _backtickCursors[width] ?? 0;
    while (cursor < runs.length && runs[cursor] < from) {
      cursor += 1;
    }
    _backtickCursors[width] = cursor;
    return cursor < runs.length ? runs[cursor] : null;
  }

  bool _stripsSpaces(int start, int end) {
    if (end - start < 2 ||
        text.codeUnitAt(start) != _space ||
        text.codeUnitAt(end - 1) != _space) {
      return false;
    }
    for (int i = start; i < end; i++) {
      final int unit = text.codeUnitAt(i);
      if (unit != _space && unit != _lineFeed) {
        return true;
      }
    }
    return false;
  }

  int _lineBreakAt(int position) {
    int markerStart = position;
    bool isHard = false;
    final _Item? last = _items.isEmpty ? null : _items.last;
    if (last is _TextItem && last.end == position) {
      int spacesStart = position;
      while (spacesStart > last.start &&
          text.codeUnitAt(spacesStart - 1) == _space) {
        spacesStart -= 1;
      }
      if (position - spacesStart >= 2) {
        isHard = true;
        markerStart = spacesStart;
      } else {
        while (markerStart > last.start &&
            _isSpaceOrTab(text.codeUnitAt(markerStart - 1))) {
          markerStart -= 1;
        }
      }
      if (markerStart < position) {
        _items.removeLast();
        if (markerStart > last.start) {
          _items.add(_TextItem(last.start, markerStart));
        }
      }
    }
    return _node(
      isHard ? MdInlineKind.hardBreak : MdInlineKind.softBreak,
      markerStart,
      position + 1,
      position,
      position + 1,
      <MdRange>[if (markerStart < position) MdRange(markerStart, position)],
    );
  }

  int _lessThanAt(int position) {
    final MdAutolinkScan? scan = MdLinks.autolink(text, position);
    if (scan == null) {
      return _literal(position, position + 1);
    }
    return _node(
      MdInlineKind.autolink,
      position,
      scan.end,
      position + 1,
      scan.end - 1,
      <MdRange>[
        MdRange(position, position + 1),
        MdRange(scan.end - 1, scan.end),
      ],
      data: MdAutolinkData(
        kind: scan.kind,
        target: text.substring(position + 1, scan.end - 1),
      ),
    );
  }

  int _openBracketAt(int position) {
    _items.add(_TextItem(position, position + 1));
    _brackets.add(_Bracket(itemIndex: _items.length - 1, position: position));
    return position + 1;
  }

  int _closeBracketAt(int position) {
    if (_brackets.isEmpty) {
      return _literal(position, position + 1);
    }
    final bool isActive = _brackets.length - 1 >= _activeBrackets;
    final _Bracket opener = _brackets.removeLast();
    if (_activeBrackets > _brackets.length) {
      _activeBrackets = _brackets.length;
    }
    final MdLinkTailScan? tail = isActive
        ? MdLinks.linkTail(text, position + 1)
        : null;
    if (tail == null) {
      return _literal(position, position + 1);
    }
    final List<MdInline> children = _resolve(
      _items.sublist(opener.itemIndex + 1),
    );
    _items.removeRange(opener.itemIndex, _items.length);
    _activeBrackets = _brackets.length;
    final MdRange? titleRange = tail.titleRange;
    return _node(
      MdInlineKind.link,
      opener.position,
      tail.end,
      opener.position + 1,
      position,
      <MdRange>[
        MdRange(opener.position, opener.position + 1),
        MdRange(position, tail.end),
      ],
      children: children,
      data: MdLinkData(
        destination: tail.destination,
        destinationRange: logical.map(
          tail.destinationRange.start,
          tail.destinationRange.end,
        ),
        title: tail.title,
        titleRange: titleRange == null
            ? null
            : logical.map(titleRange.start, titleRange.end),
      ),
    );
  }

  int _delimitersAt(int position) {
    final MdDelimiterRun run = MdDelimiters.runAt(text, position);
    if (!run.canOpen && !run.canClose) {
      return _literal(position, run.end);
    }
    _items.add(_DelimiterItem(run));
    return run.end;
  }

  List<MdInline> _resolve(List<_Item> items) {
    final List<MdDelimiterRun> runs = <MdDelimiterRun>[
      for (final _Item item in items)
        if (item is _DelimiterItem) item.run,
    ];
    if (runs.isEmpty) {
      return _finish(items);
    }
    final List<MdDelimiterMatch> matches = MdDelimiters.resolve(runs);
    final Map<int, List<_UsedDelimiter>> used = <int, List<_UsedDelimiter>>{};
    for (int m = 0; m < matches.length; m++) {
      final MdDelimiterMatch match = matches[m];
      used
          .putIfAbsent(_runContaining(runs, match.opener.start), () {
            return <_UsedDelimiter>[];
          })
          .add(_UsedDelimiter(range: match.opener, match: m, isOpener: true));
      used
          .putIfAbsent(_runContaining(runs, match.closer.start), () {
            return <_UsedDelimiter>[];
          })
          .add(_UsedDelimiter(range: match.closer, match: m, isOpener: false));
    }
    final List<_Frame> frames = <_Frame>[_Frame(-1)];
    for (final _Item item in items) {
      if (item is! _DelimiterItem) {
        frames.last.items.add(item);
        continue;
      }
      final MdDelimiterRun run = item.run;
      final List<_UsedDelimiter> parts = <_UsedDelimiter>[...?used[run.start]]
        ..sort(
          (_UsedDelimiter a, _UsedDelimiter b) =>
              a.range.start.compareTo(b.range.start),
        );
      int cursor = run.start;
      for (final _UsedDelimiter part in parts) {
        if (part.range.start > cursor) {
          frames.last.items.add(_TextItem(cursor, part.range.start));
        }
        if (part.isOpener) {
          frames.add(_Frame(part.match));
        } else {
          final _Frame frame = frames.removeLast();
          if (frame.match != part.match) {
            throw StateError('delimiter matches must nest');
          }
          final MdDelimiterMatch match = matches[part.match];
          frames.last.items.add(
            _NodeItem(
              MdInline(
                kind: match.kind,
                sourceRange: logical.map(match.opener.start, match.closer.end),
                contentRange: logical.map(match.opener.end, match.closer.start),
                markerRanges: <MdRange>[
                  logical.map(match.opener.start, match.opener.end),
                  logical.map(match.closer.start, match.closer.end),
                ],
                children: _finish(frame.items),
              ),
            ),
          );
        }
        cursor = part.range.end;
      }
      if (cursor < run.end) {
        frames.last.items.add(_TextItem(cursor, run.end));
      }
    }
    if (frames.length != 1) {
      throw StateError('every delimiter opener must close');
    }
    return _finish(frames.single.items);
  }

  List<MdInline> _finish(List<_Item> items) {
    final List<MdInline> nodes = <MdInline>[];
    int? textStart;
    int textEnd = 0;
    for (final _Item item in items) {
      if (item is _TextItem) {
        if (textStart != null && textEnd == item.start) {
          textEnd = item.end;
          continue;
        }
        if (textStart != null) {
          nodes.addAll(logical.textNodes(textStart, textEnd));
        }
        textStart = item.start;
        textEnd = item.end;
        continue;
      }
      if (textStart != null) {
        nodes.addAll(logical.textNodes(textStart, textEnd));
        textStart = null;
      }
      switch (item) {
        case _NodeItem(:final MdInline node):
          nodes.add(node);
        case _DelimiterItem(:final MdDelimiterRun run):
          nodes.addAll(logical.textNodes(run.start, run.end));
        case _TextItem():
          break;
      }
    }
    if (textStart != null) {
      nodes.addAll(logical.textNodes(textStart, textEnd));
    }
    return nodes;
  }

  static int _runContaining(List<MdDelimiterRun> runs, int position) {
    int low = 0;
    int high = runs.length - 1;
    while (low < high) {
      final int middle = (low + high + 1) >> 1;
      if (runs[middle].start <= position) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return runs[low].start;
  }

  static Map<int, List<int>> _collectBacktickRuns(String text) {
    final Map<int, List<int>> runs = <int, List<int>>{};
    int position = 0;
    while (position < text.length) {
      if (text.codeUnitAt(position) != _backtick) {
        position += 1;
        continue;
      }
      int end = position + 1;
      while (end < text.length && text.codeUnitAt(end) == _backtick) {
        end += 1;
      }
      runs.putIfAbsent(end - position, () => <int>[]).add(position);
      position = end;
    }
    return runs;
  }

  static bool _isSpecial(int unit) =>
      unit == _backslash ||
      unit == _backtick ||
      unit == _lineFeed ||
      unit == _lessThan ||
      unit == _openBracket ||
      unit == _closeBracket ||
      unit == _asterisk ||
      unit == _underscore ||
      unit == _tilde ||
      unit == _equals;

  static bool _isSpaceOrTab(int unit) => unit == _space || unit == _tab;

  static bool _isAsciiPunctuation(int unit) =>
      (unit >= 0x21 && unit <= 0x2F) ||
      (unit >= 0x3A && unit <= 0x40) ||
      (unit >= 0x5B && unit <= 0x60) ||
      (unit >= 0x7B && unit <= 0x7E);
}

const int _tab = 0x09;
const int _lineFeed = 0x0A;
const int _carriageReturn = 0x0D;
const int _space = 0x20;
const int _asterisk = 0x2A;
const int _lessThan = 0x3C;
const int _equals = 0x3D;
const int _openBracket = 0x5B;
const int _backslash = 0x5C;
const int _closeBracket = 0x5D;
const int _underscore = 0x5F;
const int _backtick = 0x60;
const int _tilde = 0x7E;
