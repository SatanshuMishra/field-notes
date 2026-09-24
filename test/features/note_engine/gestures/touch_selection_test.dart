import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/gestures/selection_overlay_controller.dart';
import 'package:field_notes/features/note_engine/gestures/touch_selection.dart';
import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_layout_engine.dart';
import 'package:field_notes/features/note_engine/projection/active_line.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:field_notes/features/note_engine/render/note_view.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';

import '../../notes/support/notes_harness.dart';

const String _harbour = 'The harbour was quiet.';

final TargetPlatformVariant _android = TargetPlatformVariant.only(
  TargetPlatform.android,
);

String _logSource() => <String>[
  for (int i = 0; i < 60; i++) 'Line $i of the harbour log',
].join('\n');

int _lineStart(String source, int line) {
  int at = 0;
  for (int i = 0; i < line; i++) {
    at = source.indexOf('\n', at) + 1;
  }
  return at;
}

String _tableRow() =>
    '| ${List<String>.filled(20, 'abcdefghij').join(' | ')} |';

String _tableSource() => <String>[
  _tableRow(),
  '|${List<String>.filled(20, ' --- ').join('|')}|',
  _tableRow(),
].join('\n');

enum _Kind {
  drag,
  select,
  toggle,
  keyboard,
  cut,
  copy,
  paste,
  selectAll,
  reveal,
}

final class _Event {
  const _Event(this.kind, {this.drag, this.selection, this.cause, this.value});

  final _Kind kind;
  final bool? drag;
  final NoteSelection? selection;
  final SelectionChangedCause? cause;
  final int? value;

  @override
  String toString() =>
      '_Event(${kind.name}, $drag, $selection, ${cause?.name}, $value)';
}

class _Host extends StatefulWidget {
  const _Host({
    super.key,
    required this.initialSource,
    required this.initialSelection,
    required this.node,
    required this.renderKey,
    required this.scrollController,
  });

  final String initialSource;
  final NoteSelection initialSelection;
  final FocusNode node;
  final GlobalKey renderKey;
  final ScrollController scrollController;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String source = widget.initialSource;
  late MdTree tree = parseNoteTree(source);
  late NoteSelection selection = widget.initialSelection;
  bool dragging = false;
  ActiveLine? activeLine;
  List<_Event> events = const <_Event>[];
  NoteSelectionOverlayController? _overlay;
  final FakeNoteMediaResolver _resolver = FakeNoteMediaResolver()..memoizeAll();
  final NoteLayoutEngine _engine = NoteLayoutEngine(
    projector: const NoteVisibleProjector(),
  );

  NoteSelectionOverlayController get overlay => _overlay!;

  @override
  void initState() {
    super.initState();
    widget.node.addListener(_handleFocus);
    activeLine = _next();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _overlay ??= NoteSelectionOverlayController(
      context: context,
      renderKey: widget.renderKey,
      onSelectionChanged: _handleSelection,
      onDragActiveChanged: _handleDrag,
      onCut: (SelectionChangedCause cause) =>
          _add(_Event(_Kind.cut, cause: cause)),
      onCopy: (SelectionChangedCause cause) =>
          _add(_Event(_Kind.copy, cause: cause)),
      onPaste: (SelectionChangedCause cause) async =>
          _add(_Event(_Kind.paste, cause: cause)),
      onSelectAll: (SelectionChangedCause cause) =>
          _add(_Event(_Kind.selectAll, cause: cause)),
      onBringIntoView: (int offset) =>
          _add(_Event(_Kind.reveal, value: offset)),
    );
  }

  @override
  void dispose() {
    widget.node.removeListener(_handleFocus);
    _overlay?.dispose();
    super.dispose();
  }

  ActiveLine? _next() => nextActiveLine(
    previous: activeLine,
    source: source,
    tree: tree,
    selection: selection,
    focused: widget.node.hasFocus,
    composing: false,
    dragging: dragging,
  );

  void _handleFocus() {
    setState(() {
      activeLine = _next();
    });
  }

  void _add(_Event event) {
    events = List<_Event>.unmodifiable(<_Event>[...events, event]);
  }

  void setSelection(NoteSelection next) {
    setState(() {
      selection = next;
      activeLine = _next();
    });
  }

  void _handleSelection(NoteSelection next, SelectionChangedCause cause) {
    setState(() {
      _add(_Event(_Kind.select, selection: next, cause: cause));
      selection = next;
      activeLine = _next();
    });
  }

