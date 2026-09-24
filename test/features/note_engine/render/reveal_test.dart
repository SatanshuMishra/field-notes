import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_layout_engine.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/render/note_view.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';
import 'package:field_notes/features/note_engine/render/reveal.dart';

import '../../notes/support/notes_harness.dart';

const String _photoLine = '![Low tide](photo/a1b2c3d4e5f6 "centre medium")';

String _lines(int count) =>
    <String>[for (int i = 1; i <= count; i++) 'Line $i'].join('\n');

int _lineOf(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length;

String _tableRow() =>
    '| ${List<String>.filled(20, 'abcdefghij').join(' | ')} |';

String _wideTable() => <String>[
  _tableRow(),
  '|${List<String>.filled(20, ' --- ').join('|')}|',
  _tableRow(),
].join('\n');

void _pinSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

final class _Harness {
  _Harness();

  final NoteLayoutEngine engine = NoteLayoutEngine(
    projector: const NoteVisibleProjector(),
  );
  final FakeNoteMediaResolver resolver = FakeNoteMediaResolver(
    <String, ResolvedMedia>{prefixOf(photoIdA): availablePhoto(photoIdA)},
  )..memoizeAll();
  GlobalKey renderKey = GlobalKey();
  ScrollController controller = ScrollController();

  RenderNoteView? renderView() =>
      renderKey.currentContext?.findRenderObject() as RenderNoteView?;

  RenderNoteView get view => renderView()!;

  ScrollPosition get position => controller.position;

  void fresh() {
    renderKey = GlobalKey();
    controller = ScrollController();
  }

  NoteView noteView(
    String source,
    NoteSelection selection, {
    bool activeLineFollowsHead = true,
    double bottomInset = 0,
    Key? key,
  }) {
    final MdTree tree = parseNoteTree(source);
    final int? activeLine = activeLineFollowsHead
        ? _lineOf(source, selection.head)
        : null;
    return NoteView(
      key: key,
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
      focused: true,
      scrollController: controller,
      bottomInset: bottomInset,
      renderKey: renderKey,
    );
  }

  Future<void> pumpBox(
    WidgetTester tester,
    String source,
    NoteSelection selection, {
    double width = 600,
    double height = 400,
    bool activeLineFollowsHead = true,
    double bottomInset = 0,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: height,
          child: noteView(
            source,
            selection,
            activeLineFollowsHead: activeLineFollowsHead,
            bottomInset: bottomInset,
          ),
        ),
      ),
    ),
  );

  Future<void> pumpScaffold(
    WidgetTester tester,
    String source,
    NoteSelection selection, {
    Key? key,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: noteView(source, selection, key: key)),
    ),
  );

  NoteCaretReveal attach(
    WidgetTester tester, {
    bool focused = true,
    bool Function()? handlesShown,
    TextSelectionControls? handleControls,
  }) {
    final NoteCaretReveal reveal = NoteCaretReveal(
      scrollController: controller,
      renderView: renderView,
      isFocused: () => focused,
      flutterView: tester.view,
      handlesShown: handlesShown,
      handleControls: handleControls,
    );
    reveal.attach();
    addTearDown(reveal.dispose);
    return reveal;
  }

  double? offsetFor({
    EdgeInsets padding = noteRevealPadding,
    double obscuredBottom = 0,
  }) => noteRevealOffset(
    target: noteRevealTarget(view)!,
    pixels: position.pixels,
    viewportExtent: position.viewportDimension,
    minScrollExtent: position.minScrollExtent,
    maxScrollExtent: position.maxScrollExtent,
    padding: padding,
    obscuredBottom: obscuredBottom,
  );

  Rect localCaret() {
    final NoteSelection selection = view.selection!;
    final Rect caret = view.noteLayout.caretRect(
      selection.head,
      selection.affinity,
    );
    return Rect.fromPoints(
      view.contentToLocal(caret.topLeft),
      view.contentToLocal(caret.bottomRight),
    );
  }
}

final class _CountingPosition extends ScrollPositionWithSingleContext {
  _CountingPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.onAnimate,
  });

  final VoidCallback onAnimate;

  @override
  Future<void> animateTo(
    double to, {
    required Duration duration,
    required Curve curve,
  }) {
    onAnimate();
    return super.animateTo(to, duration: duration, curve: curve);
  }
}

