import 'dart:ui' as ui;

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_layout_engine.dart';
import 'package:field_notes/features/note_engine/photos/photo_drag.dart';
import 'package:field_notes/features/note_engine/photos/photo_relocation.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const String _p = '![p](photo/abc123abc123)';
const String _dropSource = '$_p\nA\n\nB\n\nC';
const List<PhotoDropTarget> _dropTargets = <PhotoDropTarget>[
  PhotoDropTarget(boundary: 0, y: 0),
  PhotoDropTarget(boundary: 24, y: 100),
  PhotoDropTarget(boundary: 26, y: 130),
  PhotoDropTarget(boundary: 29, y: 160),
  PhotoDropTarget(boundary: 32, y: 190),
];
const Rect _square = Rect.fromLTWH(0, 0, 100, 100);
const Offset _inSquare = Offset(50, 50);
const double _precision = 0.01;

final class _BandLayout implements NoteLayout {
  _BandLayout(this.units, this.photoRects);

  final List<MdBlock> units;

  @override
  final List<PhotoRect> photoRects;

  @override
  Rect rangeBounds(MdRange range) {
    final int index = units.indexWhere(
      (MdBlock unit) => unit.sourceRange == range,
    );
    expect(index, isNonNegative, reason: 'rangeBounds of a unit only');
    return _band(index);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _SizedLayout implements NoteLayout {
  const _SizedLayout(this.size);

  @override
  final Size size;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _OtherDecoration extends NoteViewDecoration {
  const _OtherDecoration();

  @override
  void paint(
    Canvas canvas,
    NoteLayout layout,
    Rect? Function(Rect contentRect) place,
  ) {}

  @override
  bool shouldRepaint(NoteViewDecoration oldDecoration) => true;
}

Rect _band(int index) => Rect.fromLTWH(0, 40.0 * index, 688, 30);

MdBlock _photoUnit(MdTree tree) =>
    tree.blocks.firstWhere((MdBlock b) => b.kind == MdBlockKind.photoLine);

final class _Harness {
  _Harness(this.tester, {required this.state, required this.targets});

  final WidgetTester tester;
  EditorState state;
  List<PhotoDropTarget> targets;
  final ScrollController scroll = ScrollController();
  final GlobalKey contentKey = GlobalKey();
  final GlobalKey viewportKey = GlobalKey();
  final List<bool> moves = <bool>[];
  final List<Transaction?> ups = <Transaction?>[];
  late final PhotoDragController controller = PhotoDragController(
    vsync: tester,
    readState: () => state,
    targets: () => targets,
    scrollPosition: () => scroll.position,
    viewport: () {
      final RenderBox box =
          viewportKey.currentContext!.findRenderObject()! as RenderBox;
      return box.localToGlobal(Offset.zero) & box.size;
    },
    toContent: toContent,
  );
  bool _disposed = false;

  Offset toContent(Offset global) {
    final RenderBox box =
        contentKey.currentContext!.findRenderObject()! as RenderBox;
    return box.globalToLocal(global);
  }

  Future<void> pump({
    double viewportHeight = 800,
    double contentHeight = 2000,
    Rect? Function(Offset content)? figureAt,
    Offset Function(Offset content)? contentToLocal,
  }) async {
    final Rect? Function(Offset content) figure =
        figureAt ?? (Offset c) => _square.contains(c) ? _square : null;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            key: viewportKey,
            width: 400,
            height: viewportHeight,
            child: Stack(
              children: <Widget>[
                SingleChildScrollView(
                  controller: scroll,
                  child: Listener(
                    key: contentKey,
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (PointerDownEvent event) {
                      final Rect? rect = figure(toContent(event.position));
                      if (rect != null) {
                        controller.pointerDown(
                          event,
                          _photoUnit(state.tree),
                          rect,
                        );
                      }
                    },
                    onPointerMove: (PointerMoveEvent event) =>
                        moves.add(controller.pointerMove(event)),
                    onPointerUp: (PointerUpEvent event) {
                      final Transaction? transaction = controller.pointerUp(
                        event,
                      );
                      ups.add(transaction);
                      if (transaction != null) {
                        state = state.apply(transaction);
                      }
                    },
                    onPointerCancel: (PointerCancelEvent event) =>
                        controller.pointerCancel(),
                    child: SizedBox(width: 400, height: contentHeight),
                  ),
                ),
                if (contentToLocal != null)
                  Positioned.fill(
                    child: PhotoDragOverlay(
                      controller: controller,
                      contentToLocal: contentToLocal,
                      ghost: const ColoredBox(color: Color(0xFF336699)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void disposeController() {
    if (!_disposed) {
      _disposed = true;
      controller.dispose();
    }
  }

  Future<void> finish() async {
    await tester.pumpWidget(const SizedBox());
    disposeController();
    scroll.dispose();
  }
}

void _pinSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<_Harness> _dropHarness(WidgetTester tester, String source) async {
  final _Harness harness = _Harness(
    tester,
    state: EditorState.create(source, parse: parseNoteTree),
    targets: _dropTargets,
  );
  await harness.pump();
  return harness;
}

Future<_Harness> _scrollHarness(WidgetTester tester) async {
  final _Harness harness = _Harness(
    tester,
    state: EditorState.create('$_p\nA', parse: parseNoteTree),
    targets: <PhotoDropTarget>[
      for (int i = 0; i <= 30; i++) PhotoDropTarget(boundary: i, y: 100.0 * i),
    ],
  );
  await harness.pump(
    viewportHeight: 400,
    contentHeight: 3000,
    figureAt: (Offset c) => Rect.fromLTWH(c.dx - 50, c.dy - 50, 100, 100),
  );
  return harness;
}

Future<TestGesture> _mouseDrag(
  WidgetTester tester, {
  Offset at = _inSquare,
}) async {
  final TestGesture gesture = await tester.startGesture(
    at,
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveBy(const Offset(0, 5));
  return gesture;
}

void main() {
  test('the insertion line only sits at top level block boundaries', () {
    const String source =
        'A\nA2\n\n- x\n  - y\n\n> q\n\n| a |\n| - |\n| b |\n\n```\ncode\n```'
        '\n\n$_p\n\n~~~\nopen\nfence';
    expect(source.indexOf('~~~'), 81);
    final MdTree tree = parseNoteTree(source);
    final List<MdBlock> units = tree.blocks;
    final int photoIndex = units.indexWhere(
      (MdBlock b) => b.kind == MdBlockKind.photoLine,
    );
    final NoteLayout layout = _BandLayout(units, <PhotoRect>[
      PhotoRect(
        sourceRange: units[photoIndex].sourceRange,
        reference: 'abc123abc123',
        occurrence: 0,
        rect: _band(photoIndex),
        imageRect: _band(photoIndex),
        flow: PhotoFlow.block,
      ),
    ]);

    final List<PhotoDropTarget> targets = photoDropTargets(
      source,
      tree,
      layout,
    );

    expect(
      targets.map((PhotoDropTarget t) => t.boundary).toList(),
      photoBoundaries(source, tree),
    );
    expect(targets.map((PhotoDropTarget t) => t.boundary).toList(), <int>[
      0,
      4,
      15,
      20,
      39,
      53,
      79,
    ]);
    expect(targets.map((PhotoDropTarget t) => t.y).toList(), <double>[
      0,
      30,
      70,
      110,
      150,
      190,
      230,
    ]);
    expect(targets.every((PhotoDropTarget t) => t.boundary < 81), isTrue);

    final double lastBottom = _band(units.length - 1).bottom;
    for (double y = -50; y <= lastBottom + 50; y += 1) {
      final PhotoDropTarget? nearest = nearestPhotoDropTarget(targets, y);
      PhotoDropTarget expected = targets.first;
      for (final PhotoDropTarget t in targets) {
        if ((t.y - y).abs() < (expected.y - y).abs()) {
          expected = t;
        }
      }
      expect(nearest, expected, reason: 'at y $y');
      for (final MdBlock unit in units) {
        expect(
          unit.sourceRange.start < nearest!.boundary &&
              nearest.boundary < unit.sourceRange.end,
          isFalse,
          reason: 'at y $y inside ${unit.sourceRange}',
        );
      }
    }
    expect(nearestPhotoDropTarget(const <PhotoDropTarget>[], 10), isNull);
    expect(
      nearestPhotoDropTarget(const <PhotoDropTarget>[
        PhotoDropTarget(boundary: 1, y: 0),
        PhotoDropTarget(boundary: 2, y: 20),
      ], 10),
      const PhotoDropTarget(boundary: 1, y: 0),
    );
  });

  testWidgets('a drop relocates the photo and keeps it selected', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final _Harness harness = await _dropHarness(tester, _dropSource);

    final TestGesture gesture = await _mouseDrag(tester);
    expect(harness.controller.isDragging, isTrue);
    await gesture.moveTo(const Offset(50, 158));
    expect(harness.controller.session!.target!.boundary, 29);
    await gesture.up();

    final Transaction transaction = harness.ups.single!;
    expect(harness.state.source, 'A\n\nB\n$_p\n\nC');
    expect(transaction.selection, const NoteSelection(anchor: 5, head: 29));
    expect(transaction.event, TransactionEvent.photo);
    expect(transaction.addToHistory, isTrue);
    expect(harness.controller.session, isNull);

    const String floated = '![](photo/abc123abc123 "left large")';
    harness.state = EditorState.create(
      'A\n$floated\n\nB\n\nC',
      parse: parseNoteTree,
    );
    harness.targets = const <PhotoDropTarget>[
      PhotoDropTarget(boundary: 0, y: 0),
      PhotoDropTarget(boundary: 1, y: 30),
      PhotoDropTarget(boundary: 38, y: 130),
      PhotoDropTarget(boundary: 41, y: 160),
      PhotoDropTarget(boundary: 44, y: 190),
    ];
    final TestGesture second = await _mouseDrag(tester);
    await second.moveTo(const Offset(50, 158));
    await second.up();

    expect(harness.state.source, 'A\n\nB\n$floated\n\nC');
    expect(
      harness.ups.last!.selection,
      const NoteSelection(anchor: 5, head: 41),
    );
    await harness.finish();
  });

  testWidgets('a drop beside the photo or escape makes no transaction', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final _Harness harness = await _dropHarness(tester, _dropSource);

    for (final double y in <double>[10, 100]) {
      final TestGesture gesture = await _mouseDrag(tester);
      await gesture.moveTo(Offset(50, y));
      expect(harness.controller.session!.target!.boundary, y == 10 ? 0 : 24);
      await gesture.up();
      expect(harness.ups.last, isNull);
      expect(harness.controller.session, isNull);
      expect(harness.state.source, _dropSource);
    }

    final TestGesture gesture = await _mouseDrag(tester);
    await gesture.moveTo(const Offset(50, 158));
    expect(harness.controller.isDragging, isTrue);
    expect(harness.controller.escape(), isTrue);
    expect(harness.controller.session, isNull);
    await gesture.moveTo(const Offset(50, 190));
    expect(harness.controller.session, isNull);
    await gesture.up();
    expect(harness.ups.last, isNull);
    expect(harness.ups, hasLength(3));
    expect(harness.controller.escape(), isFalse);
    expect(harness.state.source, _dropSource);
    await harness.finish();
  });

  testWidgets('dragging near an edge scrolls the view', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final _Harness harness = await _scrollHarness(tester);
    final ScrollPosition position = harness.scroll.position;

    final TestGesture gesture = await _mouseDrag(
      tester,
      at: const Offset(50, 200),
    );
    await gesture.moveTo(const Offset(50, 390));
    final PhotoDropTarget before = harness.controller.session!.target!;
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(position.pixels, greaterThan(0));
    expect(harness.controller.session!.target, isNot(before));
    expect(
      harness.controller.session!.target,
      nearestPhotoDropTarget(
        harness.targets,
        harness.toContent(const Offset(50, 390)).dy,
      ),
    );

    await gesture.moveTo(const Offset(50, 200));
    await tester.pump(const Duration(milliseconds: 16));
    final double stopped = position.pixels;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(position.pixels, stopped);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(harness.controller.escape(), isTrue);
    await gesture.up();

    position.jumpTo(0);
    await tester.pump();
    final TestGesture top = await _mouseDrag(tester, at: const Offset(50, 200));
    await top.moveTo(const Offset(50, 10));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(milliseconds: 16));
    expect(position.pixels, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(harness.controller.escape(), isTrue);
    await top.up();
    expect(harness.ups, everyElement(isNull));
    await harness.finish();
  });

  testWidgets('a 3 px mouse move does not start a drag and 4 px does', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final _Harness harness = await _dropHarness(tester, _dropSource);
    final TestGesture gesture = await tester.startGesture(
      _inSquare,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, 3));
    expect(harness.controller.isDragging, isFalse);
    expect(harness.moves.last, isFalse);
    await gesture.moveBy(const Offset(0, 1));
    expect(harness.controller.isDragging, isTrue);
    expect(harness.moves.last, isTrue);
    harness.controller.escape();
    await gesture.up();
    await harness.finish();
  });

  testWidgets('a touch drag starts after a 400 ms long press', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final _Harness harness = await _dropHarness(tester, _dropSource);
    final TestGesture held = await tester.startGesture(_inSquare);
    await tester.pump(const Duration(milliseconds: 450));
    await held.moveBy(const Offset(0, 1));
    expect(harness.controller.isDragging, isTrue);
    harness.controller.escape();
    await held.up();

    final TestGesture early = await tester.startGesture(_inSquare);
    await tester.pump(const Duration(milliseconds: 100));
    await early.moveBy(const Offset(0, 30));
    expect(harness.controller.isDragging, isFalse);
    await tester.pumpAndSettle();
    await early.moveBy(const Offset(0, 1));
    expect(harness.controller.isDragging, isFalse);
    await early.up();
    await tester.pumpAndSettle();
    await harness.finish();
  });

  testWidgets('a touch drag takes the pointer from the scroll view', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final _Harness harness = await _scrollHarness(tester);
    final ScrollPosition position = harness.scroll.position;

    final TestGesture held = await tester.startGesture(const Offset(50, 200));
    await tester.pump(const Duration(milliseconds: 450));
    for (int i = 0; i < 3; i++) {
      await held.moveBy(const Offset(0, -20));
    }
    expect(harness.controller.isDragging, isTrue);
    expect(position.pixels, 0);
    expect(harness.controller.escape(), isTrue);
    await held.up();
    await tester.pumpAndSettle();
    expect(position.pixels, 0);

    final TestGesture early = await tester.startGesture(const Offset(50, 200));
    await tester.pump(const Duration(milliseconds: 100));
    for (int i = 0; i < 3; i++) {
      await early.moveBy(const Offset(0, -20));
    }
    expect(harness.controller.isDragging, isFalse);
    expect(position.pixels, greaterThan(0));
    await early.up();
    await tester.pumpAndSettle();
    await harness.finish();
  });

  testWidgets('a second pointer during a drag changes nothing', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final _Harness harness = await _dropHarness(tester, _dropSource);
    final TestGesture gesture = await _mouseDrag(tester);
    final PhotoDragSession session = harness.controller.session!;

    final TestGesture other = await tester.startGesture(
      const Offset(20, 20),
      kind: PointerDeviceKind.mouse,
      pointer: 9,
    );
    await other.moveBy(const Offset(0, 80));
    expect(harness.moves.last, isFalse);
    await other.up();
    expect(harness.ups.single, isNull);
    expect(identical(harness.controller.session, session), isTrue);

    harness.controller.escape();
    await gesture.up();
    await harness.finish();
  });

  testWidgets('a still pointer during a drag notifies no listener', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final _Harness harness = await _dropHarness(tester, _dropSource);
    final TestGesture gesture = await _mouseDrag(tester);
    int notified = 0;
    harness.controller.addListener(() => notified += 1);

    await gesture.moveBy(Offset.zero);
    expect(harness.moves.last, isTrue);
    expect(notified, 0);
    await gesture.moveBy(const Offset(0, 1));
    expect(notified, 1);

    harness.controller.escape();
    await gesture.up();
    await harness.finish();
  });

  test('the insertion line paints a 2 px coral rule across the column', () {
    const PhotoInsertionLineDecoration decoration =
        PhotoInsertionLineDecoration(95);
    const NoteLayout layout = _SizedLayout(Size(688, 900));
    int placed = 0;

    expect(
      (Canvas canvas) => decoration.paint(canvas, layout, (Rect r) {
        placed += 1;
        return r;
      }),
      paints
        ..rect(rect: const Rect.fromLTRB(0, 94, 688, 96), color: Palette.coral),
    );
    expect(
      (Canvas canvas) => decoration.paint(canvas, layout, (Rect r) => r),
      paintsExactlyCountTimes(#drawRect, 1),
    );
    expect(placed, 0);
    expect(
      decoration.shouldRepaint(const PhotoInsertionLineDecoration(95)),
      isFalse,
    );
    expect(
      decoration.shouldRepaint(const PhotoInsertionLineDecoration(96)),
      isTrue,
    );
    expect(decoration.shouldRepaint(const _OtherDecoration()), isTrue);
    expect(decoration, const PhotoInsertionLineDecoration(95));
  });

  testWidgets('the overlay draws the ghost only during a drag', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final _Harness harness = _Harness(
      tester,
      state: EditorState.create(_dropSource, parse: parseNoteTree),
      targets: _dropTargets,
    );
    Offset toLocal(Offset content) => content + const Offset(7, 11);
    await harness.pump(contentToLocal: toLocal);
    expect(find.byKey(photoDragGhostKey), findsNothing);

    final TestGesture gesture = await _mouseDrag(tester);
    await tester.pump();
    final PhotoDragSession session = harness.controller.session!;
    final Finder ghost = find.byKey(photoDragGhostKey);
    expect(ghost, findsOneWidget);
    expect(tester.getTopLeft(ghost), toLocal(session.ghostTopLeft));
    expect(tester.getSize(ghost), _square.size);
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(of: ghost, matching: find.byType(Opacity)),
          )
          .opacity,
      photoDragGhostOpacity,
    );
    expect(
      find.ancestor(of: ghost, matching: find.byType(IgnorePointer)),
      findsWidgets,
    );

    harness.controller.escape();
    await tester.pump();
    expect(find.byKey(photoDragGhostKey), findsNothing);
    await gesture.up();
    await harness.finish();
  });

  testWidgets('a drop after the source changed makes no transaction', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final _Harness harness = await _dropHarness(tester, _dropSource);
    final TestGesture gesture = await _mouseDrag(tester);
    await gesture.moveTo(const Offset(50, 158));
    harness.state = EditorState.create('${_dropSource}x', parse: parseNoteTree);
    await gesture.up();
    expect(harness.ups.single, isNull);
    expect(harness.state.source, '${_dropSource}x');
    await harness.finish();
  });

  testWidgets('dispose stops the auto-scroll ticker and the long press', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final _Harness scrolling = await _scrollHarness(tester);
    final TestGesture gesture = await _mouseDrag(
      tester,
      at: const Offset(50, 200),
    );
    await gesture.moveTo(const Offset(50, 390));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(scrolling.scroll.position.pixels, greaterThan(0));
    scrolling.disposeController();
    final double stopped = scrolling.scroll.position.pixels;
    await tester.pump(const Duration(milliseconds: 16));
    expect(scrolling.scroll.position.pixels, stopped);
    await gesture.up();
    await scrolling.finish();

    final _Harness pressing = await _dropHarness(tester, _dropSource);
    final TestGesture held = await tester.startGesture(_inSquare);
    await tester.pump(const Duration(milliseconds: 100));
    pressing.disposeController();
    await held.up();
    await tester.pumpAndSettle();
    await pressing.finish();
  });

  test('targets on a real layout never cut a line and follow the float', () {
    final String paragraph = List<String>.filled(120, 'harbour').join(' ');
    final String source =
        'A\n\n![](photo/abc123abc123 "right medium")\n$paragraph\n\nC';
    final MdTree tree = parseNoteTree(source);
    final NoteLayout
    layout = NoteLayoutEngine(projector: const NoteVisibleProjector()).layout(
      LayoutInputs(
        source: source,
        tree: tree,
        visibleText: const NoteVisibleProjector().project(source, tree, null),
        activeLine: null,
        columnWidth: 688,
        textScaler: TextScaler.noScaling,
        boldText: false,
        locale: const ui.Locale('en'),
        readerMode: false,
        mediaDimensions: const <String, Size>{'abc123abc123': Size(1200, 900)},
      ),
    );
    final PhotoRect photo = layout.photoRects.single;
    expect(photo.flow, PhotoFlow.floatRight);
    final double paragraphBottom = layout
        .rangeBounds(tree.blocks[2].sourceRange)
        .bottom;
    expect(paragraphBottom, greaterThan(photo.rect.bottom));

    final List<PhotoDropTarget> targets = photoDropTargets(
      source,
      tree,
      layout,
    );

    for (final PhotoDropTarget target in targets) {
      for (final FragmentInfo fragment in layout.fragments) {
        final Rect line = fragment.lineBox.rect;
        expect(
          target.y > line.top + _precision &&
              target.y < line.bottom - _precision,
          isFalse,
          reason: '$target cuts $fragment',
        );
      }
    }
    final PhotoDropTarget afterPhoto = targets.singleWhere(
      (PhotoDropTarget t) => t.boundary == photo.sourceRange.end,
    );
    expect(afterPhoto.y, closeTo(photo.rect.top, 0.5));
  });
}
