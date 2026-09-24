import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/caret_geometry.dart';
import 'package:field_notes/features/note_engine/layout/float_flow.dart';
import 'package:field_notes/features/note_engine/layout/hit_testing.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/foundation.dart' show mapEquals, setEquals;
import 'package:flutter/painting.dart';

typedef ActiveLayout = NoteFlow Function(int activeLine, {int? activeCell});

TextPosition findVerticalTarget({
  required NoteFlow flow,
  required int position,
  required TextAffinity affinity,
  required double goalX,
  required VerticalMove direction,
  required ActiveLayout layoutWithActive,
}) {
  final _Stops stops = _Stops(flow, goalX);
  final LocatedLine located = CaretGeometry(
    flow: flow,
  ).locate(position, affinity);
  final _Stop? target = direction == VerticalMove.down
      ? stops.below(located)
      : stops.above(located);
  if (target == null) {
    return TextPosition(
      offset: direction == VerticalMove.down ? flow.inputs.source.length : 0,
    );
  }
  final PlacedPhoto? photo = target.photo;
  if (photo != null) {
    return TextPosition(offset: photo.sourceRange.start);
  }
  final LocatedLine line = target.line!;
  final VisibleText visible = flow.inputs.visibleText;
  final int sourceOffset = visible.map
      .visibleToSource(line.line.visibleRange.start)
      .downstream;
  final int sourceLine = _sourceLineOf(visible, sourceOffset);
  final int? column = line.fragment.tableColumn;
  if (sourceLine == flow.inputs.activeLine && column == null) {
    return NoteHitTester(flow: flow).positionInLine(line.line, goalX);
  }
  final NoteFlow active = layoutWithActive(sourceLine, activeCell: column);
  final LocatedLine placed = CaretGeometry(
    flow: active,
  ).locate(sourceOffset, TextAffinity.downstream);
  return NoteHitTester(flow: active).positionInLine(placed.line, goalX);
}

final class VerticalGoal {
  VerticalGoal._({
    required this.x,
    required this.position,
    required this.source,
    required this.columnWidth,
    required this.textScaler,
    required this.mediaDimensions,
    required this.unavailableMedia,
  });

  factory VerticalGoal.start(
    LayoutInputs inputs, {
    required double x,
    required int position,
  }) => VerticalGoal._(
    x: x,
    position: position,
    source: inputs.source,
    columnWidth: inputs.columnWidth,
    textScaler: inputs.textScaler,
    mediaDimensions: inputs.mediaDimensions,
    unavailableMedia: inputs.unavailableMedia,
  );

  final double x;
  final int position;
  final String source;
  final double columnWidth;
  final TextScaler textScaler;
  final Map<String, Size> mediaDimensions;
  final Set<String> unavailableMedia;

  bool holdsFor(LayoutInputs inputs, int caret) =>
      caret == position &&
      inputs.source == source &&
      inputs.columnWidth == columnWidth &&
      inputs.textScaler == textScaler &&
      mapEquals(inputs.mediaDimensions, mediaDimensions) &&
      setEquals(inputs.unavailableMedia, unavailableMedia);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VerticalGoal &&
          x == other.x &&
          position == other.position &&
          source == other.source &&
          columnWidth == other.columnWidth &&
          textScaler == other.textScaler &&
          mapEquals(mediaDimensions, other.mediaDimensions) &&
          setEquals(unavailableMedia, other.unavailableMedia);

  @override
  int get hashCode => Object.hash(
    x,
    position,
    source,
    columnWidth,
    textScaler,
    Object.hashAllUnordered(<int>[
      for (final MapEntry<String, Size> entry in mediaDimensions.entries)
        Object.hash(entry.key, entry.value),
    ]),
    Object.hashAllUnordered(unavailableMedia),
  );

  @override
  String toString() =>
      'VerticalGoal(x: $x, position: $position, width: $columnWidth)';
}

final class VerticalStep {
  const VerticalStep({required this.position, required this.goal});

  final TextPosition position;
  final VerticalGoal goal;
}

VerticalStep moveVertically({
  required LayoutInputs inputs,
  required int caret,
  required TextAffinity affinity,
  required VerticalMove direction,
  required VerticalGoal? goal,
  required double Function(int position, TextAffinity affinity) caretX,
  required TextPosition Function(
    int position,
    TextAffinity affinity,
    double goalX,
    VerticalMove direction,
  )
  target,
}) {
  final VerticalGoal? kept = goal;
  final double x = kept != null && kept.holdsFor(inputs, caret)
      ? kept.x
      : caretX(caret, affinity);
  final TextPosition position = target(caret, affinity, x, direction);
  return VerticalStep(
    position: position,
    goal: VerticalGoal.start(inputs, x: x, position: position.offset),
  );
}

