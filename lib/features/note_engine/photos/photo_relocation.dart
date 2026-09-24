import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:flutter/foundation.dart';

const int _lineFeed = 0x0A;
const int _carriageReturn = 0x0D;
const int _space = 0x20;
const int _tab = 0x09;

@immutable
final class PhotoEdit {
  const PhotoEdit({required this.changes, required this.selection});

  final ChangeSet changes;
  final NoteSelection selection;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoEdit &&
          changes == other.changes &&
          selection == other.selection;

  @override
  int get hashCode => Object.hash(changes, selection);

  @override
  String toString() => 'PhotoEdit($changes, $selection)';
}

sealed class PhotoTarget {
  const PhotoTarget();
}

final class PhotoBoundaryTarget extends PhotoTarget {
  const PhotoBoundaryTarget(this.boundary);

  final int boundary;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoBoundaryTarget && boundary == other.boundary;

  @override
  int get hashCode => boundary.hashCode;

  @override
  String toString() => 'PhotoBoundaryTarget($boundary)';
}

final class PhotoEmptyLineTarget extends PhotoTarget {
  const PhotoEmptyLineTarget(this.start, this.end);

  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoEmptyLineTarget && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'PhotoEmptyLineTarget($start, $end)';
}

List<MdBlock> photoRelocationUnits(MdTree tree) => tree.blocks;

MdRange photoLineRange(String source, MdBlock photo) {
  _checkPhotoKind(photo);
  return photo.sourceRange;
}

NoteSelection photoSelection(String source, MdBlock photo) {
  final MdRange line = photoLineRange(source, photo);
  return NoteSelection(anchor: line.start, head: line.end);
}

String noteLineBreak(String source) {
  final int firstLineFeed = source.indexOf('\n');
  return firstLineFeed > 0 &&
          source.codeUnitAt(firstLineFeed - 1) == _carriageReturn
      ? '\r\n'
      : '\n';
}

List<int> photoBoundaries(String source, MdTree tree) {
  _checkTree(source, tree);
  return List<int>.unmodifiable(<int>[
    0,
    for (final MdBlock unit in tree.blocks)
      if (!_isUnclosedFence(unit)) unit.sourceRange.end,
  ]);
}

int? photoMoveUpBoundary(String source, MdTree tree, MdBlock photo) {
  _checkTree(source, tree);
  final int index = _photoIndex(tree, photo);
  if (index == 0) {
    return null;
  }
  return index == 1 ? 0 : tree.blocks[index - 2].sourceRange.end;
}

int? photoMoveDownBoundary(String source, MdTree tree, MdBlock photo) {
  _checkTree(source, tree);
  final int index = _photoIndex(tree, photo);
  if (index == tree.blocks.length - 1) {
    return null;
  }
  final MdBlock next = tree.blocks[index + 1];
  return _isUnclosedFence(next) ? null : next.sourceRange.end;
}

PhotoEdit photoRemoval(String source, MdTree tree, MdBlock photo) {
  _checkTree(source, tree);
  final int index = _photoIndex(tree, photo);
  final MdRange deletion = _removalRange(source, tree, index);
  final ChangeSet changes = ChangeSet.single(
    source.length,
    deletion.start,
    deletion.end,
    '',
  );
  return PhotoEdit(
    changes: changes,
    selection: NoteSelection.collapsed(
      changes.mapPosition(
        _caretAfterRemoval(source, photo.sourceRange),
        side: MapSide.before,
      ),
    ),
  );
}

