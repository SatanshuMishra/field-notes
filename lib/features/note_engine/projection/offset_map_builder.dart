import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:field_notes/features/note_engine/projection/visible_text_builder.dart';

List<ProjectedPiece> spliceAtomicPiece(
  List<ProjectedPiece> pieces,
  ProjectedPiece replacement,
) {
  final int start = replacement.sourceStart;
  final int end = replacement.sourceEnd;
  if (end <= start) {
    throw ArgumentError.value(replacement, 'replacement', 'range is empty');
  }
  if (pieces.isEmpty ||
      start < pieces.first.sourceStart ||
      end > pieces.last.sourceEnd) {
    throw ArgumentError.value(
      replacement,
      'replacement',
      'range lies outside the pieces',
    );
  }
  final List<ProjectedPiece> result = <ProjectedPiece>[];
  bool placed = false;
  for (final ProjectedPiece piece in pieces) {
    if (piece.sourceEnd <= start) {
      result.add(piece);
      continue;
    }
    if (piece.sourceStart >= end) {
      if (!placed) {
        result.add(replacement);
        placed = true;
      }
      result.add(piece);
      continue;
    }
    final bool cutsBefore = piece.sourceStart < start;
    final bool cutsAfter = piece.sourceEnd > end;
    if (piece.atomic != null && (cutsBefore || cutsAfter)) {
      throw ArgumentError.value(
        replacement,
        'replacement',
        'would cut the atomic piece $piece',
      );
    }
    if (cutsBefore) {
      result.add(_part(piece, piece.sourceStart, start));
    }
    if (!placed) {
      result.add(replacement);
      placed = true;
    }
    if (cutsAfter) {
      result.add(_part(piece, end, piece.sourceEnd));
    }
  }
  if (!placed) {
    result.add(replacement);
  }
  return List<ProjectedPiece>.unmodifiable(result);
}

ProjectedPiece _part(ProjectedPiece piece, int start, int end) =>
    ProjectedPiece(
      sourceStart: start,
      sourceEnd: end,
      text: piece.isHidden
          ? ''
          : piece.text.substring(
              start - piece.sourceStart,
              end - piece.sourceStart,
            ),
      dimmed: piece.dimmed,
    );

final class VisibleLineIndex {
  VisibleLineIndex(this.visible);

  final VisibleText visible;

  int? lineForSource(int sourceLine) {
    if (sourceLine < 0) {
      throw RangeError.range(sourceLine, 0, null, 'sourceLine');
    }
    final List<VisibleLine> lines = visible.lines;
    int low = 0;
    int high = lines.length - 1;
    while (low <= high) {
      final int mid = (low + high) >> 1;
      final int found = lines[mid].sourceLine;
      if (found == sourceLine) {
        return mid;
      }
      if (found < sourceLine) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return null;
  }

  int? lineAtVisible(int visibleOffset) {
    if (visibleOffset < 0 || visibleOffset > visible.text.length) {
      throw RangeError.range(
        visibleOffset,
        0,
        visible.text.length,
        'visibleOffset',
      );
    }
    final List<VisibleLine> lines = visible.lines;
    int low = 0;
    int high = lines.length - 1;
    int? found;
    while (low <= high) {
      final int mid = (low + high) >> 1;
      if (lines[mid].visibleRange.start <= visibleOffset) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return found;
  }

  int? lineAtSource(int sourceOffset) {
    if (sourceOffset < 0 || sourceOffset > visible.sourceLength) {
      throw RangeError.range(
        sourceOffset,
        0,
        visible.sourceLength,
        'sourceOffset',
      );
    }
    return lineAtVisible(visible.map.sourceToVisible(sourceOffset));
  }
}
