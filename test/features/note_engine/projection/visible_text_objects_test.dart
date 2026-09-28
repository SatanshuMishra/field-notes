import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/projection/offset_map_builder.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:field_notes/features/note_engine/projection/visible_text_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../domain/notes/note_fuzz_corpus.dart';

const NoteVisibleProjector _projector = NoteVisibleProjector();

const String _photoNote = 'A\n![p](photo/abc123abc123 "left medium")\nB';
const String _tableNote =
    '| Day | Route |\n| --- | :-: |\n'
    r'| Mon | Coast \| ridge |';

VisibleText _project(
  String source, [
  int? activeLine,
  int? activeCell,
  bool tables = true,
]) => _projector.project(
  source,
  parseNoteTree(source, tables: tables),
  activeLine,
  activeCell: activeCell,
);

String _text(String source, [int? activeLine, int? activeCell]) =>
    _project(source, activeLine, activeCell).text;

List<MdRange> _markers(VisibleText visible) => <MdRange>[
  for (final VisibleLine line in visible.lines)
    for (final VisibleSpan span in line.spans)
      if (span.kind == VisibleSpanKind.marker) span.sourceRange,
];

List<AtomicObject> _objects(VisibleText visible, AtomicKind kind) =>
    <AtomicObject>[
      for (final AtomicObject atomic in visible.atomics)
        if (atomic.kind == kind) atomic,
    ];

AtomicObject _object(
  AtomicKind kind,
  int start,
  int end,
  int visibleOffset, [
  int visibleLength = 1,
]) => AtomicObject(
  kind: kind,
  sourceRange: MdRange(start, end),
  visibleOffset: visibleOffset,
  visibleLength: visibleLength,
);

