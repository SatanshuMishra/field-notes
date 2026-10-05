import 'package:diff_match_patch/diff_match_patch.dart';

const String _lineBreak = '\n';
const int _surrogateStart = 0xd800;
const int _surrogateCount = 0x800;
const int _lineCodeCount = 0xffff - _surrogateCount;

sealed class TextMergeResult {
  const TextMergeResult();

  const factory TextMergeResult.merged(String text) = MergedText;

  const factory TextMergeResult.conflict() = TextConflict;
}

final class MergedText extends TextMergeResult {
  const MergedText(this.text);

  final String text;

  @override
  bool operator ==(Object other) => other is MergedText && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'MergedText($text)';
}

final class TextConflict extends TextMergeResult {
  const TextConflict();

  @override
  bool operator ==(Object other) => other is TextConflict;

  @override
  int get hashCode => (TextConflict).hashCode;

  @override
  String toString() => 'TextConflict()';
}

TextMergeResult merge({
  required String base,
  required String local,
  required String remote,
}) {
  final List<String> baseLines = base.split(_lineBreak);
  final List<String> localLines = local.split(_lineBreak);
  final List<String> remoteLines = remote.split(_lineBreak);
  final List<String> distinct = <String>{
    ...baseLines,
    ...localLines,
    ...remoteLines,
  }.toList();
  if (distinct.length > _lineCodeCount) {
    return const TextMergeResult.conflict();
  }
  final Map<String, String> codeOf = <String, String>{
    for (int index = 0; index < distinct.length; index++)
      distinct[index]: _lineCode(index),
  };
  final Map<String, String> lineOf = <String, String>{
    for (final MapEntry<String, String> entry in codeOf.entries)
      entry.value: entry.key,
  };
  String encode(List<String> lines) =>
      lines.map((String line) => codeOf[line]!).join();

  final String baseCodes = encode(baseLines);
  final List<_Hunk> localHunks = _hunks(baseCodes, encode(localLines));
  final List<_Hunk> remoteHunks = _hunks(
    baseCodes,
    encode(remoteLines),
  ).where((_Hunk hunk) => !localHunks.contains(hunk)).toList();
  final bool overlapping = localHunks.any(
    (_Hunk ours) => remoteHunks.any((_Hunk theirs) => ours.overlaps(theirs)),
  );
  if (overlapping) {
    return const TextMergeResult.conflict();
  }
  final String mergedCodes = _applied(baseCodes, <_Hunk>[
    ...localHunks,
    ...remoteHunks,
  ]);
  return TextMergeResult.merged(
    mergedCodes.split('').map((String code) => lineOf[code]!).join(_lineBreak),
  );
}

String _lineCode(int index) {
  final int code = index + 1;
  return String.fromCharCode(
    code < _surrogateStart ? code : code + _surrogateCount,
  );
}

List<_Hunk> _hunks(String base, String changed) {
  final List<_Hunk> hunks = <_Hunk>[];
  int position = 0;
  int? start;
  String inserted = '';
  for (final Diff part in diff(base, changed, checklines: false)) {
    if (part.operation == DIFF_EQUAL) {
      if (start != null) {
        hunks.add(_Hunk(start: start, end: position, inserted: inserted));
        start = null;
        inserted = '';
      }
      position += part.text.length;
      continue;
    }
    start ??= position;
    if (part.operation == DIFF_DELETE) {
      position += part.text.length;
    } else {
      inserted += part.text;
    }
  }
  if (start != null) {
    hunks.add(_Hunk(start: start, end: position, inserted: inserted));
  }
  return List<_Hunk>.unmodifiable(hunks);
}

String _applied(String base, List<_Hunk> hunks) {
  final List<_Hunk> ordered = <_Hunk>[...hunks]..sort(_Hunk.byPlace);
  final StringBuffer out = StringBuffer();
  int cursor = 0;
  for (final _Hunk hunk in ordered) {
    out
      ..write(base.substring(cursor, hunk.start))
      ..write(hunk.inserted);
    cursor = hunk.end;
  }
  out.write(base.substring(cursor));
  return out.toString();
}

class _Hunk {
  const _Hunk({required this.start, required this.end, required this.inserted});

  final int start;
  final int end;
  final String inserted;

  bool get isInsertion => start == end;

  bool overlaps(_Hunk other) {
    if (isInsertion && other.isInsertion) {
      return start == other.start;
    }
    if (isInsertion) {
      return other.start < start && start < other.end;
    }
    if (other.isInsertion) {
      return start < other.start && other.start < end;
    }
    return start < other.end && other.start < end;
  }

  static int byPlace(_Hunk a, _Hunk b) {
    final int byStart = a.start.compareTo(b.start);
    if (byStart != 0) {
      return byStart;
    }
    return (a.isInsertion ? 0 : 1).compareTo(b.isInsertion ? 0 : 1);
  }

  @override
  bool operator ==(Object other) =>
      other is _Hunk &&
      other.start == start &&
      other.end == end &&
      other.inserted == inserted;

  @override
  int get hashCode => Object.hash(start, end, inserted);
}
