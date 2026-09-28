import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';

typedef NoteCommand = Transaction? Function(EditorState state);

abstract interface class CommandRegistry {
  NoteCommand? commandFor(String id);
}

abstract final class NoteCommandId {
  static const String bold = 'bold';
  static const String italic = 'italic';
  static const String link = 'link';
  static const String strikethrough = 'strikethrough';
  static const String highlight = 'highlight';
  static const String inlineCode = 'inline-code';
  static const String numberedList = 'numbered-list';
  static const String bulletList = 'bullet-list';
  static const String taskList = 'task-list';
  static const String toggleTask = 'toggle-task';
  static const String headingCycle = 'heading-cycle';
  static const String quote = 'quote';
  static const String enter = 'enter';
  static const String lineBreak = 'line-break';
  static const String indent = 'indent';
  static const String outdent = 'outdent';
  static const String deleteBackward = 'delete-backward';
  static const String deleteForward = 'delete-forward';
  static const String tableInsert = 'table-insert';
  static const String tableRowAbove = 'table-row-above';
  static const String tableRowBelow = 'table-row-below';
  static const String tableColumnLeft = 'table-column-left';
  static const String tableColumnRight = 'table-column-right';
  static const String tableDeleteRow = 'table-delete-row';
  static const String tableDeleteColumn = 'table-delete-column';
  static const String tableAlignLeft = 'table-align-left';
  static const String tableAlignCentre = 'table-align-centre';
  static const String tableAlignRight = 'table-align-right';
  static const String tableDelete = 'table-delete';

  static const List<String> shortcutIds = <String>[
    bold,
    italic,
    link,
    strikethrough,
    highlight,
    inlineCode,
    numberedList,
    bulletList,
    taskList,
    toggleTask,
  ];

  static const List<String> tableIds = <String>[
    tableInsert,
    tableRowAbove,
    tableRowBelow,
    tableColumnLeft,
    tableColumnRight,
    tableDeleteRow,
    tableDeleteColumn,
    tableAlignLeft,
    tableAlignCentre,
    tableAlignRight,
    tableDelete,
  ];
}