void main() {
  test('a photo line is always one object replacement character', () {
    expect(_photoNote.length, 42);
    for (final int? active in <int?>[null, 0, 1, 2]) {
      final VisibleText visible = _project(_photoNote, active);
      expect(visible.text, 'A\n\uFFFC\nB');
      expect(visible.atomics, <AtomicObject>[
        _object(AtomicKind.photo, 2, 40, 2),
      ]);
      final VisibleLine photoLine = visible.lines.firstWhere(
        (VisibleLine line) => line.sourceLine == 1,
      );
      expect(
        photoLine.spans.where(
          (VisibleSpan span) => span.kind == VisibleSpanKind.marker,
        ),
        isEmpty,
      );
    }
    expect(_text(' ![a](photo/0123456789ab "left small") '), '\uFFFC');
    expect(_text('![a](photo/ab)'), '\uFFFC');
    expect(_text('![a](photo/ABC123ABC123)'), '\uFFFC');
    expect(
      _text('A\n![a](photo/aaaaaaaaaaaa)\n![b](photo/bbbbbbbbbbbb)'),
      'A\n\uFFFC\n\uFFFC',
    );
  });

  test('a checkbox is always a box glyph, active line or not', () {
    final VisibleText off = _project('- [x] pack');
    expect(off.text, '\u2611 pack');
    expect(off.atomics, <AtomicObject>[
      _object(AtomicKind.checkbox, 2, 6, 0, 2),
    ]);
    final VisibleText on = _project('- [x] pack', 0);
    expect(on.text, '- \u2611 pack');
    expect(_markers(on), const <MdRange>[MdRange(0, 2)]);
    expect(_objects(on, AtomicKind.checkbox), <AtomicObject>[
      _object(AtomicKind.checkbox, 2, 6, 2, 2),
    ]);
    expect(_text('- [ ] a'), '\u2610 a');
    final VisibleText ordered = _project('1. [X] a');
    expect(ordered.text, '1. \u2611 a');
    expect(_markers(ordered), isEmpty);
    final VisibleText orderedOn = _project('1. [X] a', 0);
    expect(orderedOn.text, '1. \u2611 a');
    expect(_markers(orderedOn), const <MdRange>[MdRange(0, 3)]);
    expect(_text('> - [ ] a'), '\u2610 a');
  });

  test('table cells are joined by tabs and the delimiter row produces '
      'nothing', () {
    expect(_tableNote.length, 54);
    final VisibleText off = _project(_tableNote);
    expect(off.text, 'Day\tRoute\nMon\tCoast | ridge');
    expect(_objects(off, AtomicKind.tableSeparator), <AtomicObject>[
      _object(AtomicKind.tableSeparator, 5, 8, 3),
      _object(AtomicKind.tableSeparator, 35, 38, 13),
    ]);
    final VisibleText cell = _project(_tableNote, 2, 1);
    expect(
      cell.text,
      'Day\tRoute\nMon\tCoast '
      r'\| ridge',
    );
    expect(_markers(cell), const <MdRange>[MdRange(44, 45)]);
    expect(_project(_tableNote, 2, 0).text, off.text);
    expect(_markers(_project(_tableNote, 2, 0)), isEmpty);
    expect(_project(_tableNote, 1).text, off.text);
    expect(_text('| a |\n| - |'), 'a');
    expect(_text('| a | b |\n| - | - |\n| c |'), 'a\tb\nc');
    expect(_text('| a |\n| - |\n| b | c |'), 'a\nb');
    expect(_text('| a |\n| - |\n| b | c |', 2, 0), 'a\nb');
    final VisibleText paragraph = _project(_tableNote, null, null, false);
    expect(
      paragraph.text,
      '| Day | Route |\n| --- | :-: |\n| Mon | Coast | ridge |',
    );
    expect(_objects(paragraph, AtomicKind.tableSeparator), isEmpty);
  });

  test('offsets map both ways and a crlf maps as one unit', () {
    final VisibleText fog = _project('The **fog** lifted');
    expect(fog.text, 'The fog lifted');
    expect(fog.map.visibleToSource(7), const SourceOffsets(9, 11));
    for (final int source in <int>[9, 10, 11]) {
      expect(fog.map.sourceToVisible(source), 7);
    }
    expect(fog.map.visibleToSource(4), const SourceOffsets(4, 6));
    expect(fog.map.sourceToVisible(5), 4);

    final VisibleText crlf = _project('a\r\nb');
    expect(crlf.text, 'a\nb');
    expect(crlf.map.sourceToVisible(1), 1);
    expect(crlf.map.sourceToVisible(2), 1);
    expect(crlf.map.sourceToVisible(3), 2);
    expect(crlf.map.visibleToSource(1), const SourceOffsets(1, 1));
    expect(crlf.map.visibleToSource(2), const SourceOffsets(3, 3));

    final VisibleText photo = _project(_photoNote);
    expect(photo.map.sourceToVisible(20), 2);
    expect(photo.map.visibleToSource(2), const SourceOffsets(2, 2));
    expect(photo.map.visibleToSource(3), const SourceOffsets(40, 40));

    final VisibleText bullet = _project('- a');
    expect(bullet.text, '\u2022 a');
    expect(bullet.map.visibleToSource(1), const SourceOffsets(0, 2));
    expect(bullet.map.sourceToVisible(1), 0);

    final VisibleText box = _project('- [x] pack');
    expect(box.map.visibleToSource(1), const SourceOffsets(2, 6));
  });

  test('a divider is one object off the active line', () {
    const String source = 'a\n\n---\n\nb';
    final VisibleText off = _project(source);
    expect(off.text, 'a\n\n\uFFFC\n\nb');
    expect(off.atomics, <AtomicObject>[_object(AtomicKind.divider, 3, 6, 3)]);
    final VisibleText on = _project(source, 2);
    expect(on.text, source);
    expect(_markers(on), const <MdRange>[MdRange(3, 6)]);
    expect(_objects(on, AtomicKind.divider), isEmpty);
    expect(_text('> ---'), '\uFFFC');
  });

  test('photo-shaped text inside containers is not a photo', () {
    expect(
      _text('```\n![p](photo/abc123abc123)\n```'),
      '![p](photo/abc123abc123)',
    );
    expect(_text('- a\n  ![p](photo/abc123abc123)'), '\u2022 a\n!p');
  });

  test('cell markers show only in the active cell', () {
    expect(_text('| **a** |\n| - |'), 'a');
    final VisibleText active = _project('| **a** |\n| - |', 0, 0);
    expect(active.text, '**a**');
    expect(_markers(active), const <MdRange>[MdRange(2, 4), MdRange(5, 7)]);
    expect(_text('| a |  |\n| - | - |'), 'a\t');
    expect(_text('a | b\n-|-'), 'a\tb');
    expect(
      _project('a | b\n-|-').lines.first.spans.first,
      const VisibleSpan(
        kind: VisibleSpanKind.text,
        visibleRange: MdRange(0, 1),
        sourceRange: MdRange(0, 1),
      ),
    );
  });

  test('table rows with crlf breaks', () {
    const String source = '| a | b |\r\n| - | - |\r\n| c | d |';
    final VisibleText visible = _project(source);
    expect(visible.text, 'a\tb\nc\td');
    expect(visible.lines.first.spans.last.sourceRange, const MdRange(9, 11));
    expect(visible.map.sourceToVisible(10), 3);
  });

  test('a call through the interface shows no cell markers', () {
    const VisibleProjector projector = NoteVisibleProjector();
    final VisibleText visible = projector.project(
      _tableNote,
      parseNoteTree(_tableNote),
      2,
    );
    expect(visible.text, 'Day\tRoute\nMon\tCoast | ridge');
    expect(_markers(visible), isEmpty);
  });

  test('the atomics list is in visible order', () {
    final VisibleText visible = _project(
      '- [ ] a\n---\n![p](photo/abc123abc123)\n| x | y |\n| - | - |\n1. b',
    );
    final List<int> offsets = <int>[
      for (final AtomicObject atomic in visible.atomics) atomic.visibleOffset,
    ];
    expect(offsets, List<int>.of(offsets)..sort());
    expect(
      <AtomicKind>[
        for (final AtomicObject atomic in visible.atomics) atomic.kind,
      ],
      <AtomicKind>[
        AtomicKind.checkbox,
        AtomicKind.divider,
        AtomicKind.photo,
        AtomicKind.tableSeparator,
        AtomicKind.listMarker,
      ],
    );
  });

  test('VisibleLineIndex finds lines by source line and offset', () {
    final VisibleLineIndex index = VisibleLineIndex(
      _project('a\n```\nx\n```\nb'),
    );
    expect(index.visible.text, 'a\nx\nb');
    expect(
      <int?>[for (int i = 0; i < 5; i++) index.lineForSource(i)],
      <int?>[0, null, 1, null, 2],
    );
    expect(index.lineForSource(9), isNull);
    expect(index.lineAtVisible(0), 0);
    expect(index.lineAtVisible(1), 0);
    expect(index.lineAtVisible(2), 1);
    expect(index.lineAtVisible(5), 2);
    expect(index.lineAtSource(3), 1);
    expect(() => index.lineForSource(-1), throwsRangeError);
    expect(() => index.lineAtVisible(-1), throwsRangeError);
    expect(() => index.lineAtSource(-1), throwsRangeError);
    expect(() => index.lineAtVisible(6), throwsRangeError);
    expect(VisibleLineIndex(_project('a\n')).lineAtVisible(2), 1);
    expect(VisibleLineIndex(_project('```\n```')).lineAtVisible(0), isNull);
  });

  test('spliceAtomicPiece puts one piece over a range', () {
    expect(
      spliceAtomicPiece(
        const <ProjectedPiece>[
          ProjectedPiece(sourceStart: 0, sourceEnd: 6, text: 'abcdef'),
        ],
        const ProjectedPiece(
          sourceStart: 2,
          sourceEnd: 4,
          text: '\uFFFC',
          atomic: AtomicKind.divider,
        ),
      ),
      const <ProjectedPiece>[
        ProjectedPiece(sourceStart: 0, sourceEnd: 2, text: 'ab'),
        ProjectedPiece(
          sourceStart: 2,
          sourceEnd: 4,
          text: '\uFFFC',
          atomic: AtomicKind.divider,
        ),
        ProjectedPiece(sourceStart: 4, sourceEnd: 6, text: 'ef'),
      ],
    );
    const ProjectedPiece box = ProjectedPiece(
      sourceStart: 2,
      sourceEnd: 6,
      text: '\u2611 ',
      atomic: AtomicKind.checkbox,
    );
    expect(
      spliceAtomicPiece(_pieceLines('- [x] pack').single.pieces, box),
      const <ProjectedPiece>[
        ProjectedPiece(sourceStart: 0, sourceEnd: 2, text: ''),
        box,
        ProjectedPiece(sourceStart: 6, sourceEnd: 10, text: 'pack'),
      ],
    );
    expect(
      () => spliceAtomicPiece(
        _pieceLines('- a').single.pieces,
        const ProjectedPiece(
          sourceStart: 1,
          sourceEnd: 3,
          text: '\uFFFC',
          atomic: AtomicKind.divider,
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => spliceAtomicPiece(
        _pieceLines('abc').single.pieces,
        const ProjectedPiece(
          sourceStart: 1,
          sourceEnd: 1,
          text: '\uFFFC',
          atomic: AtomicKind.divider,
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => spliceAtomicPiece(
        _pieceLines('abc').single.pieces,
        const ProjectedPiece(
          sourceStart: 2,
          sourceEnd: 4,
          text: '\uFFFC',
          atomic: AtomicKind.divider,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('offset maps hold for every fuzz corpus note', () {
    for (final String source in noteFuzzCorpus) {
      final MdTree tree = parseNoteTree(source);
      final int lineCount = MdSourceLines.split(source).lines.length;
      for (final int? active in <int?>[
        null,
        for (int i = 0; i < lineCount; i++) i,
      ]) {
        final VisibleText visible = _projector.project(source, tree, active);
        final OffsetMap map = visible.map;
        expect(map.sourceToVisible(0), 0, reason: source);
        expect(
          map.sourceToVisible(source.length),
          visible.text.length,
          reason: source,
        );
        int previous = 0;
        for (int s = 0; s <= source.length; s++) {
          final int mapped = map.sourceToVisible(s);
          expect(mapped, greaterThanOrEqualTo(previous), reason: source);
          previous = mapped;
        }
        for (int v = 0; v <= visible.text.length; v++) {
          final SourceOffsets offsets = map.visibleToSource(v);
          expect(
            offsets.upstream,
            lessThanOrEqualTo(offsets.downstream),
            reason: source,
          );
          final AtomicObject? atomic = visible.atomicAtVisible(v);
          if (atomic != null && atomic.visibleOffset < v) {
            continue;
          }
          expect(map.sourceToVisible(offsets.upstream), v, reason: source);
          expect(map.sourceToVisible(offsets.downstream), v, reason: source);
        }
      }
    }
  });
}

List<ProjectedLine> _pieceLines(String source) => const VisibleTextBuilder()
    .projectLines(source, parseNoteTree(source), null);
