import 'dart:ui' as ui;

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/caret_geometry.dart';
import 'package:field_notes/features/note_engine/layout/float_flow.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_layout_engine.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../notes/support/notes_harness.dart';

const Map<String, Size> _threeTwo = <String, Size>{
  'a1b2c3d4e5f6': Size(1200, 800),
};

LayoutInputs _inputs(
  String source, {
  int? activeLine,
  bool readerMode = false,
  double columnWidth = 688,
  TextScaler textScaler = TextScaler.noScaling,
  Map<String, Size> mediaDimensions = _threeTwo,
  Set<String> unavailableMedia = const <String>{},
}) {
  final MdTree tree = parseNoteTree(source);
  return LayoutInputs(
    source: source,
    tree: tree,
    visibleText: const NoteVisibleProjector().project(source, tree, activeLine),
    activeLine: activeLine,
    columnWidth: columnWidth,
    textScaler: textScaler,
    boldText: false,
    locale: const ui.Locale('en', 'US'),
    readerMode: readerMode,
    mediaDimensions: mediaDimensions,
    unavailableMedia: unavailableMedia,
  );
}

String _harbours(int count) => List<String>.filled(count, 'harbour').join(' ');

String _paragraph(int n) => 'Paragraph $n is a line of plain words.';

String _floatNote() => <String>[
  for (int n = 1; n <= 9; n++) _paragraph(n),
  '![](photo/a1b2c3d4e5f6 "right medium")',
  for (int n = 10; n <= 20; n++) _paragraph(n),
].join('\n\n');

List<int> _allBlocks(LayoutInputs inputs) =>
    List<int>.generate(inputs.tree.blocks.length, (int i) => i);

int _blockOf(LayoutInputs inputs, String text) {
  final int at = inputs.source.indexOf(text);
  return inputs.tree.blocks.indexWhere(
    (MdBlock block) =>
        block.sourceRange.start <= at && at < block.sourceRange.end,
  );
}

Set<int> _blocksBesideFloat(NoteFlow flow, {required bool beside}) => <int>{
  for (final LaidOutRow row in flow.rows)
    if (row.row.kind != LayoutRowKind.photo &&
        row.fragments.any(
          (LineFragment fragment) => fragment.besideFloat == beside,
        ))
      row.row.blockIndex,
};

List<String> _lineTexts(NoteFlow flow) => <String>[
  for (final LineFragment fragment in flow.fragments)
    if (fragment.kind != FragmentKind.photo)
      for (final VisualLine line in fragment.lines)
        flow.inputs.visibleText.text.substring(
          line.visibleRange.start,
          line.visibleRange.end,
        ),
];

void _expectRectClose(Rect actual, Rect expected, double tolerance) {
  expect(actual.left, closeTo(expected.left, tolerance), reason: '$actual');
  expect(actual.top, closeTo(expected.top, tolerance), reason: '$actual');
  expect(actual.right, closeTo(expected.right, tolerance), reason: '$actual');
  expect(actual.bottom, closeTo(expected.bottom, tolerance), reason: '$actual');
}

final class _CountingResolver implements MediaResolver {
  _CountingResolver(this._inner);

  final MediaResolver _inner;
  final Map<String?, int> resolveCalls = <String?, int>{};
  int resolvedCalls = 0;

  @override
  Future<ResolvedMedia> resolve(String? mediaId) {
    resolveCalls[mediaId] = (resolveCalls[mediaId] ?? 0) + 1;
    return _inner.resolve(mediaId);
  }

  @override
  ResolvedMedia? resolved(String? mediaId) {
    resolvedCalls++;
    return _inner.resolved(mediaId);
  }
}

