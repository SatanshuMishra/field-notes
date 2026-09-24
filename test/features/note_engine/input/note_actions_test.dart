import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/input/command_registry.dart';
import 'package:field_notes/features/note_engine/input/note_actions.dart';
import 'package:field_notes/features/note_engine/input/note_shortcuts.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/projection/active_line.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const NoteVisibleProjector _projector = NoteVisibleProjector();

const double _lineHeight = 20;
const double _glyphWidth = 10;
const int _lineUnits = 10;

final RegExp _wordUnit = RegExp(r'[A-Za-z0-9]');

typedef _VerticalCall = ({
  int position,
  TextAffinity affinity,
  double goalX,
  VerticalMove direction,
});

final class _FakeRegistry implements CommandRegistry {
  final Map<String, NoteCommand> commands = <String, NoteCommand>{};

  @override
  NoteCommand? commandFor(String id) => commands[id];
}

final class _FakeLayout implements NoteLayout {
  _FakeLayout(this.host);

  final _FakeHost host;

  String get _source => host.state.source;

  int get _lastLine => _source.length ~/ _lineUnits;

  @override
  LayoutInputs get inputs {
    final EditorState state = host.state;
    final VisibleText visible = host.visible;
    return LayoutInputs(
      source: state.source,
      tree: state.tree,
      visibleText: visible,
      activeLine: visible.activeLine,
      columnWidth: 90,
      textScaler: TextScaler.noScaling,
      boldText: false,
      locale: const Locale('en'),
      readerMode: false,
      mediaDimensions: const <String, Size>{},
    );
  }

  @override
  Rect caretRect(int position, TextAffinity affinity) => Rect.fromLTWH(
    (position % _lineUnits) * _glyphWidth,
    (position ~/ _lineUnits) * _lineHeight,
    2,
    _lineHeight,
  );

  @override
  TextPosition positionAt(Offset point) {
    final int line = (point.dy / _lineHeight).floor().clamp(0, _lastLine);
    final int column = (point.dx / _glyphWidth).round().clamp(0, 9);
    final int offset = line * _lineUnits + column;
    return TextPosition(
      offset: offset > _source.length ? _source.length : offset,
    );
  }

  @override
  TextPosition verticalTarget(
    int position,
    TextAffinity affinity,
    double goalX,
    VerticalMove direction,
  ) {
    host.verticalCalls.add((
      position: position,
      affinity: affinity,
      goalX: goalX,
      direction: direction,
    ));
    if (host.verticalAnswers.isNotEmpty) {
      return host.verticalAnswers.removeAt(0);
    }
    final int line =
        position ~/ _lineUnits + (direction == VerticalMove.down ? 1 : -1);
    if (line < 0) {
      return const TextPosition(offset: 0);
    }
    if (line > _lastLine) {
      return TextPosition(offset: _source.length);
    }
    return positionAt(Offset(goalX, line * _lineHeight + _lineHeight / 2));
  }

  @override
  MdRange wordBoundary(int position) {
    final String source = _source;
    int start = position;
    while (start > 0 && _wordUnit.hasMatch(source[start - 1])) {
      start--;
    }
    int end = position;
    while (end < source.length && _wordUnit.hasMatch(source[end])) {
      end++;
    }
    return MdRange(start, end);
  }

  @override
  MdRange lineBoundary(int position, TextAffinity affinity) {
    final int line =
        affinity == TextAffinity.upstream &&
            position > 0 &&
            position % _lineUnits == 0
        ? position ~/ _lineUnits - 1
        : position ~/ _lineUnits;
    final int start = line * _lineUnits;
    final int end = start + _lineUnits - 1;
    return MdRange(start, end > _source.length ? _source.length : end);
  }

  @override
  MdRange paragraphBoundary(int position) {
    final String source = _source;
    int start = position;
    while (start > 0 && source[start - 1] != '\n') {
      start--;
    }
    int end = position;
    while (end < source.length && source[end] != '\n') {
      end++;
    }
    return MdRange(start, end);
  }

