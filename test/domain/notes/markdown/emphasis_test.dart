import 'dart:math';

import 'package:field_notes/domain/notes/markdown/inline/delimiters.dart';
import 'package:field_notes/domain/notes/markdown/inline_parser.dart';
import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';
import 'package:flutter_test/flutter_test.dart';

const MdInlineParser _parser = MdInlineParser();

List<MdInline> _parse(String source, [List<MdRange>? segments]) =>
    _parser.parse(source, segments ?? <MdRange>[MdRange(0, source.length)]);

String _range(MdRange range) => '(${range.start}, ${range.end})';

String _show(MdInline node) {
  final String markers = node.markerRanges.map(_range).join(', ');
  final String children = node.children.isEmpty
      ? ''
      : ' {${node.children.map(_show).join(', ')}}';
  return '${node.kind.name}${_range(node.sourceRange)} '
      'content${_range(node.contentRange)} markers[$markers]$children';
}

List<String> _shown(List<MdInline> nodes) => nodes.map(_show).toList();

void _expectNodes(List<MdInline> actual, List<MdInline> expected) {
  expect(_shown(actual), _shown(expected));
}

List<MdInlineKind> _kinds(List<MdInline> nodes) =>
    nodes.map((MdInline n) => n.kind).toList();

MdInline _text(int start, int end) => MdInline(
  kind: MdInlineKind.text,
  sourceRange: MdRange(start, end),
  contentRange: MdRange(start, end),
);

MdInline _wrap(
  MdInlineKind kind,
  int start,
  int end,
  int width, [
  List<MdInline>? children,
]) => MdInline(
  kind: kind,
  sourceRange: MdRange(start, end),
  contentRange: MdRange(start + width, end - width),
  markerRanges: <MdRange>[
    MdRange(start, start + width),
    MdRange(end - width, end),
  ],
  children: children ?? <MdInline>[_text(start + width, end - width)],
);

MdInline _emphasis(int start, int end, [List<MdInline>? children]) =>
    _wrap(MdInlineKind.emphasis, start, end, 1, children);

MdInline _strong(int start, int end, [List<MdInline>? children]) =>
    _wrap(MdInlineKind.strong, start, end, 2, children);

MdInline _escape(int start) => MdInline(
  kind: MdInlineKind.escape,
  sourceRange: MdRange(start, start + 2),
  contentRange: MdRange(start + 1, start + 2),
  markerRanges: <MdRange>[MdRange(start, start + 1)],
);

List<MdRange> _lineSegments(String source) {
  final List<MdRange> segments = <MdRange>[];
  int lineStart = 0;
  for (int i = 0; i < source.length; i++) {
    if (source.codeUnitAt(i) != 0x0A) {
      continue;
    }
    final bool isCrLf = i > lineStart && source.codeUnitAt(i - 1) == 0x0D;
    segments.add(MdRange(lineStart, isCrLf ? i - 1 : i));
    lineStart = i + 1;
  }
  segments.add(MdRange(lineStart, source.length));
  return segments;
}

void _expectWellFormed(MdInline node) {
  if (node.kind == MdInlineKind.text) {
    expect(node.sourceRange.isEmpty, isFalse, reason: _show(node));
  }
  for (final MdRange marker in node.markerRanges) {
    expect(marker.isEmpty, isFalse, reason: _show(node));
    expect(
      marker.start >= node.sourceRange.start &&
          marker.end <= node.sourceRange.end,
      isTrue,
      reason: _show(node),
    );
  }
  for (final MdInline child in node.children) {
    expect(
      child.sourceRange.start >= node.contentRange.start &&
          child.sourceRange.end <= node.contentRange.end,
      isTrue,
      reason: _show(node),
    );
    _expectWellFormed(child);
  }
}

void _expectTiling(String source, List<MdRange> segments) {
  final List<MdInline> nodes = _parser.parse(source, segments);
  final String reason = 'source: ${source.codeUnits}';
  for (int i = 1; i < nodes.length; i++) {
    expect(
      nodes[i - 1].sourceRange.end <= nodes[i].sourceRange.start,
      isTrue,
      reason: reason,
    );
  }
  final List<int> owners = List<int>.filled(source.length, 0);
  for (final MdInline node in nodes) {
    for (int i = node.sourceRange.start; i < node.sourceRange.end; i++) {
      owners[i] += 1;
    }
    _expectWellFormed(node);
  }
  for (int s = 0; s < segments.length; s++) {
    final MdRange segment = segments[s];
    final int end = s + 1 < segments.length
        ? segments[s + 1].start
        : segment.end;
    for (int i = segment.start; i < end; i++) {
      expect(owners[i], 1, reason: '$reason, unit $i');
    }
  }
}

const List<String> _pieces = <String>[
  '*',
  '**',
  '_',
  '~~',
  '~',
  '==',
  '=',
  'a',
  ' ',
  '.',
  '[',
  ']',
  '(',
  ')',
  '\n',
];

