import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/gestures/clipboard_actions.dart';

const String _p = '![p](photo/abc123abc123)';
const String _pl = '![Low tide](photo/4fef9c2c3c9a "left medium")';

EditorState _state(String source, int anchor, [int? head]) =>
    EditorState.create(
      source,
      parse: parseNoteTree,
      selection: NoteSelection(anchor: anchor, head: head ?? anchor),
    );

void _pinSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

final class _Clipboard {
  _Clipboard(WidgetTester tester, {this.contents}) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      _handle,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

  final String? contents;
  final List<String> written = <String>[];
  int reads = 0;

  Future<Object?> _handle(MethodCall call) async {
    switch (call.method) {
      case 'Clipboard.setData':
        final Map<Object?, Object?> arguments =
            call.arguments as Map<Object?, Object?>;
        written.add(arguments['text']! as String);
        return null;
      case 'Clipboard.getData':
        reads += 1;
        final String? text = contents;
        return text == null ? null : <String, Object?>{'text': text};
    }
    return null;
  }
}

final class _Host {
  _Host(
    EditorState initial, {
    bool active = true,
    Transaction? Function(EditorState state)? cutPhoto,
  }) : _current = initial {
    actions = NoteClipboardActions(
      state: () => _current,
      dispatch: (Transaction transaction) {
        dispatched.add(transaction);
        _current = _current.apply(transaction);
      },
      select: (NoteSelection selection, SelectionChangedCause cause) =>
          selected.add((selection, cause)),
      hideToolbar: ([bool hideHandles = true]) => hidden.add(hideHandles),
      bringIntoView: revealed.add,
      isActive: () => active,
      cutPhoto: cutPhoto,
    );
  }

  EditorState _current;
  late final NoteClipboardActions actions;
  final List<Transaction> dispatched = <Transaction>[];
  final List<(NoteSelection, SelectionChangedCause)> selected =
      <(NoteSelection, SelectionChangedCause)>[];
  final List<bool> hidden = <bool>[];
  final List<int> revealed = <int>[];

  EditorState get current => _current;
}

void _expectPaste(
  String source,
  int caret,
  String text,
  String expected,
  int caretAfter,
) {
  final Transaction? transaction = notePasteTransaction(
    _state(source, caret),
    text,
  );
  expect(transaction, isNotNull);
  expect(transaction!.changes.apply(source), expected);
  expect(transaction.selection, NoteSelection.collapsed(caretAfter));
  expect(transaction.event, TransactionEvent.inputPaste);
  expect(transaction.addToHistory, isTrue);
  expect(transaction.composing, isNull);
}

