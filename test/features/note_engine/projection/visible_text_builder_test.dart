import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:field_notes/features/note_engine/projection/visible_text_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../domain/notes/note_fuzz_corpus.dart';

const VisibleTextBuilder _builder = VisibleTextBuilder();

VisibleText _project(String source, [int? activeLine]) =>
    _builder.project(source, parseNoteTree(source), activeLine);

String _text(String source, [int? activeLine]) =>
    _project(source, activeLine).text;

List<MdRange> _markers(VisibleText visible) => <MdRange>[
  for (final VisibleLine line in visible.lines)
    for (final VisibleSpan span in line.spans)
      if (span.kind == VisibleSpanKind.marker) span.sourceRange,
];

List<AtomicObject> _listMarkers(VisibleText visible) => <AtomicObject>[
  for (final AtomicObject atomic in visible.atomics)
    if (atomic.kind == AtomicKind.listMarker) atomic,
];

String _nested(int levels) =>
    <String>[for (int i = 0; i < levels; i++) '${'  ' * i}- l$i'].join('\n');

void main() {
  test('markers are hidden off the active line and shown on it', () {
    const String title = '# Title\nThe **fog** lifted';
    final VisibleText second = _project(title, 1);
    expect(second.text, 'Title\nThe **fog** lifted');
    expect(_markers(second), const <MdRange>[MdRange(12, 14), MdRange(17, 19)]);
    final VisibleText first = _project(title, 0);
    expect(first.text, '# Title\nThe fog lifted');
    expect(_markers(first), const <MdRange>[MdRange(0, 2)]);
    final VisibleText none = _project(title);
    expect(none.text, 'Title\nThe fog lifted');
    expect(_markers(none), isEmpty);

    const String story =
        '# Harbour day\nThe **fog** lifted and ==peaches== were cheap';
    final VisibleText storyActive = _project(story, 1);
    expect(
      storyActive.text,
      'Harbour day\nThe **fog** lifted and ==peaches== were cheap',
    );
    expect(_markers(storyActive), const <MdRange>[
      MdRange(18, 20),
      MdRange(23, 25),
      MdRange(37, 39),
      MdRange(46, 48),
    ]);
    expect(
      _text(story, 0).split('\n')[1],
      'The fog lifted and peaches were cheap',
    );

    expect(_text('### Deep ###'), 'Deep');
    final VisibleText deep = _project('### Deep ###', 0);
    expect(deep.text, '### Deep ###');
    expect(_markers(deep), const <MdRange>[MdRange(0, 4), MdRange(8, 12)]);
  });

  test('fence lines off the active line produce nothing with their line '
      'break', () {
    for (final int? active in <int?>[null, 1]) {
      final VisibleText code = _project('```\nlet x\n```', active);
      expect(code.text, 'let x');
      expect(
        <int>[for (final VisibleLine line in code.lines) line.sourceLine],
        <int>[1],
      );
    }
    const String framed = 'a\n```\nlet x\n```\nb';
    expect(_text(framed, 0), 'a\nlet x\nb');
    final VisibleText opening = _project(framed, 1);
    expect(opening.text, 'a\n```\nlet x\nb');
    expect(_markers(opening), const <MdRange>[MdRange(2, 5)]);
    expect(_text(framed, 3), 'a\nlet x\n```\nb');
    expect(_text('a\n```\nx\n```'), 'a\nx');
    expect(_text('```js\nx\ny'), 'x\ny');
    expect(_text('```\r\nx\r\n```\r\ny'), 'x\ny');
    final VisibleText empty = _project('```\n```');
    expect(empty.text, '');
    expect(empty.lines, isEmpty);
  });

  test('list markers become glyphs by depth and ordered items show display '
      'numbers', () {
    final VisibleText bullets = _project('- a\n  - b\n    - c\n      - d');
    expect(bullets.text, '\u2022 a\n\u25E6 b\n\u25AA c\n\u25AA d');
    expect(_listMarkers(bullets), const <AtomicObject>[
      AtomicObject(
        kind: AtomicKind.listMarker,
        sourceRange: MdRange(0, 2),
        visibleOffset: 0,
        visibleLength: 2,
      ),
      AtomicObject(
        kind: AtomicKind.listMarker,
        sourceRange: MdRange(6, 8),
        visibleOffset: 4,
        visibleLength: 2,
      ),
      AtomicObject(
        kind: AtomicKind.listMarker,
        sourceRange: MdRange(14, 16),
        visibleOffset: 8,
        visibleLength: 2,
      ),
      AtomicObject(
        kind: AtomicKind.listMarker,
        sourceRange: MdRange(24, 26),
        visibleOffset: 12,
        visibleLength: 2,
      ),
    ]);
    expect(_text('1. a\n1. b\n1. c'), '1. a\n2. b\n3. c');
    expect(_text('3) x\n7) y'), '3. x\n4. y');
    expect(_text('- a\n  1. b\n  1. c'), '\u2022 a\n1. b\n2. c');
    final VisibleText active = _project('- a\n- b', 1);
    expect(active.text, '\u2022 a\n- b');
    expect(_markers(active), const <MdRange>[MdRange(4, 6)]);
    expect(_listMarkers(active), const <AtomicObject>[
      AtomicObject(
        kind: AtomicKind.listMarker,
        sourceRange: MdRange(0, 2),
        visibleOffset: 0,
        visibleLength: 2,
      ),
    ]);
  });

  test('links keep only their text off the active line', () {
    const String link =
        'See [the harbour](https://example.com "Harbour") today';
    expect(_text(link), 'See the harbour today');
    final VisibleText active = _project(link, 0);
    expect(active.text, link);
    expect(_markers(active), const <MdRange>[MdRange(4, 5), MdRange(16, 48)]);
    expect(_text('[**fog** bank](u)'), 'fog bank');
    expect(_text('<https://example.com>'), 'https://example.com');
    expect(_text('<me@example.com>'), 'me@example.com');
    expect(_text('![a](http://x)'), '!a');
    expect(_text('[label]()'), 'label');
  });

  test('inline delimiters and escapes are hidden off the active line', () {
    const String source =
        '*a* ~~b~~ `c` '
        r'\*d\*';
    expect(_text(source), 'a b c *d*');
    final VisibleText active = _project(source, 0);
    expect(active.text, source);
    expect(_markers(active), const <MdRange>[
      MdRange(0, 1),
      MdRange(2, 3),
      MdRange(4, 6),
      MdRange(7, 9),
      MdRange(10, 11),
      MdRange(12, 13),
      MdRange(14, 15),
      MdRange(17, 18),
    ]);
    expect(_text('x ` a ` y'), 'x a y');
  });

  test('quote markers are hidden and dimmed', () {
    expect(_text('> > quoted'), 'quoted');
    expect(_markers(_project('> > quoted', 0)), const <MdRange>[
      MdRange(0, 2),
      MdRange(2, 4),
    ]);
  });

  test('breaks, leading whitespace and line endings', () {
    expect(_text('- a\n\n  b'), '\u2022 a\n\nb');
    expect(
      _text(
        r'a\'
        '\nb',
      ),
      'a\nb',
    );
    expect(_text('a  \nb'), 'a\nb');
    expect(_text('  lead'), 'lead');
    final VisibleText crlf = _project('a\r\nb');
    expect(crlf.text, 'a\nb');
    expect(
      crlf.lines.first.spans.last,
      const VisibleSpan(
        kind: VisibleSpanKind.lineBreak,
        visibleRange: MdRange(1, 2),
        sourceRange: MdRange(1, 3),
      ),
    );
    final VisibleText lone = _project('a\rb');
    expect(lone.text, 'a\rb');
    expect(lone.lines, hasLength(1));
    expect(_text('a\n\n\nb'), 'a\n\n\nb');
  });

  test('blank-line whitespace shows at the top level and hides in a list', () {
    expect(_text('a\n  \nb'), 'a\n  \nb');
    expect(_text('- a\n  \n- b'), '\u2022 a\n\n\u2022 b');
  });

  test('task items show no bullet glyph and ordered ones keep numbers', () {
    expect(_text('- [ ] a'), 'a');
    expect(_listMarkers(_project('- [ ] a')), isEmpty);
    expect(_text('1. [x] a'), '1. a');
  });

  test('a marker spanning a line break is dimmed per line', () {
    expect(_markers(_project('**a\nb**', 0)), const <MdRange>[MdRange(0, 2)]);
  });

  test('glyph depth counts every enclosing list', () {
    expect(_text('- a\n  1. b\n     - c'), '\u2022 a\n1. b\n\u25AA c');
    expect(
      _text(_nested(10)),
      <String>[
        '\u2022 l0',
        '\u25E6 l1',
        for (int i = 2; i < 10; i++) '\u25AA l$i',
      ].join('\n'),
    );
    expect(_text('* x'), '\u2022 x');
    expect(_text('+ x'), '\u2022 x');
  });

  test('a thematic break is one marker', () {
    final VisibleText off = _project('---');
    expect(off.text, '');
    expect(off.lines, hasLength(1));
    final VisibleText on = _project('---', 0);
    expect(on.text, '---');
    expect(_markers(on), const <MdRange>[MdRange(0, 3)]);
  });

  test('an empty source is one empty line', () {
    final VisibleText empty = _project('');
    expect(empty.text, '');
    expect(empty.lines, hasLength(1));
    expect(empty.lines.single.visibleRange, const MdRange(0, 0));
  });

  test('an active line past the last line throws', () {
    expect(() => _project('a\nb', 2), throwsArgumentError);
    expect(() => _project('a', -1), throwsArgumentError);
    expect(
      () => _builder.project('ab', parseNoteTree('abc'), null),
      throwsArgumentError,
    );
  });

  test('splitByMarkers keeps touching markers apart and makes no empty '
      'piece', () {
    expect(
      splitByMarkers('abcdef', 0, 6, const <MdRange>[
        MdRange(2, 4),
        MdRange(0, 2),
        MdRange(6, 8),
      ], active: false),
      const <ProjectedPiece>[
        ProjectedPiece(sourceStart: 0, sourceEnd: 2, text: ''),
        ProjectedPiece(sourceStart: 2, sourceEnd: 4, text: ''),
        ProjectedPiece(sourceStart: 4, sourceEnd: 6, text: 'ef'),
      ],
    );
    expect(
      splitByMarkers('abcdef', 1, 6, const <MdRange>[
        MdRange(0, 3),
        MdRange(2, 4),
      ], active: true),
      const <ProjectedPiece>[
        ProjectedPiece(sourceStart: 1, sourceEnd: 4, text: 'bcd', dimmed: true),
        ProjectedPiece(sourceStart: 4, sourceEnd: 6, text: 'ef'),
      ],
    );
    expect(
      splitByMarkers('abc', 0, 3, const <MdRange>[], active: false),
      const <ProjectedPiece>[
        ProjectedPiece(sourceStart: 0, sourceEnd: 3, text: 'abc'),
      ],
    );
    expect(
      splitByMarkers('abc', 1, 1, const <MdRange>[], active: false),
      isEmpty,
    );
  });

  test('project equals assemble of projectLines', () {
    const String source = '# a\n- [x] b\n```\nc\n```\n**d**';
    final MdTree tree = parseNoteTree(source);
    for (final int? active in <int?>[null, 0, 1, 2, 4, 5]) {
      expect(
        _builder.project(source, tree, active),
        _builder.assemble(
          source,
          _builder.projectLines(source, tree, active),
          activeLine: active,
        ),
      );
    }
  });

  test('every fuzz corpus note projects with pieces covering each line', () {
    for (final String source in noteFuzzCorpus) {
      final MdTree tree = parseNoteTree(source);
      final int lineCount = MdSourceLines.split(source).lines.length;
      for (final int? active in <int?>[
        null,
        for (int i = 0; i < lineCount; i++) i,
      ]) {
        final List<ProjectedLine> lines = _builder.projectLines(
          source,
          tree,
          active,
        );
        expect(lines, hasLength(lineCount));
        for (final ProjectedLine line in lines) {
          int at = line.start;
          for (final ProjectedPiece piece in line.pieces) {
            expect(piece.sourceStart, at, reason: '$source $line');
            expect(piece.sourceEnd, greaterThan(piece.sourceStart));
            at = piece.sourceEnd;
          }
          expect(at, line.end, reason: '$source $line');
        }
        expect(
          () => _builder.assemble(source, lines, activeLine: active),
          returnsNormally,
          reason: source,
        );
      }
    }
  });
}
