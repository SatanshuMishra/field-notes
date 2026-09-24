import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';

enum NoteListKind { bullet, numbered, task }

Transaction? cycleHeading(EditorState state) {
  final _Lines lines = _Lines(state);
  final List<_Line> touched = lines.touched();
  final List<_Line> eligible = <_Line>[
    for (final _Line line in touched)
      if (!line.isOpaque && (touched.length == 1 || !line.isBlank)) line,
  ];
  if (eligible.isEmpty) {
    return null;
  }
  final int target = switch (eligible.first.headingLevel) {
    0 => 1,
    1 => 2,
    2 => 3,
    _ => 0,
  };
  final List<TextReplacement> replacements = <TextReplacement>[
    for (final _Line line in eligible)
      ..._setHeading(state.source, line, target),
  ];
  return _transaction(state, replacements, TransactionEvent.format);
}

Transaction? toggleList(EditorState state, NoteListKind kind) {
  final _Lines lines = _Lines(state);
  final List<_Line> touched = lines.touched();
  final List<_Line> eligible = <_Line>[
    for (final _Line line in touched)
      if (!line.isOpaque &&
          (touched.length == 1 || !line.isBlank) &&
          !line.continuesParagraph)
        line,
  ];
  if (eligible.isEmpty) {
    return null;
  }
  final bool removing = eligible.every((_Line line) => line.listKind == kind);
  final List<TextReplacement> replacements = <TextReplacement>[];
  if (removing) {
    for (final _Line line in eligible) {
      replacements.addAll(_replaceItemPrefix(lines, line, ''));
    }
  } else {
    final List<String> markers = _markersFor(lines, eligible, kind);
    for (int i = 0; i < eligible.length; i++) {
      final _Line line = eligible[i];
      if (line.listKind == kind) {
        continue;
      }
      if (line.item == null) {
        replacements.add(
          TextReplacement(line.contentStart, line.contentStart, markers[i]),
        );
      } else {
        replacements.addAll(_replaceItemPrefix(lines, line, markers[i]));
      }
    }
  }
  replacements.sort(
    (TextReplacement a, TextReplacement b) => a.from.compareTo(b.from),
  );
  return _transaction(state, replacements, TransactionEvent.list);
}

Transaction? toggleQuote(EditorState state) {
  final _Lines lines = _Lines(state);
  final List<_Line> eligible = <_Line>[
    for (final _Line line in lines.touched())
      if (!line.isPhoto && !line.isTable) line,
  ];
  if (eligible.isEmpty) {
    return null;
  }
  final List<_Line> filled = <_Line>[
    for (final _Line line in eligible)
      if (!line.isBlank) line,
  ];
  final bool removing =
      filled.isNotEmpty &&
      filled.every((_Line line) => line.outerQuoteMarker != null);
  final List<TextReplacement> replacements = removing
      ? <TextReplacement>[
          for (final _Line line in filled)
            TextReplacement(
              line.outerQuoteMarker!.start,
              line.outerQuoteMarker!.end,
              '',
            ),
        ]
      : <TextReplacement>[
          for (final _Line line in eligible)
            if (line.outerQuoteMarker == null)
              TextReplacement(
                line.line.start,
                line.line.start,
                line.isBlank ? '>' : '> ',
              ),
        ];
  return _transaction(state, replacements, TransactionEvent.format);
}

Transaction _transaction(
  EditorState state,
  List<TextReplacement> replacements,
  TransactionEvent event,
) {
  final ChangeSet changes = ChangeSet(
    length: state.source.length,
    replacements: replacements,
  );
  return Transaction(
    changes: changes,
    selection: state.selection.mapped(changes, side: MapSide.after),
    event: event,
  );
}

List<TextReplacement> _setHeading(String source, _Line line, int target) {
  final int level = line.headingLevel;
  if (level == target) {
    return const <TextReplacement>[];
  }
  final MdBlock? heading = line.heading;
  if (heading == null) {
    final String marker = '${'#' * target} ';
    return <TextReplacement>[
      TextReplacement(
        line.contentStart,
        line.contentStart,
        line.isBareMarker(source) ? ' $marker' : marker,
      ),
    ];
  }
  final MdRange opening = heading.markerRanges.first;
  if (target == 0) {
    return <TextReplacement>[
      for (final MdRange marker in heading.markerRanges)
        TextReplacement(marker.start, marker.end, ''),
    ];
  }
  int runEnd = opening.start;
  while (runEnd < opening.end && source.codeUnitAt(runEnd) != _hash) {
    runEnd += 1;
  }
  while (runEnd < opening.end && source.codeUnitAt(runEnd) == _hash) {
    runEnd += 1;
  }
  return target > level
      ? <TextReplacement>[
          TextReplacement(runEnd, runEnd, '#' * (target - level)),
        ]
      : <TextReplacement>[
          TextReplacement(runEnd - (level - target), runEnd, ''),
        ];
}

