import 'note_block.dart';

const int _memoCapacity = 16;

final Map<String, List<NoteBlock>> _memo = <String, List<NoteBlock>>{};

List<NoteBlock> parseNote(String source) {
  final List<NoteBlock>? memoized = _memo.remove(source);
  if (memoized != null) {
    _memo[source] = memoized;
    return memoized;
  }
  final List<NoteBlock> blocks =
      List<NoteBlock>.unmodifiable(_NoteParser(source).parse());
  if (_memo.length >= _memoCapacity) {
    _memo.remove(_memo.keys.first);
  }
  _memo[source] = blocks;
  return blocks;
}

final RegExp _headingPrefix = RegExp(r'^ {0,3}#{1,3}(?:[ \t]+|$)');
final RegExp _bulletPrefix = RegExp(r'^ {0,3}[-*+][ \t]+');
final RegExp _numberPrefix = RegExp(r'^ {0,3}(\d{1,9})[.)][ \t]+');
final RegExp _quotePrefix = RegExp(r'^ {0,3}>[ \t]?');
final RegExp _fenceOpen = RegExp(r'^ {0,3}(`{3,})[ \t]*([^`]*)$');
final RegExp _fenceClose = RegExp(r'^ {0,3}(`{3,})[ \t]*$');
final RegExp _dividerLine =
    RegExp(r'^ {0,3}(?:(?:-[ \t]*){3,}|(?:\*[ \t]*){3,}|(?:_[ \t]*){3,})$');
final RegExp _photoLine = RegExp(
  r'^[ \t]*!\[([^\]]*)\]\(photo/([0-9a-fA-F]+)(?:[ \t]+"([^"]*)")?\)[ \t]*$',
);

const int _newline = 0x0A;
const int _carriageReturn = 0x0D;
const int _space = 0x20;
const int _tab = 0x09;
const int _backtick = 0x60;
const int _asterisk = 0x2A;
const int _underscore = 0x5F;
const int _tilde = 0x7E;
const int _openBracket = 0x5B;
const int _closeBracket = 0x5D;
const int _openParen = 0x28;
const int _closeParen = 0x29;

enum _LineKind {
  blank,
  heading,
  bullet,
  number,
  quote,
  fenceOpen,
  divider,
  photo,
  text,
}

final class _Line {
  const _Line({
    required this.start,
    required this.contentEnd,
    required this.textEnd,
    required this.end,
  });

  final int start;
  final int contentEnd;
  final int textEnd;
  final int end;
}

final class _Classified {
  const _Classified(this.kind, this.match);

  final _LineKind kind;
  final RegExpMatch? match;
}

final class _Opener {
  const _Opener(this.codeUnit, this.start, this.end);

  final int codeUnit;
  final int start;
  final int end;
}

final class _NoteParser {
  _NoteParser(this.source) : lines = _splitLines(source);

  final String source;
  final List<_Line> lines;

  static List<_Line> _splitLines(String source) {
    final List<_Line> lines = <_Line>[];
    int start = 0;
    while (true) {
      final int newline = source.indexOf('\n', start);
      final int textEnd = newline == -1 ? source.length : newline;
      final int end = newline == -1 ? source.length : newline + 1;
      final bool endsWithReturn =
          textEnd > start && source.codeUnitAt(textEnd - 1) == _carriageReturn;
      lines.add(
        _Line(
          start: start,
          contentEnd: endsWithReturn ? textEnd - 1 : textEnd,
          textEnd: textEnd,
          end: end,
        ),
      );
      if (newline == -1) {
        return lines;
      }
      start = end;
    }
  }