final class _CountingController extends ScrollController {
  int animations = 0;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _CountingPosition(
    physics: physics,
    context: context,
    oldPosition: oldPosition,
    onAnimate: () => animations++,
  );
}

String _insertAfterLine(String source, int line, String text) {
  final String marker = 'Line $line';
  final int end = source.indexOf('$marker\n') + marker.length;
  return '${source.substring(0, end)}$text${source.substring(end)}';
}

void main() {
  testWidgets(
    'an edit brings the caret into view with a hundred millisecond animation',
    (WidgetTester tester) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      final String source = _lines(60);
      await harness.pumpBox(tester, source, const NoteSelection.collapsed(0));
      final NoteCaretReveal reveal = harness.attach(tester);
      final String edited = _insertAfterLine(source, 40, 'x');
      final int caret = edited.indexOf('Line 40x') + 'Line 40x'.length;
      await harness.pumpBox(tester, edited, NoteSelection.collapsed(caret));
      reveal.scheduleReveal(animate: true);
      expect(harness.position.pixels, 0);
      final double? target = harness.offsetFor();
      expect(target, isNotNull);
      expect(target, greaterThan(0));
      expect(target, lessThan(harness.position.maxScrollExtent));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(harness.position.pixels, greaterThan(0));
      expect(harness.position.pixels, lessThan(target!));
      await tester.pump(const Duration(milliseconds: 20));
      expect(harness.position.pixels, moreOrLessEquals(target, epsilon: 0.01));
      expect(tester.binding.transientCallbackCount, 0);
      final RenderNoteView view = harness.view;
      final Rect caretRect = view.noteLayout.caretRect(
        caret,
        TextAffinity.downstream,
      );
      expect(
        view.contentToLocal(caretRect.bottomLeft).dy + 20,
        lessThanOrEqualTo(400 + 1e-9),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('a growing bottom inset brings the caret into view at once', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.reset);
    final _Harness harness = _Harness();
    final String source = _lines(30);
    final int caret = source.indexOf('Line 20') + 'Line 20'.length;
    final NoteSelection selection = NoteSelection.collapsed(caret);
    await harness.pumpScaffold(tester, source, selection);
    final NoteCaretReveal reveal = harness.attach(tester);
    expect(harness.position.pixels, 0);
    final Rect line = harness.view.noteLayout
        .lineBoxAt(caret, TextAffinity.downstream)
        .rect;
    expect(line.bottom + noteRevealPadding.bottom, lessThanOrEqualTo(600));
    expect(harness.offsetFor(), isNull);
    final Rect target = noteRevealTarget(harness.view)!;
    final double expected = target.bottom + noteRevealPadding.bottom - 400;
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    await tester.pump();
    expect(harness.position.viewportDimension, 400);
    expect(expected, lessThan(harness.position.maxScrollExtent));
    expect(
      noteRevealOffset(
        target: target,
        pixels: 0,
        viewportExtent: 400,
        minScrollExtent: harness.position.minScrollExtent,
        maxScrollExtent: harness.position.maxScrollExtent,
      ),
      moreOrLessEquals(expected, epsilon: 0.01),
    );
    expect(harness.position.pixels, moreOrLessEquals(expected, epsilon: 0.01));
    expect(tester.binding.transientCallbackCount, 0);
    reveal.dispose();
    tester.view.resetViewInsets();
    harness.fresh();
    await harness.pumpScaffold(
      tester,
      source,
      selection,
      key: const ValueKey<String>('fresh'),
    );
    expect(harness.position.pixels, 0);
    harness.attach(tester, focused: false);
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    await tester.pump();
    expect(harness.position.pixels, 0);
  });

  group('reveal behaviour', () {
    testWidgets('an already visible caret schedules nothing', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      final String source = _lines(60);
      await harness.pumpBox(tester, source, const NoteSelection.collapsed(0));
      final NoteCaretReveal reveal = harness.attach(tester);
      reveal.scheduleReveal(animate: true);
      await harness.pumpBox(tester, source, const NoteSelection.collapsed(3));
      expect(harness.position.pixels, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('two reveals before one frame start a single animation', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      final _CountingController controller = _CountingController();
      harness.controller = controller;
      final String source = _lines(60);
      final int caret = source.indexOf('Line 50') + 'Line 50'.length;
      await harness.pumpBox(tester, source, const NoteSelection.collapsed(0));
      final NoteCaretReveal reveal = harness.attach(tester);
      reveal.scheduleReveal(animate: true);
      reveal.scheduleReveal(animate: true);
      await harness.pumpBox(tester, source, NoteSelection.collapsed(caret));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.animations, 1);
      expect(harness.position.pixels, greaterThan(0));
      expect(harness.offsetFor(), isNull);
    });

    testWidgets('dispose before the frame scrolls nothing', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      final String source = _lines(60);
      final int caret = source.indexOf('Line 50') + 'Line 50'.length;
      await harness.pumpBox(tester, source, const NoteSelection.collapsed(0));
      final NoteCaretReveal reveal = harness.attach(tester);
      reveal.scheduleReveal(animate: false);
      reveal.dispose();
      await harness.pumpBox(tester, source, NoteSelection.collapsed(caret));
      await tester.pump(const Duration(milliseconds: 200));
      expect(harness.position.pixels, 0);
      expect(harness.offsetFor(), isNotNull);
    });

    testWidgets(
      'on Android the reveal pads for the handles and animates',
      (WidgetTester tester) async {
        _pinSurface(tester);
        final _Harness harness = _Harness();
        final String source = _lines(60);
        await harness.pumpBox(tester, source, const NoteSelection.collapsed(0));
        final NoteCaretReveal reveal = harness.attach(
          tester,
          handlesShown: () => true,
          handleControls: materialTextSelectionHandleControls,
        );
        final int caret = source.indexOf('Line 40') + 'Line 40'.length;
        await harness.pumpBox(tester, source, NoteSelection.collapsed(caret));
        reveal.scheduleReveal(animate: true);
        final double target = harness.offsetFor(
          padding: noteRevealPadding.copyWith(bottom: 39),
        )!;
        expect(target, greaterThan(harness.offsetFor()!));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 90));
        expect(harness.position.pixels, greaterThan(0));
        expect(harness.position.pixels, lessThan(target));
        await tester.pump(const Duration(milliseconds: 20));
        expect(
          harness.position.pixels,
          moreOrLessEquals(target, epsilon: 0.01),
        );
        expect(tester.binding.transientCallbackCount, 0);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'a selected photo at the end reveals its figure and the line below',
      (WidgetTester tester) async {
        _pinSurface(tester);
        final _Harness harness = _Harness();
        final String source = '${_lines(60)}\n\n$_photoLine\n';
        final int start = source.indexOf(_photoLine);
        final int end = start + _photoLine.length;
        final NoteSelection selection = NoteSelection(anchor: start, head: end);
        await harness.pumpBox(tester, source, const NoteSelection.collapsed(0));
        final NoteCaretReveal reveal = harness.attach(tester);
        reveal.scheduleReveal(animate: false);
        await harness.pumpBox(
          tester,
          source,
          selection,
          activeLineFollowsHead: false,
        );
        final RenderNoteView view = harness.view;
        expect(view.selectedPhotoRange, TextRange(start: start, end: end));
        final Rect figure = view.noteLayout.photoRects.single.rect;
        final Rect below = view.noteLayout
            .lineBoxAt(end + 1, TextAffinity.downstream)
            .rect;
        final Rect target = noteRevealTarget(view)!;
        expect(target, figure.expandToInclude(below));
        expect(target.bottom, greaterThan(figure.bottom));
        expect(harness.position.pixels, greaterThan(0));
        final double top = view.contentToLocal(target.topLeft).dy;
        final double bottom = view.contentToLocal(target.bottomLeft).dy;
        expect(top, greaterThanOrEqualTo(0));
        expect(bottom, lessThanOrEqualTo(400 + 1e-9));
      },
    );

    testWidgets('the view bottom inset is subtracted from the visible band', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      final String source = _lines(60);
      final int caret = source.indexOf('Line 30') + 'Line 30'.length;
      await harness.pumpBox(
        tester,
        source,
        const NoteSelection.collapsed(0),
        bottomInset: 120,
      );
      final NoteCaretReveal reveal = harness.attach(tester);
      reveal.scheduleReveal(animate: false);
      await harness.pumpBox(
        tester,
        source,
        NoteSelection.collapsed(caret),
        bottomInset: 120,
      );
      expect(harness.position.pixels, greaterThan(0));
      expect(
        harness.localCaret().bottom + noteRevealPadding.bottom,
        moreOrLessEquals(400 - 120, epsilon: 0.01),
      );
    });

    testWidgets('a caret in a wide table is brought into the column', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      final String table = _wideTable();
      await harness.pumpBox(
        tester,
        table,
        const NoteSelection.collapsed(2),
        width: 688,
        height: 800,
        activeLineFollowsHead: false,
      );
      final RenderNoteView view = harness.view;
      final LaidOutRow row = view.noteLayout.flow.rows.firstWhere(
        (LaidOutRow r) => r.row.kind == LayoutRowKind.table,
      );
      expect(row.contentWidth, moreOrLessEquals(1301, epsilon: 0.5));
      final int lastCell = row.fragments
          .lastWhere((LineFragment f) => f.kind == FragmentKind.tableCell)
          .visibleRange
          .start;
      final int caret = view.visibleText.map
          .visibleToSource(lastCell)
          .downstream;
      final NoteCaretReveal reveal = harness.attach(tester);
      reveal.scheduleReveal(animate: true);
      await harness.pumpBox(
        tester,
        table,
        NoteSelection.collapsed(caret),
        width: 688,
        height: 800,
        activeLineFollowsHead: false,
      );
      final double lineTop = view.noteLayout
          .lineBoxAt(caret, TextAffinity.downstream)
          .rect
          .top;
      expect(view.tableScrollOffsetAt(lineTop), greaterThan(0));
      final Rect local = harness.localCaret();
      expect(local.left, greaterThanOrEqualTo(0));
      expect(local.right, lessThanOrEqualTo(688));
    });

    testWidgets('a shrinking inset reveals nothing', (
      WidgetTester tester,
    ) async {
      addTearDown(tester.view.reset);
      final _Harness harness = _Harness();
      final String source = _lines(30);
      final int caret = source.indexOf('Line 30') + 'Line 30'.length;
      tester.view.viewInsets = const FakeViewPadding(bottom: 600);
      await harness.pumpScaffold(
        tester,
        source,
        NoteSelection.collapsed(caret),
      );
      harness.attach(tester);
      expect(harness.position.pixels, 0);
      tester.view.resetViewInsets();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(harness.position.pixels, 0);
      expect(harness.offsetFor(), isNotNull);
    });
  });

  group('reveal arithmetic', () {
    double? offset(
      Rect target, {
      double pixels = 0,
      double obscuredBottom = 0,
    }) => noteRevealOffset(
      target: target,
      pixels: pixels,
      viewportExtent: 400,
      minScrollExtent: 0,
      maxScrollExtent: 10000,
      obscuredBottom: obscuredBottom,
    );

    test('a target inside the band needs no scroll', () {
      expect(offset(const Rect.fromLTRB(0, 100, 2, 125.6)), isNull);
    });

    test('a target below the band scrolls to clear the padding', () {
      expect(
        offset(const Rect.fromLTRB(0, 500, 2, 525.6)),
        moreOrLessEquals(145.6, epsilon: 0.001),
      );
      expect(
        offset(const Rect.fromLTRB(0, 500, 2, 525.6), obscuredBottom: 120),
        moreOrLessEquals(265.6, epsilon: 0.001),
      );
    });

    test('a target above the band clamps at the minimum extent', () {
      expect(
        offset(const Rect.fromLTRB(0, 10, 2, 35.6), pixels: 200),
        moreOrLessEquals(0, epsilon: 0.001),
      );
    });

    test('a target taller than the band aligns its top', () {
      expect(
        offset(const Rect.fromLTRB(0, 1000, 2, 1600), pixels: 1200),
        moreOrLessEquals(980, epsilon: 0.001),
      );
      expect(
        offset(const Rect.fromLTRB(0, 1000, 2, 1600), pixels: 980),
        isNull,
      );
    });

    test('the result never passes the maximum extent', () {
      expect(
        noteRevealOffset(
          target: const Rect.fromLTRB(0, 900, 2, 925.6),
          pixels: 0,
          viewportExtent: 400,
          minScrollExtent: 0,
          maxScrollExtent: 500,
        ),
        500,
      );
    });

    test('the handle spacing matches EditableText for Material handles', () {
      expect(
        noteRevealHandleSpacing(materialTextSelectionHandleControls, 25.6),
        moreOrLessEquals(39, epsilon: 0.001),
      );
    });
  });
}
