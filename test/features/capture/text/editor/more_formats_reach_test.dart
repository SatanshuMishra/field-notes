import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/composer_guard.dart'
    show composerDiscardTitle;
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/text/editor/format_bar.dart';
import 'package:field_notes/features/capture/text/editor/note_editor.dart';
import 'package:field_notes/features/capture/text/editor/photo_toolbar.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show ComposerMediaScope, NoteEditorController, NoteEditorView;
import 'package:field_notes/state/state.dart';

import '../../../../support/note_editor_driver.dart';
import '../../../../support/photo_line_fixture.dart';
import '../../../notes/support/notes_harness.dart'
    show FakeNoteMediaResolver, availablePhoto, photoIdA, prefixOf;
import '../../core/capture_test_support.dart';

const Duration _hold = Duration(milliseconds: 110);
const double _tolerance = 0.01;

SemanticsNode _root(WidgetTester tester) =>
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!;

Rect _globalRect(SemanticsNode node) {
  Rect rect = node.rect;
  for (SemanticsNode? at = node; at != null; at = at.parent) {
    final Matrix4? transform = at.transform;
    if (transform != null) {
      rect = MatrixUtils.transformRect(transform, rect);
    }
  }
  return rect;
}

bool _within(Rect outer, Rect inner) =>
    inner.left >= outer.left - _tolerance &&
    inner.top >= outer.top - _tolerance &&
    inner.right <= outer.right + _tolerance &&
    inner.bottom <= outer.bottom + _tolerance;

Set<SemanticsNode> _sentNodes(SemanticsNode root) {
  final Set<SemanticsNode> sent = <SemanticsNode>{};
  void walk(SemanticsNode node) {
    if (node.isMergedIntoParent) {
      return;
    }
    sent.add(node);
    if (node.mergeAllDescendantsIntoThisNode) {
      return;
    }
    node.visitChildren((SemanticsNode child) {
      walk(child);
      return true;
    });
  }

  walk(root);
  return sent;
}

List<SemanticsNode> _readingOrderChildren(
  SemanticsNode node,
  Set<SemanticsNode> sent,
) {
  final List<SemanticsNode> listed =
      node.hasChildren && !node.mergeAllDescendantsIntoThisNode
      ? node.debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
      : const <SemanticsNode>[];
  final Object? identifier = node.traversalParentIdentifier;
  return <SemanticsNode>[
    ...listed,
    if (identifier != null)
      for (final SemanticsNode candidate in sent)
        if (candidate.attached &&
            candidate.traversalChildIdentifier == identifier &&
            !listed.contains(candidate))
          candidate,
  ];
}

SemanticsNode _pointerReaches(
  SemanticsNode node,
  Offset point,
  Set<SemanticsNode> sent,
) {
  for (final SemanticsNode child in _readingOrderChildren(
    node,
    sent,
  ).reversed) {
    if (_globalRect(child).contains(point)) {
      return _pointerReaches(child, point, sent);
    }
  }
  return node;
}

Map<SemanticsNode, SemanticsNode> _readingOrderParents(SemanticsNode root) {
  final Set<SemanticsNode> sent = _sentNodes(root);
  final Map<SemanticsNode, SemanticsNode> parents =
      <SemanticsNode, SemanticsNode>{};
  void walk(SemanticsNode node) {
    for (final SemanticsNode child in _readingOrderChildren(node, sent)) {
      if (child != root && !parents.containsKey(child)) {
        parents[child] = node;
        walk(child);
      }
    }
  }

  walk(root);
  return parents;
}

bool _hasPrimaryFocus(WidgetTester tester, Key key) =>
    Focus.of(tester.element(find.byKey(key))).hasPrimaryFocus;

