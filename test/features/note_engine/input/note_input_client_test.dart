import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/input/delta_mapping.dart';
import 'package:field_notes/features/note_engine/input/note_input_client.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/projection/active_line.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/text_input_messages.dart';

const NoteVisibleProjector _projector = NoteVisibleProjector();

final class _FakeLayout implements NoteLayout {
  _FakeLayout(this.host);

  final _FakeHost host;

  @override
  Rect caretRect(int position, TextAffinity affinity) => host.caretRect;

  @override
  Rect rangeBounds(MdRange range) => host.caretRect;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeHost implements NoteInputHost {
  _FakeHost({
    required EditorState initial,
    required this.boxKey,
    required this.contentShift,
  }) : _state = initial;

  final GlobalKey boxKey;
  final Offset contentShift;
  EditorState _state;
  NoteInputClient? client;
  int currentViewId = 0;
  Rect caretRect = const Rect.fromLTWH(10, 20, 2, 25.6);
  Transaction? Function(EditorState state)? standIn;
  final List<Transaction> applied = <Transaction>[];
  final List<ClassifiedEdit> classified = <ClassifiedEdit>[];
  final List<KeyboardInsertedContent> inserted = <KeyboardInsertedContent>[];
  final List<String> selectors = <String>[];

  @override
  EditorState get state => _state;

  set state(EditorState next) => _state = next;

  @override
  VisibleText get visible => visibleFor(_state);

  @override
  VisibleText visibleFor(EditorState state) {
    final ActiveLine active = activeLineAt(
      state.source,
      state.tree,
      state.selection,
    );
    return _projector.project(
      state.source,
      state.tree,
      active.line,
      activeCell: active.cell,
    );
  }

  @override
  int get plainVisibleLength =>
      _projector.project(_state.source, _state.tree, null).text.length;

  @override
  NoteLayout? get layout => _FakeLayout(this);

  @override
  RenderBox? get renderBox =>
      boxKey.currentContext?.findRenderObject() as RenderBox?;

  @override
  Offset contentToLocal(Offset contentPoint) => contentPoint - contentShift;

  @override
  int get viewId => currentViewId;

  @override
  void applyInput(Transaction transaction) {
    applied.add(transaction);
    _state = _state.apply(transaction);
    client!.editorChanged(transaction.changes);
  }

  @override
  void runClassified(ClassifiedEdit edit) {
    classified.add(edit);
    final Transaction? transaction = standIn?.call(_state);
    if (transaction != null) {
      applyInput(transaction);
    }
  }

  @override
  void insertContent(KeyboardInsertedContent content) {
    inserted.add(content);
  }

  @override
  void performSelector(String selectorName) {
    selectors.add(selectorName);
  }
}

class _Harness extends StatefulWidget {
  const _Harness({
    super.key,
    required this.source,
    required this.selection,
    required this.contentShift,
  });

  final String source;
  final NoteSelection selection;
  final Offset contentShift;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final FocusNode node = FocusNode();
  final GlobalKey boxKey = GlobalKey();
  late final _FakeHost host = _FakeHost(
    initial: EditorState.create(
      widget.source,
      parse: parseNoteTree,
      selection: widget.selection,
    ),
    boxKey: boxKey,
    contentShift: widget.contentShift,
  );
  late final NoteInputClient client = NoteInputClient(host: host);
  Offset offset = Offset.zero;

  @override
  void initState() {
    super.initState();
    host.client = client;
  }

  @override
  void dispose() {
    client.dispose();
    node.dispose();
    super.dispose();
  }

  void moveBy(Offset next) {
    setState(() {
      offset = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    host.currentViewId = View.of(context).viewId;
    return Transform.translate(
      offset: offset,
      child: Focus(
        focusNode: node,
        onFocusChange: (bool _) => client.focusChanged(node),
        child: NoteInputCompositionCallback(
          client: client,
          child: SizedBox(key: boxKey, width: 600, height: 400),
        ),
      ),
    );
  }
}

Future<_HarnessState> _pumpHarness(
  WidgetTester tester, {
  String source = 'hello',
  NoteSelection selection = const NoteSelection.collapsed(5),
  Offset contentShift = Offset.zero,
}) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: _Harness(
            key: ValueKey<String>('$source@$selection@$contentShift'),
            source: source,
            selection: selection,
            contentShift: contentShift,
          ),
        ),
      ),
    ),
  );
  return tester.state<_HarnessState>(find.byType(_Harness));
}

