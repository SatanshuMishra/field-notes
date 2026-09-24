import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/commands/inline_format.dart';
import 'package:field_notes/features/note_engine/commands/line_format.dart';
import 'package:field_notes/features/note_engine/commands/list_commands.dart';
import 'package:field_notes/features/note_engine/commands/note_commands.dart';
import 'package:field_notes/features/note_engine/commands/table_commands.dart';
import 'package:field_notes/features/note_engine/commands/task_commands.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/input/command_registry.dart';
import 'package:flutter/widgets.dart' show CharacterRange;
import 'package:flutter_test/flutter_test.dart';

import '../../../support/note_generators.dart';

const int _randomNotes = 1000;

const List<String> _fixtures = <String>[
  '# one\n## two\n### three\n#### four\n##### five\n###### six',
  'a *em* b **strong** c ~~gone~~ d ==mark== e `code` f [link](dest "t") '
      r'g <https://x.y> h \* i \| j',
  '***both*** and **outer *inner* outer** and `` a`b `` and [**x**](y)',
  '- a\n  - b\n    - c\n  - d\n- e',
  '1. a\n2. b\n   1) c\n   2) d\n3. e',
  '3) x\n4) y\n\n7. p\n8. q',
  '- [ ] open\n- [x] done\n  - [X] nested\n1. [ ] first\n* [x] star',
  '- a\n  - ',
  '- a\n  - \n  - b\n- \n1. \n2. [ ] ',
  '> q\n> > deeper\n> back',
  '> - a\n>   - b\n> 1. c\n> - [ ] task',
  '```dart\ncode\n# not a heading\n```\nafter',
  '~~~\nunclosed\n- not a list',
  'a\n\n---\n\n***\n___\n- - -\n\n![cap](photo/0123456789ab "left small")\n'
      '![](photo/abcdef012345)',
  '| a | b | c |\n| :--- | :---: | ---: |\n| 1 |\n| 1 | 2 | 3 | 4 |\n'
      r'| x \| y | z | \|\| |',
  '|  |  |\n| --- | --- |\n|  |  |\ntext after',
  'para\n| h |\n| - |\n| b |',
  '\n\n   \n\t\n \t \n\na\n\n\n',
  '  \n- a\n\n\n- b\n   \n> q\n\n| t |\n| - |',
  'head\n\n| a | b |\n|---|---|\n| c | d |\n\ntail',
  '- a\n  ![c](photo/0123456789ab)\n- b',
  '1. a\n\n   more\n2. b',
  '> ```\n> code\n> ```\n> - x',
];

const List<String> _cellPieces = <String>[
  'a',
  'Z',
  'q',
  ' ',
  '|',
  '\n',
  '\r\n',
];

final RegExp _bareLineFeed = RegExp(r'(?<!\r)\n');

final RegExp _markerOnly = RegExp(
  r'^[ \t]*(?:[-+*]|[0-9]{1,9}[.)])(?:[ \t]+(?:\[[ \txX]\][ \t]*)?)?$',
);

final RegExp _quotePrefix = RegExp(r'^(?:[ ]{0,3}>[ ]?)+');

final RegExp _publicTransaction = RegExp(
  r'^Transaction\??\s+([A-Za-z][A-Za-z0-9]*)\s*\(',
  multiLine: true,
);

typedef _Rule = MdRange? Function(_Case at);

typedef _Run = Transaction? Function(_Case at);

final class _Command {
  const _Command(
    this.name,
    this.function,
    this.run,
    this.range, {
    this.guardsPipes = false,
    this.single = false,
  });

  final String name;
  final String function;
  final _Run run;
  final _Rule range;
  final bool guardsPipes;
  final bool single;
}

final class _Note {
  _Note(this.seed, this.label, this.source)
    : lines = MdSourceLines.split(source),
      state = EditorState.create(source, parse: parseNoteTree) {
    items = <MdBlock>[..._blocksOf(state.tree.blocks, MdBlockKind.listItem)];
    tables = <MdBlock>[
      for (final MdBlock block in state.tree.blocks)
        if (block.kind == MdBlockKind.table) block,
    ];
    inlines = <MdInline>[
      for (final MdBlock block in _blocksOf(state.tree.blocks, null))
        ..._inlinesOf(block.inlines),
    ];
  }

