import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/capabilities.dart'
    as capabilities;
import 'package:field_notes/features/note_engine/commands/note_commands.dart';
import 'package:field_notes/features/note_engine/commands/table_commands.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/input/command_registry.dart';
import 'package:field_notes/features/note_engine/input/note_shortcuts.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';

const String _table = '| a | b |\n| --- | --- |\n| c | d |';

EditorState _caret(String source, int offset) => EditorState.create(
  source,
  parse: parseNoteTree,
  selection: NoteSelection.collapsed(offset),
);

EditorState _tablesOff(String source, int offset) => EditorState.create(
  source,
  parse: (String s) => parseNoteTree(s, tables: false),
  selection: NoteSelection.collapsed(offset),
);

EditorState _tablesOn(String source, int offset) => EditorState.create(
  source,
  parse: (String s) => parseNoteTree(s, tables: true),
  selection: NoteSelection.collapsed(offset),
);

Transaction _run(NoteCommandRegistry registry, String id, EditorState state) {
  final NoteCommand? command = registry.commandFor(id);
  expect(command, isNotNull, reason: id);
  final Transaction? transaction = command!(state);
  expect(transaction, isNotNull, reason: id);
  return transaction!;
}

String _apply(NoteCommandRegistry registry, String id, EditorState state) =>
    _run(registry, id, state).changes.apply(state.source);

void _expectNoOp(EditorState state, Transaction transaction) {
  expect(transaction.changes, ChangeSet.empty(state.source.length));
  expect(transaction.selection, state.selection);
  expect(transaction.event, TransactionEvent.table);
  expect(transaction.addToHistory, isFalse);
}