Future<_HarnessState> _pumpFocused(
  WidgetTester tester, {
  String source = 'hello',
  NoteSelection selection = const NoteSelection.collapsed(5),
  Offset contentShift = Offset.zero,
}) async {
  final _HarnessState harness = await _pumpHarness(
    tester,
    source: source,
    selection: selection,
    contentShift: contentShift,
  );
  harness.node.requestFocus();
  await tester.pump();
  return harness;
}

List<String> _methods(WidgetTester tester) => <String>[
  for (final MethodCall call in tester.testTextInput.log) call.method,
];

const List<String> _openSequence = <String>[
  'TextInput.setClient',
  'TextInput.setEditableSizeAndTransform',
  'TextInput.setEditingState',
  'TextInput.show',
];

Map<String, dynamic> _argumentsOf(MethodCall call) =>
    call.arguments as Map<String, dynamic>;

Map<String, dynamic> _lastEditingState(WidgetTester tester) =>
    _argumentsOf(textInputCalls(tester, 'TextInput.setEditingState').last);

EditorState _composingState(EditorState state, MdRange composing) =>
    state.apply(
      Transaction(
        changes: ChangeSet.empty(state.source.length),
        selection: state.selection,
        event: TransactionEvent.inputIme,
        addToHistory: false,
        composing: composing,
      ),
    );

