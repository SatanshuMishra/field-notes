import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/layout/note_layout_engine.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/render/note_semantics.dart';
import 'package:field_notes/features/note_engine/render/note_view.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';

import '../../notes/support/notes_harness.dart';

const String _siblings =
    'Intro\n\n![Low tide](photo/a1b2c3d4e5f6 "left medium")\n\n'
    '- [ ] passport\n\n| a | b |\n| --- | --- |\n| 1 | 2 |';

void _pinSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

int _lineOf(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length;

Rect _honestTarget(RenderNoteView view, double minimum) {
  final Rect box = view.contentRectToLocal(
    view.noteLayout.rangeBounds(
      noteCheckboxSemanticsOf(view.tree, view.visibleText).single.boxRange,
    ),
  )!;
  return Rect.fromCenter(
    center: box.center,
    width: math.max(box.width, minimum),
    height: math.max(box.height, minimum),
  ).intersect(Offset.zero & view.size);
}

final class _RecordingDelegate implements NoteViewDelegate {
  final List<TextSelection> selections = <TextSelection>[];
  final List<String> calls = <String>[];

  @override
  void copySelection() => calls.add('copy');

  @override
  void cutSelection() => calls.add('cut');

  @override
  void pasteClipboard() => calls.add('paste');

  @override
  void replaceVisibleText(String text) => calls.add('replace $text');

  @override
  void selectPhoto(int lineStart) => calls.add('selectPhoto $lineStart');

  @override
  void selectVisible(TextSelection selection) => selections.add(selection);

  @override
  void toggleCheckbox(int boxStart) => calls.add('toggle $boxStart');
}

final class _Harness {
  final NoteLayoutEngine engine = NoteLayoutEngine(
    projector: const NoteVisibleProjector(),
  );
  final GlobalKey renderKey = GlobalKey();
  final _RecordingDelegate delegate = _RecordingDelegate();
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
    TextEditingValue? platformValue,
    int platformValueStart = 0,
    ScrollController? scrollController,
    double width = 688,
  }) {
    final MdTree tree = parseNoteTree(source);
    final int? activeLine = focused && !readOnly && selection != null
        ? _lineOf(source, selection.head)
        : null;
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: 900,
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
                focused: focused,
                readOnly: readOnly,
                platformValue: platformValue,
                platformValueStart: platformValueStart,
                scrollController: scrollController,
                delegate: delegate,
                renderKey: renderKey,
              ),
            ),
          ),
        ),
      ),
    );
  }

  SemanticsNode container(WidgetTester tester) =>
      tester.getSemantics(find.byKey(renderKey));

  List<SemanticsNode> children(WidgetTester tester) => container(
    tester,
  ).debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder);

  SemanticsNode labelled(WidgetTester tester, String label) =>
      children(tester).singleWhere((SemanticsNode node) => node.label == label);

  SemanticsNode textField(WidgetTester tester) => children(tester).first;
}

SemanticsHandle _semantics(WidgetTester tester) => tester.ensureSemantics();

void _perform(
  WidgetTester tester,
  SemanticsNode node,
  SemanticsAction action, [
  Object? arguments,
]) {
  node.owner!.performAction(node.id, action, arguments);
}

bool _has(SemanticsNode node, SemanticsAction action) =>
    node.getSemanticsData().hasAction(action);

