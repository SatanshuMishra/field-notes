import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';

enum AtomicKind { photo, divider, checkbox, listMarker, tableSeparator }

final class AtomicObject {
  const AtomicObject({
    required this.kind,
    required this.sourceRange,
    required this.visibleOffset,
    this.visibleLength = 1,
  });

  final AtomicKind kind;
  final MdRange sourceRange;
  final int visibleOffset;
  final int visibleLength;

  MdRange get visibleRange =>
      MdRange(visibleOffset, visibleOffset + visibleLength);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AtomicObject &&
          kind == other.kind &&
          sourceRange == other.sourceRange &&
          visibleOffset == other.visibleOffset &&
          visibleLength == other.visibleLength;

  @override
  int get hashCode =>
      Object.hash(kind, sourceRange, visibleOffset, visibleLength);

  @override
  String toString() =>
      'AtomicObject(${kind.name}, $sourceRange, $visibleOffset, '
      '$visibleLength)';
}

enum VisibleSpanKind { text, marker, lineBreak, atomic }

final class VisibleSpan {
  const VisibleSpan({
    required this.kind,
    required this.visibleRange,
    required this.sourceRange,
  });

  final VisibleSpanKind kind;
  final MdRange visibleRange;
  final MdRange sourceRange;

  bool get dimmed => kind == VisibleSpanKind.marker;

  bool get mapsAsUnit =>
      kind == VisibleSpanKind.lineBreak || kind == VisibleSpanKind.atomic;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisibleSpan &&
          kind == other.kind &&
          visibleRange == other.visibleRange &&
          sourceRange == other.sourceRange;

  @override
  int get hashCode => Object.hash(kind, visibleRange, sourceRange);

  @override
  String toString() =>
      'VisibleSpan(${kind.name}, v$visibleRange, s$sourceRange)';
}

final class VisibleLine {
  VisibleLine({
    required this.sourceLine,
    required this.sourceRange,
    required this.visibleRange,
    required List<VisibleSpan> spans,
  }) : spans = List<VisibleSpan>.unmodifiable(spans);

  final int sourceLine;
  final MdRange sourceRange;
  final MdRange visibleRange;
  final List<VisibleSpan> spans;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisibleLine &&
          sourceLine == other.sourceLine &&
          sourceRange == other.sourceRange &&
          visibleRange == other.visibleRange &&
          _listEquals(spans, other.spans);

  @override
  int get hashCode =>
      Object.hash(sourceLine, sourceRange, visibleRange, Object.hashAll(spans));

  @override
  String toString() =>
      'VisibleLine($sourceLine, s$sourceRange, v$visibleRange, $spans)';
}

final class SourceOffsets {
  const SourceOffsets(this.upstream, this.downstream);

  final int upstream;
  final int downstream;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceOffsets &&
          upstream == other.upstream &&
          downstream == other.downstream;

  @override
  int get hashCode => Object.hash(upstream, downstream);

  @override
  String toString() => 'SourceOffsets($upstream, $downstream)';
}

final class OffsetMap {
  OffsetMap({
    required List<VisibleSpan> spans,
    required this.sourceLength,
    required this.visibleLength,
  }) : spans = _validatedSpans(spans, sourceLength, visibleLength);

  final List<VisibleSpan> spans;
  final int sourceLength;
  final int visibleLength;

  SourceOffsets visibleToSource(int visibleOffset) {
    if (visibleOffset < 0 || visibleOffset > visibleLength) {
      throw RangeError.range(visibleOffset, 0, visibleLength, 'visibleOffset');
    }
    final int index = _lastSpanWhere(
      (VisibleSpan span) => span.visibleRange.start <= visibleOffset,
    );
    if (index >= 0) {
      final VisibleSpan span = spans[index];
      final int start = span.visibleRange.start;
      if (visibleOffset > start && visibleOffset < span.visibleRange.end) {
        if (span.mapsAsUnit) {
          return SourceOffsets(span.sourceRange.start, span.sourceRange.end);
        }
        final int source = span.sourceRange.start + (visibleOffset - start);
        return SourceOffsets(source, source);
      }
    }
    final bool startsHere =
        index >= 0 && spans[index].visibleRange.start == visibleOffset;
    final int endingIndex = startsHere ? index - 1 : index;
    final int startingIndex = startsHere ? index : -1;
    final int upstream = endingIndex >= 0
        ? spans[endingIndex].sourceRange.end
        : 0;
    final int downstream = startingIndex >= 0
        ? spans[startingIndex].sourceRange.start
        : sourceLength;
    return SourceOffsets(upstream, downstream);
  }

