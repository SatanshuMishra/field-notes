import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/widgets/widgets.dart' show NoteMeasureScope;
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/entry_cards/media/media_image.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/capabilities.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_layout_engine.dart';
import 'package:field_notes/features/note_engine/layout/note_typography.dart';
import 'package:field_notes/features/note_engine/layout/photo_planner.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteReaderView;
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:field_notes/features/note_engine/render/photo_figure.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';
import 'package:field_notes/features/notes/render/note_photo_block.dart'
    show NoteMediaScope;

import '../../../support/photo_line_fixture.dart';
import '../../notes/support/notes_harness.dart'
    show
        FakeNoteMediaResolver,
        availablePhoto,
        photoBlob,
        photoIdA,
        photoIdB,
        prefixOf;

const String _prose =
    'The tide came in slowly over the flats this morning, '
    'and the herons stood in a line along the channel as if waiting for a '
    'signal. We walked out as far as the **old pilings**, where the mud '
    'gives way to shell, and sat on the driftwood log that has been there '
    'since the storm in March. *Nothing moved for a long time.* Then the '
    'light changed, the water turned from grey to a dull green, and the '
    'birds lifted all at once and went north over the dunes. On the way back '
    'we found a whelk shell, perfect and empty, half buried in the sand near '
    'the boardwalk, and a single blue mussel still closed tight. The wind '
    'had dropped by then and the whole marsh smelled of salt and cut grass.';

const String _planFile = 'note_photo_plan_test.dart';
const String _wrapFile = 'photo_wrap_block_test.dart';

final String _a = mdPhotoLine(photoIdA);

final String _proseVisible = _prose.replaceAll('**', '').replaceAll('*', '');

String _note({
  MdPhotoSide side = MdPhotoSide.right,
  MdPhotoSize size = MdPhotoSize.medium,
  String caption = '',
  String after = _prose,
}) =>
    '${mdPhotoLine(photoIdA, side: side, size: size, caption: caption)}\n'
    '$after';

LaidOutNote _layout(
  String source, {
  double width = 560,
  double scale = 1,
  Map<String, Size>? dimensions,
  Set<String> unavailable = const <String>{},
  bool readerMode = true,
}) {
  final MdTree tree = parseNoteTree(source, tables: tablesEnabled);
  return NoteLayoutEngine(projector: const NoteVisibleProjector()).layout(
    LayoutInputs(
      source: source,
      tree: tree,
      visibleText: const NoteVisibleProjector().project(source, tree, null),
      activeLine: null,
      columnWidth: width,
      textScaler: TextScaler.linear(scale),
      boldText: false,
      locale: const Locale('en'),
      readerMode: readerMode,
      mediaDimensions:
          dimensions ??
          <String, Size>{
            prefixOf(photoIdA): const Size(1200, 800),
            prefixOf(photoIdB): const Size(1200, 800),
          },
      unavailableMedia: unavailable,
    ),
  );
}

int _paragraphIndex(NoteLayout layout) => layout.inputs.tree.blocks.indexWhere(
  (MdBlock block) => block.kind == MdBlockKind.paragraph,
);

int _paragraphStart(NoteLayout layout) =>
    layout.inputs.tree.blocks[_paragraphIndex(layout)].sourceRange.start;

List<FragmentInfo> _paragraph(NoteLayout layout) {
  final int index = _paragraphIndex(layout);
  return <FragmentInfo>[
    for (final FragmentInfo fragment in layout.fragments)
      if (fragment.blockIndex == index) fragment,
  ];
}

List<FragmentInfo> _blockFragments(NoteLayout layout, int index) =>
    <FragmentInfo>[
      for (final FragmentInfo fragment in layout.fragments)
        if (fragment.blockIndex == index) fragment,
    ];

List<int> _breaks(List<FragmentInfo> fragments, int start) => <int>[
  for (final FragmentInfo fragment in fragments)
    fragment.sourceRange.start - start,
];

List<MdRange> _sourceRanges(NoteLayout layout) => <MdRange>[
  for (final FragmentInfo fragment in layout.fragments) fragment.sourceRange,
];

PhotoLayoutPlan _plan(
  MdPhotoSize size, {
  double column = 560,
  double em = 16,
  MdPhotoSide side = MdPhotoSide.right,
  double? aspect = 1.5,
}) => planPhoto(
  placement: MdPhotoPlacement(side: side, size: size),
  columnWidth: column,
  textScaler: TextScaler.linear(em / 16),
  aspect: aspect,
);

FakeNoteMediaResolver _resolver({
  int? width = 1200,
  int? height = 800,
  bool memoized = true,
}) {
  final FakeNoteMediaResolver resolver = FakeNoteMediaResolver(
    <String, ResolvedMedia>{
      prefixOf(photoIdA): availablePhoto(
        photoIdA,
        width: width,
        height: height,
      ),
    },
  );
  return memoized ? (resolver..memoizeAll()) : resolver;
}