  List<NoteBlock> parse() {
    final List<NoteBlock> blocks = <NoteBlock>[];
    int index = 0;
    while (index < lines.length && _isBlank(lines[index])) {
      index++;
    }
    if (index == lines.length) {
      if (source.isEmpty) {
        return blocks;
      }
      return <NoteBlock>[
        ParagraphBlock(
          inlines: const <InlineNode>[],
          sourceRange: SourceRange(0, source.length),
        ),
      ];
    }
    int blockStart = 0;
    while (index < lines.length) {
      final _Line line = lines[index];
      final _Classified classified = _classify(line);
      final (NoteBlock Function(SourceRange) build, int last) =
          switch (classified.kind) {
        _LineKind.heading => _heading(index, classified.match!),
        _LineKind.bullet => _bullet(index, classified.match!),
        _LineKind.number => _number(index, classified.match!),
        _LineKind.quote => _quote(index, classified.match!),
        _LineKind.fenceOpen => _code(index, classified.match!),
        _LineKind.divider => _divider(index),
        _LineKind.photo => _photo(index, classified.match!),
        _LineKind.text => _paragraph(index),
        _LineKind.blank => throw StateError('blank lines never open a block'),
      };
      int next = last + 1;
      while (next < lines.length && _isBlank(lines[next])) {
        next++;
      }
      final int blockEnd = lines[next - 1].end;
      blocks.add(build(SourceRange(blockStart, blockEnd)));
      blockStart = blockEnd;
      index = next;
    }
    return blocks;
  }

  bool _isBlank(_Line line) {
    for (int i = line.start; i < line.contentEnd; i++) {
      final int c = source.codeUnitAt(i);
      if (c != _space && c != _tab) {
        return false;
      }
    }
    return true;
  }

  String _textOf(_Line line) => source.substring(line.start, line.contentEnd);

  _Classified _classify(_Line line) {
    if (_isBlank(line)) {
      return const _Classified(_LineKind.blank, null);
    }
    final String text = _textOf(line);
    final RegExpMatch? divider = _dividerLine.firstMatch(text);
    if (divider != null) {
      return _Classified(_LineKind.divider, divider);
    }
    final RegExpMatch? fence = _fenceOpen.firstMatch(text);
    if (fence != null) {
      return _Classified(_LineKind.fenceOpen, fence);
    }
    final RegExpMatch? photo = _photoLine.firstMatch(text);
    if (photo != null) {
      return _Classified(_LineKind.photo, photo);
    }
    final RegExpMatch? heading = _headingPrefix.firstMatch(text);
    if (heading != null) {
      return _Classified(_LineKind.heading, heading);
    }
    final RegExpMatch? bullet = _bulletPrefix.firstMatch(text);
    if (bullet != null) {
      return _Classified(_LineKind.bullet, bullet);
    }
    final RegExpMatch? number = _numberPrefix.firstMatch(text);
    if (number != null) {
      return _Classified(_LineKind.number, number);
    }
    final RegExpMatch? quote = _quotePrefix.firstMatch(text);
    if (quote != null) {
      return _Classified(_LineKind.quote, quote);
    }
    return const _Classified(_LineKind.text, null);
  }

  (NoteBlock Function(SourceRange), int) _heading(int index, RegExpMatch match) {
    final _Line line = lines[index];
    final int markerEnd = line.start + match.end;
    final int level = match.group(0)!.trim().length;
    final List<InlineNode> inlines = _inlinesOf(<_Line>[line], <int>[markerEnd]);
    return (
      (SourceRange range) => HeadingBlock(
            level: level,
            inlines: inlines,
            sourceRange: range,
            markerRanges: <SourceRange>[SourceRange(line.start, markerEnd)],
          ),
      index,
    );
  }

  (NoteBlock Function(SourceRange), int) _bullet(int index, RegExpMatch match) {
    final _Line line = lines[index];
    final int markerEnd = line.start + match.end;
    final List<InlineNode> inlines = _inlinesOf(<_Line>[line], <int>[markerEnd]);
    return (
      (SourceRange range) => BulletBlock(
            inlines: inlines,
            sourceRange: range,
            markerRanges: <SourceRange>[SourceRange(line.start, markerEnd)],
          ),
      index,
    );
  }

