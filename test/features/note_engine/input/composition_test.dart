import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/history.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/input/composition.dart';
import 'package:field_notes/features/note_engine/input/delta_mapping.dart';
import 'package:field_notes/features/note_engine/input/input_window.dart';
import 'package:field_notes/features/note_engine/input/note_input_client.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/projection/active_line.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/text_input_messages.dart';

const NoteVisibleProjector _projector = NoteVisibleProjector();

const String _word = '\u{65E5}\u{672C}\u{8A9E}';

EditorState _state(String source, int caret) => EditorState.create(
  source,
  parse: parseNoteTree,
  selection: NoteSelection.collapsed(caret),
  history: const NoteHistory(),
);

int _undoDepth(EditorState state) => (state.history as NoteHistory).undoDepth;

Transaction _ime(
  int length,
  int from,
  int to,
  String text,
  int caret,
  MdRange? composing,
) => Transaction(
  changes: ChangeSet.single(length, from, to, text),
  selection: NoteSelection.collapsed(caret),
  event: TransactionEvent.inputIme,
  addToHistory: false,
  composing: composing,
);

final class _Admitted {
  const _Admitted(this.state, this.composition, this.step);

  final EditorState state;
  final NoteComposition composition;
  final CompositionStep step;
}

_Admitted _admit(
  EditorState state,
  NoteComposition composition,
  Transaction transaction, {
  ActiveLine? activeLine = const ActiveLine(line: 0),
  InputWindow? window = const InputWindow.whole(),
}) {
  final CompositionStep step = admitTransaction(
    composition,
    before: state,
    transaction: transaction,
    activeLine: activeLine,
    window: window,
  );
  return _Admitted(state.apply(step.transaction), step.composition, step);
}

VisibleText _projected(EditorState state, ActiveLine active) => _projector
    .project(state.source, state.tree, active.line, activeCell: active.cell);

final class _FakeLayout implements NoteLayout {
  const _FakeLayout();

  static const Rect _rect = Rect.fromLTWH(10, 20, 2, 25.6);

  @override
  Rect caretRect(int position, TextAffinity affinity) => _rect;

  @override
  Rect rangeBounds(MdRange range) => _rect;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeHost implements NoteInputHost {
  _FakeHost(this.harness, this._state);

  final _HarnessState harness;
  EditorState _state;
  int currentViewId = 0;
  Transaction? Function(EditorState state)? standIn;
  final List<ClassifiedEdit> classified = <ClassifiedEdit>[];
  final List<EditorState> classifiedOn = <EditorState>[];
  final List<CompositionCommit> commits = <CompositionCommit>[];

  @override
  EditorState get state => _state;

  @override
  VisibleText get visible => visibleFor(_state);

  @override
  VisibleText visibleFor(EditorState state) {
    final NoteComposition composition = harness.composition;
    final ActiveLine active = composition.isActive
        ? composition.activeLine!
        : activeLineAt(state.source, state.tree, state.selection);
    return _projected(state, active);
  }

  @override
  int get plainVisibleLength =>
      _projector.project(_state.source, _state.tree, null).text.length;

  @override
  NoteLayout? get layout => const _FakeLayout();

  @override
  RenderBox? get renderBox =>
      harness.boxKey.currentContext?.findRenderObject() as RenderBox?;

  @override
  Offset contentToLocal(Offset contentPoint) => contentPoint;

  @override
  int get viewId => currentViewId;

  @override
  void applyInput(Transaction transaction) {
    final CompositionStep step = admitTransaction(
      harness.composition,
      before: _state,
      transaction: transaction,
      activeLine: activeLineAt(_state.source, _state.tree, _state.selection),
      window: harness.client.window,
    );
    harness.composition = step.composition;
    final CompositionCommit? commit = step.commit;
    if (commit != null) {
      commits.add(commit);
    }
    _state = _state.apply(step.transaction);
    harness.client.editorChanged(step.transaction.changes);
  }

  @override
  void runClassified(ClassifiedEdit edit) {
    classified.add(edit);
    classifiedOn.add(_state);
    final Transaction? transaction = standIn?.call(_state);
    if (transaction != null) {
      applyInput(transaction);
    }
  }

  @override
  void insertContent(KeyboardInsertedContent content) {}

  @override
  void performSelector(String selectorName) {}
}

class _Harness extends StatefulWidget {
  const _Harness({super.key, required this.source, required this.caret});

