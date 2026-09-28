import 'dart:ui' as ui;

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/float_flow.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_layout_engine.dart';
import 'package:field_notes/features/note_engine/layout/photo_planner.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const double _eps = 0.01;
const String _rightMedium = '![](photo/a1b2c3d4e5f6 "right medium")';
const String _leftMedium = '![](photo/a1b2c3d4e5f6 "left medium")';
const Size _threeTwo = Size(1200, 800);

LayoutInputs _inputs(
  String source, {
  double columnWidth = 688,
  Map<String, Size>? mediaDimensions,
  Set<String> unavailableMedia = const <String>{},
}) {
  final MdTree tree = parseNoteTree(source);
  return LayoutInputs(
    source: source,
    tree: tree,
    visibleText: const NoteVisibleProjector().project(source, tree, null),
    activeLine: null,
    columnWidth: columnWidth,
    textScaler: TextScaler.noScaling,
    boldText: false,
    locale: const ui.Locale('en', 'US'),
    readerMode: false,
    mediaDimensions:
        mediaDimensions ??
        <String, Size>{
          for (final MdBlock block in tree.blocks)
            if (block.kind == MdBlockKind.photoLine)
              MdPhotoLine.ofBlock(block, source).reference: _threeTwo,
        },
    unavailableMedia: unavailableMedia,
  );
}

NoteFlow _flow(
  String source, {
  double columnWidth = 688,
  Map<String, Size>? mediaDimensions,
  Set<String> unavailableMedia = const <String>{},
  RowLayouter rowLayouter = layoutRow,
  PhotoPlanner photoPlanner = planPhoto,
}) => flowNote(
  _inputs(
    source,
    columnWidth: columnWidth,
    mediaDimensions: mediaDimensions,
    unavailableMedia: unavailableMedia,
  ),
  rowLayouter: rowLayouter,
  photoPlanner: photoPlanner,
);

String _harbours(int count) => List<String>.filled(count, 'harbour').join(' ');

void _expectRect(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, _eps), reason: '$actual');
  expect(actual.top, closeTo(expected.top, _eps), reason: '$actual');
  expect(actual.width, closeTo(expected.width, _eps), reason: '$actual');
  expect(actual.height, closeTo(expected.height, _eps), reason: '$actual');
}

LaidOutRow _rowWithText(NoteFlow flow, String text) => flow.rows.firstWhere(
  (LaidOutRow row) => row.fragments.any(
    (LineFragment fragment) =>
        fragment.kind == FragmentKind.text &&
        flow.inputs.visibleText.text
            .substring(fragment.visibleRange.start, fragment.visibleRange.end)
            .contains(text),
  ),
);

LineFragment _textFragment(LaidOutRow row) => row.fragments.firstWhere(
  (LineFragment fragment) => fragment.kind == FragmentKind.text,
);

List<(LineFragment, VisualLine)> _contentLines(Iterable<LineFragment> all) =>
    <(LineFragment, VisualLine)>[
      for (final LineFragment fragment in all)
        if (fragment.kind == FragmentKind.text ||
            fragment.kind == FragmentKind.blankLine)
          for (final VisualLine line in fragment.lines) (fragment, line),
    ];

void _expectSameFlow(NoteFlow actual, NoteFlow expected) {
  expect(actual.rows.length, expected.rows.length);
  for (int i = 0; i < expected.rows.length; i++) {
    final LaidOutRow a = actual.rows[i];
    final LaidOutRow e = expected.rows[i];
    expect(a.row, e.row);
    expect(a.top, closeTo(e.top, _eps));
    expect(a.bottom, closeTo(e.bottom, _eps));
    expect(a.contentWidth, closeTo(e.contentWidth, _eps));
    _expectSameFragments(a.fragments, e.fragments);
    expect(a.decorations.length, e.decorations.length);
    for (int d = 0; d < e.decorations.length; d++) {
      expect(a.decorations[d].kind, e.decorations[d].kind);
      _expectRect(a.decorations[d].rect, e.decorations[d].rect);
    }
    expect(a.styleRuns, e.styleRuns);
  }
  expect(actual.photos.length, expected.photos.length);
  for (int i = 0; i < expected.photos.length; i++) {
    final PlacedPhoto a = actual.photos[i];
    final PlacedPhoto e = expected.photos[i];
    expect(a.reference, e.reference);
    expect(a.occurrence, e.occurrence);
    expect(a.sourceRange, e.sourceRange);
    expect(a.visibleRange, e.visibleRange);
    _expectRect(a.figureRect, e.figureRect);
    _expectRect(a.imageRect, e.imageRect);
  }
  expect(actual.height, closeTo(expected.height, _eps));
}