  final int seed;
  final String label;
  final String source;
  final MdSourceLines lines;
  final EditorState state;
  late final List<MdBlock> items;
  late final List<MdBlock> tables;
  late final List<MdInline> inlines;

  MdSourceLine lineAt(int offset) => lines.lines[lines.lineIndexAt(offset)];

  List<MdBlock> get cells => <MdBlock>[
    for (final MdBlock table in tables)
      for (final MdBlock row in table.blocks) ...row.blocks,
  ];
}

final class _Case {
  const _Case(
    this.note,
    this.index,
    this.state, {
    this.offset = 0,
    this.cellText = '',
  });

  final _Note note;
  final int index;
  final EditorState state;
  final int offset;
  final String cellText;

  NoteSelection get selection => state.selection;

  String get source => note.source;
}

Iterable<MdBlock> _blocksOf(List<MdBlock> blocks, MdBlockKind? kind) sync* {
  for (final MdBlock block in blocks) {
    if (kind == null || block.kind == kind) {
      yield block;
    }
    yield* _blocksOf(block.blocks, kind);
  }
}

Iterable<MdInline> _inlinesOf(List<MdInline> inlines) sync* {
  for (final MdInline inline in inlines) {
    yield inline;
    yield* _inlinesOf(inline.children);
  }
}

int _clusterStart(String source, int offset) =>
    CharacterRange.at(source, offset).stringBeforeLength;

String _crlf(String source) =>
    source.replaceAllMapped(_bareLineFeed, (Match _) => '\r\n');

MdRange _lineSpan(_Note note, int from, int to) =>
    MdRange(note.lineAt(from).start, note.lineAt(to).end);

MdRange _union(MdRange a, MdRange b) => MdRange(
  a.start < b.start ? a.start : b.start,
  a.end > b.end ? a.end : b.end,
);

bool _intersects(MdRange range, int from, int to) =>
    range.start <= to && range.end >= from;

MdInlineKind _kindOf(InlineFormat format) => switch (format) {
  InlineFormat.bold => MdInlineKind.strong,
  InlineFormat.italic => MdInlineKind.emphasis,
  InlineFormat.strikethrough => MdInlineKind.strikethrough,
  InlineFormat.highlight => MdInlineKind.highlight,
  InlineFormat.code => MdInlineKind.codeSpan,
  InlineFormat.link => MdInlineKind.link,
};

MdRange _inlineRange(_Case at, InlineFormat format) {
  final NoteSelection selection = at.selection;
  final MdRange lines = _lineSpan(at.note, selection.start, selection.end);
  final MdInlineKind kind = _kindOf(format);
  MdInline? found;
  for (final MdInline inline in at.note.inlines) {
    if (inline.kind == kind &&
        inline.sourceRange.start <= selection.start &&
        selection.end <= inline.sourceRange.end &&
        (found == null ||
            inline.sourceRange.length < found.sourceRange.length)) {
      found = inline;
    }
  }
  return found == null ? lines : _union(lines, found.sourceRange);
}

MdRange _touchedLines(_Case at) =>
    _lineSpan(at.note, at.selection.start, at.selection.end);

MdRange _listRange(_Case at) {
  final MdRange touched = _touchedLines(at);
  int end = touched.end;
  for (final MdBlock item in at.note.items) {
    if (_intersects(item.sourceRange, touched.start, touched.end)) {
      final int last = at.note.lineAt(item.sourceRange.end).end;
      end = last > end ? last : end;
    }
  }
  return MdRange(touched.start, end);
}

MdRange _caretLine(_Case at) {
  final MdSourceLine line = at.note.lineAt(at.selection.start);
  final MdSourceLine last = at.note.lineAt(at.selection.end);
  return MdRange(line.start, last.end);
}

MdRange _selectionRange(_Case at) =>
    MdRange(at.selection.start, at.selection.end);