  (NoteBlock Function(SourceRange), int) _number(int index, RegExpMatch match) {
    final _Line line = lines[index];
    final int markerEnd = line.start + match.end;
    final int ordinal = int.parse(match.group(1)!);
    final List<InlineNode> inlines = _inlinesOf(<_Line>[line], <int>[markerEnd]);
    return (
      (SourceRange range) => NumberBlock(
            ordinal: ordinal,
            inlines: inlines,
            sourceRange: range,
            markerRanges: <SourceRange>[SourceRange(line.start, markerEnd)],
          ),
      index,
    );
  }

  (NoteBlock Function(SourceRange), int) _quote(int index, RegExpMatch first) {
    final List<_Line> quoted = <_Line>[lines[index]];
    final List<int> contentStarts = <int>[lines[index].start + first.end];
    final List<SourceRange> markers = <SourceRange>[
      SourceRange(lines[index].start, contentStarts.first),
    ];
    int last = index;
    while (last + 1 < lines.length) {
      final _Line line = lines[last + 1];
      if (_isBlank(line)) {
        break;
      }
      final RegExpMatch? match = _quotePrefix.firstMatch(_textOf(line));
      if (match == null) {
        break;
      }
      last++;
      quoted.add(line);
      contentStarts.add(line.start + match.end);
      markers.add(SourceRange(line.start, line.start + match.end));
    }
    final List<InlineNode> inlines = _inlinesOf(quoted, contentStarts);
    return (
      (SourceRange range) => QuoteBlock(
            inlines: inlines,
            sourceRange: range,
            markerRanges: markers,
          ),
      last,
    );
  }

  (NoteBlock Function(SourceRange), int) _code(int index, RegExpMatch open) {
    final _Line opening = lines[index];
    final int fenceLength = open.group(1)!.length;
    final String language = open.group(2)!.trim();
    int? closeIndex;
    for (int k = index + 1; k < lines.length; k++) {
      final RegExpMatch? close = _fenceClose.firstMatch(_textOf(lines[k]));
      if (close != null && close.group(1)!.length >= fenceLength) {
        closeIndex = k;
        break;
      }
    }
    final int last = closeIndex ?? lines.length - 1;
    int contentLast = closeIndex == null ? last : closeIndex - 1;
    while (closeIndex == null &&
        contentLast > index &&
        _isBlank(lines[contentLast])) {
      contentLast--;
    }
    final SourceRange contentRange = contentLast >= index + 1
        ? SourceRange(lines[index + 1].start, lines[contentLast].contentEnd)
        : SourceRange(opening.end, opening.end);
    final List<SourceRange> markers = <SourceRange>[
      SourceRange(opening.start, opening.contentEnd),
      if (closeIndex != null)
        SourceRange(lines[closeIndex].start, lines[closeIndex].contentEnd),
    ];
    final String text = contentRange.sliceOf(source);
    return (
      (SourceRange range) => CodeBlock(
            text: text,
            language: language,
            contentRange: contentRange,
            sourceRange: range,
            markerRanges: markers,
          ),
      last,
    );
  }

  (NoteBlock Function(SourceRange), int) _divider(int index) {
    final _Line line = lines[index];
    return (
      (SourceRange range) => DividerBlock(
            sourceRange: range,
            markerRanges: <SourceRange>[
              SourceRange(line.start, line.contentEnd),
            ],
          ),
      index,
    );
  }

  (NoteBlock Function(SourceRange), int) _photo(int index, RegExpMatch match) {
    final _Line line = lines[index];
    final String text = _textOf(line);
    final String alt = match.group(1)!;
    final String reference = match.group(2)!;
    final String? attributes = match.group(3);
    final int tokenStart = line.start + text.indexOf('![');
    final int altStart = tokenStart + 2;
    final int altEnd = altStart + alt.length;
    final int referenceStart = altEnd + '](photo/'.length;
    final int referenceEnd = referenceStart + reference.length;
    SourceRange? attributesRange;
    if (attributes != null) {
      final int quote = source.indexOf('"', referenceEnd);
      attributesRange = SourceRange(quote + 1, quote + 1 + attributes.length);
    }
    final int tokenEnd =
        (attributesRange?.end ?? referenceEnd) + (attributes == null ? 1 : 2);
    return (
      (SourceRange range) => PhotoBlock(
            alt: alt,
            reference: reference,
            attributes: attributes ?? '',
            altRange: SourceRange(altStart, altEnd),
            referenceRange: SourceRange(referenceStart, referenceEnd),
            attributesRange: attributesRange,
            sourceRange: range,
            markerRanges: <SourceRange>[SourceRange(tokenStart, tokenEnd)],
          ),
      index,
    );
  }