void _expectSameFragments(
  List<LineFragment> actual,
  List<LineFragment> expected,
) {
  expect(actual.length, expected.length);
  for (int f = 0; f < expected.length; f++) {
    final LineFragment a = actual[f];
    final LineFragment e = expected[f];
    expect(a.kind, e.kind);
    expect(a.rowIndex, e.rowIndex);
    expect(a.visibleRange, e.visibleRange);
    expect(a.besideFloat, e.besideFloat);
    expect(a.origin.dx, closeTo(e.origin.dx, _eps));
    expect(a.origin.dy, closeTo(e.origin.dy, _eps));
    expect(a.layoutWidth, closeTo(e.layoutWidth, _eps));
    expect(a.lines.length, e.lines.length);
    for (int l = 0; l < e.lines.length; l++) {
      expect(a.lines[l].visibleRange, e.lines[l].visibleRange);
      expect(a.lines[l].top, closeTo(e.lines[l].top, _eps));
      expect(a.lines[l].left, closeTo(e.lines[l].left, _eps));
    }
  }
}

List<double> _bandLineTops(String paragraph, double bandWidth) {
  final LayoutInputs inputs = _inputs(paragraph);
  return <double>[
    for (final (LineFragment _, VisualLine line) in _contentLines(
      layoutRow(
        inputs,
        layoutRowsOf(inputs).single,
        RowRegion(top: 0, left: 0, width: bandWidth, besideFloat: true),
      ).fragments,
    ))
      line.top,
  ];
}

double _firstTopReaching(List<double> tops, double threshold) =>
    tops.firstWhere((double top) => top >= threshold);

typedef _LayoutCall = ({
  int rowIndex,
  RowRegion region,
  int? visibleFrom,
  int? visibleTo,
});

LaidOutRow _tableStub(
  LayoutInputs inputs,
  LayoutRow row,
  RowRegion region, {
  int? visibleFrom,
  int? visibleTo,
}) {
  if (row.kind == LayoutRowKind.table) {
    return LaidOutRow(
      row: row,
      fragments: const <LineFragment>[],
      decorations: const <RowDecoration>[],
      top: region.top,
      bottom: region.top + 40,
      contentWidth: region.width,
    );
  }
  return layoutRow(
    inputs,
    row,
    region,
    visibleFrom: visibleFrom,
    visibleTo: visibleTo,
  );
}

