import 'dart:math';

import 'package:field_notes/domain/notes/markdown/inline_parser.dart';
import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';
import 'package:flutter_test/flutter_test.dart';

import '../note_fuzz_corpus.dart';

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

MdInline _text(int start, int end) => MdInline(
  kind: MdInlineKind.text,
  sourceRange: MdRange(start, end),
  contentRange: MdRange(start, end),
);

MdInline _node(
  MdInlineKind kind,
  MdRange source,
  MdRange content, [
  List<MdRange> markers = const <MdRange>[],
]) => MdInline(
  kind: kind,
  sourceRange: source,
  contentRange: content,
  markerRanges: markers,
);

MdInline _escape(int start) => _node(
  MdInlineKind.escape,
  MdRange(start, start + 2),
  MdRange(start + 1, start + 2),
  <MdRange>[MdRange(start, start + 1)],
);

MdInline _codeSpan(int start, int end, MdRange content) => _node(
  MdInlineKind.codeSpan,
  MdRange(start, end),
  content,
  <MdRange>[MdRange(start, content.start), MdRange(content.end, end)],
);

void _expectNodes(List<MdInline> actual, List<MdInline> expected) {
  expect(_shown(actual), _shown(expected));
}

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
  expect(() => node.children.add(_text(0, 1)), throwsUnsupportedError);
  expect(() => node.markerRanges.add(MdRange(0, 1)), throwsUnsupportedError);
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
  final String reason = 'source: ${source.codeUnits}, segments: $segments';
  expect(() => nodes.add(_text(0, 1)), throwsUnsupportedError);
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
    for (int i = segment.start; i < segment.end; i++) {
      expect(owners[i], 1, reason: '$reason, unit $i');
    }
    if (s + 1 == segments.length) {
      continue;
    }
    final int gapStart = segment.end;
    final int gapEnd = segments[s + 1].start;
    final int breakLength = source.codeUnitAt(gapStart) == 0x0A ? 1 : 2;
    for (int i = gapStart; i < gapStart + breakLength; i++) {
      expect(owners[i], 1, reason: '$reason, line break $i');
    }
    for (int i = gapStart + breakLength; i < gapEnd; i++) {
      final bool spansGap = nodes.any(
        (MdInline n) =>
            n.sourceRange.start <= gapStart && n.sourceRange.end >= gapEnd,
      );
      expect(owners[i] == 0 || spansGap, isTrue, reason: '$reason, gap $i');
    }
  }
}

const List<String> _pieces = <String>[
  '\\',
  '`',
  ' ',
  '  ',
  'a',
  '*',
  '<',
  '&',
  '[',
  ']',
  '\n',
  '\r\n',
];

