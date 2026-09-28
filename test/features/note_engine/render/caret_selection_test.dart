import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_layout_engine.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/render/caret_painter.dart';
import 'package:field_notes/features/note_engine/render/note_view.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';
import 'package:field_notes/features/note_engine/render/selection_painter.dart';

import '../../notes/support/notes_harness.dart';

const String _photoNote =
    'A\n\n![Low tide](photo/a1b2c3d4e5f6 "left medium")\n\nB';
const Color _selectionColor = Color(0x663366CC);

void _pinSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

int _lineOf(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length;

double _snap(double value, double devicePixelRatio) =>
    (value * devicePixelRatio).roundToDouble() / devicePixelRatio;

final class _Harness {
  final NoteLayoutEngine engine = NoteLayoutEngine(
    projector: const NoteVisibleProjector(),
  );
  final GlobalKey renderKey = GlobalKey();
  final FakeNoteMediaResolver resolver = FakeNoteMediaResolver(
    <String, ResolvedMedia>{prefixOf(photoIdA): availablePhoto(photoIdA)},
  )..memoizeAll();

  RenderNoteView get view =>
      renderKey.currentContext!.findRenderObject()! as RenderNoteView;

  Future<void> pump(
    WidgetTester tester,
    String source, {
    NoteSelection? selection,
    bool focused = true,
    bool readOnly = false,
    bool activeLineFollowsHead = true,
    TextRange composing = TextRange.empty,
    List<NoteViewDecoration> decorations = const <NoteViewDecoration>[],
  }) {
    final MdTree tree = parseNoteTree(source);
    final int? activeLine =
        focused && !readOnly && selection != null && activeLineFollowsHead
        ? _lineOf(source, selection.head)
        : null;
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 688,
              height: 800,
              child: NoteView(
                source: source,
                tree: tree,
                visibleText: const NoteVisibleProjector().project(
                  source,
                  tree,
                  activeLine,
                ),
                runLayout: engine.layout,
                mediaResolver: resolver,
                activeLine: activeLine,
                selection: selection,
                composing: composing,
                focused: focused,
                readOnly: readOnly,
                selectionColor: _selectionColor,
                decorations: decorations,
                renderKey: renderKey,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<(Symbol, List<dynamic>)> _paintLog(RenderNoteView view) {
  final List<(Symbol, List<dynamic>)> log = <(Symbol, List<dynamic>)>[];
  expect(
    view,
    paints..everything((Symbol method, List<dynamic> arguments) {
      log.add((method, arguments));
      return true;
    }),
  );
  return List<(Symbol, List<dynamic>)>.unmodifiable(log);
}

bool _isRectIn((Symbol, List<dynamic>) call, Color color) =>
    call.$1 == #drawRect &&
    (call.$2[1] as Paint).color.toARGB32() == color.toARGB32();

final class _CircleDecoration extends NoteViewDecoration {
  const _CircleDecoration();

  @override
  void paint(
    Canvas canvas,
    NoteLayout layout,
    Rect? Function(Rect contentRect) place,
  ) {
    canvas.drawCircle(
      const Offset(20, 20),
      4,
      Paint()..color = const Color(0xFF123456),
    );
  }

  @override
  bool shouldRepaint(_CircleDecoration oldDecoration) => false;
}

String _tableRow() =>
    '| ${List<String>.filled(20, 'abcdefghij').join(' | ')} |';

String _wideTable() => <String>[
  _tableRow(),
  '|${List<String>.filled(20, ' --- ').join('|')}|',
  _tableRow(),
].join('\n');

void main() {
  testWidgets(
    'the caret spans the line box and blinks every five hundred milliseconds',
    (WidgetTester tester) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      const String source = '# Harbour day\nThe fog lifted.';
      await harness.pump(
        tester,
        source,
        selection: const NoteSelection.collapsed(5),
      );
      final RenderNoteView view = harness.view;
      final Rect? caret = view.caretRect;
      expect(caret, isNotNull);
      expect(caret!.width, 2);
      final Rect glyph = view.contentRectToLocal(
        view.noteLayout.caretRect(5, TextAffinity.downstream),
      )!;
      final Rect lineBox = view.contentRectToLocal(
        view.noteLayout.lineBoxAt(5, TextAffinity.downstream).rect,
      )!;
      expect(caret.left, _snap(glyph.left, 1));
      expect(caret.top, _snap(lineBox.top, 1));
      expect(caret.bottom, _snap(lineBox.bottom, 1));
      expect(caret.height, _snap(lineBox.bottom, 1) - _snap(lineBox.top, 1));
      expect(caret.height, isNot(closeTo(25.6, 0.01)));

      expect(view.caretBlinkVisible, isTrue);
      await tester.pump(const Duration(milliseconds: 500));
      expect(view.caretBlinkVisible, isFalse);
      await tester.pump(const Duration(milliseconds: 500));
      expect(view.caretBlinkVisible, isTrue);

      await harness.pump(
        tester,
        source,
        selection: const NoteSelection.collapsed(6),
      );
      expect(view.caretBlinkVisible, isTrue);
      await tester.pump(const Duration(milliseconds: 499));
      expect(view.caretBlinkVisible, isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      expect(view.caretBlinkVisible, isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'the caret is hidden with a range, a selected photo or no focus',
    (WidgetTester tester) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      expect(_photoNote.length, 51);
      await harness.pump(
        tester,
        _photoNote,
        selection: const NoteSelection(anchor: 0, head: 1),
      );
      expect(harness.view.caretRect, isNull);
      await harness.pump(
        tester,
        _photoNote,
        selection: const NoteSelection.collapsed(5),
      );
      expect(harness.view.caretRect, isNull);
      await harness.pump(
        tester,
        _photoNote,
        selection: const NoteSelection(anchor: 3, head: 48),
      );
      expect(harness.view.caretRect, isNull);
      await harness.pump(
        tester,
        _photoNote,
        selection: const NoteSelection.collapsed(51),
        focused: false,
      );
      expect(harness.view.caretRect, isNull);
      await harness.pump(
        tester,
        _photoNote,
        selection: const NoteSelection.collapsed(51),
      );
      expect(harness.view.caretRect, isNotNull);
    },
  );

  testWidgets(
    'an idle editor with a selected photo schedules no frames',
    (WidgetTester tester) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      await harness.pump(
        tester,
        _photoNote,
        selection: const NoteSelection.collapsed(5),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.binding.delayed(const Duration(seconds: 3));
      expect(tester.binding.hasScheduledFrame, isFalse);

      await harness.pump(
        tester,
        _photoNote,
        selection: const NoteSelection.collapsed(51),
      );
      await tester.pump();
      await tester.pump();
      await tester.binding.delayed(const Duration(milliseconds: 600));
      expect(tester.binding.hasScheduledFrame, isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('the composing range is underlined', (WidgetTester tester) async {
    _pinSurface(tester);
    final _Harness harness = _Harness();
    const String source = 'The fog lifted.';
    await harness.pump(
      tester,
      source,
      selection: const NoteSelection.collapsed(7),
      composing: const TextRange(start: 4, end: 7),
    );
    final RenderNoteView view = harness.view;
    final List<Rect> expected = noteComposingUnderlines(
      view.noteLayout.selectionBoxes(const NoteSelection(anchor: 4, head: 7)),
    );
    expect(expected, isNotEmpty);
    final PaintPattern pattern = paints;
    for (final Rect rect in expected) {
      pattern.rect(rect: rect, color: TypographyTokens.noteBody.color);
    }
    expect(view, pattern);

    await harness.pump(
      tester,
      source,
      selection: const NoteSelection.collapsed(7),
    );
    for (final Rect rect in expected) {
      expect(view, isNot(paints..rect(rect: rect)));
    }
    expect(
      noteComposingUnderlines(<Rect>[const Rect.fromLTWH(10, 0, 30, 25.6)]),
      <Rect>[const Rect.fromLTWH(10, 24.6, 30, 1)],
    );
  });

  group('highlight and caret order', () {
    testWidgets('a range is highlighted before the photos paint', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      const String source =
          'The fog lifted at noon.\n\n'
          '![Low tide](photo/a1b2c3d4e5f6 "centre medium")';
      await harness.pump(
        tester,
        source,
        selection: const NoteSelection(anchor: 4, head: 11),
      );
      final RenderNoteView view = harness.view;
      final List<Rect> boxes = view.noteLayout.selectionBoxes(
        const NoteSelection(anchor: 4, head: 11),
      );
      expect(boxes, isNotEmpty);
      final PaintPattern pattern = paints;
      for (final Rect box in boxes) {
        pattern.rect(rect: box, color: _selectionColor);
      }
      expect(view, pattern);
      final List<(Symbol, List<dynamic>)> log = _paintLog(view);
      final int lastHighlight = log.lastIndexWhere(
        ((Symbol, List<dynamic>) call) => _isRectIn(call, _selectionColor),
      );
      final int firstPhoto = log.indexWhere(
        ((Symbol, List<dynamic>) call) => call.$1 == #transform,
      );
      expect(lastHighlight, greaterThanOrEqualTo(0));
      expect(firstPhoto, greaterThan(lastHighlight));

      await harness.pump(
        tester,
        source,
        selection: const NoteSelection.collapsed(4),
      );
      expect(
        _paintLog(
          view,
        ).where(((Symbol, List<dynamic>) c) => _isRectIn(c, _selectionColor)),
        isEmpty,
      );
    });

    test('noteCaretRect snaps to physical pixels', () {
      const Rect caret = Rect.fromLTWH(4.3, 10.3, 2, 20);
      const Rect lineBox = Rect.fromLTWH(0, 10.3, 600, 25.6);
      final Rect twice = noteCaretRect(
        caret: caret,
        lineBox: lineBox,
        devicePixelRatio: 2,
      );
      expect(twice.top, 10.5);
      expect(twice.left, 4.5);
      expect(twice.width, noteCaretWidth);
      final Rect once = noteCaretRect(
        caret: caret,
        lineBox: lineBox,
        devicePixelRatio: 1,
      );
      expect(once.top, 10);
      expect(once.bottom, 36);
    });

    testWidgets('the caret paints after the decorations', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      await harness.pump(
        tester,
        'The fog lifted.',
        selection: const NoteSelection.collapsed(3),
        decorations: const <NoteViewDecoration>[_CircleDecoration()],
      );
      final List<(Symbol, List<dynamic>)> log = _paintLog(harness.view);
      final int circle = log.indexWhere(
        ((Symbol, List<dynamic>) call) => call.$1 == #drawCircle,
      );
      final int caret = log.indexWhere(
        ((Symbol, List<dynamic>) call) => _isRectIn(call, Palette.coral),
      );
      expect(circle, greaterThanOrEqualTo(0));
      expect(caret, greaterThan(circle));
    });
  });

  group('tables, read-only and platforms', () {
    testWidgets('a scrolled table shifts the highlight and hides the caret', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      final String table = _wideTable();
      await harness.pump(
        tester,
        table,
        selection: const NoteSelection.collapsed(2),
        activeLineFollowsHead: false,
      );
      final RenderNoteView view = harness.view;
      final LaidOutRow row = view.noteLayout.flow.rows.firstWhere(
        (LaidOutRow r) => r.row.kind == LayoutRowKind.table,
      );
      final double y = row.top + 1;
      expect(view.caretRect, isNotNull);
      expect(view.scrollTableBy(y, 10000), isTrue);
      expect(view.caretRect, isNull);
      final double shift = view.tableScrollOffsetAt(y);
      await harness.pump(
        tester,
        table,
        selection: const NoteSelection(anchor: 2, head: 5),
        activeLineFollowsHead: false,
      );
      expect(
        _paintLog(
          view,
        ).where(((Symbol, List<dynamic>) c) => _isRectIn(c, _selectionColor)),
        isEmpty,
      );
      final int lastCell = row.fragments
          .lastWhere((LineFragment f) => f.kind == FragmentKind.tableCell)
          .visibleRange
          .start;
      final int lastCellSource = view.visibleText.map
          .visibleToSource(lastCell)
          .downstream;
      final NoteSelection inLastCell = NoteSelection(
        anchor: lastCellSource,
        head: lastCellSource + 3,
      );
      await harness.pump(
        tester,
        table,
        selection: inLastCell,
        activeLineFollowsHead: false,
      );
      final List<Rect> painted = <Rect>[
        for (final (Symbol, List<dynamic>) call in _paintLog(view))
          if (_isRectIn(call, _selectionColor)) call.$2[0] as Rect,
      ];
      final List<Rect> boxes = view.noteLayout.selectionBoxes(inLastCell);
      expect(boxes, isNotEmpty);
      expect(painted, <Rect>[
        for (final Rect box in boxes) box.shift(Offset(-shift, 0)),
      ]);
    });

    testWidgets('a read-only view never shows a caret or blinks', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      await harness.pump(
        tester,
        'The fog lifted.',
        selection: const NoteSelection.collapsed(3),
        readOnly: true,
      );
      await tester.pump();
      expect(harness.view.caretRect, isNull);
      expect(harness.view.caretBlinkVisible, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.binding.delayed(const Duration(seconds: 2));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets(
      'the Android caret is two pixels wide and blinks',
      (WidgetTester tester) async {
        _pinSurface(tester);
        final _Harness harness = _Harness();
        await harness.pump(
          tester,
          'The fog lifted.',
          selection: const NoteSelection.collapsed(3),
        );
        expect(harness.view.caretRect!.width, 2);
        expect(harness.view.caretBlinkVisible, isTrue);
        await tester.pump(noteCaretBlinkHalfPeriod);
        expect(harness.view.caretBlinkVisible, isFalse);
        await tester.pump(noteCaretBlinkHalfPeriod);
        expect(harness.view.caretBlinkVisible, isTrue);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('removing the view stops the blink', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      await harness.pump(
        tester,
        'The fog lifted.',
        selection: const NoteSelection.collapsed(3),
      );
      final RenderNoteView view = harness.view;
      expect(view.caretBlinkVisible, isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(view.caretBlinkVisible, isFalse);
      await tester.pump();
      await tester.binding.delayed(const Duration(seconds: 2));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    test('NoteCaretBlink.stop leaves the caret hidden and idle', () {
      int changes = 0;
      final NoteCaretBlink blink = NoteCaretBlink(onChanged: () => changes++);
      blink.start();
      expect(blink.visible, isTrue);
      expect(blink.isRunning, isTrue);
      expect(changes, 1);
      blink.stop();
      expect(blink.visible, isFalse);
      expect(blink.isRunning, isFalse);
      expect(changes, 1);
    });
  });
}