  final String source;
  final int caret;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final FocusNode node = FocusNode();
  final GlobalKey boxKey = GlobalKey();
  late final _FakeHost host = _FakeHost(
    this,
    _state(widget.source, widget.caret),
  );
  late final NoteInputClient client = NoteInputClient(host: host);
  NoteComposition composition = const NoteComposition.idle();

  @override
  void dispose() {
    client.dispose();
    node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    host.currentViewId = View.of(context).viewId;
    return Focus(
      focusNode: node,
      onFocusChange: (bool _) => client.focusChanged(node),
      child: NoteInputCompositionCallback(
        client: client,
        child: SizedBox(key: boxKey, width: 600, height: 400),
      ),
    );
  }
}

Future<_HarnessState> _pumpFocused(
  WidgetTester tester, {
  required String source,
  required int caret,
}) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: _Harness(key: UniqueKey(), source: source, caret: caret),
        ),
      ),
    ),
  );
  final _HarnessState harness = tester.state<_HarnessState>(
    find.byType(_Harness),
  );
  harness.node.requestFocus();
  await tester.pump();
  return harness;
}

Future<void> _composeAtEnd(
  WidgetTester tester, {
  required String prefix,
  required String word,
}) async {
  String text = prefix;
  for (final String letter in word.split('')) {
    await sendDeltas(tester, <Map<String, Object?>>[
      insertionDelta(
        oldText: text,
        at: text.length,
        text: letter,
        composing: TextRange(start: prefix.length, end: text.length + 1),
      ),
    ]);
    await tester.pump();
    text = '$text$letter';
  }
}

Map<String, dynamic> _lastEditingState(WidgetTester tester) =>
    textInputCalls(tester, 'TextInput.setEditingState').last.arguments
        as Map<String, dynamic>;

void _applyThroughHost(_HarnessState harness, Transaction? transaction) {
  if (transaction != null) {
    harness.host.applyInput(transaction);
  }
}

Transaction _bold(EditorState state) => Transaction(
  changes: ChangeSet(
    length: 3,
    replacements: const <TextReplacement>[
      TextReplacement(0, 0, '**'),
      TextReplacement(3, 3, '**'),
    ],
  ),
  selection: const NoteSelection.collapsed(5),
  event: TransactionEvent.format,
);

Transaction _listEnter(EditorState state) => Transaction(
  changes: ChangeSet.single(6, 6, 6, '\n- '),
  selection: const NoteSelection.collapsed(9),
  event: TransactionEvent.list,
);