void main() {
  test('a float top is anchored to the photo place whatever follows', () {
    const List<String> followers = <String>[
      '',
      'B',
      '[harbour](https://example.com) and more',
      '<https://example.com> and more',
      '# H',
      '- a\n- b',
      '- [ ] t',
      '> q',
      '\nB',
      '```\ncode\n```',
      '---',
      '![](photo/b2c3d4e5f6a1 "right medium")',
    ];
    for (final String follower in followers) {
      final String source =
          'A\n$_rightMedium${follower.isEmpty ? '' : '\n$follower'}';
      final NoteFlow flow = _flow(source, rowLayouter: _tableStub);
      expect(flow.photos.first.plan.mode, PhotoMode.floatRight, reason: source);
      _expectRect(
        flow.photos.first.figureRect,
        const Rect.fromLTWH(344, 38.4, 344, 229.33),
      );
    }
  });

  test('lines whose top is above the float bottom lie in the band', () {
    for (final (String photo, double bandLeft, double bandRight)
        in <(String, double, double)>[
          (_rightMedium, 0, 328),
          (_leftMedium, 360, 688),
        ]) {
      final NoteFlow flow = _flow('$photo\n${_harbours(150)}');
      final PlacedPhoto placed = flow.photos.single;
      expect(placed.figureRect.top, 0);
      expect(placed.figureRect.bottom, closeTo(229.33, _eps));
      final LaidOutRow paragraph = flow.rows.firstWhere(
        (LaidOutRow row) => row.row.kind == LayoutRowKind.text,
      );
      final List<(LineFragment, VisualLine)> lines = _contentLines(
        paragraph.fragments,
      );
      int beside = 0;
      int full = 0;
      double? firstFullTop;
      for (final (LineFragment fragment, VisualLine line) in lines) {
        if (line.top < 228.83) {
          beside++;
          expect(fragment.origin.dx, greaterThanOrEqualTo(bandLeft - _eps));
          expect(
            fragment.origin.dx + fragment.layoutWidth,
            lessThanOrEqualTo(bandRight + _eps),
          );
          expect(fragment.besideFloat, isTrue);
        } else {
          full++;
          firstFullTop ??= line.top;
          expect(fragment.origin.dx, 0);
          expect(fragment.layoutWidth, closeTo(688, _eps));
          expect(fragment.besideFloat, isFalse);
        }
      }
      expect(beside, greaterThan(0));
      expect(full, greaterThan(0));
      expect(
        firstFullTop,
        closeTo(
          _firstTopReaching(_bandLineTops(_harbours(150), 328), 228.83),
          _eps,
        ),
      );
    }
  });

  test('tables, code, dividers and photos start below an active float', () {
    const List<String> blocks = <String>[
      '```\ncode\n```',
      '---',
      '| a |\n| - |\n| b |',
      '![](photo/b2c3d4e5f6a1 "centre medium")',
    ];
    for (final String block in blocks) {
      final NoteFlow flow = _flow(
        'A\n$_rightMedium\nB\n$block',
        rowLayouter: _tableStub,
      );
      final LaidOutRow b = _rowWithText(flow, 'B');
      expect(b.top, closeTo(38.4, _eps), reason: block);
      expect(_textFragment(b).besideFloat, isTrue, reason: block);
      expect(b.bottom + 12.8, closeTo(76.8, _eps));
      final LaidOutRow x = flow.rows.last;
      expect(x.top, closeTo(280.53, _eps), reason: block);
      switch (x.row.kind) {
        case LayoutRowKind.code:
          final RowDecoration background = x.decorations.firstWhere(
            (RowDecoration d) => d.kind == RowDecorationKind.codeBackground,
          );
          expect(background.rect.left, 0);
          expect(background.rect.right, closeTo(688, _eps));
        case LayoutRowKind.divider:
          final RowDecoration rule = x.decorations.firstWhere(
            (RowDecoration d) => d.kind == RowDecorationKind.dividerRule,
          );
          expect(rule.rect.left, 0);
          expect(rule.rect.right, closeTo(688, _eps));
        case LayoutRowKind.table:
          expect(x.contentWidth, 688);
        case LayoutRowKind.photo:
          expect(flow.photos.last.figureRect.left, closeTo(172, _eps));
          expect(flow.photos.last.figureRect.top, closeTo(280.53, _eps));
        case LayoutRowKind.text:
        case LayoutRowKind.blankLine:
          fail('$block laid out as ${x.row.kind}');
      }
    }
  });

  test(
    'the same inputs give the same line breaks after any resize history',
    () {
      final String paragraph = _harbours(60);
      final String source =
          '![](photo/a1b2c3d4e5f6 "right large")\n'
          '${<String>[paragraph, paragraph, paragraph].join('\n\n')}';
      final NoteFlow fresh = _flow(source, columnWidth: 700);
      expect(fresh.photos.single.plan.floats, isTrue);
      expect(fresh.photos.single.plan.bandWidth, closeTo(217.33, _eps));
      final NoteLayoutEngine engine = NoteLayoutEngine();
      engine.layout(_inputs(source, columnWidth: 700));
      for (double width = 600; width <= 900; width += 10) {
        final NoteFlow swept = engine
            .layout(_inputs(source, columnWidth: width))
            .flow;
        expect(swept.photos.single.plan.floats, width >= 624);
        _expectSameFlow(swept, _flow(source, columnWidth: width));
      }
      final NoteFlow again = engine
          .layout(_inputs(source, columnWidth: 700))
          .flow;
      _expectSameFlow(again, fresh);
    },
  );

  test('a left float keeps every line beside it at x 360 or more', () {
    final NoteFlow flow = _flow(
      '$_leftMedium\n# Heading\n${_harbours(40)}\n\n- one\n- two\n\n> quoted',
    );
    final List<(LineFragment, VisualLine)> beside =
        <(LineFragment, VisualLine)>[
          for (final LineFragment fragment in flow.fragments)
            if (fragment.besideFloat)
              for (final VisualLine line in fragment.lines) (fragment, line),
        ];
    expect(beside, isNotEmpty);
    for (final (LineFragment fragment, VisualLine line) in beside) {
      expect(fragment.origin.dx, greaterThanOrEqualTo(360 - _eps));
      expect(line.left, greaterThanOrEqualTo(360 - _eps));
    }
  });

  test(
    'nothing beside a float starts inside the photo width plus the gutter',
    () {
      for (final String placement in <String>[
        'left small',
        'left medium',
        'left large',
        'right small',
        'right medium',
        'right large',
      ]) {
        final NoteFlow flow = _flow(
          '![](photo/a1b2c3d4e5f6 "$placement")\n# H\n- a\n  - b\n- [ ] t\n'
          '\n> q\n\n${_harbours(80)}',
        );
        final PlacedPhoto photo = flow.photos.single;
        final double gutterEdge = photo.plan.width + 16;
        final bool left = photo.plan.mode == PhotoMode.floatLeft;
        final Iterable<LineFragment> beside = flow.fragments.where(
          (LineFragment fragment) => fragment.besideFloat,
        );
        expect(beside, isNotEmpty, reason: placement);
        for (final LineFragment fragment in beside) {
          for (final VisualLine line in fragment.lines) {
            if (left) {
              expect(
                fragment.origin.dx,
                greaterThanOrEqualTo(gutterEdge - _eps),
              );
              expect(line.left, greaterThanOrEqualTo(gutterEdge - _eps));
            } else {
              expect(fragment.origin.dx, lessThan(688 - gutterEdge));
              expect(line.left, lessThan(688 - gutterEdge));
              expect(
                line.left + line.width,
                lessThanOrEqualTo(688 - gutterEdge + _eps),
              );
            }
          }
        }
        for (final LaidOutRow row in flow.rows) {
          for (final RowDecoration decoration in row.decorations) {
            if (decoration.rect.top < photo.figureRect.bottom - 0.5 &&
                row.fragments.any((LineFragment f) => f.besideFloat)) {
              if (left) {
                expect(
                  decoration.rect.left,
                  greaterThanOrEqualTo(gutterEdge - _eps),
                );
              } else {
                expect(decoration.rect.left, lessThan(688 - gutterEdge));
              }
            }
          }
        }
      }
    },
  );

  test('story 4 flows every short row beside a large left float', () {
    final NoteFlow flow = _flow(
      'A\n![](photo/a1b2c3d4e5f6 "left large")\n\nB\n\nC',
    );
    final PlacedPhoto photo = flow.photos.single;
    expect(photo.plan.mode, PhotoMode.floatLeft);
    _expectRect(photo.figureRect, const Rect.fromLTWH(0, 38.4, 458.67, 305.78));
    final List<LaidOutRow> after = flow.rows.sublist(photo.rowIndex + 1);
    expect(after.length, 4);
    expect(after.first.top, closeTo(38.4, _eps));
    expect(after.last.bottom, closeTo(38.4 + 102.4, _eps));
    for (final LaidOutRow row in after) {
      for (final LineFragment fragment in row.fragments) {
        expect(fragment.besideFloat, isTrue);
        expect(fragment.origin.dx, greaterThanOrEqualTo(474.67 - _eps));
      }
    }
    expect(flow.height, closeTo(344.18, _eps));
  });

  test('a float followed by nothing extends the height to its bottom', () {
    final NoteFlow flow = _flow('A\n$_rightMedium');
    expect(flow.rows.last.row.kind, LayoutRowKind.photo);
    expect(flow.height, closeTo(267.73, _eps));
    final NoteFlow short = _flow('A\n$_rightMedium\nB');
    expect(short.rows.last.bottom, closeTo(64, _eps));
    expect(short.height, closeTo(267.73, _eps));
  });

  test('a photo as the first block has its float top at 0', () {
    final NoteFlow flow = _flow('$_rightMedium\nB');
    expect(flow.photos.single.figureRect.top, 0);
    expect(flow.rows[1].top, 0);
  });

  test('a photo after a photo starts below the first one', () {
    final NoteFlow centred = _flow(
      '$_rightMedium\n![](photo/b2c3d4e5f6a1 "centre medium")\nB',
    );
    expect(centred.photos[1].figureRect.top, closeTo(229.33 + 12.8, _eps));
    final NoteFlow floated = _flow(
      '$_rightMedium\n![](photo/b2c3d4e5f6a1 "left medium")\nB',
    );
    final PlacedPhoto second = floated.photos[1];
    expect(second.plan.mode, PhotoMode.floatLeft);
    expect(second.figureRect.top, closeTo(242.13, _eps));
    final LaidOutRow b = _rowWithText(floated, 'B');
    expect(b.top, closeTo(242.13, _eps));
    final LineFragment text = _textFragment(b);
    expect(text.besideFloat, isTrue);
    expect(text.origin.dx, closeTo(360, _eps));
    final NoteFlow blocks = _flow(
      '![](photo/a1b2c3d4e5f6 "centre medium")\n'
      '![](photo/b2c3d4e5f6a1 "centre medium")',
    );
    expect(blocks.photos[1].figureRect.top, closeTo(229.33 + 12.8, _eps));
  });

  test(
    'lists and quotes beside a float keep their indentation in the band',
    () {
      const String list = '- a\n  - b\n- [ ] c';
      final NoteFlow plain = _flow(list);
      final NoteFlow beside = _flow('$_leftMedium\n$list');
      final List<LineFragment> plainFragments = plain.fragments.toList();
      final List<LineFragment> besideFragments = beside.fragments
          .where((LineFragment f) => f.kind != FragmentKind.photo)
          .toList();
      expect(besideFragments.length, plainFragments.length);
      for (int i = 0; i < plainFragments.length; i++) {
        expect(besideFragments[i].kind, plainFragments[i].kind);
        expect(besideFragments[i].besideFloat, isTrue);
        expect(
          besideFragments[i].origin.dx,
          closeTo(plainFragments[i].origin.dx + 360, _eps),
        );
      }
      const String quote = '> quoted\n> more';
      final NoteFlow plainQuote = _flow(quote);
      final NoteFlow besideQuote = _flow('$_leftMedium\n$quote');
      final List<RowDecoration> plainRules = <RowDecoration>[
        for (final LaidOutRow row in plainQuote.rows) ...row.decorations,
      ];
      final List<RowDecoration> besideRules = <RowDecoration>[
        for (final LaidOutRow row in besideQuote.rows) ...row.decorations,
      ];
      expect(plainRules, isNotEmpty);
      expect(besideRules.length, plainRules.length);
      for (int i = 0; i < plainRules.length; i++) {
        expect(besideRules[i].kind, RowDecorationKind.quoteRule);
        expect(
          besideRules[i].rect.left,
          closeTo(plainRules[i].rect.left + 360, _eps),
        );
      }
    },
  );

  test('a line at the float bottom minus 0.5 px uses the full column', () {
    final List<double> tops = _bandLineTops(_harbours(150), 328);
    final double reaching = _firstTopReaching(tops, 228.83);
    final double previous = tops[tops.indexOf(reaching) - 1];
    for (final (double floatHeight, bool reachingBeside) in <(double, bool)>[
      (reaching + 0.4, false),
      (reaching + 0.6, true),
    ]) {
      final NoteFlow flow = _flow(
        '$_rightMedium\n${_harbours(150)}',
        mediaDimensions: <String, Size>{'a1b2c3d4e5f6': Size(344, floatHeight)},
      );
      expect(flow.photos.single.figureRect.bottom, closeTo(floatHeight, 1e-6));
      final List<(LineFragment, VisualLine)> lines = _contentLines(
        flow.fragments,
      );
      final LineFragment above = lines
          .firstWhere(
            ((LineFragment, VisualLine) entry) =>
                (entry.$2.top - previous).abs() < _eps,
          )
          .$1;
      final LineFragment at = lines
          .firstWhere(
            ((LineFragment, VisualLine) entry) =>
                (entry.$2.top - reaching).abs() < _eps,
          )
          .$1;
      expect(above.besideFloat, isTrue);
      expect(above.layoutWidth, closeTo(328, _eps));
      expect(at.besideFloat, reachingBeside);
      expect(at.layoutWidth, closeTo(reachingBeside ? 328 : 688, _eps));
    }
  });

  test(
    'a row below the float bottom skips the band and a split row merges',
    () {
      final List<_LayoutCall> calls = <_LayoutCall>[];
      LaidOutRow recording(
        LayoutInputs inputs,
        LayoutRow row,
        RowRegion region, {
        int? visibleFrom,
        int? visibleTo,
      }) {
        calls.add((
          rowIndex: row.index,
          region: region,
          visibleFrom: visibleFrom,
          visibleTo: visibleTo,
        ));
        return layoutRow(
          inputs,
          row,
          region,
          visibleFrom: visibleFrom,
          visibleTo: visibleTo,
        );
      }

      final String shorts = List<String>.generate(
        8,
        (int i) => 'line $i',
      ).join('\n\n');
      final NoteFlow flow = _flow(
        '$_rightMedium\n$shorts',
        rowLayouter: recording,
      );
      final LaidOutRow below = flow.rows.firstWhere(
        (LaidOutRow row) => row.top >= 229.33 - 0.5,
      );
      final List<_LayoutCall> forBelow = calls
          .where((_LayoutCall call) => call.rowIndex == below.row.index)
          .toList();
      expect(forBelow.length, 1);
      expect(forBelow.single.region.besideFloat, isFalse);
      expect(forBelow.single.region.width, 688);
      for (final LaidOutRow row in flow.rows.skip(below.row.index + 1)) {
        expect(
          calls.where(
            (_LayoutCall call) =>
                call.rowIndex == row.row.index && call.region.besideFloat,
          ),
          isEmpty,
        );
      }

      calls.clear();
      final NoteFlow split = _flow(
        '$_rightMedium\n${_harbours(150)}',
        rowLayouter: recording,
      );
      final LaidOutRow merged = split.rows[1];
      final List<_LayoutCall> forMerged = calls
          .where((_LayoutCall call) => call.rowIndex == 1)
          .toList();
      expect(forMerged.length, 3);
      expect(forMerged[1].region.besideFloat, isTrue);
      expect(forMerged[1].visibleTo, isNotNull);
      expect(forMerged[2].region.besideFloat, isFalse);
      expect(forMerged[2].visibleFrom, forMerged[1].visibleTo);
      expect(
        forMerged[2].region.top,
        closeTo(
          _firstTopReaching(_bandLineTops(_harbours(150), 328), 228.83),
          _eps,
        ),
      );
      expect(merged.top, 0);
      expect(merged.contentWidth, 688);
      final LineFragment last = merged.fragments.last;
      expect(merged.bottom, closeTo(last.lines.last.box.bottom, _eps));
      expect(merged.fragments.first.besideFloat, isTrue);
      expect(last.besideFloat, isFalse);
      expect(
        merged.styleRuns.length,
        layoutRow(
          split.inputs,
          merged.row,
          const RowRegion(top: 0, left: 0, width: 688),
        ).styleRuns.length,
      );
    },
  );

  test('the photo planner is called once per photo row in document order', () {
    final List<(MdPhotoPlacement, double?, bool)> calls =
        <(MdPhotoPlacement, double?, bool)>[];
    final List<PhotoLayoutPlan> plans = <PhotoLayoutPlan>[];
    PhotoLayoutPlan recording({
      required MdPhotoPlacement placement,
      required double columnWidth,
      required TextScaler textScaler,
      double? aspect,
      bool unavailable = false,
      String caption = '',
      bool boldText = false,
      ui.Locale? locale,
    }) {
      calls.add((placement, aspect, unavailable));
      final PhotoLayoutPlan plan = planPhoto(
        placement: placement,
        columnWidth: columnWidth,
        textScaler: textScaler,
        aspect: aspect,
        unavailable: unavailable,
        caption: caption,
        boldText: boldText,
        locale: locale,
      );
      plans.add(plan);
      return plan;
    }

    final NoteFlow flow = _flow(
      '![](photo/a1b2c3d4e5f6 "left small")\nA\n'
      '![](photo/b2c3d4e5f6a1 "centre large")\nB\n'
      '![](photo/c3d4e5f6a1b2 "right medium")',
      mediaDimensions: const <String, Size>{
        'a1b2c3d4e5f6': Size(1200, 800),
        'c3d4e5f6a1b2': Size(800, 800),
      },
      unavailableMedia: const <String>{'b2c3d4e5f6a1'},
      photoPlanner: recording,
    );
    expect(calls.length, 3);
    expect(
      calls.map(((MdPhotoPlacement, double?, bool) c) => c.$1.side),
      <MdPhotoSide>[MdPhotoSide.left, MdPhotoSide.centre, MdPhotoSide.right],
    );
    expect(calls[0].$2, closeTo(1.5, 1e-9));
    expect(calls[1].$2, isNull);
    expect(calls[1].$3, isTrue);
    expect(calls[2].$2, 1);
    expect(calls[2].$3, isFalse);
    for (int i = 0; i < 3; i++) {
      expect(flow.photos[i].plan, plans[i]);
    }
  });

  test('centred and full photos are blocks with touching gaps', () {
    final NoteFlow medium = _flow(
      'A\n![](photo/a1b2c3d4e5f6 "centre medium")\nB',
    );
    final PlacedPhoto photo = medium.photos.single;
    _expectRect(photo.figureRect, const Rect.fromLTWH(172, 38.4, 344, 229.33));
    expect(
      _rowWithText(medium, 'B').top,
      closeTo(photo.figureRect.bottom + 12.8, _eps),
    );
    final NoteFlow full = _flow(
      'A\n![](photo/a1b2c3d4e5f6 "centre full")\n# H',
    );
    final PlacedPhoto wide = full.photos.single;
    _expectRect(wide.figureRect, const Rect.fromLTWH(0, 38.4, 688, 458.67));
    expect(full.rows.last.top, closeTo(wide.figureRect.bottom + 19.2, _eps));
    final NoteFlow fullRight = _flow(
      'A\n![](photo/a1b2c3d4e5f6 "right full")\nB',
    );
    expect(fullRight.photos.single.plan.mode, PhotoMode.centred);
    expect(
      fullRight.rows.last.top,
      closeTo(fullRight.photos.single.figureRect.bottom + 12.8, _eps),
    );
  });

  test('invalid placements, missing media and bad references', () {
    final NoteFlow invalid = _flow(
      'A\n![](photo/a1b2c3d4e5f6 "sideways huge")\nB',
    );
    final PlacedPhoto centred = invalid.photos.single;
    expect(centred.plan.mode, PhotoMode.centred);
    _expectRect(
      centred.figureRect,
      const Rect.fromLTWH(172, 38.4, 344, 229.33),
    );
    final NoteFlow missing = _flow(
      'A\n$_rightMedium\nB',
      unavailableMedia: const <String>{'a1b2c3d4e5f6'},
    );
    final PlacedPhoto gone = missing.photos.single;
    expect(gone.plan.isUnavailable, isTrue);
    expect(gone.plan.mode, PhotoMode.centred);
    _expectRect(gone.figureRect, const Rect.fromLTWH(172, 38.4, 344, 56));
    expect(_rowWithText(missing, 'B').top, closeTo(38.4 + 56 + 12.8, _eps));
    final NoteFlow upper = _flow(
      'A\n![](photo/ABC123ABC123)\nB',
      mediaDimensions: const <String, Size>{'ABC123ABC123': _threeTwo},
    );
    final PlacedPhoto bad = upper.photos.single;
    expect(bad.reference, 'ABC123ABC123');
    expect(bad.plan.isUnavailable, isTrue);
    expect(bad.figureRect.height, 56);
    final NoteFlow short = _flow('![](photo/abc123 "left medium")');
    expect(short.photos.single.plan.isUnavailable, isTrue);
    expect(short.photos.single.figureRect.height, 56);
  });

  test('a photo with unknown dimensions plans the 3:2 placeholder', () {
    final NoteFlow flow = _flow(
      'A\n![](photo/a1b2c3d4e5f6 "centre medium")',
      mediaDimensions: const <String, Size>{},
    );
    final PlacedPhoto photo = flow.photos.single;
    expect(photo.plan.isPlaceholder, isTrue);
    expect(photo.figureRect.height, closeTo(344 / 1.5, _eps));
    _expectRect(photo.imageRect, photo.figureRect);
  });

  test('a phone column reads text, a full-width image, then text', () {
    final NoteFlow flow = _flow('A\n$_rightMedium\nB', columnWidth: 350);
    final PlacedPhoto photo = flow.photos.single;
    expect(photo.plan.mode, PhotoMode.centred);
    _expectRect(photo.figureRect, Rect.fromLTWH(0, 38.4, 350, 350 / 1.5));
    final LaidOutRow b = _rowWithText(flow, 'B');
    expect(b.top, closeTo(photo.figureRect.bottom + 12.8, _eps));
    expect(_textFragment(b).besideFloat, isFalse);
    expect(_textFragment(b).layoutWidth, 350);
  });

  test('a note without photos or tables equals stackRows', () {
    const List<String> sources = <String>[
      '',
      'A',
      'A\n\nB',
      '# Title\nBody text\n- a\n  - b\n- [x] done\n\n> quote\n> more\n'
          '```\ncode\n```\n---\nlast',
    ];
    for (final String source in sources) {
      final LayoutInputs inputs = _inputs(source);
      final NoteFlow flow = flowNote(inputs);
      final List<LaidOutRow> stacked = stackRows(inputs, layoutRowsOf(inputs));
      expect(flow.rows.length, stacked.length);
      for (int i = 0; i < stacked.length; i++) {
        expect(flow.rows[i].row, stacked[i].row);
        expect(flow.rows[i].top, stacked[i].top);
        expect(flow.rows[i].bottom, stacked[i].bottom);
        expect(flow.rows[i].decorations, stacked[i].decorations);
        _expectSameFragments(flow.rows[i].fragments, stacked[i].fragments);
      }
      expect(flow.photos, isEmpty);
      expect(flow.height, stacked.isEmpty ? 0 : stacked.last.bottom);
    }
  });

  test('repeated references get occurrences in document order', () {
    final NoteFlow flow = _flow(
      '![](photo/a1b2c3d4e5f6)\nA\n![](photo/b2c3d4e5f6a1)\nB\n'
      '![](photo/a1b2c3d4e5f6 "left small")\n\n'
      '![](photo/a1b2c3d4e5f6)',
    );
    expect(
      flow.photos.map((PlacedPhoto p) => (p.reference, p.occurrence)),
      <(String, int)>[
        ('a1b2c3d4e5f6', 0),
        ('b2c3d4e5f6a1', 0),
        ('a1b2c3d4e5f6', 1),
        ('a1b2c3d4e5f6', 2),
      ],
    );
    for (final PlacedPhoto photo in flow.photos) {
      expect(
        flow.inputs.visibleText.text.substring(
          photo.visibleRange.start,
          photo.visibleRange.end,
        ),
        '\u{FFFC}',
      );
      expect(
        flow.inputs.source.substring(
          photo.sourceRange.start,
          photo.sourceRange.end,
        ),
        startsWith('![](photo/'),
      );
      expect(flow.rows[photo.rowIndex].row.kind, LayoutRowKind.photo);
    }
  });

  test('rowsIntersecting matches a linear scan', () {
    final NoteFlow flow = _flow(
      'A\n$_rightMedium\nB\n\nC\n\n${_harbours(90)}\n\n'
      '![](photo/b2c3d4e5f6a1 "left large")\nD\n```\ncode\n```\nE\n'
      '![](photo/c3d4e5f6a1b2 "centre small")\nF',
    );
    final double height = flow.height;
    final List<(double, double)> bands = <(double, double)>[
      (-100, -1),
      (0, 0),
      (0, 10),
      (50, 60),
      (100, 120),
      (240, 260),
      (267, 300),
      (300, 700),
      (height - 5, height + 100),
      (height + 1, height + 100),
      (-10, height + 10),
    ];
    for (double top = 0; top < height; top += 37.5) {
      bands.add((top, top + 90));
    }
    for (final (double top, double bottom) in bands) {
      final List<LaidOutRow> expected = <LaidOutRow>[
        for (final LaidOutRow row in flow.rows)
          if (row.top <= bottom && row.bottom >= top) row,
      ];
      expect(
        flow.rowsIntersecting(top, bottom).map((LaidOutRow r) => r.row.index),
        expected.map((LaidOutRow r) => r.row.index),
        reason: '[$top, $bottom]',
      );
    }
    final PlacedPhoto float = flow.photos.first;
    final double inside = float.figureRect.bottom - 10;
    final List<LaidOutRow> found = flow.rowsIntersecting(inside, inside + 5);
    expect(found.first.row.index, float.rowIndex);
  });

  test('a photo row holds one photo fragment and one photoLine run', () {
    final NoteFlow flow = _flow('A\n$_rightMedium\nB');
    final PlacedPhoto photo = flow.photos.single;
    final LaidOutRow row = flow.rows[photo.rowIndex];
    expect(row.top, photo.figureRect.top);
    expect(row.bottom, photo.figureRect.bottom);
    expect(row.contentWidth, photo.plan.width);
    expect(row.decorations, isEmpty);
    expect(row.styleRuns, <({TextRange visibleRange, String styleKind})>[
      (visibleRange: photo.visibleRange, styleKind: 'photoLine'),
    ]);
    final LineFragment fragment = row.fragments.single;
    expect(fragment.kind, FragmentKind.photo);
    expect(fragment.paragraph, isNull);
    expect(fragment.rect, photo.figureRect);
    expect(fragment.visibleRange, photo.visibleRange);
    expect(fragment.lines.single.box, photo.figureRect);
    _expectRect(photo.imageRect, photo.figureRect);
    expect(() => flow.rows.add(row), throwsUnsupportedError);
    expect(() => flow.photos.add(photo), throwsUnsupportedError);
  });
}