PhotoEdit? photoRelocation(
  String source,
  MdTree tree,
  MdBlock photo,
  int boundary,
) {
  _checkTree(source, tree);
  final int index = _photoIndex(tree, photo);
  _checkOffset(source, boundary, 'boundary');
  if (!photoBoundaries(source, tree).contains(boundary)) {
    return null;
  }
  final int before = index == 0 ? 0 : tree.blocks[index - 1].sourceRange.end;
  if (boundary == before || boundary == photo.sourceRange.end) {
    return null;
  }
  final String token = _token(source, photo.sourceRange);
  final String lineBreak = noteLineBreak(source);
  final MdRange deletion = _removalRange(source, tree, index);
  final String inserted = boundary == 0
      ? '$token$lineBreak'
      : '$lineBreak$token';
  final TextReplacement insertion = TextReplacement(
    boundary,
    boundary,
    inserted,
  );
  final TextReplacement removal = TextReplacement(
    deletion.start,
    deletion.end,
    '',
  );
  final bool insertsFirst = boundary < deletion.start;
  final int tokenStart =
      (insertsFirst ? boundary : boundary - deletion.length) +
      (boundary == 0 ? 0 : lineBreak.length);
  return PhotoEdit(
    changes: ChangeSet(
      length: source.length,
      replacements: insertsFirst
          ? <TextReplacement>[insertion, removal]
          : <TextReplacement>[removal, insertion],
    ),
    selection: NoteSelection(
      anchor: tokenStart,
      head: tokenStart + token.length,
    ),
  );
}

PhotoTarget photoTargetAt(String source, MdTree tree, int caret) {
  _checkTree(source, tree);
  _checkOffset(source, caret, 'caret');
  final List<MdBlock> units = tree.blocks;
  int? holder;
  for (int i = 0; i < units.length; i++) {
    if (_firstLineStart(source, units[i]) <= caret) {
      holder = i;
    } else {
      break;
    }
  }
  final int lineStart = _lineStartAt(source, caret);
  final int lineEnd = _lineContentEnd(source, lineStart);
  final bool insideUnit =
      holder != null && caret <= units[holder].sourceRange.end;
  if (!insideUnit && _isBlank(source, lineStart, lineEnd)) {
    return PhotoEmptyLineTarget(lineStart, lineEnd);
  }
  if (holder == null) {
    return const PhotoBoundaryTarget(0);
  }
  if (_isUnclosedFence(units[holder])) {
    return PhotoBoundaryTarget(
      holder == 0 ? 0 : units[holder - 1].sourceRange.end,
    );
  }
  return PhotoBoundaryTarget(units[holder].sourceRange.end);
}

PhotoEdit photoInsertion(
  String source,
  PhotoTarget target,
  List<String> references,
) {
  if (references.isEmpty) {
    throw ArgumentError.value(references, 'references', 'must not be empty');
  }
  final String lineBreak = noteLineBreak(source);
  final String lastLine = canonicalPhotoLine(
    references.last,
    '',
    const MdPhotoPlacement(),
  );
  final String lines = <String>[
    for (final String reference in references)
      canonicalPhotoLine(reference, '', const MdPhotoPlacement()),
  ].join(lineBreak);
  final (int from, int to, String inserted, int linesStart) = switch (target) {
    PhotoBoundaryTarget(boundary: final int b) when b == 0 => (
      0,
      0,
      '$lines$lineBreak',
      0,
    ),
    PhotoBoundaryTarget(boundary: final int b) => (
      b,
      b,
      b == source.length ? '$lineBreak$lines$lineBreak' : '$lineBreak$lines',
      b + lineBreak.length,
    ),
    PhotoEmptyLineTarget(start: final int s, end: final int e) => (
      s,
      e,
      e == source.length ? '$lines$lineBreak' : lines,
      s,
    ),
  };
  _checkOffset(source, from, 'target');
  _checkOffset(source, to, 'target');
  if (from > to) {
    throw ArgumentError.value(target, 'target', 'start must not pass end');
  }
  final int lastStart = linesStart + lines.length - lastLine.length;
  return PhotoEdit(
    changes: ChangeSet.single(source.length, from, to, inserted),
    selection: NoteSelection(
      anchor: lastStart,
      head: lastStart + lastLine.length,
    ),
  );
}

