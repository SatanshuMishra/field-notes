import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';

const String _objectReplacement = '\uFFFC';

String noteTableSemanticsLabel({required int rows, required int columns}) =>
    'Table, $rows rows, $columns columns';

class NoteCheckboxSemantics {
  const NoteCheckboxSemantics({
    required this.boxStart,
    required this.boxRange,
    required this.checked,
    required this.label,
  });

  final int boxStart;
  final MdRange boxRange;
  final bool checked;
  final String label;
}

class NoteTableSemantics {
  const NoteTableSemantics({
    required this.range,
    required this.rows,
    required this.columns,
    required this.text,
  });

  final MdRange range;
  final int rows;
  final int columns;
  final String text;
}

class NoteBlockSemantics {
  const NoteBlockSemantics({
    required this.range,
    required this.text,
    required this.headingLevel,
  });

  final MdRange range;
  final String text;
  final int? headingLevel;
}

Map<int, MdTaskState> _taskStatesOf(List<MdBlock> blocks) => <int, MdTaskState>{
  for (final MdBlock block in blocks) ...<int, MdTaskState>{
    if (block.data case MdListItemData(
      :final MdTaskState taskState,
      :final MdRange taskBoxRange,
    ))
      taskBoxRange.start: taskState,
    ..._taskStatesOf(block.blocks),
  },
};

String _visibleSlice(VisibleText visibleText, MdRange range) {
  final OffsetMap map = visibleText.map;
  final int start = map.sourceToVisible(range.start);
  final int end = map.sourceToVisible(range.end);
  return end <= start ? '' : visibleText.text.substring(start, end);
}

List<NoteCheckboxSemantics> noteCheckboxSemanticsOf(
  MdTree tree,
  VisibleText visibleText,
) {
  final Map<int, MdTaskState> states = _taskStatesOf(tree.blocks);
  final String text = visibleText.text;
  return List<NoteCheckboxSemantics>.unmodifiable(<NoteCheckboxSemantics>[
    for (final AtomicObject atomic in visibleText.atomics)
      if (atomic.kind == AtomicKind.checkbox)
        NoteCheckboxSemantics(
          boxStart: atomic.sourceRange.start,
          boxRange: atomic.sourceRange,
          checked: states[atomic.sourceRange.start] == MdTaskState.checked,
          label: _lineAfter(text, atomic.visibleOffset + atomic.visibleLength),
        ),
  ]);
}

String _lineAfter(String text, int from) {
  final int start = from.clamp(0, text.length);
  return text.substring(start, _lineEnd(text, start)).trim();
}

int _lineEnd(String text, int from) {
  final int end = text.indexOf('\n', from);
  return end < 0 ? text.length : end;
}

List<(int, int)> _checkboxLines(VisibleText visibleText) {
  final String text = visibleText.text;
  final List<(int, int)> lines = <(int, int)>[
    for (final AtomicObject atomic in visibleText.atomics)
      if (atomic.kind == AtomicKind.checkbox)
        (
          atomic.visibleOffset,
          _lineEnd(
            text,
            (atomic.visibleOffset + atomic.visibleLength).clamp(0, text.length),
          ),
        ),
  ]..sort(((int, int) a, (int, int) b) => a.$1.compareTo(b.$1));
  return List<(int, int)>.unmodifiable(lines);
}

String _readerSlice(
  VisibleText visibleText,
  MdRange range,
  List<(int, int)> checkboxLines,
) {
  final OffsetMap map = visibleText.map;
  final int start = map.sourceToVisible(range.start);
  final int end = map.sourceToVisible(range.end);
  if (end <= start) {
    return '';
  }
  final String text = visibleText.text;
  final List<(int, int)> cuts = <(int, int)>[
    for (final (int from, int to) in checkboxLines)
      if (from < end && to > start) (math.max(from, start), math.min(to, end)),
  ];
  if (cuts.isEmpty) {
    return text.substring(start, end);
  }
  final List<String> kept = <String>[];
  int at = start;
  for (final (int from, int to) in cuts) {
    kept.add(text.substring(at, math.max(at, from)));
    at = math.max(at, to);
  }
  kept.add(text.substring(at, end));
  return kept
      .join()
      .split('\n')
      .where(
        (String line) =>
            line.replaceAll(_objectReplacement, '').trim().isNotEmpty,
      )
      .join('\n');
}