Future<ValueNotifier<double>> _pumpPhotoSelected(WidgetTester tester) async {
  final ValueNotifier<double> width = ValueNotifier<double>(200);
  tester.view.physicalSize = const Size(1600, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final NoteEditorController controller = NoteEditorController(
    text: 'one\n${mdPhotoLine(photoIdA)}\ntwo',
  );
  final FocusNode focusNode = FocusNode();
  final UndoHistoryController undo = UndoHistoryController();
  final ScrollController scroll = ScrollController();
  addTearDown(() {
    controller.dispose();
    focusNode.dispose();
    undo.dispose();
    scroll.dispose();
    width.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: ComposerMediaScope(
          resolver: FakeNoteMediaResolver(<String, ResolvedMedia>{
            prefixOf(photoIdA): availablePhoto(
              photoIdA,
              width: 1200,
              height: 900,
            ),
          })..memoizeAll(),
          child: Align(
            alignment: Alignment.topLeft,
            child: ValueListenableBuilder<double>(
              valueListenable: width,
              builder: (BuildContext context, double value, Widget? editor) =>
                  SizedBox(width: value, height: 700, child: editor),
              child: noteEditorFor(
                NoteEditorConfig(
                  controller: controller,
                  focusNode: focusNode,
                  undoController: undo,
                  scrollController: scroll,
                  photoImporter: () async => <String>[],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  final NoteEditorDriver driver = NoteEditorDriver(tester);
  await driver.press(driver.photoFinder(0), _hold);
  await tester.pump();
  return width;
}

class _ComposerTrigger extends StatelessWidget {
  const _ComposerTrigger();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showTextComposer(context, '2026-07-19'),
      child: const Text('open'),
    );
  }
}

void main() {
  testWidgets(
    'on macOS a pointer on Highlight reaches Highlight through reading-order '
    'frames',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      for (final Size surface in <Size>[
        const Size(1280, 900),
        const Size(760, 620),
      ]) {
        tester.view.physicalSize = surface;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey<Size>(surface),
            debugShowCheckedModeBanner: false,
            home: DialogHost(
              child: ComposerShell(
                child: TextComposerSheet(
                  onSave: (String _) {},
                  onCancel: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.ensureVisible(find.byKey(formatMoreKey));
        await tester.pumpAndSettle();
        await NoteEditorDriver(tester).press(find.byKey(formatMoreKey), _hold);
        await tester.pumpAndSettle();

        final SemanticsNode highlight = tester.getSemantics(
          find.byKey(formatHighlightKey),
        );
        expect(highlight.label, 'Highlight');
        final SemanticsNode root = _root(tester);
        final SemanticsNode reached = _pointerReaches(
          root,
          _globalRect(highlight).center,
          _sentNodes(root),
        );
        expect(
          reached.id,
          highlight.id,
          reason:
              'at $surface the pointer reached #${reached.id} '
              '"${reached.label}"',
        );
      }
      handle.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    "on macOS the photo toolbar menu items lie inside a reading-order "
    "ancestor's frame",
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpPhotoSelected(tester);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await driver.press(find.byKey(photoToolbarMoreKey), _hold);
      await tester.pumpAndSettle();

      final Map<SemanticsNode, SemanticsNode> parents = _readingOrderParents(
        _root(tester),
      );
      for (final Key key in <Key>[
        photoToolbarMoveUpKey,
        photoToolbarMoveDownKey,
        photoToolbarReplaceKey,
      ]) {
        final SemanticsNode item = tester.getSemantics(find.byKey(key));
        final Rect rect = _globalRect(item);
        expect(parents.containsKey(item), isTrue, reason: '$key is read');
        for (
          SemanticsNode? ancestor = parents[item];
          ancestor != null;
          ancestor = parents[ancestor]
        ) {
          expect(
            _within(_globalRect(ancestor), rect),
            isTrue,
            reason:
                '$key $rect lies outside reading-order ancestor '
                '#${ancestor.id} "${ancestor.label}" '
                '${_globalRect(ancestor)}',
          );
        }
      }
      handle.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'the More formats menu keeps the text style and scale of its anchor',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: DialogHost(
            child: ComposerShell(
              child: TextComposerSheet(onSave: (String _) {}, onCancel: () {}),
            ),
          ),
        ),
      );
      await tester.pump();
      await NoteEditorDriver(tester).press(find.byKey(formatMoreKey), _hold);
      await tester.pumpAndSettle();

      final BuildContext anchor = tester.element(find.byKey(formatMoreKey));
      final RenderParagraph label = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(formatHighlightKey),
          matching: find.byType(RichText),
        ),
      );
      expect(
        label.text.style,
        DefaultTextStyle.of(anchor).style.merge(
          const FieldNotesTextStyles(FieldNotesColors.light).toolbarSans,
        ),
      );
      expect(label.textScaler, MediaQuery.textScalerOf(anchor));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'a keyboard reaches the photo toolbar menu items and Escape returns to '
    'the editor',
    (WidgetTester tester) async {
      await _pumpPhotoSelected(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_hasPrimaryFocus(tester, photoToolbarMoreKey), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.byKey(photoToolbarMoveUpKey), findsOneWidget);

      for (final Key key in <Key>[
        photoToolbarCaptionKey,
        photoToolbarRemoveKey,
        photoToolbarMoveUpKey,
        photoToolbarMoveDownKey,
        photoToolbarReplaceKey,
      ]) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_hasPrimaryFocus(tester, key), isTrue, reason: '$key');
      }

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.byKey(photoToolbarMoveUpKey), findsNothing);
      expect(find.byKey(photoToolbarKey), findsOneWidget);
      expect(
        tester
            .widget<NoteEditorView>(find.byType(NoteEditorView))
            .focusNode
            .hasPrimaryFocus,
        isTrue,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'a photo toolbar menu closes with its anchor and lets Escape through',
    (WidgetTester tester) async {
      final ValueNotifier<double> width = await _pumpPhotoSelected(tester);
      await NoteEditorDriver(
        tester,
      ).press(find.byKey(photoToolbarMoreKey), _hold);
      await tester.pumpAndSettle();
      expect(find.byKey(photoToolbarMoveUpKey), findsOneWidget);

      width.value = 720;
      await tester.pumpAndSettle();

      expect(find.byKey(photoToolbarMoreKey), findsNothing);
      expect(find.byKey(photoToolbarMoveUpKey), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(photoToolbarKey), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'Escape closes the open More formats menu and keeps the composer open',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            noteWriterProvider.overrideWith((Ref ref) => FakeNoteWriter()),
            draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
          ],
          child: captureHarness(const _ComposerTrigger()),
        ),
      );
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await driver.press(find.text('open'), _hold);
      await tester.pumpAndSettle();
      await driver.typeText('never mind');
      await driver.press(find.byKey(formatMoreKey), _hold);
      await tester.pumpAndSettle();
      expect(find.byKey(formatHighlightKey), findsOneWidget);

      await driver.pressKey(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(formatHighlightKey), findsNothing);
      expect(find.text(composerDiscardTitle), findsNothing);
      expect(find.byType(TextComposerSheet), findsOneWidget);
      expect(driver.source, 'never mind');

      await driver.press(find.byKey(formatMoreKey), _hold);
      await tester.pumpAndSettle();
      expect(find.byKey(formatHighlightKey), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(formatHighlightKey), findsNothing);
      expect(find.text(composerDiscardTitle), findsNothing);
      expect(find.byType(TextComposerSheet), findsOneWidget);

      await driver.pressKey(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text(composerDiscardTitle), findsOneWidget);
    },
  );
}