  @override
  MdRange get documentBoundary => MdRange(0, _source.length);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeHost implements NoteActionHost {
  _FakeHost(
    String source, {
    NoteSelection selection = const NoteSelection.collapsed(0),
  }) : _state = EditorState.create(
         source,
         parse: parseNoteTree,
         selection: selection,
       );

  EditorState _state;
  final _FakeRegistry registry = _FakeRegistry();
  final List<Transaction> applied = <Transaction>[];
  final List<NoteSelection> selections = <NoteSelection>[];
  final List<double> scrolls = <double>[];
  final List<bool> edges = <bool>[];
  final List<_VerticalCall> verticalCalls = <_VerticalCall>[];
  final List<TextPosition> verticalAnswers = <TextPosition>[];
  bool dismissible = false;
  bool toolbarTakesFocus = false;
  int dismissals = 0;
  int undos = 0;
  int redos = 0;
  int pastes = 0;
  int toolbarRequests = 0;
  final List<bool> copies = <bool>[];

  @override
  EditorState get state => _state;

  set state(EditorState next) => _state = next;

  void reset(String source, NoteSelection selection) {
    _state = EditorState.create(
      source,
      parse: parseNoteTree,
      selection: selection,
    );
  }

  void compose(MdRange range) {
    _state = _state.apply(
      Transaction(
        changes: ChangeSet.empty(_state.source.length),
        selection: _state.selection,
        event: TransactionEvent.inputIme,
        addToHistory: false,
        composing: range,
      ),
    );
  }

  bool get recordedNothing =>
      applied.isEmpty &&
      selections.isEmpty &&
      scrolls.isEmpty &&
      edges.isEmpty &&
      dismissals == 0;

  @override
  VisibleText get visible {
    final ActiveLine active = activeLineAt(
      _state.source,
      _state.tree,
      _state.selection,
    );
    return _projector.project(
      _state.source,
      _state.tree,
      active.line,
      activeCell: active.cell,
    );
  }

  @override
  NoteLayout get layout => _FakeLayout(this);

  @override
  CommandRegistry get commands => registry;

  @override
  double get viewportHeight => 100;

  @override
  bool get canDismiss => dismissible;

  @override
  void apply(Transaction transaction) {
    applied.add(transaction);
    _state = _state.apply(transaction);
  }

  @override
  void select(NoteSelection selection, SelectionChangedCause cause) {
    selections.add(selection);
    _state = _state.withSelection(selection);
  }

  @override
  void scrollBy(double pixels) {
    scrolls.add(pixels);
  }

  @override
  void scrollToEdge({required bool end}) {
    edges.add(end);
  }

  @override
  void copy({required bool cut}) {
    copies.add(cut);
  }

  @override
  Future<void> paste() async {
    pastes++;
  }

  @override
  void undo() {
    undos++;
  }

  @override
  void redo() {
    redos++;
  }

  @override
  void dismiss() {
    dismissals++;
  }

  @override
  bool focusPhotoToolbar() {
    toolbarRequests++;
    return toolbarTakesFocus;
  }
}

final class _Harness {
  _Harness(this.host);