void main() {
  test('every c3 shortcut id resolves to a command', () {
    expect(NoteCommandId.shortcutIds, hasLength(10));
    const List<NoteCommandRegistry> registries = <NoteCommandRegistry>[
      NoteCommandRegistry(tablesEnabled: true),
      NoteCommandRegistry(tablesEnabled: false),
    ];
    final List<String> expected = <String>[
      'the **quick** fox',
      'the *quick* fox',
      'the [quick]() fox',
      'the ~~quick~~ fox',
      'the ==quick== fox',
      'the `quick` fox',
      '1. the quick fox',
      '- the quick fox',
      '- [ ] the quick fox',
      '- [ ] the quick fox',
    ];
    for (final NoteCommandRegistry registry in registries) {
      for (int i = 0; i < NoteCommandId.shortcutIds.length; i++) {
        final String id = NoteCommandId.shortcutIds[i];
        final EditorState state = _caret('the quick fox', 6);
        final Transaction transaction = _run(registry, id, state);
        expect(
          transaction.changes.apply(state.source),
          expected[i],
          reason: id,
        );
        if (id == NoteCommandId.link) {
          expect(transaction.selection, const NoteSelection.collapsed(12));
        }
      }
    }
  });

  test('table commands are absent when tables are disabled', () {
    const NoteCommandRegistry off = NoteCommandRegistry(tablesEnabled: false);
    for (final String id in NoteCommandId.tableIds) {
      expect(off.commandFor(id), isNull, reason: id);
      expect(off.ids, isNot(contains(id)));
    }
    final NoteCommand? offIndent = off.commandFor(NoteCommandId.indent);
    expect(offIndent, isNotNull);
    expect(offIndent!(_tablesOff(_table, 27)), isNull);

    const NoteCommandRegistry on = NoteCommandRegistry(tablesEnabled: true);
    for (final String id in NoteCommandId.tableIds) {
      expect(on.commandFor(id), isNotNull, reason: id);
    }
    final EditorState state = _tablesOn(_table, 27);
    final Transaction move = _run(on, NoteCommandId.indent, state);
    expect(move.changes, ChangeSet.empty(state.source.length));
    expect(move.selection, const NoteSelection.collapsed(31));
    expect(move.event, TransactionEvent.table);
    expect(move.addToHistory, isFalse);
  });

  test('the default flag is the tables capability', () {
    expect(
      const NoteCommandRegistry().tablesEnabled,
      capabilities.tablesEnabled,
    );
  });

  test('an unknown id resolves to null', () {
    for (final bool tables in <bool>[true, false]) {
      final NoteCommandRegistry registry = NoteCommandRegistry(
        tablesEnabled: tables,
      );
      expect(registry.commandFor('underline'), isNull);
      expect(registry.commandFor(''), isNull);
    }
  });

  test('every shortcut intent resolves with tables disabled', () {
    const NoteCommandRegistry registry = NoteCommandRegistry(
      tablesEnabled: false,
    );
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.macOS,
      TargetPlatform.android,
    ]) {
      final Iterable<NoteCommandIntent> intents = noteShortcuts(
        platform,
      ).values.whereType<NoteCommandIntent>();
      expect(intents, isNotEmpty);
      for (final NoteCommandIntent intent in intents) {
        final String id = intent.commandId;
        expect(registry.commandFor(id), isNotNull, reason: '$platform $id');
      }
    }
  });

  test('enter outside a table continues the list', () {
    for (final bool tables in <bool>[true, false]) {
      final NoteCommandRegistry registry = NoteCommandRegistry(
        tablesEnabled: tables,
      );
      expect(
        _apply(registry, NoteCommandId.enter, _caret('- a', 3)),
        '- a\n- ',
      );
    }
  });

  test('a line break never enters a cell', () {
    const NoteCommandRegistry registry = NoteCommandRegistry(
      tablesEnabled: true,
    );
    final EditorState cell = _tablesOn(_table, 27);
    _expectNoOp(cell, _run(registry, NoteCommandId.lineBreak, cell));
    expect(
      _apply(registry, NoteCommandId.lineBreak, _tablesOn('ab', 1)),
      'a\nb',
    );
  });

  test('delete backward outdents at an item start and stops at a cell', () {
    for (final bool tables in <bool>[true, false]) {
      final NoteCommandRegistry registry = NoteCommandRegistry(
        tablesEnabled: tables,
      );
      expect(
        _apply(registry, NoteCommandId.deleteBackward, _caret('- a\n  - b', 8)),
        '- a\n- b',
      );
    }
    const NoteCommandRegistry on = NoteCommandRegistry(tablesEnabled: true);
    final EditorState cell = _tablesOn(_table, 26);
    _expectNoOp(cell, _run(on, NoteCommandId.deleteBackward, cell));
  });

  test('delete forward runs only as a table command', () {
    const NoteCommandRegistry off = NoteCommandRegistry(tablesEnabled: false);
    final NoteCommand? command = off.commandFor(NoteCommandId.deleteForward);
    expect(command, isNotNull);
    expect(command!(_tablesOff(_table, 27)), isNull);
  });

  test('heading cycle and quote resolve with tables disabled', () {
    const NoteCommandRegistry registry = NoteCommandRegistry(
      tablesEnabled: false,
    );
    expect(registry.commandFor(NoteCommandId.headingCycle), isNotNull);
    expect(registry.commandFor(NoteCommandId.quote), isNotNull);
  });

  test('ids lists every resolvable id under the flag', () {
    for (final bool tables in <bool>[true, false]) {
      final NoteCommandRegistry registry = NoteCommandRegistry(
        tablesEnabled: tables,
      );
      final List<String> ids = registry.ids.toList();
      expect(ids, containsAll(NoteCommandId.shortcutIds));
      for (final String id in NoteCommandId.tableIds) {
        expect(ids.contains(id), registry.tablesEnabled, reason: id);
      }
      for (final String id in ids) {
        expect(registry.commandFor(id), isNotNull, reason: id);
      }
      expect(ids.toSet(), hasLength(ids.length));
    }
  });

  test('a table toolbar id runs its table edit', () {
    const NoteCommandRegistry registry = NoteCommandRegistry(
      tablesEnabled: true,
    );
    final EditorState state = _tablesOn(
      '| a | b |\n| --- | --- |\n| c | d |\n| e | f |',
      3,
    );
    expect(
      _apply(registry, NoteCommandId.tableColumnRight, state),
      editTable(state, TableEdit.columnRight)!.changes.apply(state.source),
    );
  });

  test(
    'table keys never fall back to list commands while the head is in a table',
    () {
      const NoteCommandRegistry registry = NoteCommandRegistry(
        tablesEnabled: true,
      );
      final EditorState enterState = EditorState.create(
        '- a\n\n|b|\n|-|',
        parse: (String s) => parseNoteTree(s, tables: true),
        selection: const NoteSelection(anchor: 3, head: 10),
      );
      expect(registry.commandFor(NoteCommandId.enter)!(enterState), isNull);
      final EditorState outdentState = EditorState.create(
        '- a\n  - b\n\n|c|\n|-|',
        parse: (String s) => parseNoteTree(s, tables: true),
        selection: const NoteSelection(anchor: 9, head: 16),
      );
      expect(registry.commandFor(NoteCommandId.outdent)!(outdentState), isNull);
      expect(registry.commandFor(NoteCommandId.indent)!(outdentState), isNull);
      expect(
        _apply(registry, NoteCommandId.enter, _tablesOn('- a', 3)),
        '- a\n- ',
      );
    },
  );
}