MdRange _removalRange(String source, MdTree tree, int index) {
  final List<MdBlock> units = tree.blocks;
  final MdRange line = units[index].sourceRange;
  final bool hasBefore = index > 0;
  final bool hasAfter = index < units.length - 1;
  if (!hasBefore && !hasAfter) {
    return line;
  }
  if (!hasBefore) {
    return MdRange(line.start, _firstLineStart(source, units[index + 1]));
  }
  final int previousEnd = units[index - 1].sourceRange.end;
  if (!hasAfter) {
    return MdRange(previousEnd, line.end);
  }
  final int nextStart = _firstLineStart(source, units[index + 1]);
  final int s1 = _lineBreakCount(source, previousEnd, line.start);
  final int s2 = _lineBreakCount(source, line.end, nextStart);
  if (s1 == 1 && s2 == 1) {
    return line;
  }
  return s1 >= s2
      ? MdRange(line.start, nextStart)
      : MdRange(previousEnd, line.end);
}

int _caretAfterRemoval(String source, MdRange line) {
  final int after = _lineBreakLengthAt(source, line.end);
  if (after > 0) {
    return line.end + after;
  }
  if (line.start > 0) {
    final bool crlf =
        line.start >= 2 && source.codeUnitAt(line.start - 2) == _carriageReturn;
    return line.start - (crlf ? 2 : 1);
  }
  return 0;
}

String _token(String source, MdRange line) {
  int start = line.start;
  int end = line.end;
  while (start < end && _isSpaceOrTab(source.codeUnitAt(start))) {
    start += 1;
  }
  while (end > start && _isSpaceOrTab(source.codeUnitAt(end - 1))) {
    end -= 1;
  }
  return source.substring(start, end);
}

int _firstLineStart(String source, MdBlock unit) =>
    _lineStartAt(source, unit.sourceRange.start);

int _lineStartAt(String source, int offset) =>
    offset == 0 ? 0 : source.lastIndexOf('\n', offset - 1) + 1;

int _lineContentEnd(String source, int lineStart) {
  final int lineFeed = source.indexOf('\n', lineStart);
  if (lineFeed < 0) {
    return source.length;
  }
  return lineFeed > lineStart &&
          source.codeUnitAt(lineFeed - 1) == _carriageReturn
      ? lineFeed - 1
      : lineFeed;
}

int _lineBreakLengthAt(String source, int offset) {
  if (offset < source.length && source.codeUnitAt(offset) == _lineFeed) {
    return 1;
  }
  if (offset + 1 < source.length &&
      source.codeUnitAt(offset) == _carriageReturn &&
      source.codeUnitAt(offset + 1) == _lineFeed) {
    return 2;
  }
  return 0;
}

int _lineBreakCount(String source, int from, int to) {
  int count = 0;
  for (int i = from; i < to; i++) {
    if (source.codeUnitAt(i) == _lineFeed) {
      count += 1;
    }
  }
  return count;
}

bool _isBlank(String source, int start, int end) {
  for (int i = start; i < end; i++) {
    if (!_isSpaceOrTab(source.codeUnitAt(i))) {
      return false;
    }
  }
  return true;
}

bool _isSpaceOrTab(int unit) => unit == _space || unit == _tab;

bool _isUnclosedFence(MdBlock unit) {
  final MdBlockData? data = unit.data;
  return unit.kind == MdBlockKind.fencedCode &&
      data is MdFenceData &&
      !data.isClosed;
}

void _checkTree(String source, MdTree tree) {
  if (tree.sourceLength != source.length) {
    throw ArgumentError.value(
      tree.sourceLength,
      'tree',
      'source length must be ${source.length}',
    );
  }
}

void _checkOffset(String source, int offset, String name) {
  if (offset < 0 || offset > source.length) {
    throw ArgumentError.value(
      offset,
      name,
      'must lie within 0 to ${source.length}',
    );
  }
}

void _checkPhotoKind(MdBlock photo) {
  if (photo.kind != MdBlockKind.photoLine) {
    throw ArgumentError.value(photo, 'photo', 'is not a photo line');
  }
}

int _photoIndex(MdTree tree, MdBlock photo) {
  _checkPhotoKind(photo);
  final int start = photo.sourceRange.start;
  final int? index = start > tree.sourceLength
      ? null
      : tree.blockIndexAt(start);
  if (index == null || tree.blocks[index] != photo) {
    throw ArgumentError.value(photo, 'photo', 'is not a unit of the tree');
  }
  return index;
}
