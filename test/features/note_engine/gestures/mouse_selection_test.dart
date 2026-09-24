import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/gestures/mouse_selection.dart';
import 'package:field_notes/features/note_engine/layout/note_layout_engine.dart';
import 'package:field_notes/features/note_engine/projection/active_line.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:field_notes/features/note_engine/render/note_view.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';

import '../../notes/support/notes_harness.dart';

const String _photoNote =
    'A\n\n![Low tide](photo/a1b2c3d4e5f6 "left medium")\n\nB';
const Key _joinedKey = ValueKey<String>('joined');
const Key _outsideKey = ValueKey<String>('outside');

final TargetPlatformVariant _macOS = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

enum _Kind { drag, select, toggle, menu }

final class _Event {
  const _Event(this.kind, {this.drag, this.selection, this.cause, this.value});

  final _Kind kind;
  final bool? drag;
  final NoteSelection? selection;
  final SelectionChangedCause? cause;
  final Object? value;

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
    required this.resolver,
  });

  final String initialSource;
  final NoteSelection initialSelection;
  final FocusNode node;
  final GlobalKey renderKey;
  final FakeNoteMediaResolver resolver;

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
  final NoteLayoutEngine _engine = NoteLayoutEngine(
    projector: const NoteVisibleProjector(),
  );

  @override
  void initState() {
    super.initState();
    widget.node.addListener(_handleFocus);
    activeLine = _next();
  }

  @override
  void dispose() {
    widget.node.removeListener(_handleFocus);
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

  void _record(_Event event) {
    events = List<_Event>.unmodifiable(<_Event>[...events, event]);
  }

  void _handleSelection(NoteSelection next, SelectionChangedCause cause) {
    setState(() {
      _record(_Event(_Kind.select, selection: next, cause: cause));
      selection = next;
      activeLine = _next();
    });
  }

  void _handleDrag(bool value) {
    setState(() {
      _record(_Event(_Kind.drag, drag: value));
      dragging = value;
      activeLine = _next();
    });
  }

  void _handleToggle(int boxStart) {
    setState(() {
      _record(_Event(_Kind.toggle, value: boxStart));
      final String mark = source[boxStart + 1] == ' ' ? 'x' : ' ';
      source = source.replaceRange(boxStart + 1, boxStart + 2, mark);
      tree = parseNoteTree(source);
      activeLine = _next();
    });
  }

  void _handleMenu(Offset position) {
    setState(() {
      _record(_Event(_Kind.menu, value: position));
    });
  }

  @override
  Widget build(BuildContext context) {
    final ActiveLine? active = activeLine;
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: <Widget>[
            const TextFieldTapRegion(
              child: ColoredBox(
                key: _joinedKey,
                color: Color(0xFFEEEEEE),
                child: SizedBox(width: 200, height: 40),
              ),
            ),
            const ColoredBox(
              key: _outsideKey,
              color: Color(0xFFEEEEEE),
              child: SizedBox(width: 200, height: 40),
            ),
            SizedBox(
              width: 688,
              height: 600,
              child: Focus(
                focusNode: widget.node,
                child: NoteMouseSelection(
                  renderKey: widget.renderKey,
                  focusNode: widget.node,
                  onSelectionChanged: _handleSelection,
                  onDragActiveChanged: _handleDrag,
                  onToggleCheckbox: _handleToggle,
                  onContextMenu: _handleMenu,
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
                    runLayout: _engine.layout,
                    mediaResolver: widget.resolver,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _Harness {
  final GlobalKey<_HostState> hostKey = GlobalKey<_HostState>();
  final GlobalKey renderKey = GlobalKey();
  final FocusNode node = FocusNode(debugLabel: 'editor');

  _HostState get host => hostKey.currentState!;

  RenderNoteView get view =>
      renderKey.currentContext!.findRenderObject()! as RenderNoteView;

  List<_Event> get selects => <_Event>[
    for (final _Event event in host.events)
      if (event.kind == _Kind.select) event,
  ];

  Future<void> pump(
    WidgetTester tester,
    String source, {
    NoteSelection? selection,
    bool focused = true,
    FakeNoteMediaResolver? resolver,
  }) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(node.dispose);
    await tester.pumpWidget(
      _Host(
        key: hostKey,
        initialSource: source,
        initialSelection: selection ?? NoteSelection.collapsed(source.length),
        node: node,
        renderKey: renderKey,
        resolver: resolver ?? (FakeNoteMediaResolver()..memoizeAll()),
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

  Offset wordCentre(String word, {int from = 0}) {
    final int start = host.source.indexOf(word, from);
    return centreOf(start, start + word.length);
  }
}

FakeNoteMediaResolver _photoResolver() => FakeNoteMediaResolver(
  <String, ResolvedMedia>{prefixOf(photoIdA): availablePhoto(photoIdA)},
)..memoizeAll();

Future<void> _click(
  WidgetTester tester,
  Offset point, {
  int buttons = kPrimaryMouseButton,
  PointerDeviceKind kind = PointerDeviceKind.mouse,
}) async {
  final TestGesture gesture = await tester.startGesture(
    point,
    kind: kind,
    buttons: buttons,
  );
  await tester.pump(const Duration(milliseconds: 30));
  await gesture.up();
  await tester.pump();
}

Future<void> _press(
  WidgetTester tester,
  Finder finder, {
  PointerDeviceKind kind = PointerDeviceKind.mouse,
}) => _click(tester, tester.getCenter(finder), kind: kind);

Future<void> _clicks(WidgetTester tester, Offset point, int count) async {
  for (int i = 0; i < count; i++) {
    await _click(tester, point);
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<TestGesture> _heldMultiPress(
  WidgetTester tester,
  Offset point,
  int count,
) async {
  await _clicks(tester, point, count - 1);
  final TestGesture gesture = await tester.startGesture(
    point,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryMouseButton,
  );
  await tester.pump(const Duration(milliseconds: 30));
  return gesture;
}

Future<void> _dragTo(
  WidgetTester tester,
  TestGesture gesture,
  Offset from,
  Offset Function() to,
) async {
  for (int step = 1; step <= 3; step++) {
    final Offset target = to();
    await gesture.moveTo(Offset.lerp(from, target, step / 3)!);
    await tester.pump();
  }
}

void main() {
  testWidgets(
    'double clicking a word in a heading selects the word, not the marker',
    (WidgetTester tester) async {
      final _Harness harness = _Harness();
      await harness.pump(tester, '# Harbour day\n\nThe fog lifted.');
      expect(harness.host.activeLine, const ActiveLine(line: 2));
      final Offset p = harness.centreOf(2, 3);

      await _click(tester, p);
      await tester.pump(const Duration(milliseconds: 50));

      expect(harness.host.activeLine, const ActiveLine(line: 0));
      final RenderNoteView view = harness.view;
      expect(
        view.noteLayout.positionAt(view.globalToContent(p)).offset,
        lessThan(2),
      );

      await _click(tester, p);

      final _Event last = harness.selects.last;
      expect(last.selection, const NoteSelection(anchor: 2, head: 9));
      expect(last.cause, SelectionChangedCause.doubleTap);
      expect(harness.host.selection, const NoteSelection(anchor: 2, head: 9));
    },
    variant: _macOS,
  );

  testWidgets('the active line stays fixed during a drag', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    const String source = '# One\n**Two** words\n# Three';
    await harness.pump(tester, source);
    expect(harness.host.activeLine, const ActiveLine(line: 2));
    final Offset start = harness.centreOf(2, 5);

    final TestGesture gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await tester.pump();
    final List<ActiveLine?> seen = <ActiveLine?>[harness.host.activeLine];
    for (int step = 1; step <= 3; step++) {
      final Offset target = harness.centreOf(14, 19);
      await gesture.moveTo(Offset.lerp(start, target, step / 3)!);
      await tester.pump();
      seen.add(harness.host.activeLine);
    }
    await gesture.up();
    await tester.pump();

    final List<_Event> events = harness.host.events;
    expect(events.first.kind, _Kind.drag);
    expect(events.first.drag, isTrue);
    expect(events[1].kind, _Kind.select);
    expect(events[1].cause, SelectionChangedCause.tap);
    final NoteSelection pressed = events[1].selection!;
    expect(pressed.isCollapsed, isTrue);
    final int pressOffset = pressed.anchor;
    expect(pressOffset, inInclusiveRange(2, 5));
    final List<_Event> selects = harness.selects;
    expect(selects.length, greaterThan(1));
    for (final _Event event in selects) {
      expect(event.selection!.anchor, pressOffset);
    }
    expect(selects.last.selection!.head, inInclusiveRange(14, 19));
    expect(seen, everyElement(const ActiveLine(line: 2)));
    expect(events.last.kind, _Kind.drag);
    expect(events.last.drag, isFalse);
    expect(
      events.lastIndexWhere((_Event e) => e.kind == _Kind.select),
      lessThan(events.length - 1),
    );
    expect(events.where((_Event e) => e.kind == _Kind.drag).length, 2);
    expect(harness.host.activeLine, const ActiveLine(line: 1));
  }, variant: _macOS);

  testWidgets('a checkbox click toggles without moving the caret', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    await harness.pump(tester, '- [ ] passport\nsecond line');
    expect(harness.host.activeLine, const ActiveLine(line: 1));
    expect(harness.node.hasFocus, isTrue);

    await _click(tester, harness.centreOf(2, 6));

    final List<_Event> events = harness.host.events;
    expect(events.length, 1);
    expect(events.single.kind, _Kind.toggle);
    expect(events.single.value, 2);
    expect(harness.node.hasFocus, isTrue);
    expect(harness.host.source, '- [x] passport\nsecond line');
    expect(harness.host.selection, const NoteSelection.collapsed(26));
    expect(harness.host.activeLine, const ActiveLine(line: 1));
  }, variant: _macOS);

  testWidgets('taps on joined tap regions keep focus', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    await harness.pump(tester, 'The fog lifted.');
    expect(harness.node.hasFocus, isTrue);

    await _press(tester, find.byKey(_joinedKey));
    expect(harness.node.hasFocus, isTrue);

    await _press(tester, find.byKey(_outsideKey));
    expect(harness.node.hasFocus, isFalse);
  }, variant: _macOS);

  testWidgets(
    'on Android a touch outside keeps focus and a mouse press removes it',
    (WidgetTester tester) async {
      final _Harness harness = _Harness();
      await harness.pump(tester, 'The fog lifted.');

      await _press(
        tester,
        find.byKey(_outsideKey),
        kind: PointerDeviceKind.touch,
      );
      expect(harness.node.hasFocus, isTrue);

      await _press(tester, find.byKey(_outsideKey));
      expect(harness.node.hasFocus, isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('shift-click extends from the anchor', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    const String source = 'The fog lifted at noon.';
    await harness.pump(
      tester,
      source,
      selection: const NoteSelection.collapsed(4),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await _click(tester, harness.wordCentre('lifted'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    final NoteSelection selection = harness.host.selection;
    expect(selection.anchor, 4);
    expect(selection.head, inInclusiveRange(8, 14));
    expect(harness.selects.last.cause, SelectionChangedCause.tap);
  }, variant: _macOS);

  testWidgets('a triple click selects the line without its line break', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    await harness.pump(tester, 'alpha beta\ngamma delta\nend');

    await _clicks(tester, harness.wordCentre('delta'), 3);

    expect(harness.host.selection, const NoteSelection(anchor: 11, head: 22));
    expect(harness.selects.last.cause, SelectionChangedCause.tap);
  }, variant: _macOS);

  testWidgets('a triple click in a CRLF note excludes the CR and the LF', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    await harness.pump(tester, 'alpha beta\r\ngamma delta\r\nend');

    await _clicks(tester, harness.wordCentre('delta'), 3);

    expect(harness.host.selection, const NoteSelection(anchor: 12, head: 23));
  }, variant: _macOS);

  testWidgets('a word drag keeps the first word in both directions', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    await harness.pump(tester, 'one two three four five');
    final Offset start = harness.wordCentre('three');

    final TestGesture forward = await _heldMultiPress(tester, start, 2);
    await _dragTo(tester, forward, start, () => harness.wordCentre('five'));
    await forward.up();
    await tester.pump();
    expect(harness.host.selection, const NoteSelection(anchor: 8, head: 23));
    expect(harness.host.events.last.drag, isFalse);

    await tester.pump(const Duration(milliseconds: 400));
    final Offset again = harness.wordCentre('three');
    final TestGesture backward = await _heldMultiPress(tester, again, 2);
    await _dragTo(tester, backward, again, () => harness.wordCentre('one'));
    await backward.up();
    await tester.pump();
    expect(harness.host.selection, const NoteSelection(anchor: 13, head: 0));
  }, variant: _macOS);

  testWidgets('a line drag keeps the first line in both directions', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    await harness.pump(tester, 'aaa\nbbb\nccc\nddd');
    final Offset start = harness.wordCentre('ccc');

    final TestGesture forward = await _heldMultiPress(tester, start, 3);
    await _dragTo(tester, forward, start, () => harness.wordCentre('ddd'));
    await forward.up();
    await tester.pump();
    expect(harness.host.selection, const NoteSelection(anchor: 8, head: 15));

    await tester.pump(const Duration(milliseconds: 400));
    final Offset again = harness.wordCentre('ccc');
    final TestGesture backward = await _heldMultiPress(tester, again, 3);
    await _dragTo(tester, backward, again, () => harness.wordCentre('aaa'));
    await backward.up();
    await tester.pump();
    expect(harness.host.selection, const NoteSelection(anchor: 11, head: 0));
  }, variant: _macOS);

  testWidgets('a right click outside the selection selects the word', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    await harness.pump(
      tester,
      'The fog lifted',
      selection: const NoteSelection.collapsed(0),
    );
    final Offset point = harness.wordCentre('fog');

    await _click(tester, point, buttons: kSecondaryMouseButton);

    expect(harness.host.selection, const NoteSelection(anchor: 4, head: 7));
    expect(harness.selects.single.cause, SelectionChangedCause.tap);
    final _Event menu = harness.host.events.last;
    expect(menu.kind, _Kind.menu);
    expect(menu.value, point);
  }, variant: _macOS);

  testWidgets('a right click inside a range keeps the range', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    await harness.pump(
      tester,
      'The fog lifted',
      selection: const NoteSelection(anchor: 4, head: 14),
    );

    await _click(
      tester,
      harness.wordCentre('lifted'),
      buttons: kSecondaryMouseButton,
    );

    expect(harness.selects, isEmpty);
    expect(harness.host.selection, const NoteSelection(anchor: 4, head: 14));
    expect(harness.host.events.single.kind, _Kind.menu);
  }, variant: _macOS);

  testWidgets('a right click on a photo selects the photo', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    await harness.pump(tester, _photoNote, resolver: _photoResolver());
    final RenderNoteView view = harness.view;
    final Offset point = view.contentToGlobal(
      view.noteLayout.photoRects.single.rect.center,
    );

    await _click(tester, point, buttons: kSecondaryMouseButton);

    final int start = _photoNote.indexOf('![');
    final int end = _photoNote.indexOf('\n', start);
    expect(harness.host.selection, NoteSelection(anchor: start, head: end));
    expect(harness.host.events.last.kind, _Kind.menu);
  }, variant: _macOS);

  testWidgets(
    'clicking a photo selects its line and a move changes nothing',
    (WidgetTester tester) async {
      final _Harness harness = _Harness();
      await harness.pump(
        tester,
        _photoNote,
        focused: false,
        resolver: _photoResolver(),
      );
      final RenderNoteView view = harness.view;
      final Offset point = view.contentToGlobal(
        view.noteLayout.photoRects.single.rect.center,
      );
      final int start = _photoNote.indexOf('![');
      final int end = _photoNote.indexOf('\n', start);

      await _click(tester, point);

      expect(harness.host.selection, NoteSelection(anchor: start, head: end));
      expect(harness.node.hasFocus, isTrue);
      expect(harness.selects.single.cause, SelectionChangedCause.tap);

      await tester.pump(const Duration(milliseconds: 400));
      final int before = harness.host.events.length;
      final TestGesture gesture = await tester.startGesture(
        point,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      await tester.pump();
      await gesture.moveTo(harness.wordCentre('B'));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      final List<_Event> after = harness.host.events.sublist(before);
      expect(after.length, 1);
      expect(after.single.selection, NoteSelection(anchor: start, head: end));
      expect(harness.host.selection, NoteSelection(anchor: start, head: end));
    },
    variant: _macOS,
  );

  testWidgets('a click in a table cell puts the caret in that cell', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    const String source = '| a | b |\n| - | - |\n| cat | dog |';
    await harness.pump(
      tester,
      source,
      selection: const NoteSelection.collapsed(2),
    );
    final int dog = source.indexOf('dog');

    await _click(tester, harness.centreOf(dog, dog + 3));

    final NoteSelection selection = harness.host.selection;
    expect(selection.isCollapsed, isTrue);
    expect(selection.head, inInclusiveRange(dog, dog + 3));
  }, variant: _macOS);

  testWidgets('noteCheckboxAt inflates a small glyph to the minimum target', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    await harness.pump(tester, '- [ ] a\nb');
    final RenderNoteView view = harness.view;
    final AtomicObject box = view.visibleText.atomics.firstWhere(
      (AtomicObject atomic) => atomic.kind == AtomicKind.checkbox,
    );
    final Rect glyph = view.noteLayout.rangeBounds(box.sourceRange);
    expect(glyph.width, lessThan(48));
    expect(glyph.height, lessThan(48));

    for (final double target in <double>[24, 48]) {
      final double halfWidth = math.max(glyph.width, target) / 2;
      final double halfHeight = math.max(glyph.height, target) / 2;
      final Offset centre = glyph.center;
      expect(
        noteCheckboxAt(
          view,
          centre + Offset(halfWidth - 0.5, 0),
          minTarget: target,
        ),
        box.sourceRange.start,
      );
      expect(
        noteCheckboxAt(
          view,
          centre + Offset(0, halfHeight - 0.5),
          minTarget: target,
        ),
        box.sourceRange.start,
      );
      expect(
        noteCheckboxAt(
          view,
          centre + Offset(halfWidth + 0.5, 0),
          minTarget: target,
        ),
        isNull,
      );
      expect(
        noteCheckboxAt(
          view,
          centre - Offset(0, halfHeight + 0.5),
          minTarget: target,
        ),
        isNull,
      );
    }
  }, variant: _macOS);

  testWidgets('touch presses are ignored', (WidgetTester tester) async {
    final _Harness harness = _Harness();
    await harness.pump(tester, 'The fog lifted');

    await _click(
      tester,
      harness.wordCentre('fog'),
      kind: PointerDeviceKind.touch,
    );

    expect(harness.host.events, isEmpty);
    expect(harness.host.selection, const NoteSelection.collapsed(14));
  }, variant: _macOS);

  testWidgets('a press below the last line puts the caret at the end', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    const String source = 'one\ntwo';
    await harness.pump(
      tester,
      source,
      selection: const NoteSelection.collapsed(0),
    );
    final RenderNoteView view = harness.view;
    final Offset below = view.localToGlobal(Offset(20, view.size.height - 10));

    await _click(tester, below);

    expect(harness.host.selection.isCollapsed, isTrue);
    expect(harness.host.selection.head, source.length);
  }, variant: _macOS);

  testWidgets('a press outside while unfocused calls nothing', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    await harness.pump(tester, 'The fog lifted', focused: false);

    await _press(tester, find.byKey(_outsideKey));

    expect(harness.node.hasFocus, isFalse);
    expect(harness.host.events, isEmpty);
  }, variant: _macOS);
}