List<String> _markersFor(
  _Lines lines,
  List<_Line> eligible,
  NoteListKind kind,
) {
  if (kind != NoteListKind.numbered) {
    final String marker = kind == NoteListKind.task ? '- [ ] ' : '- ';
    return <String>[for (final _Line _ in eligible) marker];
  }
  final List<String> markers = <String>[];
  final List<int> counts = <int>[];
  final List<String> delimiters = <String>[];
  int previousIndex = -1;
  for (final _Line line in eligible) {
    if (previousIndex >= 0 &&
        lines.anyOpaqueBetween(previousIndex, line.line.index)) {
      counts.clear();
      delimiters.clear();
    }
    previousIndex = line.line.index;
    final int depth = line.depth;
    while (counts.length > depth + 1) {
      counts.removeLast();
      delimiters.removeLast();
    }
    while (counts.length < depth + 1) {
      counts.add(0);
      delimiters.add('.');
    }
    counts[depth] += 1;
    final String? existing = line.orderedDelimiter(lines.source);
    if (existing != null) {
      delimiters[depth] = existing;
    }
    markers.add('${counts[depth]}${delimiters[depth]} ');
  }
  return markers;
}

List<TextReplacement> _replaceItemPrefix(
  _Lines lines,
  _Line line,
  String marker,
) {
  final MdBlock item = line.item!;
  final String source = lines.source;
  final MdRange first = item.markerRanges.first;
  int markerStart = first.start;
  while (markerStart < first.end &&
      _isSpaceOrTab(source.codeUnitAt(markerStart))) {
    markerStart += 1;
  }
  int prefixEnd = first.end;
  final MdRange? box = _taskBox(item);
  if (box != null) {
    prefixEnd = box.end;
    while (prefixEnd < line.line.end &&
        _isSpaceOrTab(source.codeUnitAt(prefixEnd))) {
      prefixEnd += 1;
    }
  }
  final int oldWidth = first.end - markerStart;
  final int newWidth = marker.startsWith('- [') ? 2 : marker.length;
  final int delta = newWidth - oldWidth;
  return <TextReplacement>[
    TextReplacement(markerStart, prefixEnd, marker),
    if (delta != 0) ..._shiftSubtree(lines, item, delta),
  ];
}

List<TextReplacement> _shiftSubtree(_Lines lines, MdBlock item, int delta) {
  final String source = lines.source;
  final MdSourceLines split = lines.split;
  final int firstLine = split.lineIndexAt(item.sourceRange.start);
  final int lastLine = split.lineIndexAt(item.sourceRange.end);
  final MdRange? box = _taskBox(item);
  final List<TextReplacement> replacements = <TextReplacement>[];
  for (int index = firstLine + 1; index <= lastLine; index++) {
    final MdSourceLine line = split.lines[index];
    MdRange? consumed;
    for (final MdRange marker in item.markerRanges.skip(1)) {
      if (marker != box &&
          marker.start >= line.start &&
          marker.end <= line.end) {
        consumed = marker;
        break;
      }
    }
    if (consumed == null) {
      continue;
    }
    if (delta > 0) {
      replacements.add(
        TextReplacement(consumed.start, consumed.start, ' ' * delta),
      );
    } else {
      int end = consumed.start;
      while (end < consumed.end &&
          end - consumed.start < -delta &&
          source.codeUnitAt(end) == _space) {
        end += 1;
      }
      if (end > consumed.start) {
        replacements.add(TextReplacement(consumed.start, end, ''));
      }
    }
  }
  return replacements;
}

MdRange? _taskBox(MdBlock item) {
  final MdBlockData? data = item.data;
  return data is MdListItemData ? data.taskBoxRange : null;
}

final class _Lines {
  _Lines(EditorState state)
    : source = state.source,
      selection = state.selection,
      tree = state.tree,
      split = MdSourceLines.split(state.source);

  final String source;
  final NoteSelection selection;
  final MdTree tree;
  final MdSourceLines split;

  List<_Line> touched() {
    final int first = split.lineIndexAt(selection.start);
    int last = split.lineIndexAt(selection.end);
    if (!selection.isCollapsed &&
        last > first &&
        split.lines[last].start == selection.end) {
      last -= 1;
    }
    return <_Line>[for (int i = first; i <= last; i++) lineAt(i)];
  }

  bool anyOpaqueBetween(int from, int to) {
    for (int i = from + 1; i < to; i++) {
      if (lineAt(i).isOpaque) {
        return true;
      }
    }
    return false;
  }

  _Line lineAt(int index) {
    final MdSourceLine line = split.lines[index];
    final List<MdBlock> chain = <MdBlock>[];
    List<MdBlock> level = tree.blocks;
    while (true) {
      MdBlock? found;
      for (final MdBlock block in level) {
        if (block.sourceRange.start <= line.end &&
            block.sourceRange.end >= line.start) {
          found = block;
          break;
        }
        if (block.sourceRange.start > line.end) {
          break;
        }
      }
      if (found == null) {
        break;
      }
      chain.add(found);
      level = found.blocks;
    }
    return _Line(source, line, chain);
  }
}

