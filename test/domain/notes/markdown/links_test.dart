import 'dart:math';

import 'package:field_notes/domain/notes/markdown/inline/links.dart';
import 'package:field_notes/domain/notes/markdown/inline_parser.dart';
import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';
import 'package:flutter_test/flutter_test.dart';

const MdInlineParser _parser = MdInlineParser();

List<MdInline> _parse(String source, [List<MdRange>? segments]) =>
    _parser.parse(source, segments ?? <MdRange>[MdRange(0, source.length)]);

String _range(MdRange range) => '(${range.start}, ${range.end})';

String _show(MdInline node) {
  final String markers = node.markerRanges.map(_range).join(', ');
  final String data = node.data == null ? '' : ' data ${node.data}';
  final String children = node.children.isEmpty
      ? ''
      : ' {${node.children.map(_show).join(', ')}}';
  return '${node.kind.name}${_range(node.sourceRange)} '
      'content${_range(node.contentRange)} markers[$markers]$data$children';
}

List<String> _shown(List<MdInline> nodes) => nodes.map(_show).toList();

void _expectNodes(List<MdInline> actual, List<MdInline> expected) {
  expect(_shown(actual), _shown(expected));
}

MdInline _text(int start, int end) => MdInline(
  kind: MdInlineKind.text,
  sourceRange: MdRange(start, end),
  contentRange: MdRange(start, end),
);

MdInline _link(
  int start,
  int end,
  int closer,
  MdLinkData data, [
  List<MdInline>? children,
]) => MdInline(
  kind: MdInlineKind.link,
  sourceRange: MdRange(start, end),
  contentRange: MdRange(start + 1, closer),
  markerRanges: <MdRange>[MdRange(start, start + 1), MdRange(closer, end)],
  children: children ?? <MdInline>[_text(start + 1, closer)],
  data: data,
);

MdInline _autolink(String source, MdAutolinkKind kind) => MdInline(
  kind: MdInlineKind.autolink,
  sourceRange: MdRange(0, source.length),
  contentRange: MdRange(1, source.length - 1),
  markerRanges: <MdRange>[
    const MdRange(0, 1),
    MdRange(source.length - 1, source.length),
  ],
  data: MdAutolinkData(
    kind: kind,
    target: source.substring(1, source.length - 1),
  ),
);

Iterable<MdInline> _flatten(List<MdInline> nodes) sync* {
  for (final MdInline node in nodes) {
    yield node;
    yield* _flatten(node.children);
  }
}

bool _hasKind(List<MdInline> nodes, MdInlineKind kind) =>
    _flatten(nodes).any((MdInline n) => n.kind == kind);

MdLinkData _linkData(List<MdInline> nodes) =>
    _flatten(
          nodes,
        ).firstWhere((MdInline n) => n.kind == MdInlineKind.link).data!
        as MdLinkData;

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
  '[',
  ']',
  '(',
  ')',
  '<',
  '>',
  '!',
  ':',
  '@',
  'a',
  ' ',
  '"',
  '\n',
];

