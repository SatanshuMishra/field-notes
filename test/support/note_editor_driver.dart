import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:field_notes/domain/notes/markdown/markdown.dart'
    show MdBlock, MdBlockKind, MdPhotoLine, MdTree, parseNoteTree;
import 'package:field_notes/features/note_engine/layout/line_fragments.dart'
    show FragmentKind, LaidOutRow, LineFragment, VisualLine;
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteEditorController, NoteEditorView, noteEditorKey, tablesEnabled;
import 'package:field_notes/features/note_engine/render/note_view.dart'
    show notePhotoKey;
import 'package:field_notes/features/note_engine/render/render_note_view.dart'
    show NoteViewBody, RenderNoteView;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'text_input_messages.dart';

const CommonFinders _finders = find;

const int _focusPumps = 10;

Size firstNoteLineSize(RenderNoteView render) {
  for (final LaidOutRow row in render.noteLayout.flow.rows) {
    for (final LineFragment fragment in row.fragments) {
      if (fragment.kind == FragmentKind.text &&
          fragment.paragraph != null &&
          fragment.lines.isNotEmpty) {
        final VisualLine line = fragment.lines.first;
        return Size(line.width, line.height);
      }
    }
  }
  throw StateError('The note laid out no line of text');
}

final class _OwnPaintingContext extends TestRecordingPaintingContext {
  _OwnPaintingContext(super.canvas);

  @override
  void paintChild(RenderObject child, Offset offset) {}
}

