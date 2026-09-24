import 'markdown/markdown.dart';

const String plainParagraphBreak = '\n\n';
const String plainListBreak = '\n';

const int _space = 0x20;
const int _tab = 0x09;
const int _lineFeed = 0x0A;
const int _carriageReturn = 0x0D;

enum NotePlainKind { paragraph, heading, listItem, code, table, photo }

final class NotePlainSegment {
  const NotePlainSegment({required this.kind, required this.text});

  final NotePlainKind kind;
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotePlainSegment && kind == other.kind && text == other.text;

  @override
  int get hashCode => Object.hash(kind, text);

  @override
  String toString() => "NotePlainSegment(${kind.name}, '$text')";
}

String plainTextOf(String source, {bool tables = true}) =>
    joinNotePlainSegments(
      notePlainSegments(parseNoteTree(source, tables: tables), source),
    );

List<NotePlainSegment> notePlainSegments(MdTree tree, String source) {
  if (tree.sourceLength != source.length) {
    throw ArgumentError.value(
      tree.sourceLength,
      'tree.sourceLength',
      'must equal the source length ${source.length}',
    );
  }
  final _Extractor extractor = _Extractor(source, _mergedMarkersOf(tree));
  return <NotePlainSegment>[
    for (final MdBlock block in tree.blocks) ...extractor.segmentsOf(block),
  ];
}

String joinNotePlainSegments(Iterable<NotePlainSegment> segments) {
  final StringBuffer buffer = StringBuffer();
  NotePlainSegment? previous;
  for (final NotePlainSegment segment in segments) {
    if (segment.text.isEmpty) {
      continue;
    }
    if (previous != null) {
      buffer.write(
        previous.kind == NotePlainKind.listItem &&
                segment.kind == NotePlainKind.listItem
            ? plainListBreak
            : plainParagraphBreak,
      );
    }
    buffer.write(segment.text);
    previous = segment;
  }
  return buffer.toString();
}

final class _Extractor {
  const _Extractor(this.source, this.markers);

  final String source;
  final List<MdRange> markers;

  Iterable<NotePlainSegment> segmentsOf(MdBlock block) sync* {
    switch (block.kind) {
      case MdBlockKind.paragraph:
        yield NotePlainSegment(
          kind: NotePlainKind.paragraph,
          text: _visible(block.sourceRange),
        );
      case MdBlockKind.heading:
        yield NotePlainSegment(
          kind: NotePlainKind.heading,
          text: _visible(block.sourceRange),
        );
      case MdBlockKind.fencedCode:
        yield NotePlainSegment(kind: NotePlainKind.code, text: _code(block));
      case MdBlockKind.table:
        yield NotePlainSegment(kind: NotePlainKind.table, text: _table(block));
      case MdBlockKind.photoLine:
        final MdPhotoLineData? photo = block.photoLine;
        if (photo != null) {
          yield NotePlainSegment(
            kind: NotePlainKind.photo,
            text: photo.caption,
          );
        }
      case MdBlockKind.bulletList || MdBlockKind.orderedList:
        for (final MdBlock item in block.blocks) {
          yield* _itemSegments(item);
        }
      case MdBlockKind.listItem:
        yield* _itemSegments(block);
      case MdBlockKind.blockQuote:
        for (final MdBlock child in block.blocks) {
          yield* segmentsOf(child);
        }
      case MdBlockKind.thematicBreak ||
          MdBlockKind.blankLine ||
          MdBlockKind.tableRow ||
          MdBlockKind.tableCell:
        break;
    }
  }

  Iterable<NotePlainSegment> _itemSegments(MdBlock item) sync* {
    final List<MdBlock> children = item.blocks;
    if (children.isEmpty) {
      return;
    }
    final MdBlock first = children.first;
    final bool leadsWithParagraph = first.kind == MdBlockKind.paragraph;
    if (leadsWithParagraph) {
      yield NotePlainSegment(
        kind: NotePlainKind.listItem,
        text: _visible(first.sourceRange),
      );
    }
    for (final MdBlock child in children.skip(leadsWithParagraph ? 1 : 0)) {
      yield* segmentsOf(child);
    }
  }

  String _table(MdBlock table) => <String>[
    for (final MdBlock row in table.blocks)
      <String>[
        for (final MdBlock cell in row.blocks) _visible(cell.sourceRange),
      ].join('\t'),
  ].join('\n');

  String _code(MdBlock block) {
    final String text = _visible(block.contentRange);
    final MdBlockData? data = block.data;
    if (data is MdFenceData && data.isClosed) {
      return text;
    }
    int end = text.length;
    while (end > 0) {
      final int lineStart = text.lastIndexOf('\n', end - 1) + 1;
      if (!_isBlank(text, lineStart, end)) {
        return text.substring(0, end);
      }
      end = lineStart == 0 ? 0 : lineStart - 1;
    }
    return '';
  }

  String _visible(MdRange range) {
    final StringBuffer buffer = StringBuffer();
    int low = 0;
    int high = markers.length;
    while (low < high) {
      final int mid = (low + high) >> 1;
      if (markers[mid].end <= range.start) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    int position = range.start;
    for (
      int index = low;
      index < markers.length && markers[index].start < range.end;
      index++
    ) {
      final MdRange marker = markers[index];
      if (marker.start > position) {
        _writeContent(buffer, position, marker.start);
      }
      if (marker.end > position) {
        position = marker.end;
      }
    }
    if (position < range.end) {
      _writeContent(buffer, position, range.end);
    }
    return buffer.toString();
  }

  void _writeContent(StringBuffer buffer, int start, int end) {
    int runStart = start;
    for (int at = start; at < end; at++) {
      final bool crBeforeLf =
          source.codeUnitAt(at) == _carriageReturn &&
          at + 1 < source.length &&
          source.codeUnitAt(at + 1) == _lineFeed;
      if (crBeforeLf) {
        buffer.write(source.substring(runStart, at));
        if (at + 1 >= end) {
          buffer.writeCharCode(_lineFeed);
        }
        runStart = at + 1;
      }
    }
    buffer.write(source.substring(runStart, end));
  }
}

bool _isBlank(String text, int start, int end) {
  for (int at = start; at < end; at++) {
    final int unit = text.codeUnitAt(at);
    if (unit != _space && unit != _tab) {
      return false;
    }
  }
  return true;
}

List<MdRange> _mergedMarkersOf(MdTree tree) {
  final List<MdRange> collected = <MdRange>[];
  final List<MdNode> pending = <MdNode>[...tree.blocks];
  while (pending.isNotEmpty) {
    final MdNode node = pending.removeLast();
    collected.addAll(node.markerRanges);
    pending.addAll(node.children);
  }
  final List<MdRange> sorted = <MdRange>[
    for (final MdRange range in collected)
      if (!range.isEmpty) range,
  ]..sort((MdRange a, MdRange b) => a.start.compareTo(b.start));
  final List<MdRange> merged = <MdRange>[];
  for (final MdRange range in sorted) {
    if (merged.isNotEmpty && range.start <= merged.last.end) {
      final MdRange last = merged.removeLast();
      merged.add(
        MdRange(last.start, range.end > last.end ? range.end : last.end),
      );
    } else {
      merged.add(range);
    }
  }
  return merged;
}