void main() {
  test('an edit relays out only the changed block and its float run', () {
    final NoteLayoutEngine engine = NoteLayoutEngine();
    final String source = _floatNote();
    final LayoutInputs first = _inputs(source);
    engine.layout(first);
    expect(engine.lastRelaidBlocks, _allBlocks(first));
    expect(first.tree.blocks[9].kind, MdBlockKind.photoLine);
    engine.layout(_inputs(source));
    expect(engine.lastRelaidBlocks, isEmpty);

    final String typed = source.replaceFirst('Paragraph 3 ', 'Paragraph 3x ');
    final LayoutInputs edited = _inputs(typed);
    final LaidOutNote before = engine.layout(edited);
    expect(engine.lastRelaidBlocks, <int>[_blockOf(edited, 'Paragraph 3x')]);

    final String grown = typed.replaceFirst(
      _paragraph(10),
      '${_paragraph(10)} ${_harbours(40)}',
    );
    final LayoutInputs longer = _inputs(grown);
    final LaidOutNote after = engine.layout(longer);
    final List<int> relaid = engine.lastRelaidBlocks;
    final int photoBlock = _blockOf(longer, '![](photo');
    final int tenth = _blockOf(longer, _paragraph(10));
    expect(relaid, contains(tenth));
    final Set<int> besideBefore = _blocksBesideFloat(before.flow, beside: true);
    expect(
      relaid.where(
        (int block) => block > tenth && besideBefore.contains(block),
      ),
      isNotEmpty,
    );
    expect(relaid.where((int block) => block < photoBlock), isEmpty);
    final Set<int> fullBefore = _blocksBesideFloat(
      before.flow,
      beside: false,
    ).difference(besideBefore);
    final Set<int> fullAfter = _blocksBesideFloat(
      after.flow,
      beside: false,
    ).difference(_blocksBesideFloat(after.flow, beside: true));
    for (final int block in relaid) {
      expect(
        fullBefore.contains(block) && fullAfter.contains(block),
        isFalse,
        reason: 'block $block was full width before and after',
      );
    }
  });

  test('reader mode equals the composer with no active line', () {
    const String source =
        '# Harbour day\n![](photo/a1b2c3d4e5f6 "right small")\n## Route\n'
        '- [ ] passport\n- [x] tickets\n\nThe **fog** lifted at noon and the '
        '==peaches== were cheap.\n\n> quiet\n\n---\n\n```\nlet x\n```';
    final LaidOutNote reader = NoteLayoutEngine().layout(
      _inputs(source, readerMode: true),
    );
    final NoteLayoutEngine composer = NoteLayoutEngine();
    composer.layout(_inputs(source, activeLine: 6));
    final LaidOutNote unfocused = composer.layout(_inputs(source));
    expect(_lineTexts(reader.flow), _lineTexts(unfocused.flow));
    expect(reader.flow.rows.length, unfocused.flow.rows.length);
    for (int i = 0; i < reader.flow.rows.length; i++) {
      expect(reader.flow.rows[i].top, closeTo(unfocused.flow.rows[i].top, 0.5));
    }
    expect(reader.photoRects.length, unfocused.photoRects.length);
    for (int i = 0; i < reader.photoRects.length; i++) {
      _expectRectClose(
        reader.photoRects[i].rect,
        unfocused.photoRects[i].rect,
        0.5,
      );
    }
    expect(reader.size.width, closeTo(unfocused.size.width, 0.5));
    expect(reader.size.height, closeTo(unfocused.size.height, 0.5));
  });

  test('stored photo dimensions are read before the first layout', () async {
    final _CountingResolver resolver = _CountingResolver(
      FakeNoteMediaResolver(<String, ResolvedMedia>{
        'a1b2c3d4e5f6': availablePhoto(photoIdA, width: 1600, height: 1200),
        'b2c3d4e5f6a1': availablePhoto(photoIdB, width: null, height: null),
      }),
    );
    const String source =
        '![](photo/a1b2c3d4e5f6 "centre medium")\n\n'
        '![](photo/b2c3d4e5f6a1 "centre medium")\n\n'
        '![](photo/c3d4e5f6a1b2 "centre medium")';
    final MdTree tree = parseNoteTree(source);
    final ({Map<String, Size> dimensions, Set<String> unavailable}) media =
        await readPhotoDimensions(tree, resolver);
    final LaidOutNote note = NoteLayoutEngine().layout(
      _inputs(
        source,
        mediaDimensions: media.dimensions,
        unavailableMedia: media.unavailable,
      ),
    );
    final List<PhotoRect> rects = note.photoRects;
    expect(rects, hasLength(3));
    expect(rects[0].rect.width, closeTo(344, 0.01));
    expect(rects[0].rect.height, closeTo(258, 0.01));
    expect(rects[1].rect.width, closeTo(344, 0.01));
    expect(rects[1].rect.height, closeTo(229.33, 0.01));
    expect(rects[2].rect.width, closeTo(344, 0.01));
    expect(rects[2].rect.height, closeTo(56, 0.01));
    expect(resolver.resolveCalls, <String, int>{
      'a1b2c3d4e5f6': 1,
      'b2c3d4e5f6a1': 1,
      'c3d4e5f6a1b2': 1,
    });
  });

  test('reader mode inputs refuse an active line', () {
    expect(
      () => _inputs('A\n\nB\n\nC\n\nD', activeLine: 6, readerMode: true),
      throwsArgumentError,
    );
  });

  test('memoised media need no resolve call', () async {
    final _CountingResolver resolver = _CountingResolver(
      FakeNoteMediaResolver(<String, ResolvedMedia>{
        'a1b2c3d4e5f6': availablePhoto(photoIdA, width: 1600, height: 1200),
      })..memoizeAll(),
    );
    final ({Map<String, Size> dimensions, Set<String> unavailable}) media =
        await readPhotoDimensions(
          parseNoteTree(
            '![](photo/a1b2c3d4e5f6 "left small")\n\n'
            '![](photo/a1b2c3d4e5f6 "right small")',
          ),
          resolver,
        );
    expect(resolver.resolveCalls, isEmpty);
    expect(media.dimensions, <String, Size>{
      'a1b2c3d4e5f6': const Size(1600, 1200),
    });
    expect(media.unavailable, isEmpty);
  });

  test('upper-case references and zero dimensions', () async {
    final _CountingResolver resolver = _CountingResolver(
      FakeNoteMediaResolver(<String, ResolvedMedia>{
        'a1b2c3d4e5f6': availablePhoto(photoIdA, width: 0, height: 800),
      }),
    );
    final ({Map<String, Size> dimensions, Set<String> unavailable}) media =
        await readPhotoDimensions(
          parseNoteTree(
            '![](photo/A1B2C3D4E5F6 "centre medium")\n\n'
            '![](photo/a1b2c3d4e5f6 "centre medium")',
          ),
          resolver,
        );
    expect(media.unavailable, <String>{'A1B2C3D4E5F6'});
    expect(media.dimensions, isEmpty);
    expect(resolver.resolveCalls.keys, <String>['a1b2c3d4e5f6']);
    expect(resolver.resolvedCalls, 1);
  });

  test('moving the active line relays out only the two blocks', () {
    final NoteLayoutEngine engine = NoteLayoutEngine();
    final String source = _floatNote();
    engine.layout(_inputs(source, activeLine: 4));
    final LayoutInputs moved = _inputs(source, activeLine: 8);
    engine.layout(moved);
    expect(engine.lastRelaidBlocks, <int>[
      _blockOf(moved, _paragraph(3)),
      _blockOf(moved, _paragraph(5)),
    ]);
  });

  test('changing one photo dimension relays out only that photo', () {
    const String source =
        'Intro\n\n![](photo/a1b2c3d4e5f6 "centre medium")\n\nMiddle\n\n'
        '![](photo/b2c3d4e5f6a1 "centre medium")\n\nOutro';
    final NoteLayoutEngine engine = NoteLayoutEngine();
    engine.layout(
      _inputs(
        source,
        mediaDimensions: <String, Size>{
          'a1b2c3d4e5f6': const Size(1200, 800),
          'b2c3d4e5f6a1': const Size(1200, 800),
        },
      ),
    );
    final LayoutInputs changed = _inputs(
      source,
      mediaDimensions: <String, Size>{
        'a1b2c3d4e5f6': const Size(1200, 800),
        'b2c3d4e5f6a1': const Size(800, 1200),
      },
    );
    engine.layout(changed);
    expect(engine.lastRelaidBlocks, <int>[_blockOf(changed, '![](photo/b2c3')]);
  });

  test('a width change relays out everything and a scaler change misses', () {
    final NoteLayoutEngine engine = NoteLayoutEngine();
    final String source = _floatNote();
    engine.layout(_inputs(source));
    final LayoutInputs wider = _inputs(source, columnWidth: 720);
    engine.layout(wider);
    expect(engine.lastRelaidBlocks, _allBlocks(wider));
    final LayoutInputs scaled = _inputs(
      source,
      columnWidth: 720,
      textScaler: const TextScaler.linear(1.1),
    );
    engine.layout(scaled);
    expect(engine.lastRelaidBlocks, _allBlocks(scaled));
  });

  test('the reader engine never shows dimmed markers', () {
    const String source = '# Title\n\nThe **fog** and [a link](https://x.y)';
    final LaidOutNote note = NoteLayoutEngine().layout(
      _inputs(source, readerMode: true),
    );
    for (final VisibleLine line in note.inputs.visibleText.lines) {
      for (final VisibleSpan span in line.spans) {
        expect(span.dimmed, isFalse, reason: '$span');
      }
    }
    expect(_lineTexts(note.flow), <String>['Title', '', 'The fog and a link']);
  });

  test('every NoteLayout query answers through the engine', () {
    const String source = 'Alpha beta gamma\n\nThe **fog** lifted';
    final LaidOutNote note = NoteLayoutEngine().layout(_inputs(source));
    final NoteLayout layout = note;
    final CaretGeometry geometry = CaretGeometry(flow: note.flow);
    for (int position = 0; position <= source.length; position++) {
      final Rect caret = layout.caretRect(position, TextAffinity.downstream);
      expect(caret, geometry.caretRect(position, TextAffinity.downstream));
      expect(caret.width, 2);
    }
    for (final int position in <int>[0, 3, 6, 16, 24, 29, source.length]) {
      final Rect caret = layout.caretRect(position, TextAffinity.downstream);
      expect(
        layout.positionAt(Offset(caret.left, caret.center.dy)).offset,
        position,
      );
    }
    final SelectionEndpoints endpoints = layout.selectionEndpoints(
      const NoteSelection(anchor: 3, head: 22),
    );
    expect(endpoints.start.point.dy, closeTo(25.6, 0.5));
    expect(endpoints.endLineHeight, closeTo(25.6, 0.5));
    expect(layout.wordBoundary(2), const MdRange(0, 5));
    expect(layout.documentBoundary, const MdRange(0, source.length));
    expect(layout.paragraphBoundary(20), const MdRange(18, source.length));
    expect(
      layout.lineBoundary(3, TextAffinity.downstream),
      const MdRange(0, 16),
    );
    expect(layout.rangeBounds(const MdRange(3, 3)).width, 0);
    expect(
      layout.selectionBoxes(const NoteSelection(anchor: 0, head: 5)),
      isNotEmpty,
    );
    final List<FragmentInfo> fragments = layout.fragments;
    expect(fragments, hasLength(3));
    expect(fragments[0].sourceRange, const MdRange(0, 16));
    expect(fragments[0].visibleRange, const MdRange(0, 16));
    expect(fragments[2].sourceRange, const MdRange(18, source.length));
    for (final FragmentInfo info in fragments) {
      expect(
        info.lineBox,
        layout.lineBoxAt(info.sourceRange.start, TextAffinity.downstream),
      );
    }
    expect(layout.size, Size(688, note.flow.height));
  });

  test('an empty or unclosed fence off the active line answers queries', () {
    for (final String source in <String>[
      '```',
      '```\n```',
      'a\n```',
      '```\n```\nb',
      'a\n```\n```\nb',
    ]) {
      for (final bool readerMode in <bool>[true, false]) {
        final LaidOutNote note = NoteLayoutEngine().layout(
          _inputs(source, readerMode: readerMode),
        );
        for (int position = 0; position <= source.length; position++) {
          for (final TextAffinity affinity in TextAffinity.values) {
            expect(note.caretRect(position, affinity).height, greaterThan(0));
            expect(
              note.lineBoxAt(position, affinity).rect.height,
              greaterThan(0),
            );
          }
          final MdRange word = note.wordBoundary(position);
          expect(word.start, inInclusiveRange(0, word.end));
          expect(word.end, inInclusiveRange(word.start, source.length));
          expect(
            note
                .selectionEndpoints(NoteSelection(anchor: 0, head: position))
                .endLineHeight,
            greaterThan(0),
          );
        }
        final TextPosition hit = note.positionAt(const Offset(20, 10));
        final MdRange word = note.wordBoundary(hit.offset);
        expect(word.end, inInclusiveRange(word.start, source.length));
      }
    }

    final LaidOutNote fence = NoteLayoutEngine().layout(
      _inputs('```', readerMode: true),
    );
    final Rect caret = fence.caretRect(0, TextAffinity.downstream);
    expect(caret.left, closeTo(12, 0.01));
    expect(caret.top, greaterThanOrEqualTo(12 - 0.01));
    expect(caret.bottom, lessThanOrEqualTo(fence.size.height - 12 + 0.01));

    for (final (String source, int position) in <(String, int)>[
      ('a\n```', 1),
      ('```\n```\nb', 8),
      ('a\n```\n```\nb', 10),
    ]) {
      final LaidOutNote note = NoteLayoutEngine().layout(
        _inputs(source, readerMode: true),
      );
      final LineFragment text = note.flow.fragments.lastWhere(
        (LineFragment fragment) =>
            fragment.kind == FragmentKind.text &&
            note.flow.rows[fragment.rowIndex].row.kind == LayoutRowKind.text,
      );
      for (final TextAffinity affinity in TextAffinity.values) {
        expect(
          note.caretRect(position, affinity).top,
          closeTo(text.lines.single.top, 0.01),
          reason: '$source at $position, ${affinity.name}',
        );
      }
    }
  });

  test('vertical targets leave the relaid blocks alone', () {
    final String source = 'Top line\n${_harbours(60)}';
    final NoteLayoutEngine engine = NoteLayoutEngine();
    final LaidOutNote note = engine.layout(_inputs(source, activeLine: 1));
    final List<int> relaid = engine.lastRelaidBlocks;
    expect(relaid, <int>[0]);
    final List<VisualLine> lines = note.flow.fragments.last.lines;
    expect(lines.length, greaterThan(3));
    final int wrap = note.inputs.visibleText.map
        .visibleToSource(lines[2].visibleRange.start)
        .downstream;
    final TextPosition upstream = note.verticalTarget(
      wrap,
      TextAffinity.upstream,
      100,
      VerticalMove.up,
    );
    final TextPosition downstream = note.verticalTarget(
      wrap,
      TextAffinity.downstream,
      100,
      VerticalMove.up,
    );
    expect(
      note.geometry.locate(upstream.offset, upstream.affinity).line,
      lines[0],
    );
    expect(
      note.geometry.locate(downstream.offset, downstream.affinity).line,
      lines[1],
    );
    final TextPosition top = note.verticalTarget(
      note.inputs.visibleText.map
          .visibleToSource(lines[0].visibleRange.start)
          .downstream,
      TextAffinity.downstream,
      20,
      VerticalMove.up,
    );
    expect(top.offset, lessThan(8));
    expect(engine.lastRelaidBlocks, relaid);
    engine.layout(_inputs(source, activeLine: 1));
    expect(engine.lastRelaidBlocks, isEmpty);
  });

  test('an unavailable photo lays out once', () {
    final NoteLayoutEngine engine = NoteLayoutEngine();
    final String source = _floatNote();
    final LayoutInputs missing = _inputs(
      source,
      mediaDimensions: const <String, Size>{},
      unavailableMedia: <String>{'a1b2c3d4e5f6'},
    );
    final LaidOutNote note = engine.layout(missing);
    expect(engine.lastRelaidBlocks, _allBlocks(missing));
    expect(note.photoRects.single.rect.height, closeTo(56, 0.01));
    expect(note.photoRects.single.flow, PhotoFlow.block);
    engine.layout(
      _inputs(
        source,
        mediaDimensions: const <String, Size>{},
        unavailableMedia: <String>{'a1b2c3d4e5f6'},
      ),
    );
    expect(engine.lastRelaidBlocks, isEmpty);
  });

  test('a resize sweep ends where a fresh layout starts', () {
    final String source = _floatNote();
    final NoteLayoutEngine swept = NoteLayoutEngine();
    for (double width = 600; width <= 900; width += 25) {
      swept.layout(_inputs(source, columnWidth: width));
    }
    final LaidOutNote after = swept.layout(_inputs(source, columnWidth: 700));
    final LaidOutNote fresh = NoteLayoutEngine().layout(
      _inputs(source, columnWidth: 700),
    );
    expect(after.fragments.length, fresh.fragments.length);
    for (int i = 0; i < fresh.fragments.length; i++) {
      final FragmentInfo a = after.fragments[i];
      final FragmentInfo b = fresh.fragments[i];
      expect(a.visibleRange, b.visibleRange);
      expect(a.sourceRange, b.sourceRange);
      expect(a.besideFloat, b.besideFloat);
      _expectRectClose(a.lineBox.rect, b.lineBox.rect, 0.01);
    }
    expect(after.photoRects.length, fresh.photoRects.length);
    for (int i = 0; i < fresh.photoRects.length; i++) {
      _expectRectClose(
        after.photoRects[i].rect,
        fresh.photoRects[i].rect,
        0.01,
      );
    }
  });

  test('a table is routed to the table layout', () {
    const String source = 'Intro\n\n| a | b |\n| - | - |\n| c | d |';
    final LaidOutNote note = NoteLayoutEngine().layout(_inputs(source));
    expect(
      note.flow.fragments.where(
        (LineFragment fragment) => fragment.kind == FragmentKind.tableCell,
      ),
      hasLength(4),
    );
  });

  test('unused entries are evicted and clearCache empties the cache', () {
    final NoteLayoutEngine engine = NoteLayoutEngine();
    const String first = 'Alpha one\n\nBravo two\n\n# Charlie';
    const String second = 'Delta\n\nEcho';
    final LayoutInputs inputs = _inputs(first);
    engine.layout(inputs);
    engine.layout(_inputs(second));
    engine.layout(_inputs(first));
    expect(engine.lastRelaidBlocks, _allBlocks(inputs));
    engine.layout(_inputs(first));
    expect(engine.lastRelaidBlocks, isEmpty);
    engine.clearCache();
    engine.layout(_inputs(first));
    expect(engine.lastRelaidBlocks, _allBlocks(inputs));
  });
}