bool _isMarkerOnly(String source, MdSourceLine line) {
  final String text = source.substring(line.start, line.end);
  final Match? quote = _quotePrefix.firstMatch(text);
  return _markerOnly.hasMatch(quote == null ? text : text.substring(quote.end));
}

bool _isQuoteLineWithoutItem(_Note note, MdSourceLine line) {
  final bool inQuote = _blocksOf(note.state.tree.blocks, MdBlockKind.blockQuote)
      .any(
        (MdBlock quote) => _intersects(quote.sourceRange, line.start, line.end),
      );
  return inQuote &&
      !note.items.any(
        (MdBlock item) => _intersects(item.sourceRange, line.start, line.end),
      );
}

MdRange _itemRange(_Case at) {
  final _Note note = at.note;
  final NoteSelection selection = at.selection;
  final MdSourceLine first = note.lineAt(selection.start);
  final MdSourceLine last = note.lineAt(selection.end);
  if (_isMarkerOnly(note.source, first) ||
      _isQuoteLineWithoutItem(note, first)) {
    return MdRange(first.start, first.end);
  }
  MdBlock? innermost;
  for (final MdBlock item in note.items) {
    if (item.sourceRange.start > selection.start ||
        selection.start > item.sourceRange.end) {
      continue;
    }
    if (innermost == null ||
        item.sourceRange.start > innermost.sourceRange.start ||
        (item.sourceRange.start == innermost.sourceRange.start &&
            item.sourceRange.length < innermost.sourceRange.length)) {
      innermost = item;
    }
  }
  if (innermost == null) {
    return MdRange(first.start, last.end);
  }
  final int start = note.lineAt(innermost.sourceRange.start).start;
  int end = note.lineAt(innermost.sourceRange.end).end;
  for (final MdBlock item in note.items) {
    final int itemLine = note.lines.lineIndexAt(item.sourceRange.start);
    if (itemLine >= first.index && itemLine <= last.index) {
      final int subtreeEnd = note.lineAt(item.sourceRange.end).end;
      end = subtreeEnd > end ? subtreeEnd : end;
    }
  }
  return MdRange(start, end);
}

MdRange _headLine(_Case at) {
  final MdSourceLine line = at.note.lineAt(at.selection.head);
  return MdRange(line.start, line.end);
}

MdBlock? _tableAtHead(_Case at) {
  final int head = at.selection.head;
  MdBlock? found;
  for (final MdBlock table in at.note.tables) {
    if (table.sourceRange.start <= head && head <= table.sourceRange.end) {
      found = table;
    }
  }
  return found;
}

MdRange? _tableRange(_Case at) => _tableAtHead(at)?.sourceRange;

MdRange? _contentAt(MdBlock table, int offset) {
  for (final MdBlock row in table.blocks) {
    for (final MdBlock cell in row.blocks) {
      final MdRange content = cell.contentRange;
      if (content.start <= offset && offset <= content.end) {
        return content;
      }
    }
  }
  return null;
}

MdRange? _cellRange(_Case at) {
  final MdBlock? table = _tableAtHead(at);
  if (table == null) {
    return null;
  }
  final MdRange? first = _contentAt(table, at.selection.start);
  final MdRange? last = _contentAt(table, at.selection.end);
  if (first == null || last == null) {
    return null;
  }
  return MdRange(first.start, last.end);
}

MdRange? _deleteTableRange(_Case at) {
  final MdBlock? table = _tableAtHead(at);
  if (table == null) {
    return null;
  }
  final List<MdBlock> blocks = at.note.state.tree.blocks;
  final int index = blocks.indexWhere(
    (MdBlock block) => identical(block, table),
  );
  return MdRange(
    index > 0 ? blocks[index - 1].sourceRange.end : 0,
    index + 1 < blocks.length
        ? blocks[index + 1].sourceRange.start
        : at.source.length,
  );
}

bool _isSpacesAndTabs(String source, MdSourceLine line) {
  for (int i = line.start; i < line.end; i++) {
    final int unit = source.codeUnitAt(i);
    if (unit != 0x20 && unit != 0x09) {
      return false;
    }
  }
  return true;
}