  (NoteBlock Function(SourceRange), int) _paragraph(int index) {
    final List<_Line> body = <_Line>[lines[index]];
    int last = index;
    while (last + 1 < lines.length &&
        _classify(lines[last + 1]).kind == _LineKind.text) {
      last++;
      body.add(lines[last]);
    }
    final List<InlineNode> inlines = _inlinesOf(
      body,
      <int>[for (final _Line line in body) line.start],
    );
    return (
      (SourceRange range) =>
          ParagraphBlock(inlines: inlines, sourceRange: range),
      last,
    );
  }

  List<InlineNode> _inlinesOf(List<_Line> body, List<int> contentStarts) {
    final List<InlineNode> nodes = <InlineNode>[];
    for (int i = 0; i < body.length; i++) {
      final _Line line = body[i];
      nodes.addAll(
        _parseInline(contentStarts[i], line.contentEnd, allowLinks: true),
      );
      if (i < body.length - 1) {
        nodes.add(
          PlainNode(
            text: '\n',
            sourceRange: SourceRange(line.contentEnd, line.end),
          ),
        );
      }
    }
    return _mergePlain(nodes);
  }

  List<InlineNode> _parseInline(int start, int end, {required bool allowLinks}) {
    final List<Object> items = <Object>[];
    int textStart = start;
    int i = start;

    void flushText(int upTo) {
      if (upTo > textStart) {
        items.add(
          PlainNode(
            text: source.substring(textStart, upTo),
            sourceRange: SourceRange(textStart, upTo),
          ),
        );
      }
    }

    while (i < end) {
      final int c = source.codeUnitAt(i);
      if (c == _backtick) {
        final int close = _indexOf(_backtick, i + 1, end);
        if (close > i + 1) {
          flushText(i);
          items.add(
            CodeNode(
              text: source.substring(i + 1, close),
              sourceRange: SourceRange(i, close + 1),
              contentRange: SourceRange(i + 1, close),
            ),
          );
          i = close + 1;
          textStart = i;
          continue;
        }
        i++;
        continue;
      }
      if (c == _openBracket && allowLinks) {
        final LinkNode? link = _tryLink(i, end);
        if (link != null) {
          flushText(i);
          items.add(link);
          i = link.sourceRange.end;
          textStart = i;
          continue;
        }
        i++;
        continue;
      }
      if (c == _asterisk || c == _underscore || c == _tilde) {
        int runEnd = i + 1;
        while (runEnd < end && source.codeUnitAt(runEnd) == c) {
          runEnd++;
        }
        final InlineStyle? style = _styleFor(c, runEnd - i);
        if (style == null) {
          i = runEnd;
          continue;
        }
        if (_canClose(i, runEnd, c, start, end)) {
          final int openerIndex = _findOpener(items, c, runEnd - i);
          if (openerIndex != -1) {
            flushText(i);
            final _Opener opener = items[openerIndex] as _Opener;
            final List<InlineNode> children =
                _finish(items.sublist(openerIndex + 1));
            items.removeRange(openerIndex, items.length);
            items.add(
              StyledNode(
                style: style,
                children: children,
                sourceRange: SourceRange(opener.start, runEnd),
                contentRange: SourceRange(opener.end, i),
              ),
            );
            i = runEnd;
            textStart = i;
            continue;
          }
        }
        if (_canOpen(i, runEnd, c, start, end)) {
          flushText(i);
          items.add(_Opener(c, i, runEnd));
          i = runEnd;
          textStart = i;
          continue;
        }
        i = runEnd;
        continue;
      }
      i++;
    }
    flushText(end);
    return _finish(items);
  }