List<NoteTableSemantics> noteTableSemanticsOf(
  MdTree tree,
  VisibleText visibleText,
) => List<NoteTableSemantics>.unmodifiable(<NoteTableSemantics>[
  for (final MdBlock block in tree.blocks)
    if (block.kind == MdBlockKind.table) _tableOf(block, visibleText),
]);

NoteTableSemantics _tableOf(MdBlock table, VisibleText visibleText) {
  final List<MdBlock> rows = <MdBlock>[
    for (final MdBlock row in table.blocks)
      if (row.kind == MdBlockKind.tableRow) row,
  ];
  final int columns = rows.isEmpty
      ? 0
      : rows.first.blocks
            .where((MdBlock cell) => cell.kind == MdBlockKind.tableCell)
            .length;
  return NoteTableSemantics(
    range: table.sourceRange,
    rows: rows.length,
    columns: columns,
    text: _visibleSlice(visibleText, table.sourceRange),
  );
}

List<NoteBlockSemantics> noteReaderSemanticsOf(
  MdTree tree,
  VisibleText visibleText,
) {
  final List<(int, int)> checkboxLines = _checkboxLines(visibleText);
  return List<NoteBlockSemantics>.unmodifiable(<NoteBlockSemantics>[
    for (final MdBlock block in tree.blocks)
      if (block.kind != MdBlockKind.photoLine &&
          block.kind != MdBlockKind.table)
        if (_readerSlice(
              visibleText,
              block.sourceRange,
              checkboxLines,
            ).replaceAll(_objectReplacement, '')
            case final String text when text.trim().isNotEmpty)
          NoteBlockSemantics(
            range: block.sourceRange,
            text: text,
            headingLevel: switch (block.data) {
              MdHeadingData(:final int level) => level,
              _ => null,
            },
          ),
  ]);
}

int noteNextCharacterOffset(String value, int offset) {
  if (offset >= value.length) {
    return value.length;
  }
  final CharacterRange range = CharacterRange.at(value, offset);
  return range.moveNext() ? offset + range.current.length : value.length;
}

int notePreviousCharacterOffset(String value, int offset) {
  if (offset <= 0) {
    return 0;
  }
  final CharacterRange range = CharacterRange.at(value, offset);
  return range.moveBack() ? offset - range.current.length : 0;
}

final class NoteSemanticsNodes {
  SemanticsNode? _textField;
  Map<int, SemanticsNode> _checkboxes = const <int, SemanticsNode>{};
  Map<int, SemanticsNode> _tables = const <int, SemanticsNode>{};
  Map<int, SemanticsNode> _blocks = const <int, SemanticsNode>{};

  SemanticsNode textField() => _textField ??= SemanticsNode();

  void dropTextField() {
    _textField = null;
  }

  List<SemanticsNode> checkboxes(List<int> boxStarts) {
    final Map<int, SemanticsNode> next = _reuse(_checkboxes, boxStarts);
    _checkboxes = next;
    return _inOrder(next, boxStarts);
  }

  List<SemanticsNode> tables(List<int> rangeStarts) {
    final Map<int, SemanticsNode> next = _reuse(_tables, rangeStarts);
    _tables = next;
    return _inOrder(next, rangeStarts);
  }

  List<SemanticsNode> blocks(List<int> rangeStarts) {
    final Map<int, SemanticsNode> next = _reuse(_blocks, rangeStarts);
    _blocks = next;
    return _inOrder(next, rangeStarts);
  }

  static Map<int, SemanticsNode> _reuse(
    Map<int, SemanticsNode> known,
    List<int> keys,
  ) => Map<int, SemanticsNode>.unmodifiable(<int, SemanticsNode>{
    for (final int key in keys) key: known[key] ?? SemanticsNode(),
  });

  static List<SemanticsNode> _inOrder(
    Map<int, SemanticsNode> nodes,
    List<int> keys,
  ) => List<SemanticsNode>.unmodifiable(<SemanticsNode>[
    for (final int key in keys) nodes[key]!,
  ]);
}