MdRange _insertTableRange(_Case at) {
  final _Note note = at.note;
  final List<MdBlock> blocks = note.state.tree.blocks;
  final MdSourceLine line = note.lineAt(at.selection.end);
  final bool inBlock = blocks.any(
    (MdBlock block) => _intersects(block.sourceRange, line.start, line.end),
  );
  if (_isSpacesAndTabs(note.source, line) && !inBlock) {
    return MdRange(line.start, line.end);
  }
  int index = blocks.indexWhere(
    (MdBlock block) => _intersects(block.sourceRange, line.start, line.end),
  );
  if (index < 0) {
    index = blocks.lastIndexWhere(
      (MdBlock block) => block.sourceRange.start <= line.start,
    );
  }
  if (index < 0) {
    return const MdRange(0, 0);
  }
  final MdBlockData? data = blocks[index].data;
  if (data is MdFenceData && !data.isClosed) {
    final int end = index > 0 ? blocks[index - 1].sourceRange.end : 0;
    return MdRange(end, end);
  }
  final int end = blocks[index].sourceRange.end;
  return MdRange(end, end);
}

_Rule _tableFirst(_Rule table, _Rule otherwise) =>
    (_Case at) => _tableAtHead(at) == null ? otherwise(at) : table(at);

MdRange? _none(_Case at) => null;

List<_Command> _inlineCommands() => <_Command>[
  for (final InlineFormat format in InlineFormat.values)
    _Command(
      'toggleInlineFormat(${format.name})',
      'toggleInlineFormat',
      (_Case at) => toggleInlineFormat(at.state, format),
      (_Case at) => _inlineRange(at, format),
    ),
];

String _cellText(Random random) {
  final int count = random.nextInt(6);
  return List<String>.generate(
    count,
    (_) => _cellPieces[random.nextInt(_cellPieces.length)],
  ).join();
}

final List<_Command> _commands = <_Command>[
  ..._inlineCommands(),
  const _Command('cycleHeading', 'cycleHeading', _cycleHeading, _touchedLines),
  const _Command('toggleQuote', 'toggleQuote', _toggleQuote, _touchedLines),
  for (final NoteListKind kind in NoteListKind.values)
    _Command(
      'toggleList(${kind.name})',
      'toggleList',
      (_Case at) => toggleList(at.state, kind),
      _listRange,
    ),
  const _Command(
    'continueOnEnter',
    'continueOnEnter',
    _continueOnEnter,
    _caretLine,
  ),
  const _Command(
    'insertLineBreakWithoutContinuation',
    'insertLineBreakWithoutContinuation',
    _lineBreak,
    _selectionRange,
  ),
  const _Command('indentListItem', 'indentListItem', _indent, _itemRange),
  const _Command('outdentListItem', 'outdentListItem', _outdent, _itemRange),
  const _Command(
    'backspaceAtItemStart',
    'backspaceAtItemStart',
    _backspace,
    _itemRange,
  ),
  const _Command(
    'toggleTaskOnCaretLine',
    'toggleTaskOnCaretLine',
    _toggleTaskOnCaretLine,
    _headLine,
  ),
  const _Command(
    'replaceInCell',
    'replaceInCell',
    _replaceInCell,
    _cellRange,
    guardsPipes: true,
  ),
  const _Command(
    'deleteInCell(backward)',
    'deleteInCell',
    _deleteBackward,
    _cellRange,
    guardsPipes: true,
  ),
  const _Command(
    'deleteInCell(forward)',
    'deleteInCell',
    _deleteForward,
    _cellRange,
    guardsPipes: true,
  ),
  const _Command('nextCell', 'nextCell', _nextCell, _tableRange),
  const _Command('previousCell', 'previousCell', _previousCell, _tableRange),
  const _Command('cellBelow', 'cellBelow', _cellBelow, _tableRange),
  for (final TableEdit edit in TableEdit.values)
    _Command(
      'editTable(${edit.name})',
      'editTable',
      (_Case at) => editTable(at.state, edit),
      edit == TableEdit.deleteTable ? _deleteTableRange : _tableRange,
    ),
  const _Command(
    'insertTable',
    'insertTable',
    _insertTable,
    _insertTableRange,
    single: true,
  ),
];