void _pinSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _readerApp(
  String source, {
  double width = 560,
  double scale = 1,
  MediaResolver? resolver,
  bool fillsWidth = false,
}) => MaterialApp(
  home: Material(
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: NoteMeasureScope(
              fillsWidth: fillsWidth,
              child: NoteMediaScope(
                resolver: resolver ?? _resolver(),
                child: NoteReaderView(source: source),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _pumpReader(
  WidgetTester tester,
  String source, {
  double width = 560,
  double scale = 1,
  MediaResolver? resolver,
  bool fillsWidth = false,
}) async {
  _pinSurface(tester);
  await tester.pumpWidget(
    _readerApp(
      source,
      width: width,
      scale: scale,
      resolver: resolver,
      fillsWidth: fillsWidth,
    ),
  );
  await tester.pump();
  await tester.pump();
}

RenderNoteView _view(WidgetTester tester) =>
    tester.renderObject<RenderNoteView>(
      find.descendant(
        of: find.byType(NoteReaderView),
        matching: find.byType(NoteViewBody),
      ),
    );

double _readerLeft(WidgetTester tester) =>
    tester.getTopLeft(find.byType(NoteReaderView)).dx;

void _expectRect(
  Rect actual,
  Rect expected,
  String why, {
  double within = 0.01,
}) {
  expect(actual.left, closeTo(expected.left, within), reason: '$why left');
  expect(actual.top, closeTo(expected.top, within), reason: '$why top');
  expect(actual.width, closeTo(expected.width, within), reason: '$why width');
  expect(
    actual.height,
    closeTo(expected.height, within),
    reason: '$why height',
  );
}

double _textWidth(String text, TextStyle style) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final double width = painter.width;
  painter.dispose();
  return width;
}

List<MethodCall> _captureClipboard(WidgetTester tester) {
  final List<MethodCall> log = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      log.add(call);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return log;
}

Future<void> _pressWithControl(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  await tester.pump();
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
  await tester.pumpAndSettle();
}

String _copiedText(List<MethodCall> log) {
  final MethodCall call = log.lastWhere(
    (MethodCall c) => c.method == 'Clipboard.setData',
  );
  return (call.arguments as Map<Object?, Object?>)['text']! as String;
}

const List<int> _decodablePng = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  8,
  0,
  0,
  0,
  6,
  8,
  2,
  0,
  0,
  0,
  113,
  103,
  72,
  172,
  0,
  0,
  0,
  17,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  56,
  145,
  98,
  132,
  21,
  49,
  12,
  164,
  4,
  0,
  87,
  179,
  65,
  161,
  177,
  232,
  96,
  55,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];

void main() {
  group('note_photo_plan_test.dart', () {
    test('is the size fraction of the measure, never an em value', () {
      const String why = '$_planFile: is the size fraction of the measure; L3';
      final Map<MdPhotoSize, double> expected = <MdPhotoSize, double>{
        MdPhotoSize.small: 240,
        MdPhotoSize.medium: 360,
        MdPhotoSize.large: 480,
        MdPhotoSize.full: 720,
      };
      for (final MdPhotoSize size in MdPhotoSize.values) {
        expect(
          photoWidthFor(size, columnWidth: 720, em: 16),
          closeTo(expected[size]!, 1e-9),
          reason: '$why ${size.name}',
        );
      }
    });

    test('gives four visibly distinct widths at a 320pt phone measure', () {
      const String why = '$_planFile: four distinct widths at 320; L4';
      for (final MdPhotoSize size in MdPhotoSize.values) {
        expect(
          photoWidthFor(size, columnWidth: 320, em: 16),
          closeTo(320, 1e-9),
          reason: '$why ${size.name}',
        );
      }
    });

    test('stacks whenever the next block is not a paragraph, whatever the '
        'measure', () {
      const String why =
          '$_planFile: stacks whenever the next block is not a paragraph; '
          'L5, a photo never changes size or side because of what follows';
      final List<String> followers = <String>[
        '',
        'a paragraph',
        '# a heading',
        '- a list',
        '- [ ] a task',
        '> a quote',
        '\nafter a blank line',
        '```\ncode\n```',
        '---',
        mdPhotoLine(photoIdB),
      ];
      for (final String next in followers) {
        final PhotoRect photo = _layout('$_a\n$next').photoRects.first;
        _expectRect(
          photo.rect,
          const Rect.fromLTWH(280, 0, 280, 186.67),
          '$why [$next]',
        );
        expect(photo.flow, PhotoFlow.floatRight, reason: '$why [$next]');
      }
    });

    test('a stacked plan gives the text the whole measure', () {
      const String why =
          '$_planFile: a stacked plan gives the whole measure; '
          'L4, L5';
      final LaidOutNote layout = _layout(_note(size: MdPhotoSize.full));
      final PhotoRect photo = layout.photoRects.single;
      expect(photo.flow, PhotoFlow.block, reason: why);
      expect(photo.rect.width, closeTo(560, 0.01), reason: why);
      expect(photo.rect.height, closeTo(373.33, 0.01), reason: why);
      final List<FragmentInfo> paragraph = _paragraph(layout);
      for (final FragmentInfo fragment in paragraph) {
        expect(fragment.lineBox.rect.left, closeTo(0, 0.01), reason: why);
      }
      final LaidOutNote alone = _layout(_prose);
      expect(
        _breaks(paragraph, _paragraphStart(layout)),
        _breaks(_paragraph(alone), _paragraphStart(alone)),
        reason: why,
      );
    });

    test('follows the aspect ratio for a landscape photo', () {
      const String why = '$_planFile: follows the aspect ratio; unchanged';
      final PhotoLayoutPlan plan = _plan(
        MdPhotoSize.full,
        column: 320,
        aspect: 2,
      );
      expect(plan.width, closeTo(320, 1e-9), reason: why);
      expect(plan.photoHeight, closeTo(160, 1e-9), reason: why);
    });

    test('clamps a tall portrait photo to 1.6 times its width', () {
      const String why = '$_planFile: clamps a tall portrait; unchanged';
      final PhotoLayoutPlan plan = _plan(MdPhotoSize.medium, aspect: 9 / 16);
      expect(plan.photoHeight, closeTo(448, 1e-9), reason: why);
      expect(plan.photoHeight, lessThan(280 / (9 / 16)), reason: why);
    });

    test('falls back to 3:2 when the dimensions are unknown or nonsense', () {
      const String why = '$_planFile: falls back to 3:2; L3';
      for (final Size? dimensions in <Size?>[
        null,
        const Size(1200, 0),
        const Size(0, 800),
        const Size(-1, 800),
      ]) {
        expect(photoAspectFor(dimensions), isNull, reason: '$why $dimensions');
      }
      final PhotoLayoutPlan plan = _plan(
        MdPhotoSize.full,
        column: 320,
        aspect: null,
      );
      expect(plan.width, closeTo(320, 1e-9), reason: why);
      expect(plan.photoHeight, closeTo(213.33, 0.01), reason: why);
      expect(plan.isPlaceholder, isTrue, reason: why);
    });

    test('an unbounded or broken measure plans an empty box, not a crash', () {
      const String why = '$_planFile: an unbounded measure; L1';
      final double column = noteColumnWidth(
        availableWidth: double.infinity,
        textScaler: TextScaler.noScaling,
      );
      expect(column, 720, reason: why);
      expect(
        () => _plan(MdPhotoSize.medium, column: column),
        returnsNormally,
        reason: why,
      );
      expect(
        _plan(MdPhotoSize.medium, column: column).width,
        closeTo(360, 1e-9),
        reason: why,
      );
    });

    test('a phone measure cannot float and a desktop measure can', () {
      const String why = '$_planFile: phone versus desktop measure; L4';
      expect(isDesktopColumn(columnWidth: 320, em: 16), isFalse, reason: why);
      expect(isDesktopColumn(columnWidth: 360, em: 16), isFalse, reason: why);
      expect(isDesktopColumn(columnWidth: 560, em: 16), isTrue, reason: why);
      expect(
        photoCanFloat(size: MdPhotoSize.medium, columnWidth: 560, em: 16),
        isTrue,
        reason: why,
      );
    });

    test('the gate sits at 28.9 em of measure', () {
      const String why = '$_planFile: the gate; L4 moves it to 30 em';
      expect(isDesktopColumn(columnWidth: 480, em: 16), isTrue, reason: why);
      expect(
        isDesktopColumn(columnWidth: 479.99, em: 16),
        isFalse,
        reason: why,
      );
    });

    test('is scale invariant: 1.5x text on a 1280 window still floats', () {
      const String why = '$_planFile: scale invariant gate; L4';
      expect(isDesktopColumn(columnWidth: 840, em: 24), isTrue, reason: why);
      expect(
        photoCanFloat(size: MdPhotoSize.medium, columnWidth: 840, em: 24),
        isTrue,
        reason: why,
      );
      expect(isDesktopColumn(columnWidth: 560, em: 24), isFalse, reason: why);
    });

    test('the plan carries the same answer the gate gives', () {
      const String why = '$_planFile: the plan carries the gate; L4';
      final PhotoLayoutPlan phone = _plan(MdPhotoSize.medium, column: 320);
      expect(phone.floats, isFalse, reason: why);
      expect(phone.width, closeTo(320, 1e-9), reason: why);
      expect(_plan(MdPhotoSize.medium).floats, isTrue, reason: why);
    });

    test(
      'Side applies only where the measure floats and the size is not Full',
      () {
        const String why = '$_planFile: where Side applies; P1, L4';
        expect(
          photoCanFloat(size: MdPhotoSize.medium, columnWidth: 320, em: 16),
          isFalse,
          reason: why,
        );
        expect(
          photoCanFloat(size: MdPhotoSize.medium, columnWidth: 560, em: 16),
          isTrue,
          reason: why,
        );
        expect(
          photoCanFloat(size: MdPhotoSize.full, columnWidth: 560, em: 16),
          isFalse,
          reason: why,
        );
      },
    );

    test('sizes float in em: Small 8.5, Medium 12, Large 14.5, Full never', () {
      const String why = '$_planFile: size fractions; L3';
      expect(MdPhotoSize.small.fraction, closeTo(1 / 3, 1e-12), reason: why);
      expect(MdPhotoSize.medium.fraction, closeTo(1 / 2, 1e-12), reason: why);
      expect(MdPhotoSize.large.fraction, closeTo(2 / 3, 1e-12), reason: why);
      expect(MdPhotoSize.full.fraction, 1.0, reason: why);
      expect(
        photoCanFloat(size: MdPhotoSize.full, columnWidth: 2000, em: 16),
        isFalse,
        reason: why,
      );
    });

    test('Medium floats at 192pt beside a 352pt band on a 560 measure', () {
      const String why = '$_planFile: Medium on 560; L3';
      final PhotoLayoutPlan plan = _plan(MdPhotoSize.medium);
      expect(plan.mode, PhotoMode.floatRight, reason: why);
      expect(plan.width, closeTo(280, 0.01), reason: why);
      expect(plan.photoHeight, closeTo(186.67, 0.01), reason: why);
      expect(plan.bandWidth, closeTo(264, 0.01), reason: why);
    });

    test('is scale invariant: 1.5x text on an 840 measure floats Medium at '
        '288 beside 528', () {
      const String why = '$_planFile: Medium on 840 at 1.5x; L3';
      final PhotoLayoutPlan plan = _plan(
        MdPhotoSize.medium,
        column: 840,
        em: 24,
      );
      expect(plan.floats, isTrue, reason: why);
      expect(plan.width, closeTo(420, 1e-9), reason: why);
      expect(plan.bandWidth, closeTo(396, 1e-9), reason: why);
    });

    test(
      'shrinks before it demotes: 192 holds to 518.4, then 136 at 462.4',
      () {
        const String why =
            '$_planFile: shrink before demote; L4 has no '
            'shrinking';
        for (final double column in <double>[518.4, 490, 480]) {
          final PhotoLayoutPlan plan = _plan(
            MdPhotoSize.medium,
            column: column,
          );
          expect(plan.floats, isTrue, reason: '$why $column');
          expect(plan.width, closeTo(column / 2, 1e-9), reason: '$why $column');
        }
        final PhotoLayoutPlan phone = _plan(MdPhotoSize.medium, column: 479.99);
        expect(phone.mode, PhotoMode.centred, reason: why);
        expect(phone.width, closeTo(479.99, 1e-9), reason: why);
      },
    );

    test('a shrinking photo keeps the band at the 19.4 em residual', () {
      const String why = '$_planFile: the band residual; L4';
      final PhotoLayoutPlan wide = _plan(MdPhotoSize.large, column: 630);
      expect(wide.floats, isTrue, reason: why);
      expect(wide.width, closeTo(420, 1e-9), reason: why);
      expect(wide.bandWidth, closeTo(194, 1e-9), reason: why);
      expect(wide.bandWidth / 16, closeTo(12.125, 1e-9), reason: why);
      final PhotoLayoutPlan narrow = _plan(MdPhotoSize.large, column: 620);
      expect(narrow.mode, PhotoMode.centred, reason: why);
      expect(narrow.width, closeTo(413.33, 0.01), reason: why);
    });

    test('Full never floats', () {
      const String why = '$_planFile: Full never floats; unchanged';
      for (final double column in <double>[560, 840, 2000]) {
        final PhotoLayoutPlan plan = _plan(MdPhotoSize.full, column: column);
        expect(plan.mode, PhotoMode.centred, reason: '$why $column');
        expect(plan.width, closeTo(column, 1e-9), reason: '$why $column');
      }
    });

    test('missing or unreadable dimensions never float', () {
      const String why = '$_planFile: missing dimensions; L3, L4';
      final PhotoLayoutPlan plan = _plan(MdPhotoSize.medium, aspect: null);
      expect(plan.mode, PhotoMode.floatRight, reason: why);
      expect(plan.width, closeTo(280, 0.01), reason: why);
      expect(plan.photoHeight, closeTo(186.67, 0.01), reason: why);
      expect(plan.isPlaceholder, isTrue, reason: why);
    });

    test('a panorama too short to hold one line of text stacks', () {
      const String why =
          '$_planFile: short panorama; section 8, extreme '
          'panorama';
      final PhotoLayoutPlan medium = _plan(MdPhotoSize.medium, aspect: 7.6);
      expect(medium.floats, isTrue, reason: why);
      expect(medium.width, closeTo(280, 0.01), reason: why);
      expect(medium.photoHeight, closeTo(36.84, 0.01), reason: why);
      final PhotoLayoutPlan small = _plan(MdPhotoSize.small, aspect: 6);
      expect(small.floats, isTrue, reason: why);
      expect(small.width, closeTo(186.67, 0.01), reason: why);
      expect(small.photoHeight, closeTo(31.11, 0.01), reason: why);
    });

    test('a floated portrait is clamped to 1.6 times its width', () {
      const String why = '$_planFile: floated portrait clamp; unchanged';
      final PhotoLayoutPlan plan = _plan(MdPhotoSize.medium, aspect: 9 / 16);
      expect(plan.floats, isTrue, reason: why);
      expect(plan.width, closeTo(280, 1e-9), reason: why);
      expect(plan.photoHeight, closeTo(448, 1e-9), reason: why);
    });

    test('Side applies wherever the plan could float', () {
      const String why = '$_planFile: Side applies where it floats; L4';
      expect(
        photoCanFloat(size: MdPhotoSize.medium, columnWidth: 560, em: 16),
        isTrue,
        reason: why,
      );
      expect(
        photoCanFloat(size: MdPhotoSize.medium, columnWidth: 400, em: 16),
        isFalse,
        reason: why,
      );
    });

    test('is the width up to 35 em and pins there', () {
      const String why = '$_planFile: the measure; L1 changes 35 em to 45 em';
      expect(
        noteColumnWidth(availableWidth: 320, textScaler: TextScaler.noScaling),
        320,
        reason: why,
      );
      expect(
        noteColumnWidth(availableWidth: 1280, textScaler: TextScaler.noScaling),
        720,
        reason: why,
      );
      expect(
        noteColumnWidth(
          availableWidth: 1280,
          textScaler: const TextScaler.linear(1.5),
        ),
        1080,
        reason: why,
      );
      expect(
        noteColumnWidth(
          availableWidth: double.infinity,
          textScaler: TextScaler.noScaling,
        ),
        720,
        reason: why,
      );
    });

    test('reads real dimensions and rejects missing ones', () {
      const String why = '$_planFile: reads real dimensions; L3';
      expect(photoAspectFor(const Size(1200, 800)), 1.5, reason: why);
      expect(photoAspectFor(null), isNull, reason: why);
      expect(photoAspectFor(const Size(1200, 0)), isNull, reason: why);
      final PhotoLayoutPlan plan = _plan(
        MdPhotoSize.medium,
        column: 720,
        aspect: photoAspectFor(const Size(1200, 900)),
      );
      expect(plan.width, closeTo(360, 1e-9), reason: why);
      expect(plan.photoHeight, closeTo(270, 1e-9), reason: why);
    });
  });

  group('photo_wrap_block_test.dart', () {
    testWidgets('fills its frame, with no mount taken off it', (
      WidgetTester tester,
    ) async {
      const String why = '$_wrapFile: fills its frame; P12, unchanged';
      await _pumpReader(tester, _note());
      final Size frame = tester.getSize(find.byKey(photoFigureFrameKey));
      final Size picture = tester.getSize(
        find.descendant(
          of: find.byType(PhotoFigure),
          matching: find.byType(MediaImage),
        ),
      );
      expect(picture.width, closeTo(frame.width, 0.01), reason: why);
      expect(picture.height, closeTo(frame.height, 0.01), reason: why);
      expect(frame.width, closeTo(280, 0.01), reason: why);
      expect(frame.height, closeTo(186.67, 0.01), reason: why);
    });

    test('a right photo before a paragraph renders as a Row of head and photo '
        'with the tail below', () {
      const String why = '$_wrapFile: a right photo before a paragraph; L5';
      final LaidOutNote layout = _layout(_note());
      final PhotoRect photo = layout.photoRects.single;
      _expectRect(photo.rect, const Rect.fromLTWH(280, 0, 280, 186.67), why);
      expect(photo.flow, PhotoFlow.floatRight, reason: why);
      final List<FragmentInfo> paragraph = _paragraph(layout);
      expect(paragraph.first.lineBox.rect.left, closeTo(0, 0.01), reason: why);
      expect(paragraph.first.lineBox.rect.top, closeTo(0, 0.01), reason: why);
      int beside = 0;
      int below = 0;
      for (final FragmentInfo fragment in paragraph) {
        final Rect line = fragment.lineBox.rect;
        if (line.top < 186.17) {
          beside += 1;
          expect(fragment.besideFloat, isTrue, reason: '$why $fragment');
          expect(line.right, lessThanOrEqualTo(264.01), reason: '$why $line');
        } else {
          below += 1;
          expect(fragment.besideFloat, isFalse, reason: '$why $fragment');
          expect(line.left, closeTo(0, 0.01), reason: '$why $line');
        }
      }
      expect(beside, greaterThan(0), reason: why);
      expect(below, greaterThan(0), reason: why);
    });

    test('a left photo sits at the left edge with the head after it', () {
      const String why = '$_wrapFile: a left photo at the left edge; L5';
      final LaidOutNote layout = _layout(_note(side: MdPhotoSide.left));
      expect(layout.photoRects.single.rect.left, closeTo(0, 0.01), reason: why);
      final List<FragmentInfo> beside = <FragmentInfo>[
        for (final FragmentInfo fragment in _paragraph(layout))
          if (fragment.besideFloat) fragment,
      ];
      expect(beside, isNotEmpty, reason: why);
      for (final FragmentInfo fragment in beside) {
        final Rect line = fragment.lineBox.rect;
        expect(line.left, greaterThanOrEqualTo(295.99), reason: '$why $line');
        expect(line.right, lessThanOrEqualTo(560.01), reason: '$why $line');
      }
    });

    test('no glyph of the head or the tail overlaps the photo', () {
      const String why = '$_wrapFile: no glyph overlaps the photo; L5, L8';
      for (final MdPhotoSide side in <MdPhotoSide>[
        MdPhotoSide.left,
        MdPhotoSide.right,
      ]) {
        for (final MdPhotoSize size in <MdPhotoSize>[
          MdPhotoSize.small,
          MdPhotoSize.medium,
          MdPhotoSize.large,
        ]) {
          final String source = _note(
            side: side,
            size: size,
            caption: 'Low tide',
          );
          final LaidOutNote layout = _layout(source, width: 720);
          final PhotoRect photo = layout.photoRects.single;
          expect(
            photo.flow,
            isNot(PhotoFlow.block),
            reason: '$why ${side.name} ${size.name}',
          );
          final Rect figure = photo.rect.deflate(0.01);
          final List<Rect> boxes = layout.selectionBoxes(
            NoteSelection(anchor: _paragraphStart(layout), head: source.length),
          );
          expect(boxes, isNotEmpty, reason: why);
          for (final Rect box in boxes) {
            expect(
              box.overlaps(figure),
              isFalse,
              reason: '$why ${side.name} ${size.name} $box against $figure',
            );
          }
        }
      }
    });

    test('the cut is always a line start of the band layout', () {
      const String why = '$_wrapFile: the cut is a band line start; L5, L6';
      for (final double column in <double>[480, 500, 518, 540, 560, 600]) {
        for (final MdPhotoSize size in <MdPhotoSize>[
          MdPhotoSize.small,
          MdPhotoSize.medium,
        ]) {
          final String at = '$why $column ${size.name}';
          final LaidOutNote layout = _layout(_note(size: size), width: column);
          final double photoWidth = layout.photoRects.single.rect.width;
          final LaidOutNote band = _layout(
            _prose,
            width: column - photoWidth - 16,
          );
          final int start = _paragraphStart(layout);
          final List<FragmentInfo> paragraph = _paragraph(layout);
          final List<FragmentInfo> beside = <FragmentInfo>[
            for (final FragmentInfo fragment in paragraph)
              if (fragment.besideFloat) fragment,
          ];
          final List<int> bandBreaks = _breaks(_paragraph(band), 0);
          expect(beside, isNotEmpty, reason: at);
          expect(bandBreaks.length, greaterThan(beside.length), reason: at);
          expect(
            _breaks(beside, start),
            bandBreaks.sublist(0, beside.length),
            reason: at,
          );
          final FragmentInfo firstFull = paragraph.firstWhere(
            (FragmentInfo fragment) => !fragment.besideFloat,
          );
          expect(
            firstFull.sourceRange.start - start,
            bandBreaks[beside.length],
            reason: at,
          );
        }
      }
    });

    test('lines sit beside the photo while they start above its foot', () {
      const String why = '$_wrapFile: lines beside while above the foot; L5';
      final LaidOutNote layout = _layout(
        _note(caption: 'Low tide, from the pilings'),
      );
      final double bottom = layout.photoRects.single.rect.bottom;
      final List<FragmentInfo> paragraph = _paragraph(layout);
      final int last = paragraph.lastIndexWhere(
        (FragmentInfo fragment) => fragment.besideFloat,
      );
      expect(last, greaterThanOrEqualTo(0), reason: why);
      expect(last + 1, lessThan(paragraph.length), reason: why);
      expect(
        paragraph[last].lineBox.rect.top,
        lessThan(bottom - 0.5),
        reason: why,
      );
      expect(
        paragraph[last + 1].lineBox.rect.top,
        greaterThanOrEqualTo(bottom - 0.5),
        reason: why,
      );
    });

    test('head and tail rejoin to the paragraph with styles intact', () {
      const String why = '$_wrapFile: styles intact across the cut; L2, L5';
      final List<(String, TextStyle)> runs = <(String, TextStyle)>[
        ('old pilings', NoteTypography.body.merge(NoteTypography.strong)),
        (
          'Nothing moved for a long time.',
          NoteTypography.body.merge(NoteTypography.emphasis),
        ),
      ];
      for (final double width in <double>[480, 560, 600]) {
        final String source = _note();
        final LaidOutNote layout = _layout(source, width: width);
        for (final (String run, TextStyle style) in runs) {
          final int runStart = source.indexOf(run);
          final int runEnd = runStart + run.length;
          int parts = 0;
          for (final FragmentInfo fragment in _paragraph(layout)) {
            int start = math.max(runStart, fragment.sourceRange.start);
            int end = math.min(runEnd, fragment.sourceRange.end);
            while (start < end && source.codeUnitAt(start) == 0x20) {
              start += 1;
            }
            while (end > start && source.codeUnitAt(end - 1) == 0x20) {
              end -= 1;
            }
            if (start >= end) {
              continue;
            }
            parts += 1;
            final List<Rect> boxes = layout.selectionBoxes(
              NoteSelection(anchor: start, head: end),
            );
            final Rect union = boxes.reduce(
              (Rect x, Rect y) => x.expandToInclude(y),
            );
            final String text = source.substring(start, end);
            expect(
              union.width,
              closeTo(_textWidth(text, style), 0.5),
              reason: '$why $width [$text] besideFloat ${fragment.besideFloat}',
            );
          }
          expect(parts, greaterThan(0), reason: '$why $width $run');
        }
      }
    });

    test('a paragraph that fits beside the photo leaves no tail', () {
      const String why = '$_wrapFile: a short paragraph leaves no tail; L5';
      final LaidOutNote layout = _layout(_note(after: 'A short line.'));
      final List<FragmentInfo> paragraph = _paragraph(layout);
      expect(layout.fragments, hasLength(1), reason: why);
      expect(paragraph, hasLength(1), reason: why);
      expect(paragraph.single.besideFloat, isTrue, reason: why);
      expect(layout.size.height, closeTo(186.67, 0.01), reason: why);
    });

    testWidgets('a screen reader meets the photo before the paragraph', (
      WidgetTester tester,
    ) async {
      const String why = '$_wrapFile: screen reader order; A2, A4, 11.3';
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _pumpReader(tester, _note(caption: 'Low tide'));
      final List<String> labels = <String>[
        for (final SemanticsNode node
            in tester.semantics.simulatedAccessibilityTraversal())
          if (node.label.isNotEmpty) node.label,
      ];
      final List<int> photos = <int>[
        for (int i = 0; i < labels.length; i++)
          if (labels[i] == 'Photo, Low tide') i,
      ];
      expect(photos, hasLength(1), reason: '$why $labels');
      final List<int> paragraphs = <int>[
        for (int i = 0; i < labels.length; i++)
          if (labels[i].startsWith('The tide came in') &&
              labels[i].endsWith('salt and cut grass.'))
            i,
      ];
      expect(paragraphs, hasLength(1), reason: '$why $labels');
      expect(paragraphs.single, greaterThan(photos.single), reason: why);
      semantics.dispose();
    });

    testWidgets('a system font change re-splits the paragraph', (
      WidgetTester tester,
    ) async {
      const String why = '$_wrapFile: a font change re-splits; L6, L9';
      await _pumpReader(tester, _note());
      await tester.binding.handleSystemMessage(<String, Object?>{
        'type': 'fontsChange',
      });
      await tester.pump();
      await tester.pump();
      final LaidOutNote live = _view(tester).noteLayout;
      final LaidOutNote fresh = _layout(_note());
      expect(_sourceRanges(live), _sourceRanges(fresh), reason: why);
      _expectRect(
        live.photoRects.single.rect,
        fresh.photoRects.single.rect,
        why,
      );
    });

    testWidgets('a full-width scope floats across the whole column', (
      WidgetTester tester,
    ) async {
      const String why = '$_wrapFile: full-width scope; L1';
      await _pumpReader(tester, _note(), width: 900, fillsWidth: true);
      final LaidOutNote layout = _view(tester).noteLayout;
      expect(layout.inputs.columnWidth, 900, reason: why);
      final PhotoRect photo = layout.photoRects.single;
      _expectRect(photo.rect, const Rect.fromLTWH(450, 0, 450, 300), why);
      expect(photo.flow, PhotoFlow.floatRight, reason: why);
      expect(
        _paragraph(layout).first.lineBox.rect.left,
        closeTo(0, 0.01),
        reason: why,
      );
    });

    testWidgets(
      'outside a full-width scope the float keeps the 35 em measure',
      (WidgetTester tester) async {
        const String why =
            '$_wrapFile: the capped measure; L1 changes 35 em '
            'to 45 em';
        await _pumpReader(tester, _note(), width: 900);
        final LaidOutNote layout = _view(tester).noteLayout;
        expect(layout.inputs.columnWidth, 720, reason: why);
        final Rect photo = layout.photoRects.single.rect;
        expect(photo.width, closeTo(360, 0.01), reason: why);
        expect(photo.right, closeTo(720, 0.01), reason: why);
      },
    );

    test('floats at 1.5x text on a 840 column just as it does at 1x', () {
      const String why = '$_wrapFile: floats at 1.5x on 840; L3';
      final PhotoRect scaled = _layout(
        _note(),
        width: 840,
        scale: 1.5,
      ).photoRects.single;
      expect(scaled.rect.width, closeTo(420, 0.01), reason: why);
      expect(scaled.flow, PhotoFlow.floatRight, reason: why);
      final PhotoRect plain = _layout(_note()).photoRects.single;
      expect(plain.rect.width, closeTo(280, 0.01), reason: why);
      expect(plain.flow, PhotoFlow.floatRight, reason: why);
    });

    testWidgets(
      'a drag across the head and tail copies the paragraph exactly',
      (WidgetTester tester) async {
        const String why = '$_wrapFile: a drag across the cut copies; L10';
        final List<MethodCall> log = _captureClipboard(tester);
        await _pumpReader(tester, _note());
        await tester.pumpAndSettle();
        final RenderNoteView view = _view(tester);
        final LaidOutNote layout = view.noteLayout;
        final int from = _paragraphStart(layout) + 4;
        final FragmentInfo firstFull = _paragraph(
          layout,
        ).firstWhere((FragmentInfo fragment) => !fragment.besideFloat);
        final int to = firstFull.sourceRange.start + 20;
        final Offset start = view.contentToGlobal(
          layout.caretRect(from, TextAffinity.downstream).centerLeft,
        );
        final Offset end = view.contentToGlobal(
          layout.caretRect(to, TextAffinity.downstream).centerLeft,
        );
        final TestGesture gesture = await tester.startGesture(
          start,
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await tester.pump(const Duration(milliseconds: 110));
        await gesture.moveTo(Offset.lerp(start, end, 0.1)!);
        await tester.pump();
        await gesture.moveTo(end);
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        await _pressWithControl(tester, LogicalKeyboardKey.keyC);

        final VisibleText visible = _view(tester).visibleText;
        final OffsetMap map = visible.map;
        expect(
          _copiedText(log),
          visible.text.substring(
            map.sourceToVisible(from),
            map.sourceToVisible(to),
          ),
          reason: why,
        );
      },
    );

    testWidgets('select all copies the note with the float byte-exact', (
      WidgetTester tester,
    ) async {
      const String why = '$_wrapFile: select all copies byte-exact; L10';
      final List<MethodCall> log = _captureClipboard(tester);
      final String source =
          'Before the walk\n\n${_note(caption: 'Low tide')}\n\nAfter the walk';
      await _pumpReader(tester, source);
      await tester.pumpAndSettle();
      final RenderNoteView view = _view(tester);
      final int after = source.indexOf('After the walk');
      final FragmentInfo target = view.noteLayout.fragments.firstWhere(
        (FragmentInfo fragment) => fragment.sourceRange.start == after,
      );
      final TestGesture gesture = await tester.startGesture(
        view.contentToGlobal(target.lineBox.rect.center),
        kind: PointerDeviceKind.mouse,
      );
      addTearDown(gesture.removePointer);
      await tester.pump(const Duration(milliseconds: 110));
      await gesture.up();
      await tester.pumpAndSettle();
      await _pressWithControl(tester, LogicalKeyboardKey.keyA);
      await _pressWithControl(tester, LogicalKeyboardKey.keyC);

      expect(
        _copiedText(log),
        'Before the walk\n\n\n$_proseVisible\n\nAfter the walk',
        reason: why,
      );
    });

    test('a Full photo stacks', () {
      const String why = '$_wrapFile: a Full photo stacks; L4, unchanged';
      final LaidOutNote layout = _layout(_note(size: MdPhotoSize.full));
      final PhotoRect photo = layout.photoRects.single;
      _expectRect(photo.rect, const Rect.fromLTWH(0, 0, 560, 373.33), why);
      expect(photo.flow, PhotoFlow.block, reason: why);
      final Rect first = _paragraph(layout).first.lineBox.rect;
      expect(first.top, closeTo(386.13, 0.01), reason: why);
      expect(first.left, closeTo(0, 0.01), reason: why);
    });

    test('a photo whose next block is not a paragraph stacks', () {
      const String why = '$_wrapFile: a non-paragraph next block; L5';
      for (final String next in <String>[
        '# Heading',
        '- a list item',
        '> a quote',
      ]) {
        final LaidOutNote layout = _layout('$_a\n$next');
        final FragmentInfo first = _blockFragments(layout, 1).first;
        expect(first.besideFloat, isTrue, reason: '$why [$next]');
        expect(
          first.lineBox.rect.right,
          lessThanOrEqualTo(264.01),
          reason: '$why [$next]',
        );
      }
      final LaidOutNote twoPhotos = _layout('$_a\n${mdPhotoLine(photoIdB)}');
      expect(
        twoPhotos.photoRects[1].rect.top,
        closeTo(199.47, 0.01),
        reason: why,
      );
    });

    test('a photo at the end of the note stacks', () {
      const String why = '$_wrapFile: a photo at the end; L5';
      final LaidOutNote layout = _layout('$_prose\n$_a');
      final PhotoRect photo = layout.photoRects.single;
      expect(photo.flow, PhotoFlow.floatRight, reason: why);
      expect(photo.rect.left, closeTo(280, 0.01), reason: why);
      expect(
        photo.rect.top,
        closeTo(_paragraph(layout).last.lineBox.rect.bottom + 12.8, 0.01),
        reason: why,
      );
      expect(layout.size.height, closeTo(photo.rect.bottom, 0.01), reason: why);
    });

    test('a column narrower than 28.9 em stacks', () {
      const String why = '$_wrapFile: a phone column stacks; L4';
      for (final double width in <double>[320, 360, 430, 462, 479]) {
        final LaidOutNote layout = _layout(
          _note(size: MdPhotoSize.large),
          width: width,
        );
        final PhotoRect photo = layout.photoRects.single;
        expect(photo.rect.left, closeTo(0, 0.01), reason: '$why $width');
        expect(photo.rect.width, closeTo(width, 0.01), reason: '$why $width');
        expect(photo.flow, PhotoFlow.block, reason: '$why $width');
        expect(
          layout.fragments.where((FragmentInfo f) => f.besideFloat),
          isEmpty,
          reason: '$why $width',
        );
      }
    });

    test('missing dimensions stack', () {
      const String why = '$_wrapFile: missing dimensions; L3, L4';
      final PhotoRect photo = _layout(
        _note(),
        dimensions: <String, Size>{},
      ).photoRects.single;
      expect(photo.flow, PhotoFlow.floatRight, reason: why);
      expect(photo.rect.width, closeTo(280, 0.01), reason: why);
      expect(photo.rect.height, closeTo(186.67, 0.01), reason: why);
    });

    testWidgets('a corrupt or missing blob stacks with its placeholder', (
      WidgetTester tester,
    ) async {
      const String why =
          '$_wrapFile: a missing blob placeholder; P11, '
          'unchanged';
      await _pumpReader(
        tester,
        _note(),
        resolver: FakeNoteMediaResolver()..memoizeAll(),
      );
      await tester.pump();
      final Rect unavailable = tester.getRect(
        find.byKey(photoFigureUnavailableKey),
      );
      expect(unavailable.width, closeTo(280, 0.01), reason: why);
      expect(unavailable.height, closeTo(56, 0.01), reason: why);
      expect(
        unavailable.left - _readerLeft(tester),
        closeTo(140, 0.01),
        reason: why,
      );
      final RenderNoteView view = _view(tester);
      final Rect first = _paragraph(view.noteLayout).first.lineBox.rect;
      expect(first.left, closeTo(0, 0.01), reason: why);
      expect(
        view.contentToGlobal(first.topLeft).dy,
        greaterThanOrEqualTo(unavailable.bottom - 0.01),
        reason: why,
      );
    });

    testWidgets('a photo whose file cannot be decoded falls back to Stacked'
        'Photo', (WidgetTester tester) async {
      const String why = '$_wrapFile: an undecodable file; P11';
      final Directory root = Directory.systemTemp.createTempSync(
        'fn_parity_corrupt',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final File corrupt = File('${root.path}/corrupt.jpg')
        ..writeAsBytesSync(<int>[1, 2, 3]);
      final FakeNoteMediaResolver resolver =
          FakeNoteMediaResolver(<String, ResolvedMedia>{
            prefixOf(photoIdA): ResolvedMedia.available(
              blob: photoBlob(photoIdA, width: 1200, height: 900),
              file: corrupt,
            ),
          })..memoizeAll();

      await tester.runAsync(
        () => _pumpReader(tester, _note(), resolver: resolver),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      await tester.pump();

      final Rect unavailable = tester.getRect(
        find.byKey(photoFigureUnavailableKey),
      );
      expect(unavailable.width, closeTo(280, 0.01), reason: why);
      expect(unavailable.height, closeTo(56, 0.01), reason: why);
      expect(
        unavailable.left - _readerLeft(tester),
        closeTo(140, 0.01),
        reason: why,
      );
      expect(tester.binding.hasScheduledFrame, isFalse, reason: why);
    });

    testWidgets(
      'a decode failure left by the previous photo does not stack the next',
      (WidgetTester tester) async {
        const String why = '$_wrapFile: a decode failure does not leak; P11';
        final Directory root = Directory.systemTemp.createTempSync(
          'fn_parity_swap',
        );
        addTearDown(() => root.deleteSync(recursive: true));
        final File corrupt = File('${root.path}/corrupt.jpg')
          ..writeAsBytesSync(<int>[1, 2, 3]);
        final File decodable = File('${root.path}/decodable.png')
          ..writeAsBytesSync(_decodablePng);
        final FakeNoteMediaResolver resolver =
            FakeNoteMediaResolver(<String, ResolvedMedia>{
              prefixOf(photoIdA): ResolvedMedia.available(
                blob: photoBlob(photoIdA, width: 1200, height: 900),
                file: corrupt,
              ),
              prefixOf(photoIdB): ResolvedMedia.available(
                blob: photoBlob(photoIdB, width: 1200, height: 900),
                file: decodable,
              ),
            })..memoizeAll();

        await tester.runAsync(() async {
          await _pumpReader(tester, _note(), resolver: resolver);
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.runAsync(() async {
          await _pumpReader(
            tester,
            '${mdPhotoLine(photoIdB)}\n$_prose',
            resolver: resolver,
          );
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(find.byKey(photoFigureFrameKey), findsOneWidget, reason: why);
        expect(
          find.byKey(photoFigureUnavailableKey),
          findsNothing,
          reason: why,
        );
        expect(
          tester.getTopLeft(find.byType(PhotoFigure)).dx - _readerLeft(tester),
          closeTo(280, 0.01),
          reason: why,
        );
      },
    );

    test('the render budget turns every float into a stack', () {
      const String why = '$_wrapFile: the render budget; L6, L7 remove it';
      final LaidOutNote reader = _layout(_note());
      final LaidOutNote editor = _layout(_note(), readerMode: false);
      expect(_sourceRanges(editor), _sourceRanges(reader), reason: why);
      expect(editor.fragments.length, reader.fragments.length, reason: why);
      for (int i = 0; i < reader.fragments.length; i++) {
        _expectRect(
          editor.fragments[i].lineBox.rect,
          reader.fragments[i].lineBox.rect,
          '$why fragment $i',
          within: 0.5,
        );
      }
      _expectRect(
        editor.photoRects.single.rect,
        reader.photoRects.single.rect,
        why,
        within: 0.5,
      );
    });

    test('a panorama too short to hold one line stacks, as planned', () {
      const String why = '$_wrapFile: a short panorama; section 8';
      final PhotoRect photo = _layout(
        _note(),
        dimensions: <String, Size>{prefixOf(photoIdA): const Size(4000, 200)},
      ).photoRects.single;
      expect(photo.flow, PhotoFlow.floatRight, reason: why);
      expect(photo.rect.width, closeTo(280, 0.01), reason: why);
      expect(photo.rect.height, closeTo(14, 0.01), reason: why);
    });

    testWidgets('an unresolved photo stacks until its dimensions arrive', (
      WidgetTester tester,
    ) async {
      const String why = '$_wrapFile: an unresolved photo; L3';
      _pinSurface(tester);
      await tester.pumpWidget(
        _readerApp(_note(), resolver: _resolver(memoized: false)),
      );
      void check(int frame) {
        final Finder figure = find.byType(PhotoFigure);
        if (figure.evaluate().isEmpty) {
          return;
        }
        final Rect rect = tester.getRect(figure);
        expect(rect.width, closeTo(280, 0.01), reason: '$why frame $frame');
        expect(rect.height, closeTo(186.67, 0.01), reason: '$why frame $frame');
        expect(
          rect.left - _readerLeft(tester),
          closeTo(280, 0.01),
          reason: '$why frame $frame',
        );
      }

      check(0);
      for (int frame = 1; frame <= 9; frame++) {
        await tester.pump();
        check(frame);
      }
      expect(find.byType(PhotoFigure), findsOneWidget, reason: why);
    });

    test('the stacked fallback matches the unpaired rendering', () {
      const String why = '$_wrapFile: the stacked fallback; L4, L2';
      final LaidOutNote layout = _layout(_note(), width: 400);
      final PhotoRect photo = layout.photoRects.single;
      _expectRect(photo.rect, const Rect.fromLTWH(0, 0, 400, 266.67), why);
      expect(photo.flow, PhotoFlow.block, reason: why);
      expect(
        _paragraph(layout).first.lineBox.rect.top,
        closeTo(279.47, 0.01),
        reason: why,
      );
    });

    testWidgets('a resize inside one band bucket keeps the same head span', (
      WidgetTester tester,
    ) async {
      const String why = '$_wrapFile: a resize matches a fresh layout; L6, L1';
      for (final double width in <double>[560, 559, 558.5, 600, 900]) {
        await _pumpReader(tester, _note(), width: width);
        final LaidOutNote live = _view(tester).noteLayout;
        final LaidOutNote fresh = _layout(_note(), width: math.min(width, 720));
        expect(
          _sourceRanges(live),
          _sourceRanges(fresh),
          reason: '$why $width',
        );
        _expectRect(
          live.photoRects.single.rect,
          fresh.photoRects.single.rect,
          '$why $width',
        );
      }
    });

    testWidgets('crossing a bucket re-splits, and widening back holds it', (
      WidgetTester tester,
    ) async {
      const String why =
          '$_wrapFile: crossing widths matches a fresh '
          'layout; L6';
      for (final double width in <double>[560, 540, 544, 539, 600, 700, 560]) {
        await _pumpReader(tester, _note(), width: width);
        final LaidOutNote live = _view(tester).noteLayout;
        final LaidOutNote fresh = _layout(_note(), width: math.min(width, 720));
        expect(
          _sourceRanges(live),
          _sourceRanges(fresh),
          reason: '$why $width',
        );
        _expectRect(
          live.photoRects.single.rect,
          fresh.photoRects.single.rect,
          '$why $width',
        );
      }
    });

    testWidgets('the paper and its shadow paint inside the reserved box', (
      WidgetTester tester,
    ) async {
      const String why = '$_wrapFile: tilt inside the box; P12';
      for (final MdPhotoSide side in <MdPhotoSide>[
        MdPhotoSide.left,
        MdPhotoSide.right,
      ]) {
        await _pumpReader(tester, _note(side: side));
        final Rect box = tester.getRect(find.byKey(photoFigureFrameKey));
        final RenderBox paper = tester.renderObject<RenderBox>(
          find
              .descendant(
                of: find.byKey(photoFigureFrameKey),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final Matrix4 toGlobal = paper.getTransformTo(null);
        final List<Offset> corners = <Offset>[
          for (final Offset corner in <Offset>[
            Offset.zero,
            Offset(paper.size.width, 0),
            Offset(0, paper.size.height),
            Offset(paper.size.width, paper.size.height),
          ])
            MatrixUtils.transformPoint(toGlobal, corner),
        ];
        final Rect painted = corners
            .skip(1)
            .fold(
              Rect.fromPoints(corners.first, corners.first),
              (Rect bounds, Offset corner) =>
                  bounds.expandToInclude(Rect.fromPoints(corner, corner)),
            );
        final Rect shadow = painted.inflate(2);
        final Rect reserved = box.inflate(0.01);
        expect(
          reserved.contains(shadow.topLeft) &&
              reserved.contains(shadow.bottomRight),
          isTrue,
          reason: '$why ${side.name}: $shadow inside $reserved',
        );
        expect(
          painted.width,
          isNot(closeTo(paper.size.width, 1e-6)),
          reason: '$why ${side.name}',
        );
      }
      expect(photoFigureTiltDegrees(prefixOf(photoIdA)), 1.1, reason: why);
    });

    test('the fit scale leaves room for tilt and shadow at every aspect', () {
      const String why = '$_wrapFile: the fit scale; P12';
      for (final double tilt in photoFigureTiltsDegrees) {
        final double radians = tilt * math.pi / 180;
        for (final double aspect in <double>[4, 1.5, 1, 9 / 16]) {
          const double w = 280;
          final double h = photoHeightFor(width: w, aspect: aspect);
          final double s = photoFigureFitScale(w, h, radians);
          final double c = math.cos(radians).abs();
          final double n = math.sin(radians).abs();
          final String at = '$why $tilt $aspect';
          expect(
            s * (w * c + h * n) + 4,
            lessThanOrEqualTo(w + 1e-9),
            reason: at,
          );
          expect(
            s * (w * n + h * c) + 4,
            lessThanOrEqualTo(h + 1e-9),
            reason: at,
          );
          expect(s * w + s * h * n, lessThanOrEqualTo(w + 1e-9), reason: at);
        }
      }
    });

    test('the frame box is the height clamp for a tall portrait', () {
      const String why = '$_wrapFile: the frame box clamp; L3, unchanged';
      final PhotoLayoutPlan plan = _plan(
        MdPhotoSize.medium,
        side: MdPhotoSide.left,
        aspect: 9 / 16,
      );
      expect(plan.mode, PhotoMode.floatLeft, reason: why);
      expect(plan.photoHeight, closeTo(448, 1e-9), reason: why);
    });
  });
}