void main() {
  test('composition freezes the active line, window and history', () {
    final EditorState initial = _state('abc\ndef', 3);
    final _Admitted first = _admit(
      initial,
      const NoteComposition.idle(),
      _ime(7, 3, 3, 'n', 4, const MdRange(3, 4)),
    );
    expect(first.composition.isActive, isTrue);
    expect(first.composition.activeLine, const ActiveLine(line: 0));
    expect(first.composition.window, const InputWindow.whole());
    expect(first.step.transaction.addToHistory, isFalse);

    final _Admitted second = _admit(
      first.state,
      first.composition,
      _ime(8, 4, 4, 'i', 5, const MdRange(3, 5)),
      activeLine: const ActiveLine(line: 1),
    );
    final _Admitted third = _admit(
      second.state,
      second.composition,
      _ime(9, 5, 5, 'h', 6, const MdRange(3, 6)),
      activeLine: const ActiveLine(line: 1),
    );
    expect(second.composition.activeLine, const ActiveLine(line: 0));
    expect(third.composition.activeLine, const ActiveLine(line: 0));
    expect(second.step.transaction.addToHistory, isFalse);
    expect(third.step.transaction.addToHistory, isFalse);
    expect(third.state.source, 'abcnih\ndef');
    expect(_undoDepth(third.state), 0);
    expect(second.step.commit, isNull);
    expect(third.step.commit, isNull);

    expect(
      selectionLeavesComposition(
        third.composition,
        const NoteSelection.collapsed(5),
      ),
      isFalse,
    );
    expect(
      selectionLeavesComposition(
        third.composition,
        const NoteSelection.collapsed(8),
      ),
      isTrue,
    );

    final _Admitted ended = _admit(
      third.state,
      third.composition,
      _ime(10, 3, 6, _word, 6, null),
    );
    expect(ended.composition.isActive, isFalse);
    expect(ended.composition, const NoteComposition.idle());
    expect(ended.step.transaction.event, TransactionEvent.inputIme);
    expect(ended.step.transaction.addToHistory, isFalse);
    final CompositionCommit commit = ended.step.commit!;
    expect(
      commit.net,
      ChangeSet(
        length: 7,
        replacements: const <TextReplacement>[TextReplacement(3, 3, _word)],
      ),
    );
    expect(commit.sourceBefore, 'abc\ndef');
    expect(commit.selectionBefore, const NoteSelection.collapsed(3));
    expect(ended.state.source, 'abc$_word\ndef');
    expect(_undoDepth(ended.state), 1);
    final EditorState undone = ended.state.undo();
    expect(undone.source, 'abc\ndef');
    expect(undone.selection, const NoteSelection.collapsed(3));

    final String long = List<String>.filled(600, '${'a' * 99}\n').join();
    expect(long.length, 60000);
    final EditorState big = _state(long, 37000);
    const InputWindow w = InputWindow(start: 22000, end: 38000);
    final _Admitted composed = _admit(
      big,
      const NoteComposition.idle(),
      Transaction(
        changes: ChangeSet.single(60000, 37000, 37000, 'x'),
        selection: const NoteSelection.collapsed(37001),
        event: TransactionEvent.inputIme,
        addToHistory: false,
        composing: const MdRange(37000, 37001),
      ),
      activeLine: activeLineAt(big.source, big.tree, big.selection),
      window: w,
    );
    expect(
      composed.composition.window,
      const InputWindow(start: 22000, end: 38001),
    );
    final VisibleText visible = _projected(
      composed.state,
      activeLineAt(
        composed.state.source,
        composed.state.tree,
        composed.state.selection,
      ),
    );
    expect(
      planInputWindow(
        visible: visible,
        plainLength: 60001,
        selection: const NoteSelection.collapsed(37001),
        previous: composed.composition.window,
        composing: composed.composition.isActive,
      ),
      const InputWindow(start: 22000, end: 38001),
    );
    expect(
      planInputWindow(
        visible: visible,
        plainLength: 60001,
        selection: const NoteSelection.collapsed(37001),
        previous: composed.composition.window,
      ),
      isNot(const InputWindow(start: 22000, end: 38001)),
    );
  });

  testWidgets('a framework edit first commits the composition', (
    WidgetTester tester,
  ) async {
    final _HarnessState harness = await _pumpFocused(
      tester,
      source: '',
      caret: 0,
    );
    expect(harness.client.hasConnection, isTrue);
    await _composeAtEnd(tester, prefix: '', word: 'nihongo');
    await sendDeltas(tester, <Map<String, Object?>>[
      replacementDelta(
        oldText: 'nihongo',
        range: const TextRange(start: 0, end: 7),
        text: _word,
        composing: const TextRange(start: 0, end: 3),
      ),
    ]);
    await tester.pump();
    expect(harness.host.state.source, _word);
    expect(harness.composition.isActive, isTrue);
    expect(_undoDepth(harness.host.state), 0);

    final ({Transaction? commit, CompositionCommit? record, Transaction? edit})
    result = frameworkEdit(
      harness.composition,
      state: harness.host.state,
      command: _bold,
    );
    expect(result.commit, isNotNull);
    expect(result.record, isNotNull);
    expect(result.edit, isNotNull);

    harness.composition = const NoteComposition.idle();
    _applyThroughHost(harness, result.commit);
    await tester.pump();
    final Map<String, dynamic> sent = _lastEditingState(tester);
    expect(sent['text'], _word);
    expect(sent['composingBase'], -1);
    expect(sent['composingExtent'], -1);

    _applyThroughHost(harness, result.edit);
    await tester.pump();
    final EditorState bolded = harness.host.state;
    expect(bolded.source, '**$_word**');
    expect(_undoDepth(bolded), 2);
    final EditorState once = bolded.undo();
    expect(once.source, _word);
    expect(once.undo().source, '');
  });

  testWidgets(
    'enter after a composing word on android continues the list',
    (WidgetTester tester) async {
      final _HarnessState harness = await _pumpFocused(
        tester,
        source: '- ',
        caret: 2,
      );
      harness.host.standIn = _listEnter;
      await _composeAtEnd(tester, prefix: '- ', word: 'milk');
      expect(harness.host.state.source, '- milk');
      expect(harness.composition.isActive, isTrue);
      expect(
        harness.composition.selectionBefore,
        const NoteSelection.collapsed(2),
      );

      await sendDeltas(tester, <Map<String, Object?>>[
        selectionDelta(
          oldText: '- milk',
          selection: const TextSelection.collapsed(offset: 6),
        ),
        insertionDelta(oldText: '- milk', at: 6, text: '\n'),
      ]);
      await tester.pump();
      expect(harness.host.classified, const <ClassifiedEdit>[EnterEdit()]);
      expect(harness.host.classifiedOn.single.composing, isNull);
      expect(
        harness.host.commits.single.net,
        ChangeSet.single(2, 2, 2, 'milk'),
      );
      final EditorState entered = harness.host.state;
      expect(entered.source, '- milk\n- ');
      expect(entered.selection, const NoteSelection.collapsed(9));
      expect(_undoDepth(entered), 2);
      final EditorState once = entered.undo();
      expect(once.source, '- milk');
      expect(once.selection, const NoteSelection.collapsed(6));
      final EditorState twice = once.undo();
      expect(twice.source, '- ');
      expect(twice.selection, const NoteSelection.collapsed(2));

      final _HarnessState fresh = await _pumpFocused(
        tester,
        source: '- ',
        caret: 2,
      );
      fresh.host.standIn = _listEnter;
      await _composeAtEnd(tester, prefix: '- ', word: 'milk');
      await sendDeltas(tester, <Map<String, Object?>>[
        insertionDelta(
          oldText: '- milk',
          at: 6,
          text: '\n',
          composing: const TextRange(start: 2, end: 6),
        ),
      ]);
      await tester.pump();
      expect(fresh.host.classified, isEmpty);
      expect(fresh.host.state.source, '- milk\n');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  test('commitComposition on blur yields the commit transaction', () {
    final _Admitted composing = _admit(
      _state('ab', 2),
      const NoteComposition.idle(),
      _ime(2, 2, 2, 'k', 3, const MdRange(2, 3)),
    );
    final ({
      NoteComposition composition,
      Transaction? commit,
      CompositionCommit? record,
    })
    committed = commitComposition(
      composing.composition,
      state: composing.state,
    );
    final Transaction commit = committed.commit!;
    expect(committed.composition, const NoteComposition.idle());
    expect(commit.changes, ChangeSet.empty(3));
    expect(commit.selection, const NoteSelection.collapsed(3));
    expect(commit.event, TransactionEvent.inputIme);
    expect(commit.addToHistory, isFalse);
    expect(commit.composing, isNull);
    expect(committed.record!.net, ChangeSet.single(2, 2, 2, 'k'));
    expect(committed.record!.selectionAfter, const NoteSelection.collapsed(3));
    final EditorState after = composing.state.apply(commit);
    expect(_undoDepth(after), 1);
    expect(after.undo().source, 'ab');

    final ({
      NoteComposition composition,
      Transaction? commit,
      CompositionCommit? record,
    })
    idle = commitComposition(
      const NoteComposition.idle(),
      state: composing.state,
    );
    expect(idle.commit, isNull);
    expect(idle.record, isNull);
  });

  test('a cancelled composition yields no commit', () {
    final _Admitted typed = _admit(
      _state('ab', 2),
      const NoteComposition.idle(),
      _ime(2, 2, 2, 'k', 3, const MdRange(2, 3)),
    );
    final _Admitted cancelled = _admit(
      typed.state,
      typed.composition,
      _ime(3, 2, 3, '', 2, null),
    );
    expect(cancelled.composition.isActive, isFalse);
    expect(cancelled.step.commit, isNull);
    expect(cancelled.state.source, 'ab');
    expect(_undoDepth(cancelled.state), 0);
  });

  test('a transaction admitted while idle comes back identical', () {
    final Transaction typed = Transaction(
      changes: ChangeSet.single(2, 2, 2, 'c'),
      selection: const NoteSelection.collapsed(3),
      event: TransactionEvent.inputType,
    );
    final CompositionStep step = admitTransaction(
      const NoteComposition.idle(),
      before: _state('ab', 2),
      transaction: typed,
      activeLine: const ActiveLine(line: 0),
      window: const InputWindow.whole(),
    );
    expect(identical(step.transaction, typed), isTrue);
    expect(step.commit, isNull);
    expect(step.composition, const NoteComposition.idle());
  });

  test('frameworkEdit while idle runs only the command', () {
    final EditorState state = _state('abc', 3);
    final Transaction expected = _bold(state);
    final ({Transaction? commit, CompositionCommit? record, Transaction? edit})
    result = frameworkEdit(
      const NoteComposition.idle(),
      state: state,
      command: (EditorState _) => expected,
    );
    expect(result.commit, isNull);
    expect(result.record, isNull);
    expect(identical(result.edit, expected), isTrue);
  });

  test('an external write while composing is committed first', () {
    final _Admitted composing = _admit(
      _state('ab', 2),
      const NoteComposition.idle(),
      _ime(2, 2, 2, 'k', 3, const MdRange(2, 3)),
    );
    final List<EditorState> seen = <EditorState>[];
    final ({Transaction? commit, CompositionCommit? record, Transaction? edit})
    result = frameworkEdit(
      composing.composition,
      state: composing.state,
      command: (EditorState state) {
        seen.add(state);
        return state.externalWrite(
          'abk!',
          selectionBase: 4,
          selectionExtent: 4,
        );
      },
    );
    expect(seen.single.composing, isNull);
    expect(result.record!.net, ChangeSet.single(2, 2, 2, 'k'));
    final EditorState committed = composing.state.apply(result.commit!);
    final EditorState written = committed.apply(result.edit!);
    expect(written.source, 'abk!');
    expect(_undoDepth(committed), 1);
    expect(_undoDepth(written), 2);
    expect(written.undo().source, 'abk');
  });

  test(
    'the frozen window follows every admitted change and keeps the cell',
    () {
      final String source = List<String>.filled(300, '${'b' * 99}\n').join();
      final EditorState state = _state(source, 10000);
      const InputWindow window = InputWindow(start: 5000, end: 15000);
      const ActiveLine cell = ActiveLine(line: 2, cell: 1);
      final Transaction insert = _ime(
        30000,
        4000,
        4000,
        'yy',
        4002,
        const MdRange(4000, 4002),
      );
      final _Admitted first = _admit(
        state,
        const NoteComposition.idle(),
        insert,
        activeLine: cell,
        window: window,
      );
      final InputWindow afterFirst = window.mapThrough(insert.changes);
      expect(first.composition.window, afterFirst);
      expect(afterFirst, const InputWindow(start: 5002, end: 15002));
      final Transaction grow = _ime(
        30002,
        4002,
        4002,
        'z',
        4003,
        const MdRange(4000, 4003),
      );
      final _Admitted second = _admit(
        first.state,
        first.composition,
        grow,
        activeLine: const ActiveLine(line: 7),
        window: const InputWindow(start: 0, end: 1),
      );
      expect(second.composition.window, afterFirst.mapThrough(grow.changes));
      expect(second.composition.activeLine, cell);
      expect(second.composition.net, insert.changes.compose(grow.changes));
      expect(second.composition.range, const MdRange(4000, 4003));
      expect(second.composition.sourceBefore, source);
    },
  );

  test('selectionLeavesComposition is false when idle', () {
    expect(
      selectionLeavesComposition(
        const NoteComposition.idle(),
        const NoteSelection.collapsed(100),
      ),
      isFalse,
    );
    expect(const NoteComposition.idle().range, isNull);
    expect(const NoteComposition.idle().net, isNull);
    expect(const NoteComposition.idle().window, isNull);
  });
}