void main() {
  testWidgets(
    'the connection opens with the delta model, multiline and newline',
    (WidgetTester tester) async {
      final _HarnessState harness = await _pumpHarness(tester);
      tester.testTextInput.log.clear();
      harness.node.requestFocus();
      await tester.pump();

      expect(_methods(tester).take(4).toList(), _openSequence);
      final List<dynamic> clientArguments =
          tester.testTextInput.log.first.arguments as List<dynamic>;
      final Map<String, dynamic> configuration =
          clientArguments[1] as Map<String, dynamic>;
      expect(configuration['enableDeltaModel'], isTrue);
      expect(
        (configuration['inputType'] as Map<String, dynamic>)['name'],
        'TextInputType.multiline',
      );
      expect(configuration['inputAction'], 'TextInputAction.newline');
      expect(
        configuration['textCapitalization'],
        'TextCapitalization.sentences',
      );
      expect(configuration['viewId'], tester.view.viewId);
      expect(configuration['readOnly'], isFalse);
      final Map<String, dynamic> size = _argumentsOf(
        tester.testTextInput.log[1],
      );
      expect(size['width'], 600);
      expect(size['height'], 400);
      final Map<String, dynamic> editing = _argumentsOf(
        tester.testTextInput.log[2],
      );
      expect(editing['text'], 'hello');
      expect(editing['selectionBase'], 5);
      expect(editing['selectionExtent'], 5);
      expect(editing['composingBase'], -1);

      await sendConnectionClosed(tester);
      expect(harness.node.hasFocus, isTrue);
      expect(harness.client.hasConnection, isFalse);
      tester.testTextInput.log.clear();
      harness.client.focusChanged(harness.node);
      expect(textInputCalls(tester, 'TextInput.setClient'), isEmpty);

      harness.node.unfocus();
      await tester.pump();
      harness.node.requestFocus();
      await tester.pump();
      expect(harness.client.hasConnection, isTrue);
      tester.testTextInput.log.clear();
      harness.node.unfocus();
      await tester.pump();
      expect(_methods(tester), contains('TextInput.clearClient'));
      expect(harness.client.hasConnection, isFalse);
    },
  );

  testWidgets(
    'the keyboard is shown again when the connection is already open',
    (WidgetTester tester) async {
      final _HarnessState harness = await _pumpFocused(tester);
      tester.testTextInput.log.clear();
      tester.testTextInput.hide();

      harness.client.showKeyboard(harness.node);
      expect(textInputCalls(tester, 'TextInput.show'), hasLength(1));
      expect(textInputCalls(tester, 'TextInput.setClient'), isEmpty);
      expect(tester.testTextInput.isVisible, isTrue);

      await sendConnectionClosed(tester);
      expect(harness.node.hasFocus, isTrue);
      tester.testTextInput.log.clear();
      harness.client.showKeyboard(harness.node);
      expect(_methods(tester), _openSequence);

      harness.node.unfocus();
      await tester.pump();
      tester.testTextInput.log.clear();
      harness.client.showKeyboard(harness.node);
      await tester.pump();
      expect(harness.node.hasFocus, isTrue);
      expect(_methods(tester).take(4).toList(), _openSequence);
    },
  );

  testWidgets('geometry is reported after frames without scheduling frames', (
    WidgetTester tester,
  ) async {
    final _HarnessState harness = await _pumpFocused(tester);
    await tester.pump();

    final List<MethodCall> carets = textInputCalls(
      tester,
      'TextInput.setCaretRect',
    );
    final List<MethodCall> marked = textInputCalls(
      tester,
      'TextInput.setMarkedTextRect',
    );
    expect(carets, hasLength(1));
    expect(marked, hasLength(1));
    for (final MethodCall call in <MethodCall>[carets.single, marked.single]) {
      final Map<String, dynamic> rect = _argumentsOf(call);
      expect(rect['x'], 10);
      expect(rect['y'], 20);
      expect(rect['width'], 2);
      expect(rect['height'], 25.6);
    }
    expect(tester.binding.hasScheduledFrame, isFalse);

    tester.binding.scheduleFrame();
    await tester.pump();
    expect(textInputCalls(tester, 'TextInput.setCaretRect'), hasLength(1));
    expect(textInputCalls(tester, 'TextInput.setMarkedTextRect'), hasLength(1));

    harness.host.caretRect = const Rect.fromLTWH(30, 20, 2, 25.6);
    tester.binding.scheduleFrame();
    await tester.pump();
    final List<MethodCall> moved = textInputCalls(
      tester,
      'TextInput.setCaretRect',
    );
    expect(moved, hasLength(2));
    expect(_argumentsOf(moved.last)['x'], 30);
    expect(tester.binding.hasScheduledFrame, isFalse);

    final int transforms = textInputCalls(
      tester,
      'TextInput.setEditableSizeAndTransform',
    ).length;
    harness.moveBy(const Offset(0, -300));
    await tester.pump();
    final List<MethodCall> sized = textInputCalls(
      tester,
      'TextInput.setEditableSizeAndTransform',
    );
    expect(sized, hasLength(transforms + 1));
    final List<dynamic> transform =
        _argumentsOf(sized.last)['transform'] as List<dynamic>;
    expect(transform[13], -300);
  });

  testWidgets(
    'android extras are applied on android only',
    (WidgetTester tester) async {
      final bool android = defaultTargetPlatform == TargetPlatform.android;
      final _HarnessState harness = await _pumpFocused(tester);
      final Map<String, dynamic> configuration =
          (textInputCalls(tester, 'TextInput.setClient').last.arguments
                  as List<dynamic>)[1]
              as Map<String, dynamic>;
      expect(
        configuration['contentCommitMimeTypes'],
        android ? <String>['image/*'] : isEmpty,
      );
      if (!android) {
        return;
      }

      const KeyboardInsertedContent gif = KeyboardInsertedContent(
        mimeType: 'image/gif',
        uri: 'content://keyboard/1',
      );
      await sendCommitContent(tester, gif);
      expect(harness.host.inserted, <KeyboardInsertedContent>[gif]);

      await sendPrivateCommand(tester, 'com.example.command');
      expect(tester.takeException(), isNull);
      expect(harness.host.applied, isEmpty);

      final _HarnessState rebuilt = await _pumpFocused(
        tester,
        source: 'teh',
        selection: const NoteSelection.collapsed(3),
      );
      await sendDeltas(tester, <Map<String, Object?>>[
        deletionDelta(oldText: 'teh', range: const TextRange(start: 0, end: 3)),
        insertionDelta(oldText: '', at: 0, text: 'the'),
      ]);
      expect(rebuilt.host.applied, hasLength(1));
      final Transaction transaction = rebuilt.host.applied.single;
      expect(
        transaction.changes,
        ChangeSet(
          length: 3,
          replacements: const <TextReplacement>[TextReplacement(0, 3, 'the')],
        ),
      );
      expect(transaction.event, TransactionEvent.inputType);
      expect(rebuilt.host.state.source, 'the');
    },
    variant: TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.android,
      TargetPlatform.macOS,
    }),
  );

  testWidgets('blur and a closed connection clear the composing range', (
    WidgetTester tester,
  ) async {
    final _HarnessState harness = await _pumpFocused(tester);
    harness.host.state = _composingState(
      harness.host.state,
      const MdRange(0, 5),
    );
    harness.node.unfocus();
    await tester.pump();
    expect(harness.host.applied, hasLength(1));
    final Transaction blurred = harness.host.applied.single;
    expect(blurred.changes.isEmpty, isTrue);
    expect(blurred.event, TransactionEvent.inputIme);
    expect(blurred.addToHistory, isFalse);
    expect(harness.host.state.composing, isNull);

    harness.node.requestFocus();
    await tester.pump();
    harness.host.state = _composingState(
      harness.host.state,
      const MdRange(0, 5),
    );
    harness.host.applied.clear();
    await sendConnectionClosed(tester);
    expect(harness.host.applied, hasLength(1));
    final Transaction closed = harness.host.applied.single;
    expect(closed.changes.isEmpty, isTrue);
    expect(closed.event, TransactionEvent.inputIme);
    expect(closed.addToHistory, isFalse);
    expect(harness.host.state.composing, isNull);
    expect(harness.node.hasFocus, isTrue);

    await sendRequestExistingInputState(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('requestExistingInputState re-sends the current value', (
    WidgetTester tester,
  ) async {
    final _HarnessState harness = await _pumpFocused(tester);
    tester.testTextInput.log.clear();
    await sendRequestExistingInputState(tester);
    expect(_methods(tester), <String>[
      'TextInput.setClient',
      'TextInput.setEditingState',
    ]);
    final TextEditingValue sent = TextEditingValue.fromJSON(
      _lastEditingState(tester),
    );
    expect(sent.text, 'hello');
    expect(harness.client.mirror.value, sent);
  });

  testWidgets('a one-grapheme backspace runs the classified edit', (
    WidgetTester tester,
  ) async {
    final _HarnessState harness = await _pumpFocused(tester);
    tester.testTextInput.log.clear();
    await sendDeltas(tester, <Map<String, Object?>>[
      deletionDelta(oldText: 'hello', range: const TextRange(start: 4, end: 5)),
    ]);
    expect(harness.host.classified, <ClassifiedEdit>[const BackspaceEdit()]);
    expect(harness.host.state.source, 'hello');
    expect(_lastEditingState(tester)['text'], 'hello');

    harness.host.standIn = (EditorState state) => Transaction(
      changes: ChangeSet.single(state.source.length, 4, 5, ''),
      selection: const NoteSelection.collapsed(4),
      event: TransactionEvent.inputDelete,
    );
    tester.testTextInput.log.clear();
    await sendDeltas(tester, <Map<String, Object?>>[
      deletionDelta(oldText: 'hello', range: const TextRange(start: 4, end: 5)),
    ]);
    expect(harness.host.classified, hasLength(2));
    expect(harness.host.state.source, 'hell');
    expect(textInputCalls(tester, 'TextInput.setEditingState'), isEmpty);
  });

  testWidgets('a batch that yields the current value is ignored', (
    WidgetTester tester,
  ) async {
    final _HarnessState harness = await _pumpFocused(tester);
    tester.testTextInput.log.clear();
    await sendDeltas(tester, <Map<String, Object?>>[
      selectionDelta(
        oldText: 'hello',
        selection: const TextSelection.collapsed(offset: 5),
      ),
    ]);
    expect(harness.host.applied, isEmpty);
    expect(textInputCalls(tester, 'TextInput.setEditingState'), isEmpty);

    final _HarnessState ranged = await _pumpFocused(
      tester,
      selection: const NoteSelection(anchor: 0, head: 5),
    );
    tester.testTextInput.log.clear();
    await sendDeltas(tester, <Map<String, Object?>>[
      selectionDelta(
        oldText: 'hello',
        selection: const TextSelection(baseOffset: 0, extentOffset: 5),
      ),
    ]);
    expect(ranged.host.applied, isEmpty);
    expect(textInputCalls(tester, 'TextInput.setEditingState'), isEmpty);
  });

  testWidgets('a full value is applied as one minimal edit', (
    WidgetTester tester,
  ) async {
    final _HarnessState harness = await _pumpFocused(tester);
    await sendEditingState(
      tester,
      const TextEditingValue(
        text: 'hello there',
        selection: TextSelection.collapsed(offset: 11),
      ),
    );
    expect(harness.host.applied, hasLength(1));
    final Transaction transaction = harness.host.applied.single;
    expect(transaction.changes, ChangeSet.single(5, 5, 5, ' there'));
    expect(transaction.selection, const NoteSelection.collapsed(11));
    expect(harness.host.state.source, 'hello there');
  });

  testWidgets('a delta matching no known value is dropped and resynced', (
    WidgetTester tester,
  ) async {
    final _HarnessState harness = await _pumpFocused(tester);
    tester.testTextInput.log.clear();
    await sendDeltas(tester, <Map<String, Object?>>[
      insertionDelta(oldText: 'nope', at: 0, text: 'x'),
    ]);
    expect(harness.client.drops, hasLength(1));
    expect(harness.host.applied, isEmpty);
    expect(textInputCalls(tester, 'TextInput.setEditingState'), hasLength(1));
    expect(_lastEditingState(tester)['text'], 'hello');
  });

  testWidgets('a structure change mid-batch rebases the next delta', (
    WidgetTester tester,
  ) async {
    final _HarnessState harness = await _pumpFocused(
      tester,
      source: '# a\nb',
      selection: const NoteSelection.collapsed(5),
    );
    expect(_lastEditingState(tester)['text'], 'a\nb');
    await sendDeltas(tester, <Map<String, Object?>>[
      deletionDelta(
        oldText: 'a\nb',
        range: const TextRange(start: 1, end: 2),
        selection: const TextSelection.collapsed(offset: 2),
      ),
      insertionDelta(oldText: 'ab', at: 2, text: 'c'),
    ]);
    expect(harness.host.applied, hasLength(2));
    expect(harness.host.state.source, '# abc');
    expect(harness.host.state.selection, const NoteSelection.collapsed(5));
    expect(harness.client.drops, isEmpty);
  });

  testWidgets('a selection delta carrying a composing range applies it', (
    WidgetTester tester,
  ) async {
    final _HarnessState harness = await _pumpFocused(tester);
    await sendDeltas(tester, <Map<String, Object?>>[
      selectionDelta(
        oldText: 'hello',
        selection: const TextSelection.collapsed(offset: 3),
        composing: const TextRange(start: 1, end: 3),
      ),
    ]);
    expect(tester.takeException(), isNull);
    expect(harness.host.state.composing, const MdRange(1, 3));
    expect(harness.host.applied.single.event, TransactionEvent.inputIme);
  });

  testWidgets('a selected photo sends exactly its placeholder', (
    WidgetTester tester,
  ) async {
    await _pumpFocused(
      tester,
      source: 'A\n![p](photo/abc123abc123)\nB',
      selection: const NoteSelection(anchor: 2, head: 26),
    );
    final Map<String, dynamic> editing = _lastEditingState(tester);
    expect(editing['selectionBase'], 2);
    expect(editing['selectionExtent'], 3);
  });

  testWidgets('a long note sends the window around the caret', (
    WidgetTester tester,
  ) async {
    final String source = List<String>.filled(600, '${'a' * 99}\n').join();
    final _HarnessState harness = await _pumpFocused(
      tester,
      source: source,
      selection: const NoteSelection.collapsed(30000),
    );
    final Map<String, dynamic> editing = _lastEditingState(tester);
    expect((editing['text'] as String).length, 16000);
    expect(editing['selectionBase'], 8000);
    expect(harness.client.windowBase, 22000);
  });

  testWidgets('geometry goes through the host content-to-local conversion', (
    WidgetTester tester,
  ) async {
    await _pumpFocused(tester, contentShift: const Offset(0, 100));
    await tester.pump();
    final Map<String, dynamic> caret = _argumentsOf(
      textInputCalls(tester, 'TextInput.setCaretRect').last,
    );
    expect(caret['y'], -80);
  });

  test('every delta helper decodes to its delta', () {
    final TextEditingDelta insertion = TextEditingDelta.fromJSON(
      insertionDelta(oldText: 'hello', at: 5, text: '!'),
    );
    expect(insertion, isA<TextEditingDeltaInsertion>());
    final TextEditingDeltaInsertion inserted =
        insertion as TextEditingDeltaInsertion;
    expect(inserted.oldText, 'hello');
    expect(inserted.textInserted, '!');
    expect(inserted.insertionOffset, 5);
    expect(inserted.selection, const TextSelection.collapsed(offset: 6));
    expect(inserted.composing, TextRange.empty);

    final TextEditingDelta deletion = TextEditingDelta.fromJSON(
      deletionDelta(
        oldText: 'hello',
        range: const TextRange(start: 1, end: 3),
        composing: const TextRange(start: 0, end: 1),
      ),
    );
    expect(deletion, isA<TextEditingDeltaDeletion>());
    final TextEditingDeltaDeletion deleted =
        deletion as TextEditingDeltaDeletion;
    expect(deleted.deletedRange, const TextRange(start: 1, end: 3));
    expect(deleted.selection, const TextSelection.collapsed(offset: 1));
    expect(deleted.composing, const TextRange(start: 0, end: 1));

    final TextEditingDelta replacement = TextEditingDelta.fromJSON(
      replacementDelta(
        oldText: 'hello',
        range: const TextRange(start: 1, end: 3),
        text: 'XY',
        selection: const TextSelection.collapsed(
          offset: 2,
          affinity: TextAffinity.upstream,
        ),
      ),
    );
    expect(replacement, isA<TextEditingDeltaReplacement>());
    final TextEditingDeltaReplacement replaced =
        replacement as TextEditingDeltaReplacement;
    expect(replaced.replacedRange, const TextRange(start: 1, end: 3));
    expect(replaced.replacementText, 'XY');
    expect(
      replaced.selection,
      const TextSelection.collapsed(offset: 2, affinity: TextAffinity.upstream),
    );

    final TextEditingDelta selection = TextEditingDelta.fromJSON(
      selectionDelta(
        oldText: 'hello',
        selection: const TextSelection(baseOffset: 1, extentOffset: 4),
      ),
    );
    expect(selection, isA<TextEditingDeltaNonTextUpdate>());
    expect(selection.oldText, 'hello');
    expect(
      selection.selection,
      const TextSelection(baseOffset: 1, extentOffset: 4),
    );
    expect(selection.composing, TextRange.empty);
  });

  testWidgets('selectors are forwarded to the host in order', (
    WidgetTester tester,
  ) async {
    final _HarnessState harness = await _pumpFocused(tester);
    harness.client.performSelector('moveLeft:');
    await sendSelectors(tester, <String>['deleteBackward:', 'insertTab:']);
    expect(harness.host.selectors, <String>[
      'moveLeft:',
      'deleteBackward:',
      'insertTab:',
    ]);
  });
}