void main() {
  test('a code span strips one space from each end', () {
    _expectNodes(_parse('` a `'), <MdInline>[
      _codeSpan(0, 5, const MdRange(2, 3)),
    ]);
    _expectNodes(_parse('`  a  `'), <MdInline>[
      _codeSpan(0, 7, const MdRange(2, 5)),
    ]);
    _expectNodes(_parse('` a`'), <MdInline>[
      _codeSpan(0, 4, const MdRange(1, 3)),
    ]);
    _expectNodes(_parse('`   `'), <MdInline>[
      _codeSpan(0, 5, const MdRange(1, 4)),
    ]);
    _expectNodes(_parse('`` foo ` bar ``'), <MdInline>[
      _codeSpan(0, 15, const MdRange(3, 12)),
    ]);
    _expectNodes(_parse('` `` `'), <MdInline>[
      _codeSpan(0, 6, const MdRange(2, 4)),
    ]);
    _expectNodes(_parse('`foo`'), <MdInline>[
      _codeSpan(0, 5, const MdRange(1, 4)),
    ]);
    _expectNodes(_parse('`foo'), <MdInline>[_text(0, 4)]);
    _expectNodes(_parse('```foo``'), <MdInline>[_text(0, 8)]);
    _expectNodes(_parse('`foo``bar``'), <MdInline>[
      _text(0, 4),
      _codeSpan(4, 11, const MdRange(6, 9)),
    ]);
  });

  test('a backslash escapes ascii punctuation only', () {
    final List<int> punctuation = <int>[
      for (int unit = 0x21; unit <= 0x7E; unit++)
        if (!(unit >= 0x30 && unit <= 0x39) &&
            !(unit >= 0x41 && unit <= 0x5A) &&
            !(unit >= 0x61 && unit <= 0x7A))
          unit,
    ];
    expect(punctuation, hasLength(32));
    for (final int unit in punctuation) {
      _expectNodes(_parse('\\${String.fromCharCode(unit)}'), <MdInline>[
        _escape(0),
      ]);
    }
    for (final String source in <String>[
      r'\a',
      r'\A',
      r'\3',
      '\\ ',
      '\\\t',
      '\\φ',
      '\\«',
    ]) {
      _expectNodes(_parse(source), <MdInline>[_text(0, 2)]);
    }
    const String shrug = '¯\\_(ツ)_/¯';
    expect(shrug, r'¯\_(ツ)_/¯');
    expect(shrug.length, 9);
    _expectNodes(_parse(shrug), <MdInline>[
      _text(0, 1),
      _escape(1),
      _text(3, 9),
    ]);
    const String doubled = '¯\\\\_(ツ)_/¯';
    expect(doubled, r'¯\\_(ツ)_/¯');
    expect(doubled.length, 10);
    final List<MdInline> doubledNodes = _parse(doubled);
    expect(
      _shown(doubledNodes.take(2).toList()),
      _shown(<MdInline>[_text(0, 1), _escape(1)]),
    );
    expect(
      doubledNodes.where(
        (MdInline n) =>
            n.kind == MdInlineKind.escape &&
            (n.sourceRange.start == 2 || n.sourceRange.start == 3),
      ),
      isEmpty,
    );
    _expectNodes(_parse(r'foo\'), <MdInline>[_text(0, 4)]);
  });

  test(
    'a backslash or two or more spaces before a line break is a hard break',
    () {
      _expectNodes(
        _parse('foo  \nbar', const <MdRange>[MdRange(0, 5), MdRange(6, 9)]),
        <MdInline>[
          _text(0, 3),
          _node(
            MdInlineKind.hardBreak,
            const MdRange(3, 6),
            const MdRange(5, 6),
            const <MdRange>[MdRange(3, 5)],
          ),
          _text(6, 9),
        ],
      );
      _expectNodes(
        _parse('foo\\\nbar', const <MdRange>[MdRange(0, 4), MdRange(5, 8)]),
        <MdInline>[
          _text(0, 3),
          _node(
            MdInlineKind.hardBreak,
            const MdRange(3, 5),
            const MdRange(4, 5),
            const <MdRange>[MdRange(3, 4)],
          ),
          _text(5, 8),
        ],
      );
      _expectNodes(
        _parse('foo       \nbar', const <MdRange>[
          MdRange(0, 10),
          MdRange(11, 14),
        ]),
        <MdInline>[
          _text(0, 3),
          _node(
            MdInlineKind.hardBreak,
            const MdRange(3, 11),
            const MdRange(10, 11),
            const <MdRange>[MdRange(3, 10)],
          ),
          _text(11, 14),
        ],
      );
      _expectNodes(
        _parse('foo  \r\nbar', const <MdRange>[MdRange(0, 5), MdRange(7, 10)]),
        <MdInline>[
          _text(0, 3),
          _node(
            MdInlineKind.hardBreak,
            const MdRange(3, 7),
            const MdRange(5, 7),
            const <MdRange>[MdRange(3, 5)],
          ),
          _text(7, 10),
        ],
      );
      _expectNodes(
        _parse('foo \nbar', const <MdRange>[MdRange(0, 4), MdRange(5, 8)]),
        <MdInline>[
          _text(0, 3),
          _node(
            MdInlineKind.softBreak,
            const MdRange(3, 5),
            const MdRange(4, 5),
            const <MdRange>[MdRange(3, 4)],
          ),
          _text(5, 8),
        ],
      );
      _expectNodes(
        _parse('foo\nbar', const <MdRange>[MdRange(0, 3), MdRange(4, 7)]),
        <MdInline>[
          _text(0, 3),
          _node(
            MdInlineKind.softBreak,
            const MdRange(3, 4),
            const MdRange(3, 4),
          ),
          _text(4, 7),
        ],
      );
      final List<MdInline> quoted = _parse('> foo  \n> bar', const <MdRange>[
        MdRange(2, 7),
        MdRange(10, 13),
      ]);
      _expectNodes(quoted, <MdInline>[
        _text(2, 5),
        _node(
          MdInlineKind.hardBreak,
          const MdRange(5, 8),
          const MdRange(7, 8),
          const <MdRange>[MdRange(5, 7)],
        ),
        _text(10, 13),
      ]);
      expect(
        quoted.where(
          (MdInline n) => n.sourceRange.start < 10 && n.sourceRange.end > 8,
        ),
        isEmpty,
      );
      _expectNodes(_parse('foo  '), <MdInline>[_text(0, 5)]);
      _expectNodes(
        _parse('`code  \nspan`', const <MdRange>[
          MdRange(0, 7),
          MdRange(8, 13),
        ]),
        <MdInline>[_codeSpan(0, 13, const MdRange(1, 12))],
      );
    },
  );

  test('html and entity references stay literal text', () {
    for (final String source in <String>[
      '<b>bold</b> &amp; &#35; &copy;',
      '<a href="/x">link</a>',
      '<!-- note -->',
      '&nbsp;&amp;',
    ]) {
      _expectNodes(_parse(source), <MdInline>[_text(0, source.length)]);
    }
  });

  test('segments that overlap, run backwards, leave the source or hide an '
      'extra line feed are rejected', () {
    expect(
      () => _parse('abcdef', const <MdRange>[MdRange(0, 3), MdRange(2, 5)]),
      throwsArgumentError,
    );
    expect(
      () => _parse('abcdef', const <MdRange>[MdRange(3, 5), MdRange(0, 2)]),
      throwsArgumentError,
    );
    expect(
      () => _parse('ab\ncd', const <MdRange>[MdRange(0, 1), MdRange(3, 5)]),
      throwsArgumentError,
    );
    expect(
      () => _parse('a\n\nb', const <MdRange>[MdRange(0, 1), MdRange(3, 4)]),
      throwsArgumentError,
    );
    expect(
      () => _parse('abc', const <MdRange>[MdRange(0, 4)]),
      throwsArgumentError,
    );
  });

  test('an in-line gap stands for nothing and splits text', () {
    _expectNodes(
      _parse('abcdef', const <MdRange>[MdRange(0, 2), MdRange(3, 5)]),
      <MdInline>[_text(0, 2), _text(3, 5)],
    );
    _expectNodes(
      _parse(r'f\|oo', const <MdRange>[MdRange(0, 1), MdRange(2, 5)]),
      <MdInline>[_text(0, 1), _text(2, 5)],
    );
    _expectNodes(
      _parse(r'b `\|` az', const <MdRange>[MdRange(0, 3), MdRange(4, 9)]),
      <MdInline>[
        _text(0, 2),
        _node(
          MdInlineKind.codeSpan,
          const MdRange(2, 6),
          const MdRange(4, 5),
          const <MdRange>[MdRange(2, 3), MdRange(5, 6)],
        ),
        _text(6, 9),
      ],
    );
  });

  test('no segments or one empty segment give no nodes', () {
    expect(_parser.parse('', const <MdRange>[]), isEmpty);
    expect(_parser.parse('abc', const <MdRange>[]), isEmpty);
    expect(_parser.parse('', const <MdRange>[MdRange(0, 0)]), isEmpty);
  });

  test('a soft break separates two lines', () {
    _expectNodes(
      _parse('first\nsecond', const <MdRange>[MdRange(0, 5), MdRange(6, 12)]),
      <MdInline>[
        _text(0, 5),
        _node(MdInlineKind.softBreak, const MdRange(5, 6), const MdRange(5, 6)),
        _text(6, 12),
      ],
    );
  });

  test('code spans run across lines and hide what is inside them', () {
    _expectNodes(
      _parse('`a\nb`', const <MdRange>[MdRange(0, 2), MdRange(3, 5)]),
      <MdInline>[_codeSpan(0, 5, const MdRange(1, 4))],
    );
    _expectNodes(_parse(r'`foo\`bar`'), <MdInline>[
      _codeSpan(0, 6, const MdRange(1, 5)),
      _text(6, 10),
    ]);
    _expectNodes(_parse(r'\`not code`'), <MdInline>[_escape(0), _text(2, 11)]);
    _expectNodes(_parse('``a``'), <MdInline>[
      _codeSpan(0, 5, const MdRange(2, 3)),
    ]);
  });

  test('parsed nodes tile the fuzz corpus split into lines', () {
    for (final String source in noteFuzzCorpus) {
      _expectTiling(source, _lineSegments(source));
    }
  });

  test('parsed nodes tile generated sources split into lines', () {
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