  LinkNode? _tryLink(int open, int end) {
    final int close = _indexOf(_closeBracket, open + 1, end);
    if (close <= open + 1) {
      return null;
    }
    final int nested = _indexOf(_openBracket, open + 1, close);
    if (nested != -1) {
      return null;
    }
    if (close + 1 >= end || source.codeUnitAt(close + 1) != _openParen) {
      return null;
    }
    final int urlStart = close + 2;
    final int urlEnd = _indexOf(_closeParen, urlStart, end);
    if (urlEnd <= urlStart) {
      return null;
    }
    for (int k = urlStart; k < urlEnd; k++) {
      final int c = source.codeUnitAt(k);
      if (c == _space || c == _tab || c == _openParen) {
        return null;
      }
    }
    return LinkNode(
      children: _parseInline(open + 1, close, allowLinks: false),
      url: source.substring(urlStart, urlEnd),
      sourceRange: SourceRange(open, urlEnd + 1),
      contentRange: SourceRange(open + 1, close),
      urlRange: SourceRange(urlStart, urlEnd),
    );
  }

  int _indexOf(int codeUnit, int from, int end) {
    for (int k = from; k < end; k++) {
      if (source.codeUnitAt(k) == codeUnit) {
        return k;
      }
    }
    return -1;
  }

  static InlineStyle? _styleFor(int codeUnit, int runLength) {
    if (codeUnit == _tilde) {
      return runLength == 2 ? InlineStyle.strike : null;
    }
    return switch (runLength) {
      1 => InlineStyle.italic,
      2 => InlineStyle.bold,
      _ => null,
    };
  }

  bool _canOpen(int runStart, int runEnd, int codeUnit, int start, int end) {
    if (runEnd >= end || _isWhitespace(source.codeUnitAt(runEnd))) {
      return false;
    }
    if (codeUnit == _underscore && runStart > start) {
      return !_isAlphanumeric(source.codeUnitAt(runStart - 1));
    }
    return true;
  }

  bool _canClose(int runStart, int runEnd, int codeUnit, int start, int end) {
    if (runStart <= start || _isWhitespace(source.codeUnitAt(runStart - 1))) {
      return false;
    }
    if (codeUnit == _underscore && runEnd < end) {
      return !_isAlphanumeric(source.codeUnitAt(runEnd));
    }
    return true;
  }

  static int _findOpener(List<Object> items, int codeUnit, int runLength) {
    for (int k = items.length - 1; k >= 0; k--) {
      final Object item = items[k];
      if (item is _Opener &&
          item.codeUnit == codeUnit &&
          item.end - item.start == runLength) {
        return k;
      }
    }
    return -1;
  }

  List<InlineNode> _finish(List<Object> items) {
    return _mergePlain(<InlineNode>[
      for (final Object item in items)
        if (item is _Opener)
          PlainNode(
            text: source.substring(item.start, item.end),
            sourceRange: SourceRange(item.start, item.end),
          )
        else
          item as InlineNode,
    ]);
  }

  static List<InlineNode> _mergePlain(List<InlineNode> nodes) {
    final List<InlineNode> merged = <InlineNode>[];
    for (final InlineNode node in nodes) {
      final InlineNode? last = merged.isEmpty ? null : merged.last;
      if (node is PlainNode &&
          last is PlainNode &&
          last.sourceRange.end == node.sourceRange.start) {
        merged[merged.length - 1] = PlainNode(
          text: last.text + node.text,
          sourceRange: SourceRange(last.sourceRange.start, node.sourceRange.end),
        );
      } else {
        merged.add(node);
      }
    }
    return List<InlineNode>.unmodifiable(merged);
  }

  static bool _isWhitespace(int c) =>
      c == _space || c == _tab || c == _newline || c == _carriageReturn;

  static bool _isAlphanumeric(int c) =>
      (c >= 0x30 && c <= 0x39) ||
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x61 && c <= 0x7A);
}