void main() {
  test('emphasis and strong follow commonmark delimiter run rules', () {
    _expectNodes(_parse('*a*'), <MdInline>[_emphasis(0, 3)]);
    _expectNodes(_parse('**a**'), <MdInline>[_strong(0, 5)]);
    _expectNodes(_parse('_a_'), <MdInline>[_emphasis(0, 3)]);
    _expectNodes(_parse('__a__'), <MdInline>[_strong(0, 5)]);
    _expectNodes(_parse('a*b*c'), <MdInline>[
      _text(0, 1),
      _emphasis(1, 4),
      _text(4, 5),
    ]);
    _expectNodes(_parse('a_b_c'), <MdInline>[_text(0, 5)]);
    _expectNodes(_parse('* a *'), <MdInline>[_text(0, 5)]);
    _expectNodes(_parse('**a*'), <MdInline>[_text(0, 1), _emphasis(1, 4)]);
    _expectNodes(_parse('*foo**bar**baz*'), <MdInline>[
      _emphasis(0, 15, <MdInline>[_text(1, 4), _strong(4, 11), _text(11, 14)]),
    ]);
    _expectNodes(_parse('*foo**bar*'), <MdInline>[_emphasis(0, 10)]);
    _expectNodes(_parse('It is the **fog** now'), <MdInline>[
      _text(0, 10),
      _strong(10, 17),
      _text(17, 21),
    ]);
    _expectNodes(
      _parse('**line one\nline two**', const <MdRange>[
        MdRange(0, 10),
        MdRange(11, 21),
      ]),
      <MdInline>[
        _strong(0, 21, <MdInline>[
          _text(2, 10),
          MdInline(
            kind: MdInlineKind.softBreak,
            sourceRange: const MdRange(10, 11),
            contentRange: const MdRange(10, 11),
          ),
          _text(11, 19),
        ]),
      ],
    );
    _expectNodes(_parse('*[foo*](/url)'), <MdInline>[
      _text(0, 1),
      MdInline(
        kind: MdInlineKind.link,
        sourceRange: const MdRange(1, 13),
        contentRange: const MdRange(2, 6),
        markerRanges: const <MdRange>[MdRange(1, 2), MdRange(6, 13)],
        children: <MdInline>[_text(2, 6)],
        data: const MdLinkData(
          destination: '/url',
          destinationRange: MdRange(8, 12),
        ),
      ),
    ]);
  });

  test('strikethrough needs exactly two tildes', () {
    _expectNodes(_parse('~~fog~~'), <MdInline>[
      _wrap(MdInlineKind.strikethrough, 0, 7, 2),
    ]);
    for (final String source in <String>[
      '~fog~',
      '~~~fog~~~',
      '~~fog~',
      'a ~~ b ~~ c',
    ]) {
      _expectNodes(_parse(source), <MdInline>[_text(0, source.length)]);
    }
  });

  test('highlight needs exactly two equals signs with flanking rules', () {
    _expectNodes(_parse('a ==big== b'), <MdInline>[
      _text(0, 2),
      _wrap(MdInlineKind.highlight, 2, 9, 2),
      _text(9, 11),
    ]);
    _expectNodes(_parse('x==y=='), <MdInline>[
      _text(0, 1),
      _wrap(MdInlineKind.highlight, 1, 6, 2),
    ]);
    for (final String source in <String>[
      'a = b',
      'a === b',
      '===a===',
      '==a=',
      '== a ==',
    ]) {
      _expectNodes(_parse(source), <MdInline>[_text(0, source.length)]);
    }
  });

  test('triple star text is bold italic', () {
    _expectNodes(_parse('***a***'), <MdInline>[
      _emphasis(0, 7, <MdInline>[_strong(1, 6)]),
    ]);
    _expectNodes(_parse('***fog***'), <MdInline>[
      _emphasis(0, 9, <MdInline>[_strong(1, 8)]),
    ]);
    _expectNodes(_parse('___a___'), <MdInline>[
      _emphasis(0, 7, <MdInline>[_strong(1, 6)]),
    ]);
    _expectNodes(_parse('***a** b*'), <MdInline>[
      _emphasis(0, 9, <MdInline>[_strong(1, 6), _text(6, 8)]),
    ]);
  });

  test('commonmark emphasis examples keep their tree shapes', () {
    expect(_kinds(_parse('foo-_(bar)_')), <MdInlineKind>[
      MdInlineKind.text,
      MdInlineKind.emphasis,
    ]);
    const String cyrillic = 'пристаням_стремятся_';
    _expectNodes(_parse(cyrillic), <MdInline>[_text(0, cyrillic.length)]);
    _expectNodes(_parse('*(*foo*)*'), <MdInline>[
      _emphasis(0, 9, <MdInline>[_text(1, 2), _emphasis(2, 7), _text(7, 8)]),
    ]);
    _expectNodes(_parse('_foo_bar_baz_'), <MdInline>[_emphasis(0, 13)]);
    _expectNodes(_parse('foo***bar***baz'), <MdInline>[
      _text(0, 3),
      _emphasis(3, 12, <MdInline>[_strong(4, 11)]),
      _text(12, 15),
    ]);
    final List<MdInline> linked = _parse('*foo [bar](/url)*');
    expect(_kinds(linked), <MdInlineKind>[MdInlineKind.emphasis]);
    expect(_kinds(linked.single.children), <MdInlineKind>[
      MdInlineKind.text,
      MdInlineKind.link,
    ]);
    final List<MdInline> inLink = _parse('[*a*](b)');
    expect(_kinds(inLink), <MdInlineKind>[MdInlineKind.link]);
    _expectNodes(inLink.single.children, <MdInline>[_emphasis(1, 4)]);
    _expectNodes(_parse('a*"foo"*'), <MdInline>[_text(0, 8)]);
  });

  test('both shrug spellings keep their escapes', () {
    _expectNodes(_parse('¯\\_(ツ)_/¯'), <MdInline>[
      _text(0, 1),
      _escape(1),
      _text(3, 9),
    ]);
    _expectNodes(_parse('¯\\\\_(ツ)_/¯'), <MdInline>[
      _text(0, 1),
      _escape(1),
      _emphasis(3, 8),
      _text(8, 10),
    ]);
  });

  test('styles run across two lines', () {
    const List<MdRange> segments = <MdRange>[MdRange(0, 9), MdRange(10, 19)];
    final List<MdInline> italic = _parse('_line one\nline two_', segments);
    expect(_kinds(italic), <MdInlineKind>[MdInlineKind.emphasis]);
    expect(italic.single.sourceRange, const MdRange(0, 19));
    expect(_kinds(italic.single.children), <MdInlineKind>[
      MdInlineKind.text,
      MdInlineKind.softBreak,
      MdInlineKind.text,
    ]);
    final List<MdInline> struck = _parse(
      '~~line one\nline two~~',
      const <MdRange>[MdRange(0, 10), MdRange(11, 21)],
    );
    expect(_kinds(struck), <MdInlineKind>[MdInlineKind.strikethrough]);
    expect(struck.single.contentRange, const MdRange(2, 19));
  });

  test('styles nest and odd runs stay text', () {
    _expectNodes(_parse('**~~a~~**'), <MdInline>[
      _strong(0, 9, <MdInline>[_wrap(MdInlineKind.strikethrough, 2, 7, 2)]),
    ]);
    _expectNodes(_parse('==**a**=='), <MdInline>[
      _wrap(MdInlineKind.highlight, 0, 9, 2, <MdInline>[_strong(2, 7)]),
    ]);
    _expectNodes(_parse('~~a~~~'), <MdInline>[_text(0, 6)]);
    _expectNodes(_parse('*\u00A0a\u00A0*'), <MdInline>[_text(0, 5)]);
  });

  test('an in-line gap is invisible to flanking', () {
    _expectNodes(
      _parse(r'**\|**', const <MdRange>[MdRange(0, 2), MdRange(3, 6)]),
      <MdInline>[
        MdInline(
          kind: MdInlineKind.strong,
          sourceRange: const MdRange(0, 6),
          contentRange: const MdRange(3, 4),
          markerRanges: const <MdRange>[MdRange(0, 2), MdRange(4, 6)],
          children: <MdInline>[_text(3, 4)],
        ),
      ],
    );
  });

  test('delimiter runs are classified by flanking', () {
    expect(
      MdDelimiters.runAt('**a', 0),
      const MdDelimiterRun(
        character: 0x2A,
        start: 0,
        end: 2,
        canOpen: true,
        canClose: false,
      ),
    );
    expect(
      MdDelimiters.runAt('a**', 1),
      const MdDelimiterRun(
        character: 0x2A,
        start: 1,
        end: 3,
        canOpen: false,
        canClose: true,
      ),
    );
    expect(
      MdDelimiters.runAt('~~~', 0),
      const MdDelimiterRun(
        character: 0x7E,
        start: 0,
        end: 3,
        canOpen: false,
        canClose: false,
      ),
    );
    expect(
      MdDelimiters.runAt('==', 0),
      const MdDelimiterRun(
        character: 0x3D,
        start: 0,
        end: 2,
        canOpen: false,
        canClose: false,
      ),
    );
    expect(
      MdDelimiters.resolve(<MdDelimiterRun>[
        MdDelimiters.runAt('***a***', 0),
        MdDelimiters.runAt('***a***', 4),
      ]),
      const <MdDelimiterMatch>[
        MdDelimiterMatch(
          kind: MdInlineKind.strong,
          opener: MdRange(1, 3),
          closer: MdRange(4, 6),
        ),
        MdDelimiterMatch(
          kind: MdInlineKind.emphasis,
          opener: MdRange(0, 1),
          closer: MdRange(6, 7),
        ),
      ],
    );
  });

  test('parsed emphasis tiles generated sources split into lines', () {
    final Random random = Random(20260923);
    for (int n = 0; n < 5000; n++) {
      final int count = random.nextInt(31);
      final String source = <String>[
        for (int i = 0; i < count; i++) _pieces[random.nextInt(_pieces.length)],
      ].join();
      _expectTiling(source, _lineSegments(source));
    }
  });
}