final class _Line {
  factory _Line(String source, MdSourceLine line, List<MdBlock> chain) {
    int prefixEnd = line.start;
    int depth = 0;
    MdRange? outerQuoteMarker;
    MdBlock? item;
    for (final MdBlock block in chain) {
      if (block.kind == MdBlockKind.listItem &&
          block.sourceRange.start >= line.start) {
        item = block;
        continue;
      }
      if (item != null ||
          (block.kind != MdBlockKind.blockQuote &&
              block.kind != MdBlockKind.listItem)) {
        continue;
      }
      MdRange? marker;
      for (final MdRange range in block.markerRanges) {
        if (range.start >= prefixEnd && range.end <= line.end) {
          marker = range;
          break;
        }
      }
      if (marker == null) {
        break;
      }
      if (block.kind == MdBlockKind.blockQuote) {
        outerQuoteMarker ??= marker;
      }
      prefixEnd = marker.end;
      depth += 1;
    }
    int contentStart = prefixEnd;
    if (item != null) {
      contentStart = item.markerRanges.first.end;
      final MdRange? box = _taskBox(item);
      if (box != null) {
        contentStart = box.end;
      }
    }
    while (contentStart < line.end &&
        _isSpaceOrTab(source.codeUnitAt(contentStart))) {
      contentStart += 1;
    }
    bool isBlank = true;
    for (int i = line.start; i < line.end; i++) {
      if (!_isSpaceOrTab(source.codeUnitAt(i))) {
        isBlank = false;
        break;
      }
    }
    final MdBlock? leaf = chain.isEmpty ? null : chain.last;
    return _Line._(
      line: line,
      chain: chain,
      prefixEnd: prefixEnd,
      contentStart: contentStart,
      depth: depth,
      item: item,
      outerQuoteMarker: outerQuoteMarker,
      heading: leaf?.kind == MdBlockKind.heading ? leaf : null,
      isBlank: isBlank,
    );
  }

  const _Line._({
    required this.line,
    required this.chain,
    required this.prefixEnd,
    required this.contentStart,
    required this.depth,
    required this.item,
    required this.outerQuoteMarker,
    required this.heading,
    required this.isBlank,
  });

  final MdSourceLine line;
  final List<MdBlock> chain;
  final int prefixEnd;
  final int contentStart;
  final int depth;
  final MdBlock? item;
  final MdRange? outerQuoteMarker;
  final MdBlock? heading;
  final bool isBlank;

  bool get isPhoto =>
      chain.any((MdBlock block) => block.kind == MdBlockKind.photoLine);

  bool get isTable => chain.isNotEmpty && chain.first.kind == MdBlockKind.table;

  bool get isOpaque =>
      isTable ||
      chain.any(
        (MdBlock block) =>
            block.kind == MdBlockKind.fencedCode ||
            block.kind == MdBlockKind.photoLine ||
            block.kind == MdBlockKind.thematicBreak,
      );

  bool get continuesParagraph =>
      item == null &&
      chain.isNotEmpty &&
      chain.last.kind == MdBlockKind.paragraph &&
      chain.any((MdBlock block) => block.kind == MdBlockKind.listItem);

  int get headingLevel {
    final MdBlockData? data = heading?.data;
    return data is MdHeadingData ? data.level : 0;
  }

  NoteListKind? get listKind {
    final MdBlock? current = item;
    if (current == null) {
      return null;
    }
    if (_taskBox(current) != null) {
      return NoteListKind.task;
    }
    final MdBlock list = chain[chain.indexOf(current) - 1];
    return list.kind == MdBlockKind.orderedList
        ? NoteListKind.numbered
        : NoteListKind.bullet;
  }

  bool isBareMarker(String source) {
    final MdBlock? current = item;
    if (current == null || _taskBox(current) != null) {
      return false;
    }
    final MdRange first = current.markerRanges.first;
    return first.end == line.end &&
        !_isSpaceOrTab(source.codeUnitAt(first.end - 1));
  }

  String? orderedDelimiter(String source) {
    final MdBlock? current = item;
    if (current == null || listKind != NoteListKind.numbered) {
      return null;
    }
    final MdRange first = current.markerRanges.first;
    for (int i = first.start; i < first.end; i++) {
      final int unit = source.codeUnitAt(i);
      if (unit == _period || unit == _closeParen) {
        return String.fromCharCode(unit);
      }
    }
    return null;
  }
}

bool _isSpaceOrTab(int unit) => unit == _space || unit == _tab;

const int _space = 0x20;
const int _tab = 0x09;
const int _hash = 0x23;
const int _period = 0x2E;
const int _closeParen = 0x29;
