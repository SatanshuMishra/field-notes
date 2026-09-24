enum MapSide { before, after }

final class TextReplacement {
  const TextReplacement(this.from, this.to, this.inserted);

  final int from;
  final int to;
  final String inserted;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextReplacement &&
          from == other.from &&
          to == other.to &&
          inserted == other.inserted;

  @override
  int get hashCode => Object.hash(from, to, inserted);

  @override
  String toString() => "TextReplacement($from, $to, '$inserted')";
}

final class ChangeSet {
  ChangeSet({required this.length, required List<TextReplacement> replacements})
    : replacements = List<TextReplacement>.unmodifiable(
        _canonical(length, replacements),
      );

  factory ChangeSet.empty(int length) =>
      ChangeSet(length: length, replacements: const <TextReplacement>[]);

  factory ChangeSet.single(int length, int from, int to, String inserted) =>
      ChangeSet(
        length: length,
        replacements: <TextReplacement>[TextReplacement(from, to, inserted)],
      );

  final int length;
  final List<TextReplacement> replacements;

  int get newLength {
    int result = length;
    for (final TextReplacement r in replacements) {
      result += _delta(r);
    }
    return result;
  }

  bool get isEmpty => replacements.isEmpty;

  String apply(String document) {
    if (document.length != length) {
      throw ArgumentError.value(
        document.length,
        'document',
        'length must be $length',
      );
    }
    final StringBuffer buffer = StringBuffer();
    int cursor = 0;
    for (final TextReplacement r in replacements) {
      buffer
        ..write(document.substring(cursor, r.from))
        ..write(r.inserted);
      cursor = r.to;
    }
    buffer.write(document.substring(cursor));
    return buffer.toString();
  }

  ChangeSet invert(String original) {
    if (original.length != length) {
      throw ArgumentError.value(
        original.length,
        'original',
        'length must be $length',
      );
    }
    final List<TextReplacement> inverted = <TextReplacement>[];
    int shift = 0;
    for (final TextReplacement r in replacements) {
      final int start = r.from + shift;
      inverted.add(
        TextReplacement(
          start,
          start + r.inserted.length,
          original.substring(r.from, r.to),
        ),
      );
      shift += _delta(r);
    }
    return ChangeSet(length: newLength, replacements: inverted);
  }

  ChangeSet compose(ChangeSet next) {
    final int middleLength = newLength;
    if (next.length != middleLength) {
      throw ArgumentError.value(
        next.length,
        'next',
        'length must be $middleLength',
      );
    }
    final List<_Segment> middle = <_Segment>[];
    int cursor = 0;
    for (final TextReplacement r in replacements) {
      middle
        ..add(_Segment.kept(cursor, r.from))
        ..add(_Segment.text(r.inserted));
      cursor = r.to;
    }
    middle.add(_Segment.kept(cursor, length));

    final List<_Segment> result = <_Segment>[];
    int segmentIndex = 0;
    int segmentStart = 0;
    void emit(int from, int to) {
      while (segmentIndex < middle.length) {
        final _Segment segment = middle[segmentIndex];
        final int segmentEnd = segmentStart + segment.length;
        final int lo = from > segmentStart ? from : segmentStart;
        final int hi = to < segmentEnd ? to : segmentEnd;
        if (lo < hi) {
          result.add(segment.slice(lo - segmentStart, hi - segmentStart));
        }
        if (segmentEnd > to) {
          return;
        }
        segmentIndex += 1;
        segmentStart = segmentEnd;
      }
    }

    int position = 0;
    for (final TextReplacement r in next.replacements) {
      emit(position, r.from);
      result.add(_Segment.text(r.inserted));
      position = r.to;
    }
    emit(position, middleLength);

    final List<TextReplacement> composed = <TextReplacement>[];
    final StringBuffer pending = StringBuffer();
    int keptEnd = 0;
    for (final _Segment segment in result) {
      final String? text = segment.text;
      if (text != null) {
        pending.write(text);
      } else if (segment.from < segment.to) {
        if (segment.from > keptEnd || pending.isNotEmpty) {
          composed.add(
            TextReplacement(keptEnd, segment.from, pending.toString()),
          );
          pending.clear();
        }
        keptEnd = segment.to;
      }
    }
    if (keptEnd < length || pending.isNotEmpty) {
      composed.add(TextReplacement(keptEnd, length, pending.toString()));
    }
    return ChangeSet(length: length, replacements: composed);
  }

  int mapPosition(int position, {required MapSide side}) {
    if (position < 0 || position > length) {
      throw RangeError.range(position, 0, length, 'position');
    }
    int shift = 0;
    for (final TextReplacement r in replacements) {
      if (position < r.from) {
        return position + shift;
      }
      final int start = r.from + shift;
      final int end = start + r.inserted.length;
      if (r.from == r.to) {
        if (position == r.from) {
          return side == MapSide.before ? start : end;
        }
      } else if (position == r.from) {
        return start;
      } else if (position == r.to) {
        return end;
      } else if (position < r.to) {
        return side == MapSide.before ? start : end;
      }
      shift += _delta(r);
    }
    return position + shift;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! ChangeSet ||
        length != other.length ||
        replacements.length != other.replacements.length) {
      return false;
    }
    for (int i = 0; i < replacements.length; i++) {
      if (replacements[i] != other.replacements[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(length, Object.hashAll(replacements));

  @override
  String toString() => 'ChangeSet($length, $replacements)';

  static List<TextReplacement> _canonical(
    int length,
    List<TextReplacement> replacements,
  ) {
    if (length < 0) {
      throw ArgumentError.value(length, 'length', 'must not be negative');
    }
    int previousEnd = 0;
    for (final TextReplacement r in replacements) {
      if (r.from < 0 || r.to > length || r.from > r.to) {
        throw ArgumentError.value(
          r,
          'replacements',
          'must lie within 0 to $length with from <= to',
        );
      }
      if (r.from < previousEnd) {
        throw ArgumentError.value(
          r,
          'replacements',
          'must be ordered and must not overlap',
        );
      }
      previousEnd = r.to;
    }
    final List<TextReplacement> result = <TextReplacement>[];
    for (final TextReplacement r in replacements) {
      if (r.from == r.to && r.inserted.isEmpty) {
        continue;
      }
      if (result.isNotEmpty && result.last.to == r.from) {
        final TextReplacement previous = result.removeLast();
        result.add(
          TextReplacement(previous.from, r.to, previous.inserted + r.inserted),
        );
      } else {
        result.add(r);
      }
    }
    return result;
  }
}

int _delta(TextReplacement r) => r.inserted.length - (r.to - r.from);

final class _Segment {
  const _Segment.kept(this.from, this.to) : text = null;

  const _Segment.text(String this.text) : from = 0, to = 0;

  final int from;
  final int to;
  final String? text;

  int get length => text?.length ?? to - from;

  _Segment slice(int start, int end) {
    final String? value = text;
    return value != null
        ? _Segment.text(value.substring(start, end))
        : _Segment.kept(from + start, from + end);
  }
}