void main() {
  testWidgets('the text field node carries the visible text and selection', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final SemanticsHandle handle = _semantics(tester);
    final _Harness harness = _Harness();
    const String source = '# Harbour day\nThe **fog** lifted at noon.\n';
    expect(source.length, 42);
    await harness.pump(
      tester,
      source,
      selection: const NoteSelection.collapsed(42),
    );
    final SemanticsNode field = harness.textField(tester);
    expect(
      field,
      isSemantics(
        isTextField: true,
        isMultiline: true,
        isFocusable: true,
        isFocused: true,
        isReadOnly: false,
        value: 'Harbour day\nThe fog lifted at noon.\n',
      ),
    );
    final SemanticsData data = field.getSemanticsData();
    expect(data.textSelection, const TextSelection.collapsed(offset: 36));
    expect(data.value, isNot(contains('*')));
    expect(data.value, isNot(contains('#')));

    await harness.pump(
      tester,
      source,
      selection: const NoteSelection.collapsed(42),
      platformValue: const TextEditingValue(
        text: 'The fog lifted at noon.\n',
        selection: TextSelection.collapsed(offset: 24),
      ),
      platformValueStart: 12,
    );
    final SemanticsData window = harness.textField(tester).getSemanticsData();
    expect(window.value, 'The fog lifted at noon.\n');
    expect(window.textSelection, const TextSelection.collapsed(offset: 24));
    handle.dispose();
  });

  testWidgets(
    'photo, checkbox and table nodes are siblings after the text field',
    (WidgetTester tester) async {
      _pinSurface(tester);
      final SemanticsHandle handle = _semantics(tester);
      final _Harness harness = _Harness();
      await harness.pump(
        tester,
        _siblings,
        selection: const NoteSelection.collapsed(0),
      );
      final SemanticsNode container = harness.container(tester);
      final List<SemanticsNode> children = harness.children(tester);
      expect(children, hasLength(4));
      expect(children[0], isSemantics(isTextField: true));
      expect(
        children[1],
        isSemantics(label: 'Photo, Low tide', isButton: true),
      );
      expect(
        children[2],
        isSemantics(
          label: 'passport',
          hasCheckedState: true,
          isChecked: false,
          hasTapAction: true,
        ),
      );
      expect(children[3], isSemantics(label: 'Table, 2 rows, 2 columns'));
      expect(children[0].childrenCount, 0);
      for (final SemanticsNode child in children) {
        expect(identical(child.parent, container), isTrue);
      }
      handle.dispose();
    },
  );

  testWidgets('set text and set selection work only while focused', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final SemanticsHandle handle = _semantics(tester);
    final _Harness harness = _Harness();
    const String source = 'The harbour was quiet.';
    await harness.pump(
      tester,
      source,
      selection: const NoteSelection.collapsed(0),
      focused: false,
    );
    SemanticsNode field = harness.textField(tester);
    expect(field, isSemantics(isTextField: true));
    expect(_has(field, SemanticsAction.setSelection), isFalse);
    expect(_has(field, SemanticsAction.setText), isFalse);

    await harness.pump(
      tester,
      source,
      selection: const NoteSelection.collapsed(0),
    );
    field = harness.textField(tester);
    expect(_has(field, SemanticsAction.setSelection), isTrue);
    expect(_has(field, SemanticsAction.setText), isTrue);
    final FinderBase<SemanticsNode> finder = find.semantics.byFlag(
      SemanticsFlag.isTextField,
    );
    tester.semantics.setSelection(finder, base: 4, extent: 11);
    expect(harness.delegate.selections, <TextSelection>[
      const TextSelection(baseOffset: 4, extentOffset: 11),
    ]);
    tester.semantics.setText(finder, 'The harbour was calm.');
    expect(harness.delegate.calls, <String>['replace The harbour was calm.']);

    await harness.pump(
      tester,
      source,
      selection: const NoteSelection.collapsed(0),
      readOnly: true,
    );
    expect(finder, findsNothing);
    handle.dispose();
  });

  testWidgets('a table node counts the header row', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final SemanticsHandle handle = _semantics(tester);
    final _Harness harness = _Harness();
    await harness.pump(
      tester,
      '| Day | Route |\n| --- | --- |\n| Mon | Coast |\n| Tue | Ridge |',
      selection: const NoteSelection.collapsed(0),
    );
    expect(
      harness.labelled(tester, 'Table, 3 rows, 2 columns'),
      isA<SemanticsNode>(),
    );
    await harness.pump(
      tester,
      '| a | b | c |\n| - | - | - |',
      selection: const NoteSelection.collapsed(0),
    );
    expect(
      harness.labelled(tester, 'Table, 1 rows, 3 columns'),
      isA<SemanticsNode>(),
    );
    expect(
      noteTableSemanticsLabel(rows: 3, columns: 2),
      'Table, 3 rows, 2 columns',
    );
    handle.dispose();
  });

  group('checkboxes and photos', () {
    testWidgets('activating a checkbox or a photo calls the delegate', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final SemanticsHandle handle = _semantics(tester);
      final _Harness harness = _Harness();
      await harness.pump(
        tester,
        '- [ ] passport',
        selection: const NoteSelection.collapsed(0),
        focused: false,
      );
      tester.semantics.tap(find.semantics.byLabel('passport'));
      expect(harness.delegate.calls, <String>['toggle 2']);

      await harness.pump(
        tester,
        '- [x] passport',
        selection: const NoteSelection.collapsed(0),
        focused: false,
      );
      expect(
        harness.labelled(tester, 'passport'),
        isSemantics(hasCheckedState: true, isChecked: true),
      );

      await harness.pump(
        tester,
        _siblings,
        selection: const NoteSelection.collapsed(0),
      );
      tester.semantics.tap(find.semantics.byLabel('Photo, Low tide'));
      expect(harness.delegate.calls.last, 'selectPhoto 7');
      handle.dispose();
    });

    testWidgets(
      'an Android checkbox target is the 48 by 48 minimum around its box, '
      'cut to the view',
      (WidgetTester tester) async {
        _pinSurface(tester);
        final SemanticsHandle handle = _semantics(tester);
        final _Harness harness = _Harness();
        await harness.pump(
          tester,
          '- [ ] passport',
          selection: const NoteSelection.collapsed(0),
          focused: false,
        );
        expect(
          harness.labelled(tester, 'passport').rect,
          rectMoreOrLessEquals(_honestTarget(harness.view, 48)),
        );
        handle.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'a macOS checkbox target is the 24 by 24 minimum around its box, '
      'cut to the view',
      (WidgetTester tester) async {
        _pinSurface(tester);
        final SemanticsHandle handle = _semantics(tester);
        final _Harness harness = _Harness();
        await harness.pump(
          tester,
          '- [ ] passport',
          selection: const NoteSelection.collapsed(0),
          focused: false,
        );
        expect(
          harness.labelled(tester, 'passport').rect,
          rectMoreOrLessEquals(_honestTarget(harness.view, 24)),
        );
        handle.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  });

  group('text field actions', () {
    testWidgets('cursor moves by character and by word', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final SemanticsHandle handle = _semantics(tester);
      final _Harness harness = _Harness();
      const String source = 'The harbour was quiet.';
      await harness.pump(
        tester,
        source,
        selection: const NoteSelection.collapsed(0),
      );
      SemanticsNode field = harness.textField(tester);
      expect(
        _has(field, SemanticsAction.moveCursorBackwardByCharacter),
        isFalse,
      );
      _perform(
        tester,
        field,
        SemanticsAction.moveCursorForwardByCharacter,
        false,
      );
      _perform(tester, field, SemanticsAction.moveCursorForwardByWord, false);
      expect(harness.delegate.selections, <TextSelection>[
        const TextSelection.collapsed(offset: 1),
        const TextSelection.collapsed(offset: 3),
      ]);

      await harness.pump(
        tester,
        source,
        selection: const NoteSelection.collapsed(3),
      );
      field = harness.textField(tester);
      _perform(tester, field, SemanticsAction.moveCursorForwardByWord, false);
      _perform(
        tester,
        field,
        SemanticsAction.moveCursorForwardByCharacter,
        true,
      );
      _perform(tester, field, SemanticsAction.moveCursorBackwardByWord, false);
      expect(harness.delegate.selections.sublist(2), <TextSelection>[
        const TextSelection.collapsed(offset: 11),
        const TextSelection(baseOffset: 3, extentOffset: 4),
        const TextSelection.collapsed(offset: 0),
      ]);

      await harness.pump(
        tester,
        source,
        selection: NoteSelection.collapsed(source.length),
      );
      field = harness.textField(tester);
      expect(
        _has(field, SemanticsAction.moveCursorForwardByCharacter),
        isFalse,
      );
      expect(_has(field, SemanticsAction.moveCursorForwardByWord), isFalse);
      expect(_has(field, SemanticsAction.moveCursorBackwardByWord), isTrue);
      handle.dispose();
    });

    testWidgets('clipboard actions follow the selection and focus', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final SemanticsHandle handle = _semantics(tester);
      final _Harness harness = _Harness();
      const String source = 'The harbour was quiet.';
      await harness.pump(
        tester,
        source,
        selection: const NoteSelection.collapsed(3),
      );
      SemanticsNode field = harness.textField(tester);
      expect(_has(field, SemanticsAction.copy), isFalse);
      expect(_has(field, SemanticsAction.cut), isFalse);
      expect(_has(field, SemanticsAction.paste), isTrue);

      await harness.pump(
        tester,
        source,
        selection: const NoteSelection(anchor: 4, head: 11),
      );
      field = harness.textField(tester);
      _perform(tester, field, SemanticsAction.copy);
      _perform(tester, field, SemanticsAction.cut);
      _perform(tester, field, SemanticsAction.paste);
      expect(harness.delegate.calls, <String>['copy', 'cut', 'paste']);

      await harness.pump(
        tester,
        source,
        selection: const NoteSelection(anchor: 4, head: 11),
        focused: false,
      );
      field = harness.textField(tester);
      expect(_has(field, SemanticsAction.paste), isFalse);
      expect(_has(field, SemanticsAction.copy), isTrue);
      handle.dispose();
    });

    testWidgets('set selection adds the window start', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final SemanticsHandle handle = _semantics(tester);
      final _Harness harness = _Harness();
      await harness.pump(
        tester,
        '# Harbour day\nThe **fog** lifted at noon.\n',
        selection: const NoteSelection.collapsed(42),
        platformValue: const TextEditingValue(
          text: 'The fog lifted at noon.\n',
          selection: TextSelection.collapsed(offset: 24),
        ),
        platformValueStart: 12,
      );
      tester.semantics.setSelection(
        find.semantics.byFlag(SemanticsFlag.isTextField),
        base: 4,
        extent: 7,
      );
      expect(harness.delegate.selections, <TextSelection>[
        const TextSelection(baseOffset: 16, extentOffset: 19),
      ]);
      handle.dispose();
    });
  });

  group('read-only views', () {
    testWidgets('blocks are formatting-free with headings marked', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final SemanticsHandle handle = _semantics(tester);
      final _Harness harness = _Harness();
      await harness.pump(
        tester,
        '# Harbour day\nThe fog lifted at noon.\n\n---',
        readOnly: true,
      );
      expect(find.semantics.byFlag(SemanticsFlag.isTextField), findsNothing);
      final List<SemanticsNode> children = harness.children(tester);
      expect(children.map((SemanticsNode node) => node.label), <String>[
        'Harbour day',
        'The fog lifted at noon.',
      ]);
      final SemanticsData heading = children.first.getSemanticsData();
      expect(children.first, isSemantics(isHeader: true));
      expect(heading.headingLevel, 1);

      await harness.pump(
        tester,
        '| a | b |\n| - | - |\n| 1 | 2 |',
        readOnly: true,
      );
      expect(
        harness.labelled(tester, 'Table, 2 rows, 2 columns').value,
        'a\tb\n1\t2',
      );
      handle.dispose();
    });

    testWidgets('photos and tables are read in source order', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final SemanticsHandle handle = _semantics(tester);
      final _Harness harness = _Harness();
      await harness.pump(
        tester,
        'Intro\n\n![Low tide](photo/a1b2c3d4e5f6 "left medium")\n\nAfter',
        readOnly: true,
      );
      final List<SemanticsNode> photoOrder = harness.children(tester);
      expect(photoOrder.map((SemanticsNode node) => node.label), <String>[
        'Intro',
        'Photo, Low tide',
        'After',
      ]);
      expect(photoOrder[1], isSemantics(isImage: true));

      await harness.pump(
        tester,
        'Intro\n\n| a | b |\n| - | - |\n\nAfter',
        readOnly: true,
      );
      expect(
        harness.children(tester).map((SemanticsNode n) => n.label),
        <String>['Intro', 'Table, 1 rows, 2 columns', 'After'],
      );
      handle.dispose();
    });
  });

  group('geometry', () {
    testWidgets('a wide table node stays inside the view', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final SemanticsHandle handle = _semantics(tester);
      final _Harness harness = _Harness();
      final String row =
          '| ${List<String>.filled(20, 'abcdefghij').join(' | ')} |';
      final String table = <String>[
        row,
        '|${List<String>.filled(20, ' --- ').join('|')}|',
        row,
      ].join('\n');
      await harness.pump(
        tester,
        table,
        selection: const NoteSelection.collapsed(0),
        focused: false,
      );
      final Rect rect = harness
          .labelled(tester, 'Table, 2 rows, 20 columns')
          .rect;
      final Rect bounds = Offset.zero & harness.view.size;
      expect(rect.left, greaterThanOrEqualTo(bounds.left));
      expect(rect.right, lessThanOrEqualTo(bounds.right));
      expect(rect.width, greaterThan(0));
      handle.dispose();
    });

    testWidgets('scrolling moves the node rects', (WidgetTester tester) async {
      _pinSurface(tester);
      final SemanticsHandle handle = _semantics(tester);
      final _Harness harness = _Harness();
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      final String before = <String>[
        for (int i = 0; i < 30; i++) 'Line $i',
      ].join('\n\n');
      await harness.pump(
        tester,
        '$before\n\n- [ ] passport',
        selection: const NoteSelection.collapsed(0),
        focused: false,
        scrollController: controller,
      );
      final double top = harness.labelled(tester, 'passport').rect.top;
      controller.jumpTo(200);
      await tester.pump();
      expect(
        harness.labelled(tester, 'passport').rect.top,
        closeTo(top - 200, 0.01),
      );
      handle.dispose();
    });
  });
}