int _sourceLineOf(VisibleText visible, int sourceOffset) {
  final List<VisibleLine> lines = visible.lines;
  int low = 0;
  int high = lines.length;
  while (low < high) {
    final int mid = (low + high) >> 1;
    if (lines[mid].sourceRange.start <= sourceOffset) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low == 0 ? 0 : lines[low - 1].sourceLine;
}

final class _Stop {
  const _Stop.photo(PlacedPhoto this.photo) : line = null;

  const _Stop.line(LocatedLine this.line) : photo = null;

  final PlacedPhoto? photo;
  final LocatedLine? line;
}

final class _Stops {
  const _Stops(this.flow, this.goalX);

  final NoteFlow flow;
  final double goalX;

  _Stop? below(LocatedLine current) {
    final LaidOutRow row = flow.rows[current.fragment.rowIndex];
    final _Stop? inside = switch (row.row.kind) {
      LayoutRowKind.photo => null,
      LayoutRowKind.table => _tableStep(row, current, down: true),
      _ => _textStep(row, current, down: true),
    };
    return inside ?? _enterRow(current.fragment.rowIndex + 1, down: true);
  }

  _Stop? above(LocatedLine current) {
    final LaidOutRow row = flow.rows[current.fragment.rowIndex];
    final _Stop? inside = switch (row.row.kind) {
      LayoutRowKind.photo => null,
      LayoutRowKind.table => _tableStep(row, current, down: false),
      _ => _textStep(row, current, down: false),
    };
    return inside ?? _enterRow(current.fragment.rowIndex - 1, down: false);
  }

  _Stop? _enterRow(int from, {required bool down}) {
    for (
      int i = from;
      i >= 0 && i < flow.rows.length;
      i = down ? i + 1 : i - 1
    ) {
      final LaidOutRow row = flow.rows[i];
      if (row.fragments.isEmpty) {
        continue;
      }
      switch (row.row.kind) {
        case LayoutRowKind.photo:
          final PlacedPhoto? photo = _photoOf(i);
          if (photo != null) {
            return _Stop.photo(photo);
          }
        case LayoutRowKind.table:
          final List<List<LineFragment>> table = _tableRows(row);
          if (table.isEmpty) {
            continue;
          }
          final LineFragment cell = _cellUnderGoal(
            down ? table.first : table.last,
          );
          return _Stop.line((
            fragment: cell,
            line: down ? cell.lines.first : cell.lines.last,
          ));
        default:
          final List<LocatedLine> lines = _contentLines(row);
          if (lines.isNotEmpty) {
            return _Stop.line(down ? lines.first : lines.last);
          }
      }
    }
    return null;
  }

  _Stop? _textStep(LaidOutRow row, LocatedLine current, {required bool down}) {
    final List<LocatedLine> lines = _contentLines(row);
    final LocatedLine anchor = _contentOf(current);
    final int index = lines.indexWhere(
      (LocatedLine line) =>
          identical(line.fragment, anchor.fragment) && line.line == anchor.line,
    );
    if (index < 0) {
      return null;
    }
    final int next = down ? index + 1 : index - 1;
    return next >= 0 && next < lines.length ? _Stop.line(lines[next]) : null;
  }

  _Stop? _tableStep(LaidOutRow row, LocatedLine current, {required bool down}) {
    final List<VisualLine> own = current.fragment.lines;
    final int index = own.indexOf(current.line);
    final int next = down ? index + 1 : index - 1;
    if (index >= 0 && next >= 0 && next < own.length) {
      return _Stop.line((fragment: current.fragment, line: own[next]));
    }
    final List<List<LineFragment>> table = _tableRows(row);
    final int tableRow = table.indexWhere(
      (List<LineFragment> cells) =>
          cells.any((LineFragment cell) => identical(cell, current.fragment)),
    );
    final int target = down ? tableRow + 1 : tableRow - 1;
    if (tableRow < 0 || target < 0 || target >= table.length) {
      return null;
    }
    final LineFragment cell = _cellUnderGoal(table[target]);
    return _Stop.line((
      fragment: cell,
      line: down ? cell.lines.first : cell.lines.last,
    ));
  }

  LocatedLine _contentOf(LocatedLine current) {
    if (current.fragment.kind != FragmentKind.marker) {
      return current;
    }
    final double y = current.line.top + current.line.height / 2;
    for (final LocatedLine member in NoteHitTester(
      flow: flow,
    ).visualLineAt(current, y)) {
      if (member.fragment.kind != FragmentKind.marker) {
        return member;
      }
    }
    return current;
  }

  List<LocatedLine> _contentLines(LaidOutRow row) => <LocatedLine>[
    for (final LineFragment fragment in row.fragments)
      if (fragment.kind != FragmentKind.marker &&
          fragment.kind != FragmentKind.photo)
        for (final VisualLine line in fragment.lines)
          (fragment: fragment, line: line),
  ];

  List<List<LineFragment>> _tableRows(LaidOutRow row) {
    final List<List<LineFragment>> rows = <List<LineFragment>>[];
    List<LineFragment> current = <LineFragment>[];
    int previous = -1;
    for (final LineFragment cell in row.fragments) {
      final int column = cell.tableColumn ?? 0;
      if (column <= previous && current.isNotEmpty) {
        rows.add(List<LineFragment>.unmodifiable(current));
        current = <LineFragment>[];
      }
      current = <LineFragment>[...current, cell];
      previous = column;
    }
    if (current.isNotEmpty) {
      rows.add(List<LineFragment>.unmodifiable(current));
    }
    return rows;
  }

  LineFragment _cellUnderGoal(List<LineFragment> cells) {
    LineFragment best = cells.first;
    double bestDistance = double.infinity;
    for (final LineFragment cell in cells) {
      final double left = cell.origin.dx;
      final double right = left + cell.layoutWidth;
      final double distance = goalX < left
          ? left - goalX
          : goalX > right
          ? goalX - right
          : 0;
      if (distance < bestDistance) {
        best = cell;
        bestDistance = distance;
      }
    }
    return best;
  }

  PlacedPhoto? _photoOf(int rowIndex) {
    for (final PlacedPhoto photo in flow.photos) {
      if (photo.rowIndex == rowIndex) {
        return photo;
      }
    }
    return null;
  }
}