const _Command _toggleTaskAtCommand = _Command(
  'toggleTaskAt',
  'toggleTaskAt',
  _toggleTaskAt,
  _taskBoxRange,
);

Transaction? _cycleHeading(_Case at) => cycleHeading(at.state);

Transaction? _toggleQuote(_Case at) => toggleQuote(at.state);

Transaction? _continueOnEnter(_Case at) => continueOnEnter(at.state);

Transaction? _lineBreak(_Case at) =>
    insertLineBreakWithoutContinuation(at.state);

Transaction? _indent(_Case at) => indentListItem(at.state);

Transaction? _outdent(_Case at) => outdentListItem(at.state);

Transaction? _backspace(_Case at) => backspaceAtItemStart(at.state);

Transaction? _toggleTaskOnCaretLine(_Case at) =>
    toggleTaskOnCaretLine(at.state);

Transaction? _replaceInCell(_Case at) => replaceInCell(at.state, at.cellText);

Transaction? _deleteBackward(_Case at) =>
    deleteInCell(at.state, forward: false);

Transaction? _deleteForward(_Case at) => deleteInCell(at.state, forward: true);

Transaction? _nextCell(_Case at) => nextCell(at.state);

Transaction? _previousCell(_Case at) => previousCell(at.state);

Transaction? _cellBelow(_Case at) => cellBelow(at.state);

Transaction? _insertTable(_Case at) => insertTable(at.state);

Transaction? _toggleTaskAt(_Case at) => toggleTaskAt(at.state, at.offset);

MdRange? _taskBoxRange(_Case at) {
  for (final MdBlock item in at.note.items) {
    final MdBlockData? data = item.data;
    final MdRange? box = data is MdListItemData ? data.taskBoxRange : null;
    if (box != null &&
        at.note.lines.lineIndexAt(item.sourceRange.start) ==
            at.note.lines.lineIndexAt(at.offset)) {
      return MdRange(box.start + 1, box.start + 2);
    }
  }
  return null;
}

final Map<String, _Rule> _idRanges = <String, _Rule>{
  NoteCommandId.bold: (_Case at) => _inlineRange(at, InlineFormat.bold),
  NoteCommandId.italic: (_Case at) => _inlineRange(at, InlineFormat.italic),
  NoteCommandId.link: (_Case at) => _inlineRange(at, InlineFormat.link),
  NoteCommandId.strikethrough: (_Case at) =>
      _inlineRange(at, InlineFormat.strikethrough),
  NoteCommandId.highlight: (_Case at) =>
      _inlineRange(at, InlineFormat.highlight),
  NoteCommandId.inlineCode: (_Case at) => _inlineRange(at, InlineFormat.code),
  NoteCommandId.numberedList: _listRange,
  NoteCommandId.bulletList: _listRange,
  NoteCommandId.taskList: _listRange,
  NoteCommandId.toggleTask: _headLine,
  NoteCommandId.headingCycle: _touchedLines,
  NoteCommandId.quote: _touchedLines,
  NoteCommandId.enter: _tableFirst(_tableRange, _caretLine),
  NoteCommandId.lineBreak: _selectionRange,
  NoteCommandId.indent: _tableFirst(_tableRange, _itemRange),
  NoteCommandId.outdent: _tableFirst(_tableRange, _itemRange),
  NoteCommandId.deleteBackward: _tableFirst(_cellRange, _itemRange),
  NoteCommandId.deleteForward: _tableFirst(_cellRange, _none),
  NoteCommandId.tableInsert: _insertTableRange,
  NoteCommandId.tableRowAbove: _tableRange,
  NoteCommandId.tableRowBelow: _tableRange,
  NoteCommandId.tableColumnLeft: _tableRange,
  NoteCommandId.tableColumnRight: _tableRange,
  NoteCommandId.tableDeleteRow: _tableRange,
  NoteCommandId.tableDeleteColumn: _tableRange,
  NoteCommandId.tableAlignLeft: _tableRange,
  NoteCommandId.tableAlignCentre: _tableRange,
  NoteCommandId.tableAlignRight: _tableRange,
  NoteCommandId.tableDelete: _deleteTableRange,
};