  int sourceToVisible(int sourceOffset) {
    if (sourceOffset < 0 || sourceOffset > sourceLength) {
      throw RangeError.range(sourceOffset, 0, sourceLength, 'sourceOffset');
    }
    final int index = _lastSpanWhere(
      (VisibleSpan span) => span.sourceRange.start <= sourceOffset,
    );
    if (index < 0) {
      return 0;
    }
    final VisibleSpan span = spans[index];
    final MdRange source = span.sourceRange;
    if (sourceOffset > source.end) {
      return span.visibleRange.end;
    }
    if (!span.mapsAsUnit) {
      return span.visibleRange.start + (sourceOffset - source.start);
    }
    return sourceOffset == source.end
        ? span.visibleRange.end
        : span.visibleRange.start;
  }

  int _lastSpanWhere(bool Function(VisibleSpan span) test) {
    int low = 0;
    int high = spans.length - 1;
    int found = -1;
    while (low <= high) {
      final int mid = (low + high) >> 1;
      if (test(spans[mid])) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return found;
  }

  static List<VisibleSpan> _validatedSpans(
    List<VisibleSpan> spans,
    int sourceLength,
    int visibleLength,
  ) {
    if (sourceLength < 0) {
      throw ArgumentError.value(
        sourceLength,
        'sourceLength',
        'must not be negative',
      );
    }
    int visibleEnd = 0;
    int sourceEnd = 0;
    for (int i = 0; i < spans.length; i++) {
      final VisibleSpan span = spans[i];
      final MdRange visible = span.visibleRange;
      final MdRange source = span.sourceRange;
      if (visible.isEmpty) {
        throw ArgumentError.value(span, 'spans[$i]', 'visible range is empty');
      }
      if (visible.start != visibleEnd) {
        throw ArgumentError.value(
          span,
          'spans[$i]',
          'visible range must start at $visibleEnd',
        );
      }
      if (source.start < sourceEnd || source.end > sourceLength) {
        throw ArgumentError.value(
          span,
          'spans[$i]',
          'source range must lie in [$sourceEnd, $sourceLength]',
        );
      }
      switch (span.kind) {
        case VisibleSpanKind.text:
        case VisibleSpanKind.marker:
          if (visible.length != source.length) {
            throw ArgumentError.value(
              span,
              'spans[$i]',
              'visible and source lengths must be equal',
            );
          }
        case VisibleSpanKind.lineBreak:
          if (visible.length != 1 || source.length < 1 || source.length > 2) {
            throw ArgumentError.value(
              span,
              'spans[$i]',
              'a line break is one visible unit over one or two source units',
            );
          }
        case VisibleSpanKind.atomic:
          if (source.isEmpty) {
            throw ArgumentError.value(
              span,
              'spans[$i]',
              'source range is empty',
            );
          }
      }
      visibleEnd = visible.end;
      sourceEnd = source.end;
    }
    if (visibleEnd != visibleLength) {
      throw ArgumentError.value(
        visibleLength,
        'visibleLength',
        'spans end at $visibleEnd',
      );
    }
    return List<VisibleSpan>.unmodifiable(spans);
  }
}

final class VisibleText {
  VisibleText({
    required this.text,
    required this.sourceLength,
    required List<VisibleLine> lines,
    required List<AtomicObject> atomics,
    this.activeLine,
  }) : lines = List<VisibleLine>.unmodifiable(lines),
       atomics = List<AtomicObject>.unmodifiable(atomics),
       map = _validatedMap(text, sourceLength, lines, atomics, activeLine);

  final String text;
  final int sourceLength;
  final List<VisibleLine> lines;
  final List<AtomicObject> atomics;
  final int? activeLine;
  final OffsetMap map;