  final _FakeHost host;
  final FocusNode editorNode = FocusNode(debugLabel: 'editor');
  final FocusNode siblingNode = FocusNode(debugLabel: 'sibling');
  late BuildContext editorContext;
  int saves = 0;
  int cancels = 0;
}

bool get _apple => defaultTargetPlatform == TargetPlatform.macOS;

LogicalKeyboardKey get _modifierKey =>
    _apple ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft;

Future<_Harness> _pump(
  WidgetTester tester,
  String source, {
  NoteSelection selection = const NoteSelection.collapsed(0),
}) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _Harness harness = _Harness(_FakeHost(source, selection: selection));
  addTearDown(harness.editorNode.dispose);
  addTearDown(harness.siblingNode.dispose);
  final bool apple = _apple;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            SingleActivator(
              LogicalKeyboardKey.enter,
              meta: apple,
              control: !apple,
            ): () =>
                harness.saves++,
            SingleActivator(
              LogicalKeyboardKey.numpadEnter,
              meta: apple,
              control: !apple,
            ): () =>
                harness.saves++,
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                harness.cancels++,
          },
          child: Column(
            children: <Widget>[
              NoteKeyboardScope(
                host: harness.host,
                child: Focus(
                  autofocus: true,
                  focusNode: harness.editorNode,
                  child: Builder(
                    builder: (BuildContext context) {
                      harness.editorContext = context;
                      return const SizedBox(width: 600, height: 400);
                    },
                  ),
                ),
              ),
              Focus(
                focusNode: harness.siblingNode,
                child: const SizedBox(width: 10, height: 10),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return harness;
}

Future<bool> _chord(
  WidgetTester tester,
  List<LogicalKeyboardKey> modifiers,
  LogicalKeyboardKey key,
) async {
  for (final LogicalKeyboardKey modifier in modifiers) {
    await tester.sendKeyDownEvent(modifier);
  }
  final bool handled = await tester.sendKeyEvent(key);
  for (final LogicalKeyboardKey modifier in modifiers.reversed) {
    await tester.sendKeyUpEvent(modifier);
  }
  return handled;
}

Future<BuildContext> _mount(WidgetTester tester, NoteActions actions) async {
  late BuildContext captured;
  await tester.pumpWidget(
    Actions(
      actions: actions.actions,
      child: Builder(
        builder: (BuildContext context) {
          captured = context;
          return const SizedBox();
        },
      ),
    ),
  );
  return captured;
}

Transaction _marker(EditorState state, int caret) => Transaction(
  changes: ChangeSet.empty(state.source.length),
  selection: NoteSelection.collapsed(caret),
  event: TransactionEvent.format,
  addToHistory: false,
);

const String _photoNote = 'A\n![p](photo/abc123abc123)\nB';

const List<String> _macOSSelectors = <String>[
  'deleteBackward:',
  'deleteWordBackward:',
  'deleteToBeginningOfLine:',
  'deleteForward:',
  'deleteWordForward:',
  'deleteToEndOfLine:',
  'moveLeft:',
  'moveRight:',
  'moveForward:',
  'moveBackward:',
  'moveUp:',
  'moveDown:',
  'moveLeftAndModifySelection:',
  'moveRightAndModifySelection:',
  'moveUpAndModifySelection:',
  'moveDownAndModifySelection:',
  'moveWordLeft:',
  'moveWordRight:',
  'moveToBeginningOfParagraph:',
  'moveToEndOfParagraph:',
  'moveWordLeftAndModifySelection:',
  'moveWordRightAndModifySelection:',
  'moveParagraphBackwardAndModifySelection:',
  'moveParagraphForwardAndModifySelection:',
  'moveToLeftEndOfLine:',
  'moveToRightEndOfLine:',
  'moveToBeginningOfDocument:',
  'moveToEndOfDocument:',
  'moveToLeftEndOfLineAndModifySelection:',
  'moveToRightEndOfLineAndModifySelection:',
  'moveToBeginningOfDocumentAndModifySelection:',
  'moveToEndOfDocumentAndModifySelection:',
  'transpose:',
  'scrollToBeginningOfDocument:',
  'scrollToEndOfDocument:',
  'scrollPageUp:',
  'scrollPageDown:',
  'pageUpAndModifySelection:',
  'pageDownAndModifySelection:',
  'cancelOperation:',
  'insertTab:',
  'insertBacktab:',
];

void main() {
  testWidgets(
    'text intents pass through to the input method',
    (WidgetTester tester) async {
      final _Harness harness = await _pump(
        tester,
        'alpha beta\ngamma',
        selection: const NoteSelection.collapsed(3),
      );
      for (final LogicalKeyboardKey key in <LogicalKeyboardKey>[
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.backspace,
        LogicalKeyboardKey.delete,
        LogicalKeyboardKey.tab,
        LogicalKeyboardKey.home,
        LogicalKeyboardKey.end,
        LogicalKeyboardKey.pageUp,
        LogicalKeyboardKey.pageDown,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.enter,
      ]) {
        expect(await tester.sendKeyEvent(key), isFalse, reason: '$key');
      }
      expect(harness.host.recordedNothing, isTrue);
      expect(harness.saves, 0);
      expect(harness.cancels, 0);
      final Action<Intent>? doNothing = Actions.maybeFind<Intent>(
        harness.editorContext,
        intent: const DoNothingAndStopPropagationTextIntent(),
      );
      expect(doNothing, isA<DoNothingAction>());
      expect(
        doNothing!.consumesKey(const DoNothingAndStopPropagationTextIntent()),
        isFalse,
      );

      harness.host.registry.commands[NoteCommandId.lineBreak] =
          (EditorState state) => _marker(state, 0);
      harness.host.compose(const MdRange(0, 5));
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.escape), isFalse);
      expect(harness.cancels, 0);
      expect(
        await _chord(tester, <LogicalKeyboardKey>[
          LogicalKeyboardKey.shiftLeft,
        ], LogicalKeyboardKey.enter),
        isFalse,
      );
      expect(harness.host.applied, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'the editor never consumes command enter or numpad enter',
    (WidgetTester tester) async {
      final _Harness harness = await _pump(
        tester,
        'alpha beta',
        selection: const NoteSelection.collapsed(3),
      );
      for (final String id in NoteCommandId.shortcutIds) {
        harness.host.registry.commands[id] = (EditorState state) =>
            _marker(state, 1);
      }
      await _chord(tester, <LogicalKeyboardKey>[
        _modifierKey,
      ], LogicalKeyboardKey.enter);
      await _chord(tester, <LogicalKeyboardKey>[
        _modifierKey,
      ], LogicalKeyboardKey.numpadEnter);
      expect(harness.saves, 2);
      expect(harness.host.recordedNothing, isTrue);

      harness.host.compose(const MdRange(0, 5));
      await _chord(tester, <LogicalKeyboardKey>[
        _modifierKey,
      ], LogicalKeyboardKey.enter);
      await _chord(tester, <LogicalKeyboardKey>[
        _modifierKey,
      ], LogicalKeyboardKey.numpadEnter);
      expect(harness.saves, 4);
      expect(harness.host.recordedNothing, isTrue);

      harness.host.reset('alpha beta', const NoteSelection.collapsed(3));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(harness.cancels, 1);
      expect(harness.host.dismissals, 0);

      harness.host.dismissible = true;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(harness.host.dismissals, 1);
      expect(harness.cancels, 1);
    },
    variant: TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.macOS,
      TargetPlatform.android,
    }),
  );

  testWidgets('every macos selector maps to an enabled action', (
    WidgetTester tester,
  ) async {
    const String source = 'alpha beta\ngamma';
    const NoteSelection caret = NoteSelection.collapsed(3);
    final _Harness harness = await _pump(tester, source, selection: caret);
    expect(_macOSSelectors, hasLength(42));
    for (final String name in _macOSSelectors) {
      harness.host.reset(source, caret);
      harness.editorNode.requestFocus();
      await tester.pump();
      final Intent? intent = intentForMacOSSelector(name);
      expect(intent, isNotNull, reason: name);
      final Action<Intent>? action = Actions.maybeFind<Intent>(
        harness.editorContext,
        intent: intent,
      );
      expect(action, isNotNull, reason: name);
      expect(action!.isEnabled(intent!), isTrue, reason: name);
      invokeMacOSSelector(harness.editorContext, name);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: name);
    }

    harness.host.reset(source, caret);
    harness.editorNode.requestFocus();
    await tester.pump();
    harness.host.applied.clear();
    harness.host.selections.clear();
    invokeMacOSSelector(harness.editorContext, 'noSuchSelector:');
    invokeMacOSSelector(
      harness.editorContext,
      'deleteBackwardByDecomposingPreviousCharacter:',
    );
    expect(tester.takeException(), isNull);
    expect(harness.host.applied, isEmpty);
    expect(harness.host.selections, isEmpty);
    expect(harness.host.state.source, source);
    expect(harness.host.state.selection, caret);
  });

  testWidgets('deletions cover whole grapheme clusters', (
    WidgetTester tester,
  ) async {
    const String family = 'ab\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}';
    const String flag = '\u{1F1EF}\u{1F1F5}x';
    const String accent = 'e\u{0301}f';
    final _Harness harness = await _pump(
      tester,
      family,
      selection: const NoteSelection.collapsed(10),
    );

    Future<void> check(
      String source,
      int caret, {
      required bool forward,
      required String result,
      required bool bySelector,
    }) async {
      harness.host.reset(source, NoteSelection.collapsed(caret));
      harness.host.applied.clear();
      if (bySelector) {
        invokeMacOSSelector(
          harness.editorContext,
          forward ? 'deleteForward:' : 'deleteBackward:',
        );
      } else {
        Actions.invoke(
          harness.editorContext,
          DeleteCharacterIntent(forward: forward),
        );
      }
      await tester.pump();
      expect(harness.host.state.source, result, reason: source);
      expect(harness.host.applied, hasLength(1));
      expect(harness.host.applied.single.event, TransactionEvent.inputDelete);
    }

    for (final bool bySelector in <bool>[false, true]) {
      await check(
        family,
        10,
        forward: false,
        result: 'ab',
        bySelector: bySelector,
      );
      expect(
        harness.host.applied.single.changes.replacements,
        const <TextReplacement>[TextReplacement(2, 10, '')],
      );
      await check(flag, 0, forward: true, result: 'x', bySelector: bySelector);
      await check(
        accent,
        2,
        forward: false,
        result: 'f',
        bySelector: bySelector,
      );
    }

    harness.host.reset(family, const NoteSelection.collapsed(10));
    harness.host.applied.clear();
    harness.host.registry.commands[NoteCommandId.deleteBackward] =
        (EditorState state) => Transaction(
          changes: ChangeSet.single(state.source.length, 0, 1, ''),
          selection: const NoteSelection.collapsed(0),
          event: TransactionEvent.list,
        );
    Actions.invoke(
      harness.editorContext,
      const DeleteCharacterIntent(forward: false),
    );
    expect(harness.host.applied.single.event, TransactionEvent.list);
    expect(
      harness.host.state.source,
      'b\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}',
    );
    harness.host.registry.commands.remove(NoteCommandId.deleteBackward);

    harness.host.reset('hello world', const NoteSelection(anchor: 2, head: 7));
    harness.host.applied.clear();
    Actions.invoke(
      harness.editorContext,
      const DeleteCharacterIntent(forward: false),
    );
    expect(
      harness.host.applied.single.changes.replacements,
      const <TextReplacement>[TextReplacement(2, 7, '')],
    );
    expect(harness.host.state.source, 'heorld');
  });

  testWidgets(
    'page keys follow each platform',
    (WidgetTester tester) async {
      final String source = List<String>.filled(20, 'abcdefghi').join('\n');
      const NoteSelection caret = NoteSelection.collapsed(23);
      final _Harness harness = await _pump(tester, source, selection: caret);
      if (defaultTargetPlatform == TargetPlatform.android) {
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        expect(harness.host.state.selection.head, 73);
        expect(harness.host.state.selection.isCollapsed, isTrue);

        harness.host.reset(source, caret);
        await _chord(tester, <LogicalKeyboardKey>[
          LogicalKeyboardKey.shiftLeft,
        ], LogicalKeyboardKey.pageDown);
        expect(harness.host.state.selection.anchor, 23);
        expect(harness.host.state.selection.head, 73);

        harness.host.reset(source, caret);
        await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
        expect(harness.host.state.selection, const NoteSelection.collapsed(0));
        return;
      }
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.pageDown), isFalse);
      expect(harness.host.recordedNothing, isTrue);

      invokeMacOSSelector(harness.editorContext, 'scrollPageDown:');
      expect(harness.host.scrolls, <double>[100]);
      expect(harness.host.state.selection, caret);

      invokeMacOSSelector(harness.editorContext, 'pageDownAndModifySelection:');
      expect(harness.host.state.selection.anchor, 23);
      expect(harness.host.state.selection.head, 73);
    },
    variant: TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.macOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'each C3 shortcut runs its command, and none while composing',
    (WidgetTester tester) async {
      final _Harness harness = await _pump(
        tester,
        'abcdefghijklmnop',
        selection: const NoteSelection.collapsed(0),
      );
      for (int i = 0; i < NoteCommandId.shortcutIds.length; i++) {
        final int marker = i + 1;
        harness.host.registry.commands[NoteCommandId.shortcutIds[i]] =
            (EditorState state) => _marker(state, marker);
      }
      final List<(bool, LogicalKeyboardKey)> keys =
          <(bool, LogicalKeyboardKey)>[
            (false, LogicalKeyboardKey.keyB),
            (false, LogicalKeyboardKey.keyI),
            (false, LogicalKeyboardKey.keyK),
            (true, LogicalKeyboardKey.keyX),
            (true, LogicalKeyboardKey.keyH),
            (false, LogicalKeyboardKey.keyE),
            (true, LogicalKeyboardKey.digit7),
            (true, LogicalKeyboardKey.digit8),
            (true, LogicalKeyboardKey.digit9),
            (false, LogicalKeyboardKey.keyL),
          ];
      Future<void> pressAll() async {
        for (final (bool shift, LogicalKeyboardKey key) in keys) {
          await _chord(tester, <LogicalKeyboardKey>[
            _modifierKey,
            if (shift) LogicalKeyboardKey.shiftLeft,
          ], key);
        }
      }

      await pressAll();
      expect(
        <int>[
          for (final Transaction transaction in harness.host.applied)
            transaction.selection.head,
        ],
        <int>[for (int i = 1; i <= 10; i++) i],
      );

      harness.host.applied.clear();
      harness.host.compose(const MdRange(0, 3));
      await pressAll();
      expect(harness.host.applied, isEmpty);
    },
    variant: TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.macOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'control y redoes on android',
    (WidgetTester tester) async {
      final _Harness harness = await _pump(tester, 'hello');
      await _chord(tester, <LogicalKeyboardKey>[
        LogicalKeyboardKey.controlLeft,
      ], LogicalKeyboardKey.keyY);
      expect(harness.host.redos, 1);
      expect(
        noteShortcuts(TargetPlatform.macOS).values,
        isNot(contains(isA<RedoTextIntent>())),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('shift enter applies the line break command', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pump(
      tester,
      'hello',
      selection: const NoteSelection.collapsed(5),
    );
    harness.host.registry.commands[NoteCommandId.lineBreak] =
        (EditorState state) => Transaction(
          changes: ChangeSet.single(state.source.length, 5, 5, '\n'),
          selection: const NoteSelection.collapsed(6),
          event: TransactionEvent.inputType,
        );
    await _chord(tester, <LogicalKeyboardKey>[
      LogicalKeyboardKey.shiftLeft,
    ], LogicalKeyboardKey.enter);
    expect(harness.host.state.source, 'hello\n');
    await _chord(tester, <LogicalKeyboardKey>[
      LogicalKeyboardKey.shiftLeft,
    ], LogicalKeyboardKey.numpadEnter);
    expect(harness.host.applied, hasLength(2));
  });

  testWidgets(
    'tab indents, enters the photo toolbar, or moves focus',
    (WidgetTester tester) async {
      final _Harness harness = await _pump(
        tester,
        '- a\n- b',
        selection: const NoteSelection.collapsed(7),
      );
      harness.host.registry.commands[NoteCommandId.indent] =
          (EditorState state) => Transaction(
            changes: ChangeSet.single(state.source.length, 4, 4, '  '),
            selection: const NoteSelection.collapsed(9),
            event: TransactionEvent.list,
          );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(harness.host.state.source, '- a\n  - b');
      expect(harness.editorNode.hasPrimaryFocus, isTrue);
      harness.host.registry.commands.remove(NoteCommandId.indent);

      harness.host.reset(_photoNote, const NoteSelection(anchor: 2, head: 26));
      harness.host.toolbarTakesFocus = true;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(harness.host.toolbarRequests, 1);
      expect(harness.editorNode.hasPrimaryFocus, isTrue);

      harness.host.toolbarTakesFocus = false;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(harness.host.toolbarRequests, 2);
      expect(harness.siblingNode.hasPrimaryFocus, isTrue);

      harness.editorNode.requestFocus();
      await tester.pump();
      harness.host.reset('plain', const NoteSelection.collapsed(2));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(harness.host.toolbarRequests, 2);
      expect(harness.siblingNode.hasPrimaryFocus, isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('horizontal moves select a photo and then cross it', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pump(
      tester,
      _photoNote,
      selection: const NoteSelection.collapsed(1),
    );
    const Intent right = ExtendSelectionByCharacterIntent(
      forward: true,
      collapseSelection: true,
    );
    const Intent left = ExtendSelectionByCharacterIntent(
      forward: false,
      collapseSelection: true,
    );
    Actions.invoke(harness.editorContext, right);
    expect(
      harness.host.state.selection,
      const NoteSelection(anchor: 2, head: 26),
    );
    Actions.invoke(harness.editorContext, right);
    expect(harness.host.state.selection, const NoteSelection.collapsed(27));
    Actions.invoke(harness.editorContext, left);
    expect(
      harness.host.state.selection,
      const NoteSelection(anchor: 2, head: 26),
    );
    Actions.invoke(harness.editorContext, left);
    expect(harness.host.state.selection, const NoteSelection.collapsed(1));
    expect(harness.host.applied, isEmpty);
  });

  testWidgets('a selection-only registry delete is applied as given', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pump(
      tester,
      _photoNote,
      selection: const NoteSelection.collapsed(27),
    );
    harness.host.registry.commands[NoteCommandId.deleteBackward] =
        (EditorState state) => Transaction(
          changes: ChangeSet.empty(state.source.length),
          selection: const NoteSelection(anchor: 2, head: 26),
          event: TransactionEvent.photo,
          addToHistory: false,
        );
    Actions.invoke(
      harness.editorContext,
      const DeleteCharacterIntent(forward: false),
    );
    expect(harness.host.applied, hasLength(1));
    expect(harness.host.applied.single.changes.isEmpty, isTrue);
    expect(harness.host.state.source, _photoNote);
    expect(
      harness.host.state.selection,
      const NoteSelection(anchor: 2, head: 26),
    );
  });

  testWidgets('down keeps the goal x across a run and resets it', (
    WidgetTester tester,
  ) async {
    final _FakeHost host = _FakeHost(
      List<String>.filled(6, 'abcdefghi').join('\n'),
      selection: const NoteSelection.collapsed(5),
    );
    final NoteActions actions = NoteActions(host: host);
    final BuildContext context = await _mount(tester, actions);
    const Intent down = ExtendSelectionVerticallyToAdjacentLineIntent(
      forward: true,
      collapseSelection: true,
    );
    host.verticalAnswers.add(const TextPosition(offset: 12));
    Actions.invoke(context, down);
    expect(host.state.selection, const NoteSelection.collapsed(12));
    Actions.invoke(context, down);
    expect(host.verticalCalls.map((_VerticalCall call) => call.goalX), <double>[
      50,
      50,
    ]);
    expect(host.verticalCalls.last.position, 12);

    host.verticalAnswers.add(const TextPosition(offset: 33));
    Actions.invoke(context, down);
    final int length = host.state.source.length;
    host.apply(
      Transaction(
        changes: ChangeSet.single(length, length, length, 'z'),
        selection: host.state.selection,
        event: TransactionEvent.inputType,
      ),
    );
    Actions.invoke(context, down);
    expect(host.verticalCalls.last.goalX, 30);

    host.verticalAnswers.add(const TextPosition(offset: 51));
    Actions.invoke(context, down);
    actions.resetVerticalRun();
    Actions.invoke(context, down);
    expect(host.verticalCalls.last.goalX, 10);
  });

  testWidgets('down passes the head affinity to the layout', (
    WidgetTester tester,
  ) async {
    final _FakeHost host = _FakeHost(
      List<String>.filled(3, 'abcdefghi').join('\n'),
      selection: const NoteSelection.collapsed(
        10,
        affinity: TextAffinity.upstream,
      ),
    );
    Actions.invoke(
      await _mount(tester, NoteActions(host: host)),
      const ExtendSelectionVerticallyToAdjacentLineIntent(
        forward: true,
        collapseSelection: true,
      ),
    );
    expect(host.verticalCalls.single.affinity, TextAffinity.upstream);
  });

  testWidgets('down through a photo keeps a collapsed caret and the goal', (
    WidgetTester tester,
  ) async {
    final _FakeHost host = _FakeHost(
      _photoNote,
      selection: const NoteSelection.collapsed(1),
    );
    final NoteActions actions = NoteActions(host: host);
    final BuildContext context = await _mount(tester, actions);
    const Intent down = ExtendSelectionVerticallyToAdjacentLineIntent(
      forward: true,
      collapseSelection: true,
    );
    host.verticalAnswers.addAll(const <TextPosition>[
      TextPosition(offset: 2),
      TextPosition(offset: 27),
    ]);
    Actions.invoke(context, down);
    expect(host.state.selection, const NoteSelection.collapsed(2));
    Actions.invoke(context, down);
    expect(host.verticalCalls[1].goalX, host.verticalCalls[0].goalX);
    expect(host.verticalCalls[0].goalX, 10);
    expect(host.verticalCalls[1].position, 2);
  });

  testWidgets(
    'a collapsed backspace over a table cell separator changes nothing',
    (WidgetTester tester) async {
      const String table = '| a | b |\n| --- | --- |\n| c | d |';
      final int caret = table.lastIndexOf('d');
      final _FakeHost host = _FakeHost(
        table,
        selection: NoteSelection.collapsed(caret),
      );
      final VisibleText visible = host.visible;
      final int visibleCaret = visible.map.sourceToVisible(caret);
      expect(visible.text[visibleCaret - 1], '\t');
      Actions.invoke(
        await _mount(tester, NoteActions(host: host)),
        const DeleteCharacterIntent(forward: false),
      );
      expect(host.applied, isEmpty);
      expect(host.state.source, table);
    },
  );

  testWidgets(
    'option backspace across a line break removes a hidden node whole',
    (WidgetTester tester) async {
      const String source = 'The **fog**\nnext';
      final _FakeHost host = _FakeHost(
        source,
        selection: NoteSelection.collapsed(source.indexOf('next')),
      );
      expect(host.visible.text, 'The fog\nnext');
      Actions.invoke(
        await _mount(tester, NoteActions(host: host)),
        const DeleteToNextWordBoundaryIntent(forward: false),
      );
      expect(host.state.source, 'The next');
      expect(host.state.selection, const NoteSelection.collapsed(4));
      expect(host.applied.single.event, TransactionEvent.inputDelete);
    },
  );

  testWidgets('option delete across a line break removes a hidden link whole', (
    WidgetTester tester,
  ) async {
    final _FakeHost host = _FakeHost(
      'a\n[site](https://x.y) b',
      selection: const NoteSelection.collapsed(1),
    );
    expect(host.visible.text, 'a\nsite b');
    Actions.invoke(
      await _mount(tester, NoteActions(host: host)),
      const DeleteToNextWordBoundaryIntent(forward: true),
    );
    expect(host.state.source, 'a b');
    expect(host.state.selection, const NoteSelection.collapsed(1));
    expect(host.applied.single.event, TransactionEvent.inputDelete);
  });

  testWidgets('word and line deletes in a table cell stay inside that cell', (
    WidgetTester tester,
  ) async {
    const String table = '| ab | cd |\n| - | - |';
    final int cell = table.indexOf('cd');
    final _FakeHost host = _FakeHost(
      table,
      selection: NoteSelection.collapsed(cell),
    );
    final BuildContext context = await _mount(tester, NoteActions(host: host));
    expect(host.visible.text, 'ab\tcd');
    Actions.invoke(
      context,
      const DeleteToNextWordBoundaryIntent(forward: false),
    );
    expect(host.applied, isEmpty);
    expect(host.state.source, table);

    host.reset(table, NoteSelection.collapsed(cell + 2));
    Actions.invoke(context, const DeleteToLineBreakIntent(forward: false));
    expect(host.state.source, '| ab |  |\n| - | - |');
    expect(host.state.selection, NoteSelection.collapsed(cell));
  });

  testWidgets('option backspace below a table keeps its hidden markup', (
    WidgetTester tester,
  ) async {
    const String source = '| a | b |\n| - | - |\n\nnext';
    final _FakeHost host = _FakeHost(
      source,
      selection: NoteSelection.collapsed(source.indexOf('next')),
    );
    expect(host.visible.text, 'a\tb\n\nnext');
    Actions.invoke(
      await _mount(tester, NoteActions(host: host)),
      const DeleteToNextWordBoundaryIntent(forward: false),
    );
    expect(host.state.source, '| a |  |\n| - | - |next');
    expect(host.state.selection, const NoteSelection.collapsed(6));
    expect(host.applied.single.event, TransactionEvent.inputDelete);
  });

  testWidgets(
    'every default text editing intent has an enabled action',
    (WidgetTester tester) async {
      final _Harness harness = await _pump(
        tester,
        'alpha beta\ngamma',
        selection: const NoteSelection.collapsed(3),
      );
      final Iterable<Shortcuts> shortcuts = tester.widgetList<Shortcuts>(
        find.descendant(
          of: find.byType(DefaultTextEditingShortcuts),
          matching: find.byType(Shortcuts),
        ),
      );
      final Set<Intent> intents = <Intent>{
        for (final Shortcuts widget in shortcuts)
          if (widget.debugLabel?.contains('Text Editing') ?? false)
            ...widget.shortcuts.values,
      };
      expect(intents, isNotEmpty);
      for (final Intent intent in intents) {
        final Action<Intent>? action = Actions.maybeFind<Intent>(
          harness.editorContext,
          intent: intent,
        );
        expect(action, isNotNull, reason: '$intent');
        expect(action!.isEnabled(intent), isTrue, reason: '$intent');
      }
    },
    variant: TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.macOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'tap outside unfocuses on macos and not for touch on android',
    (WidgetTester tester) async {
      final _Harness harness = await _pump(tester, 'hello');
      expect(harness.editorNode.hasFocus, isTrue);
      Actions.invoke(
        harness.editorContext,
        EditableTextTapOutsideIntent(
          focusNode: harness.editorNode,
          pointerDownEvent: const PointerDownEvent(
            kind: PointerDeviceKind.touch,
          ),
        ),
      );
      await tester.pump();
      expect(
        harness.editorNode.hasFocus,
        defaultTargetPlatform == TargetPlatform.android,
      );
    },
    variant: TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.macOS,
      TargetPlatform.android,
    }),
  );
}