  void _handleDrag(bool value) {
    setState(() {
      _add(_Event(_Kind.drag, drag: value));
      dragging = value;
      activeLine = _next();
    });
  }

  void _handleToggle(int boxStart) {
    setState(() {
      _add(_Event(_Kind.toggle, value: boxStart));
      final String mark = source[boxStart + 1] == ' ' ? 'x' : ' ';
      source = source.replaceRange(boxStart + 1, boxStart + 2, mark);
      tree = parseNoteTree(source);
      activeLine = _next();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ActiveLine? active = activeLine;
    final NoteSelectionOverlayController controller = overlay;
    return Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 600,
          height: 400,
          child: Focus(
            focusNode: widget.node,
            child: NoteTouchSelection(
              renderKey: widget.renderKey,
              overlay: controller,
              focusNode: widget.node,
              onSelectionChanged: _handleSelection,
              onDragActiveChanged: _handleDrag,
              onToggleCheckbox: _handleToggle,
              onRequestKeyboard: () => _add(const _Event(_Kind.keyboard)),
              child: NoteView(
                renderKey: widget.renderKey,
                source: source,
                tree: tree,
                visibleText: const NoteVisibleProjector().project(
                  source,
                  tree,
                  active?.line,
                  activeCell: active?.cell,
                ),
                activeLine: active?.line,
                selection: selection,
                focused: widget.node.hasFocus,
                scrollController: widget.scrollController,
                runLayout: _engine.layout,
                mediaResolver: _resolver,
                startHandleLayerLink: controller.startHandleLayerLink,
                endHandleLayerLink: controller.endHandleLayerLink,
                toolbarLayerLink: controller.toolbarLayerLink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _Harness {
  final GlobalKey<_HostState> hostKey = GlobalKey<_HostState>();
  final GlobalKey renderKey = GlobalKey();
  final FocusNode node = FocusNode(debugLabel: 'editor');
  final ScrollController scroll = ScrollController();

  _HostState get host => hostKey.currentState!;

  NoteSelectionOverlayController get overlay => host.overlay;

  RenderNoteView get view =>
      renderKey.currentContext!.findRenderObject()! as RenderNoteView;

  List<_Event> of(_Kind kind) => <_Event>[
    for (final _Event event in host.events)
      if (event.kind == kind) event,
  ];

  Future<void> pump(
    WidgetTester tester,
    String source, {
    NoteSelection? selection,
    bool focused = true,
  }) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(node.dispose);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: _Host(
          key: hostKey,
          initialSource: source,
          initialSelection: selection ?? const NoteSelection.collapsed(0),
          node: node,
          renderKey: renderKey,
          scrollController: scroll,
        ),
      ),
    );
    await tester.pump();
    if (focused) {
      node.requestFocus();
      await tester.pump();
    }
  }

  Offset centreOf(int start, int end) => view.contentToGlobal(
    view.noteLayout.rangeBounds(MdRange(start, end)).center,
  );
}

Future<void> _touch(
  WidgetTester tester,
  Offset point, {
  PointerDeviceKind kind = PointerDeviceKind.touch,
}) async {
  final TestGesture gesture = await tester.startGesture(point, kind: kind);
  await tester.pump(const Duration(milliseconds: 30));
  await gesture.up();
  await tester.pump();
}

Future<void> _longPress(WidgetTester tester, Offset point) async {
  final TestGesture gesture = await tester.startGesture(
    point,
    kind: PointerDeviceKind.touch,
  );
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.up();
  await tester.pump();
  await tester.pump();
}

Future<void> _dragBy(
  WidgetTester tester,
  Offset from,
  Offset by, {
  int steps = 8,
}) async {
  final TestGesture gesture = await tester.startGesture(
    from,
    kind: PointerDeviceKind.touch,
  );
  await tester.pump();
  final Offset slop = Offset(
    by.dx == 0 ? 0 : (kTouchSlop + 2) * by.dx.sign,
    by.dy == 0 ? 0 : (kTouchSlop + 2) * by.dy.sign,
  );
  await gesture.moveBy(slop);
  await tester.pump();
  final Offset step = (by - slop) / steps.toDouble();
  for (int i = 0; i < steps; i++) {
    await gesture.moveBy(step);
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}

TextSelectionHandleType _handleTypeOf(WidgetTester tester, Finder follower) {
  final List<Transform> turns = tester
      .widgetList<Transform>(
        find.descendant(of: follower, matching: find.byType(Transform)),
      )
      .toList();
  if (turns.isEmpty) {
    return TextSelectionHandleType.right;
  }
  final Float64List storage = turns.first.transform.storage;
  final double angle = math.atan2(storage[1], storage[0]);
  return (angle - math.pi / 4).abs() < 0.01
      ? TextSelectionHandleType.collapsed
      : TextSelectionHandleType.left;
}

List<TextSelectionHandleType> _handleTypes(
  WidgetTester tester,
  NoteSelectionOverlayController overlay,
) => <TextSelectionHandleType>[
  for (final LayerLink link in <LayerLink>[
    overlay.startHandleLayerLink,
    overlay.endHandleLayerLink,
  ])
    for (final Element follower
        in find
            .byWidgetPredicate(
              (Widget widget) =>
                  widget is CompositedTransformFollower && widget.link == link,
            )
            .evaluate())
      _handleTypeOf(
        tester,
        find.byElementPredicate((Element e) => e == follower),
      ),
];

List<String> _toolbarLabels(WidgetTester tester) => <String>[
  for (final Text text in tester.widgetList<Text>(
    find.descendant(
      of: find.byType(AdaptiveTextSelectionToolbar),
      matching: find.byType(Text),
    ),
  ))
    text.data ?? '',
];

void main() {
  testWidgets('a long press selects a word and shows the magnifier', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    await harness.pump(tester, _harbour);
    final TestGesture gesture = await tester.startGesture(
      harness.centreOf(4, 11),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(const Duration(milliseconds: 600));

    final List<_Event> events = harness.host.events;
    final int select = events.indexWhere(
      (_Event event) => event.kind == _Kind.select,
    );
    expect(select, greaterThanOrEqualTo(0));
    expect(events[select].selection, const NoteSelection(anchor: 4, head: 11));
    expect(events[select].cause, SelectionChangedCause.longPress);
    final int dragOn = events.indexWhere(
      (_Event event) => event.kind == _Kind.drag && event.drag == true,
    );
    expect(dragOn, greaterThanOrEqualTo(0));
    expect(dragOn, lessThan(select));
    expect(find.byType(TextMagnifier), findsOneWidget);

    await gesture.up();
    await tester.pump();
    await tester.pump();

    expect(find.byType(TextMagnifier), findsNothing);
    expect(harness.of(_Kind.drag).map((_Event event) => event.drag), <bool?>[
      true,
      false,
    ]);
    expect(harness.overlay.handlesShown, isTrue);
    expect(harness.overlay.toolbarShown, isTrue);
  }, variant: _android);

  testWidgets('handles hide when their end leaves the viewport', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    final String source = _logSource();
    await harness.pump(tester, source, focused: false);
    final int from = _lineStart(source, 2) + 3;
    final int to = _lineStart(source, 10) + 6;
    harness.host.setSelection(NoteSelection(anchor: from, head: to));
    await tester.pump();
    harness.overlay.showHandles();
    await tester.pump();

    final NoteSelectionOverlayController overlay = harness.overlay;
    expect(overlay.startHandleVisible.value, isTrue);
    expect(overlay.endHandleVisible.value, isTrue);

    final NoteLayout layout = harness.view.noteLayout;
    final Rect second = layout.lineBoxAt(from, TextAffinity.downstream).rect;
    final Rect tenth = layout.lineBoxAt(to, TextAffinity.downstream).rect;
    expect(second.bottom + 1, lessThan(tenth.top));
    harness.scroll.jumpTo(second.bottom + 1);
    await tester.pump();
    expect(overlay.startHandleVisible.value, isFalse);
    expect(overlay.endHandleVisible.value, isTrue);

    harness.scroll.jumpTo(tenth.bottom + 1);
    await tester.pump();
    expect(overlay.startHandleVisible.value, isFalse);
    expect(overlay.endHandleVisible.value, isFalse);

    harness.scroll.jumpTo(0);
    await tester.pump();
    expect(overlay.startHandleVisible.value, isTrue);
    expect(overlay.endHandleVisible.value, isTrue);
  }, variant: _android);

  testWidgets(
    'the context menu shows cut, copy, paste and select all',
    (WidgetTester tester) async {
      final _Harness harness = _Harness();
      await harness.pump(tester, _harbour);
      final bool android = defaultTargetPlatform == TargetPlatform.android;
      if (android) {
        await _longPress(tester, harness.centreOf(4, 11));
        expect(
          harness.host.selection,
          const NoteSelection(anchor: 4, head: 11),
        );
        harness.overlay.hideToolbar(false);
        await tester.pump();
        expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
        await _touch(tester, harness.centreOf(4, 11));
      } else {
        harness.host.setSelection(const NoteSelection(anchor: 4, head: 11));
        await tester.pump();
        harness.overlay.showToolbar(anchor: harness.centreOf(4, 11));
        await tester.pump();
      }

      expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
      expect(
        _toolbarLabels(tester),
        android
            ? <String>['Cut', 'Copy', 'Paste', 'Select all']
            : <String>['Cut', 'Copy', 'Paste', 'Select All'],
      );

      await _touch(tester, tester.getCenter(find.text('Copy')));
      expect(
        harness.of(_Kind.copy).map((_Event event) => event.cause),
        <SelectionChangedCause>[SelectionChangedCause.toolbar],
      );
    },
    variant: TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.android,
      TargetPlatform.macOS,
    }),
  );

  group('also', () {
    testWidgets('a tap places the caret on tap-up, not tap-down', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness();
      await harness.pump(tester, _harbour);
      final TestGesture gesture = await tester.startGesture(
        harness.centreOf(12, 15),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump(const Duration(milliseconds: 30));
      expect(harness.of(_Kind.select), isEmpty);

      await gesture.up();
      await tester.pump();
      await tester.pump();

      final List<_Event> selects = harness.of(_Kind.select);
      expect(selects, hasLength(1));
      expect(selects.single.cause, SelectionChangedCause.tap);
      expect(selects.single.selection!.isCollapsed, isTrue);
      expect(selects.single.selection!.head, inInclusiveRange(12, 15));
      expect(harness.overlay.handlesShown, isTrue);
      expect(harness.overlay.toolbarShown, isFalse);
    }, variant: _android);

    testWidgets('a tap on the caret or a handle toggles the toolbar', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness();
      await harness.pump(tester, _harbour);
      final Offset point = harness.centreOf(12, 15);
      await _touch(tester, point);
      await tester.pump();
      final NoteSelection caret = harness.host.selection;
      expect(caret.isCollapsed, isTrue);
      await tester.pump(const Duration(milliseconds: 500));

      await _touch(tester, point);
      expect(harness.host.selection, caret);
      expect(harness.overlay.toolbarShown, isTrue);
      await tester.pump(const Duration(milliseconds: 500));

      final RenderNoteView view = harness.view;
      final Offset handle = view.contentToGlobal(
        view.noteLayout.selectionEndpoints(caret).start.point,
      );
      await _touch(tester, handle + const Offset(0, 14));
      expect(harness.overlay.toolbarShown, isFalse);
      await tester.pump(const Duration(milliseconds: 500));
      await _touch(tester, handle + const Offset(0, 14));
      expect(harness.overlay.toolbarShown, isTrue);
      expect(harness.host.selection, caret);
    }, variant: _android);

    testWidgets('every tap asks for the keyboard, even on the caret', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness();
      await harness.pump(tester, _harbour);
      final Offset point = harness.centreOf(12, 15);
      await _touch(tester, point);
      await tester.pump();
      final NoteSelection caret = harness.host.selection;
      expect(harness.of(_Kind.keyboard), hasLength(1));
      await tester.pump(const Duration(milliseconds: 500));

      await _touch(tester, point);
      expect(harness.host.selection, caret);
      expect(harness.overlay.toolbarShown, isTrue);
      expect(harness.of(_Kind.keyboard), hasLength(2));
      await tester.pump(const Duration(milliseconds: 500));

      await _touch(tester, point);
      expect(harness.overlay.toolbarShown, isFalse);
      expect(harness.of(_Kind.keyboard), hasLength(3));
    }, variant: _android);

    testWidgets('a tap near a checkbox only toggles it', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness();
      const String source = '- [ ] passport\nsecond line';
      await harness.pump(
        tester,
        source,
        selection: const NoteSelection.collapsed(source.length),
      );
      final RenderNoteView view = harness.view;
      final AtomicObject box = view.visibleText.atomics.firstWhere(
        (AtomicObject atomic) => atomic.kind == AtomicKind.checkbox,
      );
      final Rect glyph = view.noteLayout.rangeBounds(box.sourceRange);
      await _touch(
        tester,
        view.contentToGlobal(glyph.center + const Offset(20, 0)),
      );
      expect(harness.of(_Kind.toggle), hasLength(1));
      expect(harness.of(_Kind.select), isEmpty);
      expect(harness.of(_Kind.keyboard), isEmpty);
      expect(harness.host.source, '- [x] passport\nsecond line');
      expect(
        harness.host.selection,
        const NoteSelection.collapsed(source.length),
      );
    }, variant: _android);

    testWidgets('a mouse click triggers nothing', (WidgetTester tester) async {
      final _Harness harness = _Harness();
      await harness.pump(tester, _harbour);
      await _touch(
        tester,
        harness.centreOf(12, 15),
        kind: PointerDeviceKind.mouse,
      );
      final TestGesture gesture = await tester.startGesture(
        harness.centreOf(4, 11),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.up();
      await tester.pump();
      expect(harness.host.events, isEmpty);
      expect(harness.overlay.handlesShown, isFalse);
    }, variant: _android);

    testWidgets('a vertical touch drag scrolls and selects nothing', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness();
      await harness.pump(tester, _logSource());
      final TestGesture gesture = await tester.startGesture(
        const Offset(300, 300),
        kind: PointerDeviceKind.touch,
      );
      for (int step = 0; step < 10; step++) {
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(harness.scroll.offset, greaterThan(100));
      expect(harness.of(_Kind.select), isEmpty);
    }, variant: _android);

    testWidgets('dragging the end handle extends the selection', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness();
      final String source = _logSource();
      await harness.pump(tester, source, focused: false);
      final int from = _lineStart(source, 2) + 3;
      final int to = _lineStart(source, 10) + 6;
      harness.host.setSelection(NoteSelection(anchor: from, head: to));
      await tester.pump();
      harness.overlay.showHandles();
      await tester.pump();

      final RenderNoteView view = harness.view;
      final SelectionEndpoints endpoints = view.noteLayout.selectionEndpoints(
        harness.host.selection,
      );
      final Offset end = view.contentToGlobal(endpoints.end.point);
      final double lineHeight = endpoints.endLineHeight;
      final TestGesture gesture = await tester.startGesture(
        end + const Offset(10, 10),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(0, kTouchSlop + 2));
      await tester.pump();
      for (int step = 0; step < 8; step++) {
        await gesture.moveBy(Offset(0, lineHeight / 4));
        await tester.pump();
      }
      expect(find.byType(TextMagnifier), findsOneWidget);
      await gesture.up();
      await tester.pump();

      expect(harness.of(_Kind.drag).map((_Event event) => event.drag), <bool?>[
        true,
        false,
      ]);
      final NoteSelection selection = harness.host.selection;
      expect(selection.start, from);
      expect(
        selection.end,
        inInclusiveRange(_lineStart(source, 12), _lineStart(source, 13) - 1),
      );
      expect(harness.of(_Kind.select).last.cause, SelectionChangedCause.drag);
      expect(find.byType(TextMagnifier), findsNothing);
    }, variant: _android);

    testWidgets('dragging the caret handle moves the caret', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness();
      await harness.pump(tester, _harbour);
      await _touch(tester, harness.centreOf(4, 11));
      await tester.pump();
      final NoteSelection caret = harness.host.selection;
      expect(caret.isCollapsed, isTrue);
      expect(harness.overlay.handlesShown, isTrue);

      final RenderNoteView view = harness.view;
      final Offset handle = view.contentToGlobal(
        view.noteLayout.selectionEndpoints(caret).start.point,
      );
      await _dragBy(tester, handle + const Offset(0, 14), const Offset(120, 0));

      final List<NoteSelection> dragged = <NoteSelection>[
        for (final _Event event in harness.of(_Kind.select))
          if (event.cause == SelectionChangedCause.drag) event.selection!,
      ];
      expect(dragged, isNotEmpty);
      expect(
        dragged.where((NoteSelection selection) => !selection.isCollapsed),
        isEmpty,
      );
      final NoteSelection moved = harness.host.selection;
      expect(moved.isCollapsed, isTrue);
      expect(moved.head, greaterThan(caret.head));
    }, variant: _android);

