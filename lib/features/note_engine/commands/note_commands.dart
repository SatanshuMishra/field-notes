import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/capabilities.dart'
    as capabilities;
import 'package:field_notes/features/note_engine/commands/inline_format.dart';
import 'package:field_notes/features/note_engine/commands/line_format.dart';
import 'package:field_notes/features/note_engine/commands/list_commands.dart';
import 'package:field_notes/features/note_engine/commands/table_commands.dart';
import 'package:field_notes/features/note_engine/commands/task_commands.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/input/command_registry.dart';

final class NoteCommandRegistry implements CommandRegistry {
  const NoteCommandRegistry({this.tablesEnabled = capabilities.tablesEnabled});

  final bool tablesEnabled;

  Iterable<String> get ids => <String>[
    ...NoteCommandId.shortcutIds,
    NoteCommandId.headingCycle,
    NoteCommandId.quote,
    NoteCommandId.enter,
    NoteCommandId.lineBreak,
    NoteCommandId.indent,
    NoteCommandId.outdent,
    NoteCommandId.deleteBackward,
    NoteCommandId.deleteForward,
    if (tablesEnabled) ...NoteCommandId.tableIds,
  ];

  @override
  NoteCommand? commandFor(String id) => switch (id) {
    NoteCommandId.bold => _inline(InlineFormat.bold),
    NoteCommandId.italic => _inline(InlineFormat.italic),
    NoteCommandId.link => _inline(InlineFormat.link),
    NoteCommandId.strikethrough => _inline(InlineFormat.strikethrough),
    NoteCommandId.highlight => _inline(InlineFormat.highlight),
    NoteCommandId.inlineCode => _inline(InlineFormat.code),
    NoteCommandId.numberedList => _list(NoteListKind.numbered),
    NoteCommandId.bulletList => _list(NoteListKind.bullet),
    NoteCommandId.taskList => _list(NoteListKind.task),
    NoteCommandId.toggleTask => toggleTaskOnCaretLine,
    NoteCommandId.headingCycle => cycleHeading,
    NoteCommandId.quote => toggleQuote,
    NoteCommandId.enter => _tableFirst(cellBelow, continueOnEnter),
    NoteCommandId.lineBreak => _lineBreak,
    NoteCommandId.indent => _tableFirst(nextCell, indentListItem),
    NoteCommandId.outdent => _tableFirst(previousCell, outdentListItem),
    NoteCommandId.deleteBackward => _tableFirst(
      _deleteInCellBackward,
      backspaceAtItemStart,
    ),
    NoteCommandId.deleteForward => _tableFirst(_deleteInCellForward, _nothing),
    _ => tablesEnabled ? _tableCommand(id) : null,
  };

  NoteCommand _inline(InlineFormat format) =>
      (EditorState state) => toggleInlineFormat(state, format);

  NoteCommand _list(NoteListKind kind) =>
      (EditorState state) => toggleList(state, kind);

  NoteCommand _tableFirst(NoteCommand table, NoteCommand otherwise) {
    if (!tablesEnabled) {
      return otherwise;
    }
    return (EditorState state) => table(state) ?? otherwise(state);
  }

  Transaction? _lineBreak(EditorState state) {
    if (tablesEnabled &&
        state.tree.blockAt(state.selection.head)?.kind == MdBlockKind.table) {
      return Transaction(
        changes: ChangeSet.empty(state.source.length),
        selection: state.selection,
        event: TransactionEvent.table,
        addToHistory: false,
      );
    }
    return insertLineBreakWithoutContinuation(state);
  }

  NoteCommand? _tableCommand(String id) => switch (id) {
    NoteCommandId.tableInsert => insertTable,
    NoteCommandId.tableRowAbove => _edit(TableEdit.rowAbove),
    NoteCommandId.tableRowBelow => _edit(TableEdit.rowBelow),
    NoteCommandId.tableColumnLeft => _edit(TableEdit.columnLeft),
    NoteCommandId.tableColumnRight => _edit(TableEdit.columnRight),
    NoteCommandId.tableDeleteRow => _edit(TableEdit.deleteRow),
    NoteCommandId.tableDeleteColumn => _edit(TableEdit.deleteColumn),
    NoteCommandId.tableAlignLeft => _edit(TableEdit.alignLeft),
    NoteCommandId.tableAlignCentre => _edit(TableEdit.alignCentre),
    NoteCommandId.tableAlignRight => _edit(TableEdit.alignRight),
    NoteCommandId.tableDelete => _edit(TableEdit.deleteTable),
    _ => null,
  };

  NoteCommand _edit(TableEdit edit) =>
      (EditorState state) => editTable(state, edit);
}

Transaction? _deleteInCellBackward(EditorState state) =>
    deleteInCell(state, forward: false);

Transaction? _deleteInCellForward(EditorState state) =>
    deleteInCell(state, forward: true);

Transaction? _nothing(EditorState state) => null;