ui.Paragraph? _paintedHint(RenderNoteView render) {
  final List<ui.Paragraph> laidOut = <ui.Paragraph>[
    for (final LaidOutRow row in render.noteLayout.flow.rows)
      for (final LineFragment fragment in row.fragments)
        if (fragment.paragraph case final ui.Paragraph paragraph) paragraph,
  ];
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  final _OwnPaintingContext context = _OwnPaintingContext(canvas);
  render.paint(context, Offset.zero);
  context.dispose();
  final List<ui.Paragraph> drawn = <ui.Paragraph>[
    for (final RecordedInvocation call in canvas.invocations)
      if (call.invocation.memberName == #drawParagraph)
        call.invocation.positionalArguments.first as ui.Paragraph,
  ];
  return drawn
      .where(
        (ui.Paragraph paragraph) => !laidOut.any(
          (ui.Paragraph text) => identical(text, paragraph),
        ),
      )
      .firstOrNull;
}

class NoteEditorDriver {
  const NoteEditorDriver(this.tester);

  final WidgetTester tester;

  Finder get find => _finders.byKey(noteEditorKey);

  NoteEditorView get _view =>
      tester.widget<NoteEditorView>(_finders.byType(NoteEditorView));

  NoteEditorController get _controller => _view.controller;

  RenderNoteView get _render => tester.renderObject<RenderNoteView>(
    _finders.descendant(
      of: _finders.byType(NoteEditorView),
      matching: _finders.byType(NoteViewBody),
    ),
  );

  String get source => _controller.text;

  String get visibleText => _render.visibleText.text;

  TextSelection get selection => _controller.selection;

  Size get firstLineSize => firstNoteLineSize(_render);

  ui.Paragraph? get paintedHint => _paintedHint(_render);

  TextStyle? get visibleHintStyle {
    final RenderNoteView render = _render;
    return _paintedHint(render) == null ? null : render.hintStyle;
  }

  Rect get caretRect {
    final TextSelection current = selection;
    if (!current.isValid) {
      throw StateError('The editor has no valid selection');
    }
    final RenderNoteView render = _render;
    final Rect content = render.noteLayout.caretRect(
      current.extentOffset,
      current.affinity,
    );
    return Rect.fromPoints(
      render.contentToGlobal(content.topLeft),
      render.contentToGlobal(content.bottomRight),
    );
  }

  Rect get contentRect {
    final RenderNoteView render = _render;
    final Offset origin = render.contentToGlobal(Offset.zero);
    return Rect.fromLTWH(
      origin.dx,
      origin.dy,
      render.size.width,
      math.max(
        render.size.height - render.bottomInset,
        render.noteLayout.size.height,
      ),
    );
  }

  Future<void> enterText(String text) async {
    _registerTextInput();
    if (!tester.testTextInput.hasAnyClients) {
      await _focus();
    }
    _controller.selection = TextSelection(
      baseOffset: source.length,
      extentOffset: 0,
    );
    await tester.pump();
    final TextEditingValue platform = await _platformValue();
    await sendDeltas(tester, <Map<String, Object?>>[
      replacementDelta(
        oldText: platform.text,
        range: TextRange(
          start: platform.selection.start,
          end: platform.selection.end,
        ),
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    ]);
    await tester.pump();
  }

  Future<void> typeText(String text) async {
    _registerTextInput();
    if (!tester.testTextInput.hasAnyClients) {
      throw StateError('The editor has no input connection');
    }
    for (final String cluster in text.characters) {
      final TextEditingValue platform = await _platformValue();
      final TextSelection current = platform.selection;
      final int start = current.isValid ? current.start : platform.text.length;
      final int end = current.isValid ? current.end : platform.text.length;
      final Map<String, Object?> delta = start == end
          ? insertionDelta(oldText: platform.text, at: start, text: cluster)
          : replacementDelta(
              oldText: platform.text,
              range: TextRange(start: start, end: end),
              text: cluster,
            );
      await sendDeltas(tester, <Map<String, Object?>>[delta]);
      await tester.pump();
    }
  }

  Future<void> setSelection(TextSelection selection) async {
    _controller.selection = selection;
    await tester.pump();
  }

  Future<void> pressKey(
    LogicalKeyboardKey key, {
    bool shift = false,
    bool control = false,
    bool alt = false,
    bool meta = false,
  }) async {
    final List<LogicalKeyboardKey> modifiers = <LogicalKeyboardKey>[
      if (meta) LogicalKeyboardKey.metaLeft,
      if (control) LogicalKeyboardKey.controlLeft,
      if (alt) LogicalKeyboardKey.altLeft,
      if (shift) LogicalKeyboardKey.shiftLeft,
    ];
    for (final LogicalKeyboardKey modifier in modifiers) {
      await tester.sendKeyDownEvent(modifier);
    }
    await tester.sendKeyEvent(key);
    for (final LogicalKeyboardKey modifier in modifiers.reversed) {
      await tester.sendKeyUpEvent(modifier);
    }
    await tester.pump();
  }

  Finder photoFinder(int n) {
    final String text = source;
    final MdTree tree = parseNoteTree(text, tables: tablesEnabled);
    final List<String> references = <String>[
      for (final MdBlock block in tree.blocks)
        if (block.kind == MdBlockKind.photoLine)
          MdPhotoLine.ofBlock(block, text).reference,
    ];
    if (n < 0 || n >= references.length) {
      return _finders.byWidgetPredicate((Widget _) => false);
    }
    final String reference = references[n];
    final int occurrence = references
        .sublist(0, n)
        .where((String earlier) => earlier == reference)
        .length;
    return _finders.byKey(notePhotoKey(reference, occurrence));
  }

  Future<void> press(
    Finder finder,
    Duration hold, {
    PointerDeviceKind kind = PointerDeviceKind.touch,
  }) async {
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(finder),
      kind: kind,
    );
    await tester.pump(hold);
    await gesture.up();
    await tester.pump();
  }

  void _registerTextInput() {
    if (tester.testTextInput.isRegistered) {
      return;
    }
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);
  }

  Future<void> _focus() async {
    final FocusNode focusNode = _view.focusNode;
    if (focusNode.hasFocus) {
      focusNode.unfocus();
      await tester.pump();
    }
    focusNode.requestFocus();
    for (int pumps = 0; pumps < _focusPumps; pumps++) {
      await tester.pump();
      if (tester.testTextInput.hasAnyClients) {
        return;
      }
    }
    throw StateError('The editor opened no input connection');
  }

  Future<TextEditingValue> _platformValue() async {
    await sendRequestExistingInputState(tester);
    await tester.pump();
    final Map<String, dynamic>? state = tester.testTextInput.editingState;
    if (state == null) {
      throw StateError('The editor sent no editing state');
    }
    return TextEditingValue.fromJSON(state);
  }
}