const Set<String> _pipeGuardedIds = <String>{
  NoteCommandId.deleteBackward,
  NoteCommandId.deleteForward,
};

const NoteCommandRegistry _registry = NoteCommandRegistry(tablesEnabled: true);

List<_Command> _registryCommands() => <_Command>[
  for (final String id in _registry.ids)
    _Command(
      id,
      id,
      (_Case at) => _registry.commandFor(id)!(at.state),
      _idRanges[id]!,
      guardsPipes: _pipeGuardedIds.contains(id),
      single: id == NoteCommandId.tableInsert,
    ),
];

List<int> _pipesOf(_Note note, MdBlock table) {
  final int first = note.lines.lineIndexAt(table.sourceRange.start);
  final int last = note.lines.lineIndexAt(table.sourceRange.end);
  return <int>[
    for (int index = first; index <= last; index++)
      for (
        int at = note.lines.lines[index].start;
        at < note.lines.lines[index].end;
        at++
      )
        if (note.source.codeUnitAt(at) == 0x7C &&
            (at == 0 || note.source.codeUnitAt(at - 1) != 0x5C))
          at,
  ];
}

String _describe(_Case at, String command, MdRange? range, Object detail) =>
    'seed ${at.note.seed} (${at.note.label}), case ${at.index}, '
    'command $command, source ${jsonEncode(at.source)}, '
    'selection (anchor ${at.selection.anchor}, head ${at.selection.head})'
    '${at.offset == 0 ? '' : ', offset ${at.offset}'}, '
    'stated range $range: $detail';

String? _violation(_Case at, _Command command) {
  final Transaction? transaction = command.run(at);
  if (transaction == null) {
    return null;
  }
  final String source = at.source;
  final ChangeSet changes = transaction.changes;
  if (changes.length != source.length) {
    return _describe(
      at,
      command.name,
      null,
      'change set length ${changes.length} is not ${source.length}',
    );
  }
  if (changes.isEmpty) {
    return null;
  }
  final MdRange? range = command.range(at);
  if (range == null || range.end > source.length) {
    return _describe(at, command.name, range, 'no stated range for $changes');
  }
  if (command.single && changes.replacements.length != 1) {
    return _describe(
      at,
      command.name,
      range,
      '${changes.replacements.length} replacements, not one',
    );
  }
  for (final TextReplacement replacement in changes.replacements) {
    if (replacement.from < range.start || replacement.to > range.end) {
      return _describe(
        at,
        command.name,
        range,
        'replacement $replacement lies outside it',
      );
    }
  }
  if (command.guardsPipes) {
    final MdBlock? table = _tableAtHead(at);
    if (table != null) {
      for (final int pipe in _pipesOf(at.note, table)) {
        for (final TextReplacement replacement in changes.replacements) {
          if (replacement.from <= pipe && pipe < replacement.to) {
            return _describe(
              at,
              command.name,
              range,
              'replacement $replacement covers the pipe at $pipe',
            );
          }
        }
      }
    }
  }
  final String after = changes.apply(source);
  final int tail = source.length - range.end;
  if (after.length < range.start ||
      after.substring(0, range.start) != source.substring(0, range.start)) {
    return _describe(
      at,
      command.name,
      range,
      'bytes before it changed: ${jsonEncode(after)}',
    );
  }
  if (after.length < tail ||
      after.substring(after.length - tail) != source.substring(range.end)) {
    return _describe(
      at,
      command.name,
      range,
      'bytes after it changed: ${jsonEncode(after)}',
    );
  }
  return null;
}

