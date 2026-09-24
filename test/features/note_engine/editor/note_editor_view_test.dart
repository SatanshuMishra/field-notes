import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/capabilities.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/editor/composer_media_scope.dart';
import 'package:field_notes/features/note_engine/editor/editor_keys.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_controller.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_view.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/photos/photo_drag.dart';
import 'package:field_notes/features/note_engine/platform/spell_check_service.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:field_notes/features/note_engine/render/note_view.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';

import '../../../support/text_input_messages.dart';
import '../../notes/support/notes_harness.dart';

const String _reference = 'a1b2c3d4e5f6';
const String _lowTideNote =
    'A\n\n![Low tide](photo/a1b2c3d4e5f6 "left medium")\n\nB';
const String _keyPathNote = 'A\n![p](photo/abc123abc123)\nB';

final class _Editor {
  _Editor(this.controller)
    : focusNode = FocusNode(),
      undo = UndoHistoryController(),
      scroll = ScrollController();

  final NoteEditorController controller;
  final FocusNode focusNode;
  final UndoHistoryController undo;
  final ScrollController scroll;

  void dispose() {
    scroll.dispose();
    undo.dispose();
    focusNode.dispose();
    controller.dispose();
  }
}

void _pinSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

_Editor _editor(String text) {
  final _Editor editor = _Editor(NoteEditorController(text: text));
  addTearDown(editor.dispose);
  return editor;
}

MediaResolver _resolver() => FakeNoteMediaResolver(<String, ResolvedMedia>{
  _reference: availablePhoto(photoIdA),
})..memoizeAll();

Widget _app(
  _Editor editor, {
  required MediaResolver resolver,
  String hintText = '',
  double bottomInset = 0,
  bool spellCheckEnabled = false,
  NotePhotoToolbarBuilder? photoToolbarBuilder,
  Widget Function(Widget view)? wrap,
}) {
  final Widget view = NoteEditorView(
    controller: editor.controller,
    focusNode: editor.focusNode,
    undoController: editor.undo,
    scrollController: editor.scroll,
    hintText: hintText,
    bottomInset: bottomInset,
    spellCheckEnabled: spellCheckEnabled,
    photoToolbarBuilder: photoToolbarBuilder,
  );
  return MaterialApp(
    home: Material(
      child: ComposerMediaScope(
        resolver: resolver,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 688,
            height: 600,
            child: wrap == null ? view : wrap(view),
          ),
        ),
      ),
    ),
  );
}

Future<_Editor> _pump(
  WidgetTester tester,
  String text, {
  String hintText = '',
  double bottomInset = 0,
  bool spellCheckEnabled = false,
  NotePhotoToolbarBuilder? photoToolbarBuilder,
  Widget Function(Widget view)? wrap,
}) async {
  _pinSurface(tester);
  final _Editor editor = _editor(text);
  await tester.pumpWidget(
    _app(
      editor,
      resolver: _resolver(),
      hintText: hintText,
      bottomInset: bottomInset,
      spellCheckEnabled: spellCheckEnabled,
      photoToolbarBuilder: photoToolbarBuilder,
      wrap: wrap,
    ),
  );
  await tester.pump();
  return editor;
}

Future<void> _focus(WidgetTester tester, _Editor editor) async {
  editor.focusNode.requestFocus();
  await tester.pump();
  await tester.pump();
}

Future<void> _select(
  WidgetTester tester,
  _Editor editor,
  TextSelection selection,
) async {
  editor.controller.selection = selection;
  await tester.pump();
}

RenderNoteView _renderView(WidgetTester tester) =>
    tester.renderObject<RenderNoteView>(find.byType(NoteViewBody));

NoteEditorViewState _viewState(WidgetTester tester) =>
    tester.state<NoteEditorViewState>(find.byType(NoteEditorView));

String _lastSentText(WidgetTester tester) {
  final List<MethodCall> sent = textInputCalls(
    tester,
    'TextInput.setEditingState',
  );
  final Map<Object?, Object?> state =
      sent.last.arguments as Map<Object?, Object?>;
  return state['text']! as String;
}

Future<void> _settle(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 1));

const Duration _idleWindow = Duration(seconds: 3);