void main() {
  test('angle autolinks accept uris and email addresses', () {
    _expectNodes(_parse('<https://example.com>'), <MdInline>[
      MdInline(
        kind: MdInlineKind.autolink,
        sourceRange: const MdRange(0, 21),
        contentRange: const MdRange(1, 20),
        markerRanges: const <MdRange>[MdRange(0, 1), MdRange(20, 21)],
        data: const MdAutolinkData(
          kind: MdAutolinkKind.uri,
          target: 'https://example.com',
        ),
      ),
    ]);
    _expectNodes(_parse('<foo@bar.example.com>'), <MdInline>[
      MdInline(
        kind: MdInlineKind.autolink,
        sourceRange: const MdRange(0, 21),
        contentRange: const MdRange(1, 20),
        markerRanges: const <MdRange>[MdRange(0, 1), MdRange(20, 21)],
        data: const MdAutolinkData(
          kind: MdAutolinkKind.email,
          target: 'foo@bar.example.com',
        ),
      ),
    ]);
    for (final String source in <String>[
      '<a+b+c:d>',
      '<MAILTO:FOO@BAR.BAZ>',
      '<made-up-scheme://foo,bar>',
      '<localhost:5001/foo>',
    ]) {
      _expectNodes(_parse(source), <MdInline>[
        _autolink(source, MdAutolinkKind.uri),
      ]);
    }
    const String special = '<foo+special@Bar.baz-bar0.com>';
    _expectNodes(_parse(special), <MdInline>[
      _autolink(special, MdAutolinkKind.email),
    ]);
    for (final String source in <String>[
      '<https://foo.bar/baz bim>',
      '<>',
      '< https://foo.bar >',
      '<m:abc>',
      '<foo.bar.baz>',
      'https://example.com',
      'foo@bar.example.com',
    ]) {
      _expectNodes(_parse(source), <MdInline>[_text(0, source.length)]);
    }
    expect(
      _hasKind(_parse(r'<foo\+@bar.example.com>'), MdInlineKind.autolink),
      isFalse,
    );
  });

  test('link destinations balance parentheses and keep titles', () {
    _expectNodes(_parse('[a](b(c))'), <MdInline>[
      _link(
        0,
        9,
        2,
        const MdLinkData(destination: 'b(c)', destinationRange: MdRange(4, 8)),
      ),
    ]);
    _expectNodes(_parse('[a](u "t")'), <MdInline>[
      _link(
        0,
        10,
        2,
        const MdLinkData(
          destination: 'u',
          destinationRange: MdRange(4, 5),
          title: 't',
          titleRange: MdRange(7, 8),
        ),
      ),
    ]);
    for (final String source in <String>["[a](u 't')", '[a](u (t))']) {
      expect(_linkData(_parse(source)).title, 't');
    }
    expect(
      _linkData(_parse('[a](<b c>)')),
      const MdLinkData(destination: 'b c', destinationRange: MdRange(5, 8)),
    );
    expect(
      _linkData(_parse(r'[a](b\)c)')),
      const MdLinkData(destination: 'b)c', destinationRange: MdRange(4, 8)),
    );
    _expectNodes(_parse('[label]()'), <MdInline>[
      _link(
        0,
        9,
        6,
        const MdLinkData(destination: '', destinationRange: MdRange(8, 8)),
      ),
    ]);
    expect(
      _linkData(_parse('[link](foo(and(bar)))')).destination,
      'foo(and(bar))',
    );
    for (final String source in <String>[
      '[link](foo(and(bar))',
      '[link](/my uri)',
    ]) {
      expect(_hasKind(_parse(source), MdInlineKind.link), isFalse);
    }
  });

  test('an image other than a photo line is a bang then a link', () {
    _expectNodes(_parse('![a](http://x)'), <MdInline>[
      _text(0, 1),
      _link(
        1,
        14,
        3,
        const MdLinkData(
          destination: 'http://x',
          destinationRange: MdRange(5, 13),
        ),
      ),
    ]);
    _expectNodes(_parse('x ![p](photo/abc123abc123) y'), <MdInline>[
      _text(0, 3),
      _link(
        3,
        26,
        5,
        const MdLinkData(
          destination: 'photo/abc123abc123',
          destinationRange: MdRange(7, 25),
        ),
      ),
      _text(26, 28),
    ]);
  });

  test('reference links stay literal text', () {
    for (final String source in <String>[
      '[a][b]',
      '[a][]',
      '[a]',
      '[a]: /url "title"',
    ]) {
      _expectNodes(_parse(source), <MdInline>[_text(0, source.length)]);
    }
    _expectNodes(_parse('[a][b](c)'), <MdInline>[
      _text(0, 3),
      _link(
        3,
        9,
        5,
        const MdLinkData(destination: 'c', destinationRange: MdRange(7, 8)),
      ),
    ]);
  });

  test('a link title sits inside the destination marker', () {
    _expectNodes(_parse('[sea](https://x.y "Sea")'), <MdInline>[
      _link(
        0,
        24,
        4,
        const MdLinkData(
          destination: 'https://x.y',
          destinationRange: MdRange(6, 17),
          title: 'Sea',
          titleRange: MdRange(19, 22),
        ),
      ),
    ]);
  });

  test('brackets nest and links never contain links', () {
    _expectNodes(_parse('[link [foo [bar]]](/uri)'), <MdInline>[
      _link(
        0,
        24,
        17,
        const MdLinkData(
          destination: '/uri',
          destinationRange: MdRange(19, 23),
        ),
      ),
    ]);
    _expectNodes(_parse('[link] bar](/uri)'), <MdInline>[_text(0, 17)]);
    _expectNodes(_parse('[link [bar](/uri)'), <MdInline>[
      _text(0, 6),
      _link(
        6,
        17,
        10,
        const MdLinkData(
          destination: '/uri',
          destinationRange: MdRange(12, 16),
        ),
      ),
    ]);
    _expectNodes(_parse('[foo [bar](/uri)](/uri)'), <MdInline>[
      _text(0, 5),
      _link(
        5,
        16,
        9,
        const MdLinkData(
          destination: '/uri',
          destinationRange: MdRange(11, 15),
        ),
      ),
      _text(16, 23),
    ]);
    final List<MdInline> escaped = _parse(r'[link \[bar](/uri)');
    expect(escaped, hasLength(1));
    expect(escaped.single.kind, MdInlineKind.link);
    expect(
      escaped.single.children.map((MdInline n) => n.kind).toList(),
      <MdInlineKind>[MdInlineKind.text, MdInlineKind.escape, MdInlineKind.text],
    );
  });

  test('code spans and autolinks bind tighter than brackets', () {
    _expectNodes(_parse('[not a `link](/foo`)'), <MdInline>[
      _text(0, 7),
      MdInline(
        kind: MdInlineKind.codeSpan,
        sourceRange: const MdRange(7, 19),
        contentRange: const MdRange(8, 18),
        markerRanges: const <MdRange>[MdRange(7, 8), MdRange(18, 19)],
      ),
      _text(19, 20),
    ]);
    const String autolinked = '[foo<https://example.com/?search=](uri)>';
    _expectNodes(_parse(autolinked), <MdInline>[
      _text(0, 4),
      MdInline(
        kind: MdInlineKind.autolink,
        sourceRange: const MdRange(4, 40),
        contentRange: const MdRange(5, 39),
        markerRanges: const <MdRange>[MdRange(4, 5), MdRange(39, 40)],
        data: const MdAutolinkData(
          kind: MdAutolinkKind.uri,
          target: 'https://example.com/?search=](uri)',
        ),
      ),
    ]);
  });

  test('a link tail may run across one line break', () {
    final List<MdInline> spread = _parse(
      '[link](   /uri\n  "title"  )',
      const <MdRange>[MdRange(0, 14), MdRange(17, 27)],
    );
    _expectNodes(spread, <MdInline>[
      _link(
        0,
        27,
        5,
        const MdLinkData(
          destination: '/uri',
          destinationRange: MdRange(10, 14),
          title: 'title',
          titleRange: MdRange(18, 23),
        ),
      ),
    ]);
    _expectNodes(
      _parse('> [a](\n> b)', const <MdRange>[MdRange(2, 6), MdRange(9, 11)]),
      <MdInline>[
        _link(
          2,
          11,
          4,
          const MdLinkData(destination: 'b', destinationRange: MdRange(9, 10)),
        ),
      ],
    );
    expect(
      _hasKind(
        _parse('[link](<foo\nbar>)', const <MdRange>[
          MdRange(0, 11),
          MdRange(12, 17),
        ]),
        MdInlineKind.link,
      ),
      isFalse,
    );
  });

  test('the link scanners report logical ends and resolved values', () {
    expect(
      MdLinks.autolink('<https://example.com>', 0),
      const MdAutolinkScan(end: 21, kind: MdAutolinkKind.uri),
    );
    expect(
      MdLinks.autolink('a <x@y.z> b', 2),
      const MdAutolinkScan(end: 9, kind: MdAutolinkKind.email),
    );
    expect(MdLinks.autolink('<>', 0), isNull);
    expect(MdLinks.autolink('<m:abc>', 0), isNull);
    expect(MdLinks.autolink('abc', 0), isNull);
    expect(
      MdLinks.linkTail('(b(c))', 0),
      const MdLinkTailScan(
        end: 6,
        destination: 'b(c)',
        destinationRange: MdRange(1, 5),
      ),
    );
    expect(
      MdLinks.linkTail('](u "t\\"")', 1),
      const MdLinkTailScan(
        end: 10,
        destination: 'u',
        destinationRange: MdRange(2, 3),
        title: 't"',
        titleRange: MdRange(5, 8),
      ),
    );
    expect(
      MdLinks.linkTail('()', 0),
      const MdLinkTailScan(
        end: 2,
        destination: '',
        destinationRange: MdRange(1, 1),
      ),
    );
    expect(
      MdLinks.linkTail('(<a&amp;b>)', 0),
      const MdLinkTailScan(
        end: 11,
        destination: 'a&amp;b',
        destinationRange: MdRange(2, 9),
      ),
    );
    expect(MdLinks.linkTail('(/my uri)', 0), isNull);
    expect(MdLinks.linkTail('(a(b)', 0), isNull);
    expect(MdLinks.linkTail('x', 0), isNull);
  });

  test('parsed links tile generated sources split into lines', () {
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