void main() {
  testWidgets('copy writes the source markdown of the selection', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    const String source = '# Harbour day\nThe **fog** lifted';
    final _Clipboard clipboard = _Clipboard(tester);

    await _Host(
      _state(source, 14, 32),
    ).actions.copySelection(SelectionChangedCause.keyboard);
    await _Host(
      _state(source, 18, 25),
    ).actions.copySelection(SelectionChangedCause.keyboard);
    await _Host(
      _state('A\n$_pl\nB', 5),
    ).actions.copySelection(SelectionChangedCause.keyboard);
    expect(clipboard.written, <String>['The **fog** lifted', '**fog**', _pl]);

    await _Host(
      _state(source, 3),
    ).actions.copySelection(SelectionChangedCause.keyboard);
    expect(clipboard.written, hasLength(3));

    final _Host host = _Host(_state(source, 18, 25));
    await host.actions.copySelection(SelectionChangedCause.keyboard);
    expect(host.hidden, isEmpty);
    expect(host.selected, isEmpty);
  });

  test('a pasted photo line moves to the boundary after its block', () {
    _expectPaste(
      'The tide came in.\n\nLater.',
      8,
      _pl,
      'The tide came in.\n$_pl\n\nLater.',
      8,
    );
    _expectPaste('XY', 1, 'a\n$_p\nb', 'Xa\nbY\n$_p', 4);
    _expectPaste(
      'One\r\ntwo\r\n\r\nNext',
      3,
      _p,
      'One\r\ntwo\r\n$_p\r\n\r\nNext',
      3,
    );
    _expectPaste('A\n\nB', 2, _p, 'A\n$_p\nB', 26);
    _expectPaste('```\ncode', 8, _p, '```\ncode$_p', 32);
    _expectPaste('X', 1, '\n\n$_p\n\nY', 'X\n\n$_p\n\nY', 30);
  });

  testWidgets(
    'copy from the android toolbar collapses the selection',
    (WidgetTester tester) async {
      _pinSurface(tester);
      final _Clipboard clipboard = _Clipboard(tester);
      final _Host host = _Host(_state('The **fog** lifted', 4, 11));

      await host.actions.copySelection(SelectionChangedCause.toolbar);

      expect(clipboard.written, <String>['**fog**']);
      expect(host.hidden, <bool>[false]);
      if (defaultTargetPlatform == TargetPlatform.android) {
        expect(host.selected, <(NoteSelection, SelectionChangedCause)>[
          (const NoteSelection.collapsed(11), SelectionChangedCause.toolbar),
        ]);
      } else {
        expect(host.selected, isEmpty);
      }
    },
    variant: TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.android,
      TargetPlatform.macOS,
    }),
  );

  testWidgets('cut writes the range and deletes it as input.delete', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final _Clipboard clipboard = _Clipboard(tester);
    final _Host host = _Host(_state('The **fog** lifted', 4, 11));

    await host.actions.cutSelection(SelectionChangedCause.toolbar);

    expect(clipboard.written, <String>['**fog**']);
    expect(host.dispatched, hasLength(1));
    final Transaction transaction = host.dispatched.single;
    expect(transaction.event, TransactionEvent.inputDelete);
    expect(transaction.addToHistory, isTrue);
    expect(host.current.source, 'The  lifted');
    expect(host.current.selection, const NoteSelection.collapsed(4));
    expect(host.hidden, <bool>[true]);
    expect(host.revealed, <int>[4]);
  });

  testWidgets('cut with a selected photo goes through cutPhoto', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final _Clipboard clipboard = _Clipboard(tester);
    final List<EditorState> asked = <EditorState>[];
    final EditorState state = _state('A\n$_p\nB', 2, 26);
    final _Host host = _Host(
      state,
      cutPhoto: (EditorState s) {
        asked.add(s);
        return null;
      },
    );

    await host.actions.cutSelection(SelectionChangedCause.keyboard);

    expect(clipboard.written, <String>[_p]);
    expect(asked, hasLength(1));
    expect(host.dispatched, isEmpty);
    expect(noteCutTransaction(state), isNull);
  });

  test('a paste with a photo selected goes on a new line after it', () {
    final Transaction? transaction = notePasteTransaction(
      _state('A\n$_p\nB', 2, 26),
      'h',
    );
    expect(transaction!.changes.apply('A\n$_p\nB'), 'A\n$_p\nh\nB');
    expect(transaction.selection, const NoteSelection.collapsed(28));
    expect(transaction.event, TransactionEvent.inputPaste);
  });

  testWidgets('the clipboard is read only when pasteText runs', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final _Clipboard clipboard = _Clipboard(tester, contents: 'fog');
    final _Host host = _Host(_state('The lifted', 4));
    await host.actions.copySelection(SelectionChangedCause.keyboard);
    await host.actions.cutSelection(SelectionChangedCause.keyboard);
    host.actions.selectAll(SelectionChangedCause.keyboard);
    expect(clipboard.reads, 0);

    await host.actions.pasteText(SelectionChangedCause.toolbar);

    expect(clipboard.reads, 1);
    expect(host.current.source, 'The foglifted');
    expect(host.hidden, <bool>[true]);
    expect(host.revealed, <int>[7]);
  });

  testWidgets('an empty clipboard or an inactive editor dispatches nothing', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    _Clipboard(tester, contents: '');
    final _Host empty = _Host(_state('The lifted', 4));
    await empty.actions.pasteText(SelectionChangedCause.keyboard);
    expect(empty.dispatched, isEmpty);

    _Clipboard(tester);
    final _Host missing = _Host(_state('The lifted', 4));
    await missing.actions.pasteText(SelectionChangedCause.keyboard);
    expect(missing.dispatched, isEmpty);

    _Clipboard(tester, contents: 'fog');
    final _Host inactive = _Host(_state('The lifted', 4), active: false);
    await inactive.actions.pasteText(SelectionChangedCause.toolbar);
    expect(inactive.dispatched, isEmpty);
    expect(inactive.hidden, isEmpty);
  });

  testWidgets(
    'select all from the toolbar scrolls only on android',
    (WidgetTester tester) async {
      _pinSurface(tester);
      final _Host host = _Host(_state('The **fog** lifted', 3));

      host.actions.selectAll(SelectionChangedCause.toolbar);

      expect(host.selected, <(NoteSelection, SelectionChangedCause)>[
        (
          const NoteSelection(anchor: 0, head: 18),
          SelectionChangedCause.toolbar,
        ),
      ]);
      expect(host.hidden, <bool>[true]);
      expect(
        host.revealed,
        defaultTargetPlatform == TargetPlatform.android ? <int>[18] : <int>[],
      );
    },
    variant: TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.android,
      TargetPlatform.macOS,
    }),
  );

  test('a 1 MB paste is one transaction inserted byte-for-byte', () {
    const String source = 'The **fog** lifted';
    final String text = List<String>.generate(
      1048576,
      (int i) => i % 64 == 63 ? '\n' : String.fromCharCode(97 + i % 26),
    ).join();
    final Transaction? transaction = notePasteTransaction(
      _state(source, 4),
      text,
    );
    expect(transaction!.changes.replacements, hasLength(1));
    expect(transaction.changes.apply(source), source.replaceRange(4, 4, text));
    expect(transaction.selection, NoteSelection.collapsed(4 + text.length));
  });

  test('cutting a collapsed caret is null', () {
    expect(noteCutTransaction(_state('The **fog** lifted', 4)), isNull);
  });

  test('a lone carriage return is pasted byte-for-byte', () {
    _expectPaste('The fog', 4, 'a\rb', 'The a\rbfog', 7);
  });

  test('a moved photo line is written without its spaces and tabs', () {
    _expectPaste('The fog.', 3, '  $_p\t', 'The fog.\n$_p', 3);
  });

  test('a photo line pasted into a closed fence moves after the fence', () {
    _expectPaste(
      '```\ncode\n```\n\nAfter',
      8,
      _p,
      '```\ncode\n```\n$_p\n\nAfter',
      8,
    );
  });

  test('a paste without photo lines is a plain insertion', () {
    final Transaction? transaction = notePasteTransaction(
      _state('The **fog** lifted', 0),
      '**fog**',
    );
    expect(transaction!.changes.replacements, hasLength(1));
    expect(
      transaction.changes.apply('The **fog** lifted'),
      '**fog**The **fog** lifted',
    );
    expect(transaction.selection, const NoteSelection.collapsed(7));
  });
}