Future<int> _framesOver(WidgetTester tester, Duration window) async {
  const Duration step = Duration(milliseconds: 50);
  final int steps = window.inMicroseconds ~/ step.inMicroseconds;
  int frames = 0;
  for (int at = 0; at < steps; at++) {
    await tester.binding.delayed(step);
    if (tester.binding.hasScheduledFrame) {
      frames += 1;
      await tester.pump();
    }
  }
  return frames;
}

void main() {
  testWidgets('typing through the input client edits the source', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(tester, 'hello');
    await _focus(tester, editor);

    await sendDeltas(tester, <Map<String, Object?>>[
      insertionDelta(oldText: 'hello', at: 5, text: ' world'),
    ]);
    await tester.pump();

    expect(editor.controller.text, 'hello world');
    expect(editor.controller.selection, const TextSelection.collapsed(offset: 11));
  });

  testWidgets('typing over a selection that spans lines replaces it', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(tester, 'one\ntwo\nthree');
    await _focus(tester, editor);
    await _select(
      tester,
      editor,
      const TextSelection(baseOffset: 1, extentOffset: 13),
    );

    await sendDeltas(tester, <Map<String, Object?>>[
      replacementDelta(
        oldText: _lastSentText(tester),
        range: const TextRange(start: 1, end: 13),
        text: 'x',
      ),
    ]);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(editor.controller.text, 'ox');
    expect(
      editor.controller.selection,
      const TextSelection.collapsed(offset: 2),
    );
    expect(_viewState(tester).debugInputDrops, isEmpty);
  });

  testWidgets('a composition over a selection that spans lines replaces it', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(tester, 'one\ntwo\nthree');
    await _focus(tester, editor);
    await _select(
      tester,
      editor,
      const TextSelection(baseOffset: 1, extentOffset: 13),
    );

    await sendDeltas(tester, <Map<String, Object?>>[
      replacementDelta(
        oldText: _lastSentText(tester),
        range: const TextRange(start: 1, end: 13),
        text: 'k',
        composing: const TextRange(start: 1, end: 2),
      ),
    ]);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(editor.controller.text, 'ok');
    expect(
      editor.controller.value.composing,
      const TextRange(start: 1, end: 2),
    );
    expect(_viewState(tester).debugInputDrops, isEmpty);
  });

  testWidgets('a structure change mid-batch rebases the next delta', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(tester, '# a\nb');
    await _focus(tester, editor);
    await _select(tester, editor, const TextSelection.collapsed(offset: 5));
    expect(_lastSentText(tester), 'a\nb');

    await sendDeltas(tester, <Map<String, Object?>>[
      deletionDelta(
        oldText: 'a\nb',
        range: const TextRange(start: 1, end: 2),
        selection: const TextSelection.collapsed(offset: 2),
      ),
      insertionDelta(oldText: 'ab', at: 2, text: 'c'),
    ]);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(editor.controller.text, '# abc');
    expect(
      editor.controller.selection,
      const TextSelection.collapsed(offset: 5),
    );
    expect(_viewState(tester).debugInputDrops, isEmpty);
  });

  testWidgets('a keystroke on a plain line projects the note once', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(tester, '# Harbour\nfog\nlifted');
    await _focus(tester, editor);
    await _select(tester, editor, const TextSelection.collapsed(offset: 13));
    final int before = _viewState(tester).debugProjectionCount;

    await sendDeltas(tester, <Map<String, Object?>>[
      insertionDelta(oldText: _lastSentText(tester), at: 11, text: 's'),
    ]);
    await tester.pump();

    expect(editor.controller.text, '# Harbour\nfogs\nlifted');
    expect(_viewState(tester).debugProjectionCount - before, 1);
  });

  testWidgets('a keystroke on a marked line projects the note twice', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(tester, '# Harbour\nfog\nlifted');
    await _focus(tester, editor);
    await _select(tester, editor, const TextSelection.collapsed(offset: 9));
    final int before = _viewState(tester).debugProjectionCount;

    await sendDeltas(tester, <Map<String, Object?>>[
      insertionDelta(oldText: _lastSentText(tester), at: 9, text: 's'),
    ]);
    await tester.pump();

    expect(editor.controller.text, '# Harbours\nfog\nlifted');
    expect(_viewState(tester).debugProjectionCount - before, 2);
  });

  test('an active line that shows no markers projects as it does inactive', () {
    const String note =
        '# Harbour\n'
        'Tides\n'
        '===\n'
        '\n'
        'fog *lifted* early\n'
        'plain words\n'
        '  indented  \n'
        '- milk\n'
        '  - eggs\n'
        '9. first\n'
        '10. second\n'
        '- [ ] pack\n'
        '- [x] chart\n'
        '> quote\n'
        '---\n'
        '![p](photo/abc123abc123)\n'
        '| a | b |\n'
        '| - | - |\n'
        '| c | **d** |\n'
        '\n'
        '```dart\n'
        'code\n'
        '```';
    final MdTree tree = parseNoteTree(note, tables: tablesEnabled);
    const NoteVisibleProjector projector = NoteVisibleProjector();
    final int plain = projector.project(note, tree, null).text.length;
    final int lineCount = '\n'.allMatches(note).length + 1;
    final List<int> unmarked = <int>[];

    for (int line = 0; line < lineCount; line++) {
      for (final int? cell in <int?>[null, 0, 1]) {
        final VisibleText active = projector.project(
          note,
          tree,
          line,
          activeCell: cell,
        );
        final bool marked = active.lines.any(
          (VisibleLine visible) =>
              visible.sourceLine == line &&
              visible.spans.any(
                (VisibleSpan span) => span.kind == VisibleSpanKind.marker,
              ),
        );
        if (!marked) {
          unmarked.add(line);
          expect(active.text.length, plain, reason: 'line $line, cell $cell');
        }
      }
    }
    expect(unmarked.toSet(), containsAll(<int>[1, 3, 5, 15, 17, 21]));
  });

  testWidgets('the input window follows the length with no active line', (
    WidgetTester tester,
  ) async {
    final String note = '# ${List<String>.filled(200, 'x' * 99).join('\n')}x';
    final _Editor editor = await _pump(tester, note);
    await _focus(tester, editor);
    await _select(tester, editor, const TextSelection.collapsed(offset: 3));

    expect(_lastSentText(tester), note);

    await _select(tester, editor, const TextSelection.collapsed(offset: 150));

    expect(_lastSentText(tester).length, 20000);

    await sendDeltas(tester, <Map<String, Object?>>[
      insertionDelta(oldText: _lastSentText(tester), at: 148, text: 'y'),
    ]);
    await tester.pump();

    expect(editor.controller.text.length, note.length + 1);
    expect(_lastSentText(tester).length, lessThan(20001));
  });

  testWidgets(
    'a line move sent before the next frame uses the typed text',
    (WidgetTester tester) async {
      final _Editor editor = await _pump(tester, 'fog');
      await _focus(tester, editor);
      await _select(tester, editor, const TextSelection.collapsed(offset: 3));

      await sendDeltas(tester, <Map<String, Object?>>[
        insertionDelta(oldText: 'fog', at: 3, text: 'a'),
      ]);
      await sendSelectors(tester, <String>['moveDown:']);

      expect(tester.takeException(), isNull);
      expect(editor.controller.text, 'foga');
      expect(
        editor.controller.selection,
        const TextSelection.collapsed(offset: 4),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'the document end sent before the next frame is the typed end',
    (WidgetTester tester) async {
      final _Editor editor = await _pump(tester, 'fog\nharbour');
      await _focus(tester, editor);
      await _select(tester, editor, const TextSelection.collapsed(offset: 0));

      await sendDeltas(tester, <Map<String, Object?>>[
        insertionDelta(oldText: 'fog\nharbour', at: 0, text: 'The '),
      ]);
      await sendSelectors(tester, <String>['moveToEndOfDocument:']);

      expect(tester.takeException(), isNull);
      expect(editor.controller.text, 'The fog\nharbour');
      expect(editor.controller.selection.isCollapsed, isTrue);
      expect(editor.controller.selection.extentOffset, 15);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('clicking a photo selects its line', (WidgetTester tester) async {
    final _Editor editor = await _pump(tester, _lowTideNote);
    final Offset centre = tester.getCenter(
      find.byKey(notePhotoKey(_reference, 0)),
    );

    final TestGesture gesture = await tester.startGesture(
      centre,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 110));
    await gesture.up();
    await tester.pump();

    expect(editor.controller.selection.start, 3);
    expect(editor.controller.selection.end, 48);
    await _settle(tester);
  });

  testWidgets('the editor drives the undo history controller', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(tester, 'fog');
    await _focus(tester, editor);

    await sendDeltas(tester, <Map<String, Object?>>[
      insertionDelta(oldText: 'fog', at: 3, text: ' lifted'),
    ]);
    await tester.pump();

    expect(editor.undo.value.canUndo, isTrue);
    expect(editor.undo.value.canRedo, isFalse);

    editor.undo.undo();
    await tester.pump();

    expect(editor.controller.text, 'fog');
    expect(editor.controller.selection, const TextSelection.collapsed(offset: 3));
    expect(editor.undo.value.canUndo, isFalse);
    expect(editor.undo.value.canRedo, isTrue);

    editor.undo.redo();
    await tester.pump();

    expect(editor.controller.text, 'fog lifted');
  });

  testWidgets('add memory places the photo after the caret block', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final _Editor editor = _editor('A\n\nB\n\nC');
    editor.controller.selection = const TextSelection.collapsed(offset: 1);
    await tester.pumpWidget(_app(editor, resolver: _resolver()));

    final Future<void> added = editor.controller.addPhotos(
      () async => <String>[_reference],
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await added;

    expect(
      editor.controller.text,
      'A\n![](photo/a1b2c3d4e5f6 "right medium")\n\nB\n\nC',
    );
    expect(editor.controller.selection.start, 2);
    expect(editor.controller.selection.end, 40);

    editor.controller.undo();
    await tester.pump();

    expect(editor.controller.text, 'A\n\nB\n\nC');
  });

  test('a plain text editing controller is refused', () {
    final TextEditingController plain = TextEditingController();
    final FocusNode focusNode = FocusNode();
    final UndoHistoryController undo = UndoHistoryController();
    final ScrollController scroll = ScrollController();
    addTearDown(() {
      scroll.dispose();
      undo.dispose();
      focusNode.dispose();
      plain.dispose();
    });

    expect(
      () => NoteEditorView(
        controller: plain,
        focusNode: focusNode,
        undoController: undo,
        scrollController: scroll,
      ),
      throwsArgumentError,
    );
  });

  testWidgets('the editing surface box is the scrolled content box', (
    WidgetTester tester,
  ) async {
    final String longNote = List<String>.generate(
      120,
      (int i) => 'line $i',
    ).join('\n');
    final _Editor editor = await _pump(tester, longNote);

    expect(find.byKey(noteEditorKey), findsOneWidget);
    final Rect before = tester.getRect(find.byKey(noteEditorKey));
    expect(before.width, 688);
    expect(before.height, greaterThan(600));

    editor.scroll.jumpTo(300);
    await tester.pump();

    final Rect after = tester.getRect(find.byKey(noteEditorKey));
    expect(after.top, moreOrLessEquals(before.top - 300));
    expect(after.height, moreOrLessEquals(before.height));
  });

  testWidgets('the surface box ends above the bottom inset at the end', (
    WidgetTester tester,
  ) async {
    final String longNote = List<String>.generate(
      120,
      (int i) => 'line $i',
    ).join('\n');
    final _Editor editor = await _pump(tester, longNote, bottomInset: 120);

    editor.scroll.jumpTo(editor.scroll.position.maxScrollExtent);
    await tester.pump();

    final Rect view = tester.getRect(find.byType(NoteEditorView));
    final Rect surface = tester.getRect(find.byKey(noteEditorKey));
    expect(surface.bottom, moreOrLessEquals(view.bottom - 120));
  });

  testWidgets('the hint is painted only while the source is empty', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(tester, '', hintText: 'Start');
    final RenderNoteView view = _renderView(tester);

    expect(view.hintText, 'Start');
    expect(view, paints..paragraph());

    editor.controller.text = 'x';
    await tester.pump();

    expect(view, paintsExactlyCountTimes(#drawParagraph, 1));

    editor.controller.text = '';
    await tester.pump();

    expect(view, paintsExactlyCountTimes(#drawParagraph, 2));

    await tester.pumpWidget(_app(editor, resolver: _resolver()));
    await tester.pump();

    expect(_renderView(tester).hintText, '');
    expect(_renderView(tester), paintsExactlyCountTimes(#drawParagraph, 1));
  });

  testWidgets('adding photos after unmount reports a detached surface', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(tester, 'fog');
    await tester.pumpWidget(const SizedBox());

    expect(
      () => editor.controller.addPhotos(() async => <String>[_reference]),
      throwsStateError,
    );
  });

  testWidgets(
    'command Z undoes on macOS',
    (WidgetTester tester) async {
      final _Editor editor = await _pump(tester, 'fog');
      await _focus(tester, editor);
      await sendDeltas(tester, <Map<String, Object?>>[
        insertionDelta(oldText: 'fog', at: 3, text: ' lifted'),
      ]);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(editor.controller.text, 'fog');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'control Z undoes on Android',
    (WidgetTester tester) async {
      final _Editor editor = await _pump(tester, 'fog');
      await _focus(tester, editor);
      await sendDeltas(tester, <Map<String, Object?>>[
        insertionDelta(oldText: 'fog', at: 3, text: ' lifted'),
      ]);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(editor.controller.text, 'fog');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'backspace selectors select and then remove a photo on macOS',
    (WidgetTester tester) async {
      final _Editor editor = await _pump(tester, _keyPathNote);
      await _focus(tester, editor);
      await _select(
        tester,
        editor,
        const TextSelection.collapsed(offset: 27),
      );

      await sendSelectors(tester, <String>['deleteBackward:']);
      await tester.pump();

      expect(editor.controller.selection.start, 2);
      expect(editor.controller.selection.end, 26);
      expect(editor.controller.text, _keyPathNote);

      await sendSelectors(tester, <String>['deleteBackward:']);
      await tester.pump();

      expect(editor.controller.text, 'A\n\nB');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('an enter delta over a selected photo adds one empty line', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(tester, _keyPathNote);
    await _focus(tester, editor);
    await _select(
      tester,
      editor,
      const TextSelection(baseOffset: 2, extentOffset: 26),
    );
    final String platformText = _lastSentText(tester);
    final int photo = platformText.indexOf('￼');

    await sendDeltas(tester, <Map<String, Object?>>[
      replacementDelta(
        oldText: platformText,
        range: TextRange(start: photo, end: photo + 1),
        text: '\n',
      ),
    ]);
    await tester.pump();

    expect(editor.controller.text, 'A\n![p](photo/abc123abc123)\n\nB');
    expect(editor.controller.selection, const TextSelection.collapsed(offset: 27));
  });

  testWidgets('escape on a selected photo puts the caret after it', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(tester, _keyPathNote);
    await _focus(tester, editor);
    await _select(
      tester,
      editor,
      const TextSelection(baseOffset: 2, extentOffset: 26),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(editor.controller.selection, const TextSelection.collapsed(offset: 27));
  });

  testWidgets('escape passes on when the photo is the whole note', (
    WidgetTester tester,
  ) async {
    int escapes = 0;
    final _Editor editor = await _pump(
      tester,
      '![p](photo/abc123abc123)',
      wrap: (Widget view) => CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): () => escapes += 1,
        },
        child: view,
      ),
    );
    await _focus(tester, editor);
    await _select(
      tester,
      editor,
      const TextSelection(baseOffset: 0, extentOffset: 24),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(escapes, 1);
    expect(editor.controller.selection.start, 0);
    expect(editor.controller.selection.end, 24);
  });

  testWidgets('an import in flight shows one placeholder and no source', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(tester, 'A\n\nB');
    final Completer<List<String>> loaded = Completer<List<String>>();

    final Future<void> added = editor.controller.addPhotos(
      () => loaded.future,
    );
    await tester.pump();

    expect(editor.controller.text, 'A\n\nB');
    expect(_viewState(tester).debugImportPlaceholders, hasLength(1));

    loaded.complete(const <String>[]);
    await tester.pump();
    await added;

    expect(_viewState(tester).debugImportPlaceholders, isEmpty);
    expect(editor.controller.text, 'A\n\nB');
  });

  testWidgets('a failing importer reaches the caller with no toast', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(tester, 'A\n\nB');
    final StateError failure = StateError('disk full');
    Object? caught;

    await editor.controller
        .addPhotos(() async => throw failure)
        .catchError((Object error) {
          caught = error;
        });
    await tester.pump();

    expect(identical(caught, failure), isTrue);
    expect(editor.controller.text, 'A\n\nB');
    expect(editor.controller.canUndo, isFalse);
    expect(find.byType(Toast), findsNothing);
  });

  testWidgets('add memory at the end of a long note reveals the photo', (
    WidgetTester tester,
  ) async {
    final String longNote = List<String>.generate(
      120,
      (int i) => 'line $i',
    ).join('\n');
    final _Editor editor = await _pump(tester, longNote);
    await _select(
      tester,
      editor,
      TextSelection.collapsed(offset: longNote.length),
    );

    final Future<void> added = editor.controller.addPhotos(
      () async => <String>[_reference],
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await added;
    await tester.pump(const Duration(milliseconds: 200));

    final Rect view = tester.getRect(find.byType(NoteEditorView));
    final Rect photo = tester.getRect(find.byKey(notePhotoKey(_reference, 0)));
    final RenderNoteView render = _renderView(tester);
    final String text = editor.controller.text;
    final Rect caretLine = render.noteLayout
        .lineBoxAt(text.length, TextAffinity.downstream)
        .rect;
    final Offset caretBottom = render.contentToGlobal(caretLine.bottomLeft);
    expect(photo.top, greaterThanOrEqualTo(view.top));
    expect(photo.bottom, lessThanOrEqualTo(view.bottom));
    expect(caretBottom.dy, lessThanOrEqualTo(view.bottom));
  });

  testWidgets('the photo toolbar builder is asked only for a selected photo', (
    WidgetTester tester,
  ) async {
    final List<NotePhotoToolbarRequest> requests = <NotePhotoToolbarRequest>[];
    final List<TextSelection> selectionsAtCall = <TextSelection>[];
    late final _Editor editor;
    editor = await _pump(
      tester,
      _lowTideNote,
      photoToolbarBuilder:
          (BuildContext context, NotePhotoToolbarRequest request) {
            requests.add(request);
            selectionsAtCall.add(editor.controller.selection);
            return const SizedBox();
          },
    );

    expect(requests, isEmpty);

    await _select(
      tester,
      editor,
      const TextSelection(baseOffset: 3, extentOffset: 48),
    );

    expect(requests, isNotEmpty);
    final NotePhotoToolbarRequest request = requests.last;
    final RenderNoteView render = _renderView(tester);
    final PhotoRect rect = render.noteLayout.photoRects.single;
    final RenderBox layer = tester.renderObject<RenderBox>(
      find.byKey(notePhotoToolbarLayerKey),
    );
    final Rect expected = Rect.fromPoints(
      layer.globalToLocal(render.contentToGlobal(rect.imageRect.topLeft)),
      layer.globalToLocal(render.contentToGlobal(rect.imageRect.bottomRight)),
    );
    expect(request.photoLineStart, 3);
    expect(request.ordinal, 0);
    expect(request.photoRect, rectMoreOrLessEquals(expected));

    await _select(tester, editor, const TextSelection.collapsed(offset: 0));
    editor.scroll.jumpTo(0);
    await tester.pump();

    expect(
      selectionsAtCall,
      everyElement(const TextSelection(baseOffset: 3, extentOffset: 48)),
    );
  });

  testWidgets('the toolbar request keeps the bottom inset out of the surface', (
    WidgetTester tester,
  ) async {
    NotePhotoToolbarRequest? last;
    final _Editor editor = await _pump(
      tester,
      _lowTideNote,
      bottomInset: 120,
      photoToolbarBuilder:
          (BuildContext context, NotePhotoToolbarRequest request) {
            last = request;
            return const SizedBox();
          },
    );
    await _select(
      tester,
      editor,
      const TextSelection(baseOffset: 3, extentOffset: 48),
    );

    final Rect view = tester.getRect(find.byType(NoteEditorView));
    expect(last!.bottomInset, 120);
    expect(last!.surface.bottom, moreOrLessEquals(view.height - 120));
  });

  testWidgets('tab from a selected photo focuses the toolbar', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(
      tester,
      _lowTideNote,
      photoToolbarBuilder:
          (BuildContext context, NotePhotoToolbarRequest request) => Focus(
            focusNode: request.firstControlFocusNode,
            child: const SizedBox(width: 20, height: 20),
          ),
    );
    await _focus(tester, editor);
    await _select(
      tester,
      editor,
      const TextSelection(baseOffset: 3, extentOffset: 48),
    );
    NotePhotoToolbarRequest? captured;
    await tester.pumpWidget(
      _app(
        editor,
        resolver: _resolver(),
        photoToolbarBuilder:
            (BuildContext context, NotePhotoToolbarRequest request) {
              captured = request;
              return Focus(
                focusNode: request.firstControlFocusNode,
                child: const SizedBox(width: 20, height: 20),
              );
            },
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(captured!.firstControlFocusNode.hasFocus, isTrue);
    expect(editor.focusNode.hasFocus, isFalse);
  });

  testWidgets('a selected photo with its toolbar schedules no frames', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(
      tester,
      _lowTideNote,
      photoToolbarBuilder:
          (BuildContext context, NotePhotoToolbarRequest request) =>
              const SizedBox(),
    );
    await _focus(tester, editor);
    await _select(
      tester,
      editor,
      const TextSelection(baseOffset: 3, extentOffset: 48),
    );
    await _settle(tester);

    await tester.binding.delayed(_idleWindow);

    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('an unfocused editor schedules no frames', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(tester, _lowTideNote);
    await _settle(tester);

    await tester.binding.delayed(_idleWindow);

    expect(editor.focusNode.hasFocus, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a selected range schedules no frames', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(tester, 'fog lifted');
    await _focus(tester, editor);
    await _select(
      tester,
      editor,
      const TextSelection(baseOffset: 0, extentOffset: 3),
    );
    await _settle(tester);

    await tester.binding.delayed(_idleWindow);

    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('an open composition schedules only caret blinks', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(tester, 'fog');
    await _focus(tester, editor);
    await _select(tester, editor, const TextSelection.collapsed(offset: 3));
    await sendDeltas(tester, <Map<String, Object?>>[
      insertionDelta(
        oldText: 'fog',
        at: 3,
        text: 'k',
        composing: const TextRange(start: 3, end: 4),
      ),
    ]);
    await _settle(tester);
    await tester.pump();
    expect(
      editor.controller.value.composing,
      const TextRange(start: 3, end: 4),
    );

    final int frames = await _framesOver(tester, _idleWindow);

    expect(frames, lessThanOrEqualTo(6));
    expect(
      editor.controller.value.composing,
      const TextRange(start: 3, end: 4),
    );
  });

  testWidgets('the removal toast goes with the next edit and on unmount', (
    WidgetTester tester,
  ) async {
    NotePhotoToolbarRequest? last;
    final _Editor editor = await _pump(
      tester,
      _lowTideNote,
      photoToolbarBuilder:
          (BuildContext context, NotePhotoToolbarRequest request) {
            last = request;
            return const SizedBox();
          },
    );
    await _focus(tester, editor);
    await _select(
      tester,
      editor,
      const TextSelection(baseOffset: 3, extentOffset: 48),
    );
    final BuildContext context = tester.element(find.byType(NoteEditorView));

    showTransientToast(context, 'Photo removed');
    last!.onRemovalToastShown();
    await tester.pump();
    expect(find.text('Photo removed'), findsOneWidget);

    await _select(tester, editor, const TextSelection.collapsed(offset: 1));
    await sendDeltas(tester, <Map<String, Object?>>[
      insertionDelta(oldText: _lastSentText(tester), at: 1, text: 'h'),
    ]);
    await tester.pump();
    expect(find.text('Photo removed'), findsNothing);

    await _select(
      tester,
      editor,
      const TextSelection(baseOffset: 4, extentOffset: 49),
    );
    showTransientToast(context, 'Photo removed');
    last!.onRemovalToastShown();
    await tester.pump();
    expect(find.text('Photo removed'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    expect(find.text('Photo removed'), findsNothing);
  });

  testWidgets(
    'spell check follows its setting on macOS',
    (WidgetTester tester) async {
      final List<MethodCall> calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel(spellCheckChannelName),
        (MethodCall call) async {
          calls.add(call);
          return const <Object?>[];
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel(spellCheckChannelName),
          null,
        ),
      );
      _pinSurface(tester);
      final _Editor editor = _editor('teh harbour');
      final MediaResolver resolver = _resolver();
      await tester.pumpWidget(_app(editor, resolver: resolver));
      await _focus(tester, editor);

      await sendDeltas(tester, <Map<String, Object?>>[
        insertionDelta(oldText: 'teh harbour', at: 11, text: 's'),
      ]);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(calls, isEmpty);

      await tester.pumpWidget(
        _app(editor, resolver: resolver, spellCheckEnabled: true),
      );
      await tester.pump(Duration.zero);

      if (spellCheckAvailable) {
        expect(calls, isNotEmpty);
      } else {
        expect(calls, isEmpty);
      }
      await tester.pump(const Duration(seconds: 1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('a semantics set text is one transaction', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final _Editor editor = await _pump(tester, 'fog');
    await _focus(tester, editor);
    final List<Transaction> transactions = <Transaction>[];
    editor.controller.addTransactionListener(transactions.add);

    tester.semantics.setText(
      find.semantics.byFlag(SemanticsFlag.isTextField),
      'fog lifted',
    );
    await tester.pump();

    expect(editor.controller.text, 'fog lifted');
    expect(
      transactions.where((Transaction t) => !t.changes.isEmpty),
      hasLength(1),
    );
    semantics.dispose();
  });

  testWidgets('a deleted list marker runs backspace at the item start', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(tester, '- milk');
    await _focus(tester, editor);

    await sendDeltas(tester, <Map<String, Object?>>[
      deletionDelta(
        oldText: '- milk',
        range: const TextRange(start: 0, end: 1),
        selection: const TextSelection.collapsed(offset: 5),
      ),
    ]);
    await tester.pump();

    expect(editor.controller.text, 'milk');
    expect(editor.controller.selection, const TextSelection.collapsed(offset: 0));
  });

  testWidgets('typing in a table cell replaces only that cell', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(tester, '| a | b |\n| - | - |');
    await _focus(tester, editor);
    await _select(tester, editor, const TextSelection.collapsed(offset: 3));
    final List<Transaction> transactions = <Transaction>[];
    editor.controller.addTransactionListener(transactions.add);
    final String platformText = _lastSentText(tester);

    await sendDeltas(tester, <Map<String, Object?>>[
      insertionDelta(oldText: platformText, at: 1, text: 'a|b'),
    ]);
    await tester.pump();

    expect(editor.controller.text, '| aa\\|b | b |\n| - | - |');
    expect(
      transactions.where((Transaction t) => !t.changes.isEmpty),
      hasLength(1),
    );
  }, skip: !tablesEnabled);

  testWidgets('dragging a photo shows one insertion line until release', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(tester, _lowTideNote);
    final Offset centre = tester.getCenter(
      find.byKey(notePhotoKey(_reference, 0)),
    );

    final TestGesture gesture = await tester.startGesture(
      centre,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.moveBy(const Offset(0, 10));
    await tester.pump();

    final RenderNoteView render = _renderView(tester);
    expect(
      render.decorations.whereType<PhotoInsertionLineDecoration>(),
      hasLength(1),
    );
    expect(_viewState(tester).debugDropBoundary, isNotNull);

    await gesture.up();
    await tester.pump();

    expect(
      render.decorations.whereType<PhotoInsertionLineDecoration>(),
      isEmpty,
    );
    expect(_viewState(tester).debugDropBoundary, isNull);
    expect(editor.controller.text, contains('![Low tide]'));
    await _settle(tester);
  });
}