List<NoteSelection> _targets(Random random, _Note note) {
  final String source = note.source;
  final List<NoteSelection> pool = <NoteSelection>[
    for (final MdBlock cell in note.cells)
      NoteSelection.collapsed(
        _clusterStart(
          source,
          cell.contentRange.start +
              random.nextInt(cell.contentRange.length + 1),
        ),
      ),
    for (final MdBlock item in note.items)
      NoteSelection.collapsed(_contentStart(note, item)),
    for (final MdSourceLine line in note.lines.lines)
      NoteSelection.collapsed(line.end),
    for (int i = 0; i + 1 < note.lines.lines.length; i++)
      NoteSelection(
        anchor: note.lines.lines[i].start,
        head: note.lines.lines[i + 1].end,
      ),
  ];
  final List<NoteSelection> chosen = <NoteSelection>[];
  final List<NoteSelection> remaining = <NoteSelection>[...pool];
  while (chosen.length < 3 && remaining.isNotEmpty) {
    chosen.add(remaining.removeAt(random.nextInt(remaining.length)));
  }
  return chosen;
}

int _contentStart(_Note note, MdBlock item) {
  final MdBlockData? data = item.data;
  final MdRange? box = data is MdListItemData ? data.taskBoxRange : null;
  final MdSourceLine line = note.lineAt(item.sourceRange.start);
  int at = box?.end ?? item.markerRanges.first.end;
  while (at < line.end &&
      (note.source.codeUnitAt(at) == 0x20 ||
          note.source.codeUnitAt(at) == 0x09)) {
    at += 1;
  }
  return at > line.end ? line.end : at;
}

void main() {
  test(
    'no command changes bytes outside its replacement range',
    () {
      final List<_Command> commands = <_Command>[
        ..._commands,
        ..._registryCommands(),
      ];
      int index = 0;
      for (int n = 0; n < _randomNotes + _fixtures.length; n++) {
        final int seed = noteGeneratorSeed + n;
        final Random random = Random(seed);
        final String original = n < _randomNotes
            ? randomNote(random)
            : _fixtures[n - _randomNotes];
        final String label = n < _randomNotes
            ? 'random note $n'
            : 'fixture ${n - _randomNotes}';
        for (final _Note note in <_Note>[
          _Note(seed, '$label, LF', original),
          _Note(seed, '$label, CRLF', _crlf(original)),
        ]) {
          final List<NoteSelection> selections = <NoteSelection>[
            randomSelection(random, note.source),
            ..._targets(random, note),
            for (final MdBlock cell in note.cells)
              NoteSelection.collapsed(cell.contentRange.end),
          ];
          for (final NoteSelection selection in selections) {
            final _Case at = _Case(
              note,
              index,
              note.state.withSelection(selection),
              cellText: _cellText(random),
            );
            index += 1;
            for (final _Command command in commands) {
              final String? violation = _violation(at, command);
              if (violation != null) {
                fail(violation);
              }
            }
          }
          for (final MdBlock item in note.items) {
            final MdBlockData? data = item.data;
            if (data is! MdListItemData || data.taskBoxRange == null) {
              continue;
            }
            final MdSourceLine line = note.lineAt(item.sourceRange.start);
            final _Case at = _Case(
              note,
              index,
              note.state,
              offset: line.start + random.nextInt(line.end - line.start + 1),
            );
            index += 1;
            final String? violation = _violation(at, _toggleTaskAtCommand);
            if (violation != null) {
              fail(violation);
            }
          }
        }
      }
      expect(index, greaterThanOrEqualTo(2000));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('every command and every registry id is covered by the property', () {
    final Set<String> covered = <String>{
      for (final _Command command in _commands) command.function,
      _toggleTaskAtCommand.function,
    };
    final List<String> functions = <String>[
      for (final FileSystemEntity entity
          in Directory('lib/features/note_engine/commands').listSync()..sort(
            (FileSystemEntity a, FileSystemEntity b) =>
                a.path.compareTo(b.path),
          ))
        if (entity is File && entity.path.endsWith('.dart'))
          for (final RegExpMatch match in _publicTransaction.allMatches(
            entity.readAsStringSync(),
          ))
            match.group(1)!,
    ];
    expect(functions, isNotEmpty);
    expect(covered, containsAll(functions));
    expect(_idRanges.keys, containsAll(_registry.ids));
  });
}