    testWidgets('a handle drag never carries its end past the other end', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness();
      await harness.pump(tester, _harbour, focused: false);
      harness.host.setSelection(const NoteSelection(anchor: 4, head: 15));
      await tester.pump();
      harness.overlay.showHandles();
      await tester.pump();

      final RenderNoteView view = harness.view;
      final Offset end = view.contentToGlobal(
        view.noteLayout.selectionEndpoints(harness.host.selection).end.point,
      );
      await _dragBy(tester, end + const Offset(10, 10), const Offset(-160, 0));

      final List<NoteSelection> dragged = <NoteSelection>[
        for (final _Event event in harness.of(_Kind.select))
          if (event.cause == SelectionChangedCause.drag) event.selection!,
      ];
      expect(dragged, isNotEmpty);
      expect(
        dragged.where(
          (NoteSelection selection) =>
              selection.anchor != 4 || selection.head <= 4,
        ),
        isEmpty,
      );
      expect(harness.host.selection.start, 4);
      expect(harness.host.selection.end, greaterThan(4));
    }, variant: _android);

    testWidgets('the handles follow a selection changed elsewhere', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness();
      await harness.pump(tester, _harbour);
      await _longPress(tester, harness.centreOf(4, 11));
      expect(harness.host.selection, const NoteSelection(anchor: 4, head: 11));
      expect(_handleTypes(tester, harness.overlay), <TextSelectionHandleType>[
        TextSelectionHandleType.left,
        TextSelectionHandleType.right,
      ]);

      harness.host.setSelection(const NoteSelection.collapsed(11));
      await tester.pump();
      await tester.pump();

      expect(harness.overlay.handlesShown, isTrue);
      expect(_handleTypes(tester, harness.overlay), <TextSelectionHandleType>[
        TextSelectionHandleType.collapsed,
      ]);

      harness.host.setSelection(const NoteSelection(anchor: 0, head: 22));
      await tester.pump();
      await tester.pump();

      expect(_handleTypes(tester, harness.overlay), <TextSelectionHandleType>[
        TextSelectionHandleType.left,
        TextSelectionHandleType.right,
      ]);
    }, variant: _android);

    testWidgets('the menu for a caret shows paste and select all only', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness();
      await harness.pump(tester, _harbour);
      harness.overlay.showToolbar();
      await tester.pump();
      expect(_toolbarLabels(tester), <String>['Paste', 'Select all']);

      harness.overlay.hideToolbar();
      harness.host.setSelection(const NoteSelection(anchor: 4, head: 11));
      await tester.pump();
      harness.overlay.showToolbar(
        leadingItems: <ContextMenuButtonItem>[
          ContextMenuButtonItem(label: 'harbor', onPressed: () {}),
        ],
      );
      await tester.pump();
      expect(_toolbarLabels(tester), <String>[
        'harbor',
        'Cut',
        'Copy',
        'Paste',
        'Select all',
      ]);
    }, variant: _android);

    testWidgets('a horizontal touch drag scrolls a wide table', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness();
      final String source = '${_tableSource()}\n\nAfter.';
      await harness.pump(tester, source, focused: false);
      final RenderNoteView view = harness.view;
      final LaidOutRow row = view.noteLayout.flow.rows.firstWhere(
        (LaidOutRow row) => row.row.kind == LayoutRowKind.table,
      );
      expect(row.contentWidth, closeTo(1301, 1));
      final double y = row.top + 1;
      final TestGesture gesture = await tester.startGesture(
        view.contentToGlobal(Offset(300, y)),
        kind: PointerDeviceKind.touch,
      );
      await gesture.moveBy(const Offset(-150, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(view.tableScrollOffsetAt(y), 150);

      final int after = source.indexOf('After');
      final Offset paragraph = harness.centreOf(after, after + 5);
      final TestGesture second = await tester.startGesture(
        paragraph,
        kind: PointerDeviceKind.touch,
      );
      await second.moveBy(const Offset(-150, 0));
      await tester.pump();
      await second.up();
      await tester.pump();
      expect(view.tableScrollOffsetAt(y), 150);
      expect(harness.host.events, isEmpty);
    }, variant: _android);

    testWidgets('dispose leaves no overlay entries', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness();
      await harness.pump(tester, _harbour);
      await _longPress(tester, harness.centreOf(4, 11));
      expect(harness.overlay.handlesShown, isTrue);
      expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
      expect(find.byType(CompositedTransformFollower), findsWidgets);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
      expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
      expect(find.byType(CompositedTransformFollower), findsNothing);
      expect(find.byType(TextMagnifier), findsNothing);
    }, variant: _android);

    testWidgets('the delegate value is the visible text', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness();
      const String source = 'The **fog** lifted\nsecond';
      await harness.pump(
        tester,
        source,
        selection: const NoteSelection.collapsed(source.length),
      );
      expect(harness.host.activeLine, const ActiveLine(line: 1));
      final TextEditingValue value = harness.overlay.textEditingValue;
      expect(value.text, 'The fog lifted\nsecond');
      expect(value.selection, const TextSelection.collapsed(offset: 21));
    }, variant: _android);
  });
}