  AtomicObject? atomicAtVisible(int visibleOffset) {
    final AtomicObject? candidate = _lastAtomicWhere(
      (AtomicObject atomic) => atomic.visibleOffset <= visibleOffset,
    );
    return candidate != null && candidate.visibleRange.contains(visibleOffset)
        ? candidate
        : null;
  }

  AtomicObject? atomicAtSource(int sourceOffset) {
    final AtomicObject? candidate = _lastAtomicWhere(
      (AtomicObject atomic) => atomic.sourceRange.start <= sourceOffset,
    );
    return candidate != null && candidate.sourceRange.contains(sourceOffset)
        ? candidate
        : null;
  }

  AtomicObject? _lastAtomicWhere(bool Function(AtomicObject atomic) test) {
    int low = 0;
    int high = atomics.length - 1;
    AtomicObject? found;
    while (low <= high) {
      final int mid = (low + high) >> 1;
      if (test(atomics[mid])) {
        found = atomics[mid];
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return found;
  }

  static OffsetMap _validatedMap(
    String text,
    int sourceLength,
    List<VisibleLine> lines,
    List<AtomicObject> atomics,
    int? activeLine,
  ) {
    if (activeLine != null && activeLine < 0) {
      throw ArgumentError.value(
        activeLine,
        'activeLine',
        'must not be negative',
      );
    }
    final List<VisibleSpan> spans = <VisibleSpan>[];
    int previousLine = -1;
    for (int i = 0; i < lines.length; i++) {
      final VisibleLine line = lines[i];
      if (line.sourceLine <= previousLine) {
        throw ArgumentError.value(
          line,
          'lines[$i]',
          'source lines must be strictly increasing',
        );
      }
      if (line.sourceRange.end > sourceLength ||
          line.visibleRange.end > text.length) {
        throw ArgumentError.value(
          line,
          'lines[$i]',
          'line ranges must lie inside the source and the visible text',
        );
      }
      for (final VisibleSpan span in line.spans) {
        if (!_isInside(span.visibleRange, line.visibleRange) ||
            !_isInside(span.sourceRange, line.sourceRange)) {
          throw ArgumentError.value(
            span,
            'lines[$i].spans',
            'span must lie inside its line',
          );
        }
      }
      spans.addAll(line.spans);
      previousLine = line.sourceLine;
    }
    final int visibleEnd = spans.isEmpty ? 0 : spans.last.visibleRange.end;
    if (text.length != visibleEnd) {
      throw ArgumentError.value(
        text.length,
        'text.length',
        'spans end at $visibleEnd',
      );
    }
    final OffsetMap map = OffsetMap(
      spans: spans,
      sourceLength: sourceLength,
      visibleLength: text.length,
    );
    final List<VisibleSpan> atomicSpans = <VisibleSpan>[
      for (final VisibleSpan span in map.spans)
        if (span.kind == VisibleSpanKind.atomic) span,
    ];
    if (atomicSpans.length != atomics.length) {
      throw ArgumentError.value(
        atomics.length,
        'atomics.length',
        'there are ${atomicSpans.length} atomic spans',
      );
    }
    for (int i = 0; i < atomics.length; i++) {
      if (atomics[i].visibleRange != atomicSpans[i].visibleRange ||
          atomics[i].sourceRange != atomicSpans[i].sourceRange) {
        throw ArgumentError.value(
          atomics[i],
          'atomics[$i]',
          'does not match ${atomicSpans[i]}',
        );
      }
    }
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisibleText &&
          text == other.text &&
          sourceLength == other.sourceLength &&
          activeLine == other.activeLine &&
          _listEquals(lines, other.lines) &&
          _listEquals(atomics, other.atomics);

  @override
  int get hashCode => Object.hash(
    text,
    sourceLength,
    Object.hashAll(lines),
    Object.hashAll(atomics),
    activeLine,
  );

  @override
  String toString() =>
      "VisibleText('$text', $sourceLength, $lines, $atomics, $activeLine)";
}

abstract interface class VisibleProjector {
  VisibleText project(String source, MdTree tree, int? activeLine);
}

bool _isInside(MdRange inner, MdRange outer) =>
    inner.start >= outer.start && inner.end <= outer.end;

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
