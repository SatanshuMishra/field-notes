import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/input/delta_mapping.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const int mirrorMemory = 16;

@immutable
final class KnownValue {
  const KnownValue({
    required this.value,
    required this.state,
    required this.visible,
    required this.windowBase,
    required this.version,
    this.platformEdits = const <TextEditingDelta>[],
  });

  final TextEditingValue value;
  final EditorState state;
  final VisibleText visible;
  final int windowBase;
  final int version;
  final List<TextEditingDelta> platformEdits;

  @override
  String toString() =>
      "KnownValue('${value.text}', version: $version, "
      'windowBase: $windowBase, platformEdits: ${platformEdits.length})';
}

enum DeltaDropReason { noMatchingValue, rebaseOutOfRange }

@immutable
final class DeltaDrop {
  const DeltaDrop({
    required this.reason,
    required this.oldText,
    required this.version,
  });

  final DeltaDropReason reason;
  final String oldText;
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeltaDrop &&
          reason == other.reason &&
          oldText == other.oldText &&
          version == other.version;

  @override
  int get hashCode => Object.hash(reason, oldText, version);

  @override
  String toString() => "DeltaDrop(${reason.name}, '$oldText', $version)";
}

sealed class MirrorStep {
  const MirrorStep();
}

final class CurrentDelta extends MirrorStep {
  const CurrentDelta({required this.against});

  final KnownValue against;

  @override
  String toString() => 'CurrentDelta($against)';
}

final class RebasedDelta extends MirrorStep {
  const RebasedDelta(this.transaction);

  final Transaction transaction;

  @override
  String toString() => 'RebasedDelta($transaction)';
}

final class KeptAffinity extends MirrorStep {
  const KeptAffinity();

  @override
  String toString() => 'KeptAffinity()';
}

final class DroppedDelta extends MirrorStep {
  const DroppedDelta(this.drop);

  final DeltaDrop drop;

  @override
  String toString() => 'DroppedDelta($drop)';
}

@immutable
final class DeltaMirror {
  const DeltaMirror.empty()
    : value = TextEditingValue.empty,
      version = 0,
      drops = const <DeltaDrop>[],
      _entries = const <_Entry>[],
      _log = const <ChangeSet>[],
      _logBase = 0;

  DeltaMirror._(
    this._logBase, {
    required this.value,
    required this.version,
    required List<DeltaDrop> drops,
    required List<_Entry> entries,
    required List<ChangeSet> log,
  }) : drops = List<DeltaDrop>.unmodifiable(drops),
       _entries = List<_Entry>.unmodifiable(entries),
       _log = List<ChangeSet>.unmodifiable(log);

  final TextEditingValue value;
  final int version;
  final List<DeltaDrop> drops;
  final List<_Entry> _entries;
  final List<ChangeSet> _log;
  final int _logBase;

  List<KnownValue> get knownValues =>
      List<KnownValue>.unmodifiable(<KnownValue>[
        for (final _Entry entry in _entries)
          if (entry.isProjection) entry.known,
      ]);

  List<KnownValue> get derivedValues =>
      List<KnownValue>.unmodifiable(<KnownValue>[
        for (final _Entry entry in _entries)
          if (!entry.isProjection) entry.known,
      ]);

  DeltaMirror recordSent(KnownValue sent) => _withProjection(sent);

  DeltaMirror recordHeld(KnownValue held) => _withProjection(held);

  DeltaMirror recordSourceChange(ChangeSet change) => _trimmed(
    value: value,
    version: version + 1,
    drops: drops,
    entries: _entries,
    log: <ChangeSet>[..._log, change],
  );

  ({DeltaMirror mirror, MirrorStep step}) step(
    TextEditingDelta delta, {
    required EditorState current,
    required NoteSelection localSelection,
  }) {
    final int index = _entries.indexWhere(
      (_Entry entry) => entry.known.value.text == delta.oldText,
    );
    if (index < 0) {
      return _dropped(DeltaDropReason.noMatchingValue, delta);
    }
    final _Entry match = _entries[index];
    final KnownValue known = match.known;
    final TextEditingValue applied = delta.apply(known.value);
    final bool keepsAffinity = _keepsAffinity(
      delta,
      known,
      applied,
      localSelection,
    );
    final TextEditingValue platform = keepsAffinity
        ? applied.copyWith(
            selection: applied.selection.copyWith(
              affinity: localSelection.affinity,
            ),
          )
        : applied;
    final _Entry derived = _Entry(
      known: KnownValue(
        value: platform,
        state: known.state,
        visible: known.visible,
        windowBase: known.windowBase,
        version: known.version,
        platformEdits: <TextEditingDelta>[...known.platformEdits, delta],
      ),
      projection: match.projection,
    );
    final DeltaMirror advanced = DeltaMirror._(
      _logBase,
      value: platform,
      version: version,
      drops: drops,
      entries: <_Entry>[derived, ..._entries],
      log: _log,
    );
    if (keepsAffinity) {
      return (mirror: advanced, step: const KeptAffinity());
    }
    if (index == 0 && known.version == version) {
      return (mirror: advanced, step: CurrentDelta(against: known));
    }
    final Transaction? rebased = _rebase(delta, match, current);
    if (rebased == null) {
      return advanced._dropped(DeltaDropReason.rebaseOutOfRange, delta);
    }
    return (mirror: advanced, step: RebasedDelta(rebased));
  }

  bool differsFrom(TextEditingValue clientValue) => clientValue != value;

  TextEditingDelta reduceFullValue(TextEditingValue full) {
    final String before = value.text;
    final String after = full.text;
    if (before == after) {
      return TextEditingDeltaNonTextUpdate(
        oldText: before,
        selection: full.selection,
        composing: full.composing,
      );
    }
    final (int, int) range = _minimalRange(before, after, _atomicsFor(before));
    final int start = range.$1;
    final int end = range.$2;
    final String inserted = after.substring(
      start,
      end + after.length - before.length,
    );
    final TextSelection selection = TextSelection.collapsed(
      offset: start + inserted.length,
    );
    if (start == end) {
      return TextEditingDeltaInsertion(
        oldText: before,
        textInserted: inserted,
        insertionOffset: start,
        selection: selection,
        composing: full.composing,
      );
    }
    if (inserted.isEmpty) {
      return TextEditingDeltaDeletion(
        oldText: before,
        deletedRange: TextRange(start: start, end: end),
        selection: selection,
        composing: full.composing,
      );
    }
    return TextEditingDeltaReplacement(
      oldText: before,
      replacementText: inserted,
      replacedRange: TextRange(start: start, end: end),
      selection: selection,
      composing: full.composing,
    );
  }

  DeltaMirror _withProjection(KnownValue projection) {
    final List<_Entry> entries = <_Entry>[
      _Entry(known: projection, projection: projection),
      ..._entries,
    ];
    final List<KnownValue> kept = <KnownValue>[
      for (final _Entry entry in entries)
        if (entry.isProjection) entry.known,
    ].take(mirrorMemory).toList();
    return _trimmed(
      value: projection.value,
      version: version,
      drops: drops,
      entries: <_Entry>[
        for (final _Entry entry in entries)
          if (kept.any((KnownValue k) => identical(k, entry.projection))) entry,
      ],
      log: _log,
    );
  }

  DeltaMirror _trimmed({
    required TextEditingValue value,
    required int version,
    required List<DeltaDrop> drops,
    required List<_Entry> entries,
    required List<ChangeSet> log,
  }) {
    int oldest = version;
    for (final _Entry entry in entries) {
      if (entry.isProjection && entry.known.version < oldest) {
        oldest = entry.known.version;
      }
    }
    final int excess = oldest - _logBase;
    final int cut = excess <= 0
        ? 0
        : excess > log.length
        ? log.length
        : excess;
    return DeltaMirror._(
      _logBase + cut,
      value: value,
      version: version,
      drops: drops,
      entries: entries,
      log: log.sublist(cut),
    );
  }

  ({DeltaMirror mirror, MirrorStep step}) _dropped(
    DeltaDropReason reason,
    TextEditingDelta delta,
  ) {
    final DeltaDrop drop = DeltaDrop(
      reason: reason,
      oldText: delta.oldText,
      version: version,
    );
    return (
      mirror: DeltaMirror._(
        _logBase,
        value: value,
        version: version,
        drops: <DeltaDrop>[...drops, drop],
        entries: _entries,
        log: _log,
      ),
      step: DroppedDelta(drop),
    );
  }

  List<AtomicObject> _atomicsFor(String text) {
    for (final _Entry entry in _entries) {
      if (entry.isProjection && entry.known.value.text == text) {
        final int base = entry.known.windowBase;
        return <AtomicObject>[
          for (final AtomicObject atomic in entry.known.visible.atomics)
            AtomicObject(
              kind: atomic.kind,
              sourceRange: atomic.sourceRange,
              visibleOffset: atomic.visibleOffset - base,
              visibleLength: atomic.visibleLength,
            ),
        ];
      }
    }
    return const <AtomicObject>[];
  }

  bool _keepsAffinity(
    TextEditingDelta delta,
    KnownValue known,
    TextEditingValue applied,
    NoteSelection localSelection,
  ) {
    final TextSelection platform = delta.selection;
    if (delta is! TextEditingDeltaNonTextUpdate ||
        applied.text != known.value.text ||
        applied.composing != known.value.composing ||
        !platform.isValid ||
        !platform.isCollapsed ||
        localSelection.end > known.visible.sourceLength) {
      return false;
    }
    final TextSelection local = visibleSelectionFor(
      visible: known.visible,
      selection: localSelection,
      windowBase: known.windowBase,
    );
    return local.isCollapsed && local.baseOffset == platform.baseOffset;
  }

  List<ChangeSet>? _changesSince(int from) {
    if (from < _logBase || from > version) {
      return null;
    }
    return _log.sublist(from - _logBase);
  }

  Transaction? _rebase(
    TextEditingDelta delta,
    _Entry match,
    EditorState current,
  ) {
    final KnownValue known = match.known;
    final KnownValue projection = match.projection;
    final TextEditingDelta? equivalent = _equivalentDelta(
      delta,
      known.platformEdits,
      projection.value.text,
    );
    final List<ChangeSet>? logged = _changesSince(known.version);
    if (equivalent == null ||
        logged == null ||
        known.windowBase < 0 ||
        known.windowBase + projection.value.text.length >
            known.visible.text.length) {
      return null;
    }
    final ChangeSet? since = _chained(
      logged,
      known.state.source.length,
      current.source.length,
    );
    if (since == null) {
      return null;
    }
    final DeltaOutcome outcome = mapDelta(
      state: known.state,
      visible: known.visible,
      windowBase: known.windowBase,
      platformBefore: projection.value,
      delta: equivalent,
      classify: false,
    );
    return switch (outcome) {
      MappedEdit(:final Transaction transaction) => _rebasedEdit(
        transaction,
        since,
      ),
      SelectionEdit(
        :final NoteSelection selection,
        :final MdRange? composing,
      ) =>
        _rebasedSelection(selection, composing, since),
      ClassifiedEdit() => throw StateError('stale deltas are never classified'),
    };
  }

  Transaction? _rebasedEdit(Transaction mapped, ChangeSet since) {
    final ChangeSet edit = mapped.changes;
    final List<TextReplacement> replacements = <TextReplacement>[];
    final List<int> editStarts = <int>[];
    final List<int> rebasedStarts = <int>[];
    int editShift = 0;
    int rebasedShift = 0;
    for (final TextReplacement r in edit.replacements) {
      final int start = since.mapPosition(r.from, side: MapSide.after);
      final int mappedEnd = since.mapPosition(r.to, side: MapSide.before);
      final int end = mappedEnd < start ? start : mappedEnd;
      replacements.add(TextReplacement(start, end, r.inserted));
      editStarts.add(r.from + editShift);
      rebasedStarts.add(start + rebasedShift);
      editShift += r.inserted.length - (r.to - r.from);
      rebasedShift += r.inserted.length - (end - start);
    }
    final ChangeSet rebased = ChangeSet(
      length: since.newLength,
      replacements: replacements,
    );
    int? rebase(int offset) {
      if (offset < 0 || offset > edit.newLength) {
        return null;
      }
      final List<TextReplacement> edits = edit.replacements;
      int back = offset;
      for (int i = 0; i < edits.length; i++) {
        final int insertedEnd = editStarts[i] + edits[i].inserted.length;
        if (editStarts[i] <= offset && offset <= insertedEnd) {
          return rebasedStarts[i] + offset - editStarts[i];
        }
        if (insertedEnd < offset) {
          back -= edits[i].inserted.length - (edits[i].to - edits[i].from);
        }
      }
      return rebased.mapPosition(
        since.mapPosition(back, side: MapSide.after),
        side: MapSide.after,
      );
    }

    final NoteSelection selection = mapped.selection;
    final int? anchor = rebase(selection.anchor);
    final int? head = rebase(selection.head);
    final MdRange? composing = mapped.composing;
    final int? composingStart = composing == null
        ? null
        : rebase(composing.start);
    final int? composingEnd = composing == null ? null : rebase(composing.end);
    final int limit = rebased.newLength;
    if (anchor == null ||
        head == null ||
        anchor > limit ||
        head > limit ||
        (composing != null &&
            (composingStart == null ||
                composingEnd == null ||
                composingEnd > limit))) {
      return null;
    }
    return Transaction(
      changes: rebased,
      selection: NoteSelection(
        anchor: anchor,
        head: head,
        affinity: selection.affinity,
      ),
      event: mapped.event,
      addToHistory: mapped.addToHistory,
      composing: _nonEmpty(composingStart, composingEnd),
    );
  }

  Transaction? _rebasedSelection(
    NoteSelection selection,
    MdRange? composing,
    ChangeSet since,
  ) {
    final int length = since.length;
    if (selection.end > length ||
        (composing != null && composing.end > length)) {
      return null;
    }
    final MdRange? rebasedComposing = composing == null
        ? null
        : _nonEmpty(
            since.mapPosition(composing.start, side: MapSide.after),
            since.mapPosition(composing.end, side: MapSide.after),
          );
    return Transaction(
      changes: ChangeSet.empty(since.newLength),
      selection: NoteSelection(
        anchor: since.mapPosition(selection.anchor, side: MapSide.after),
        head: since.mapPosition(selection.head, side: MapSide.after),
        affinity: selection.affinity,
      ),
      event: rebasedComposing == null
          ? TransactionEvent.inputType
          : TransactionEvent.inputIme,
      addToHistory: false,
      composing: rebasedComposing,
    );
  }
}

@immutable
final class _Entry {
  const _Entry({required this.known, required this.projection});

  final KnownValue known;
  final KnownValue projection;

  bool get isProjection => identical(known, projection);
}

typedef _Span = ({int start, int end, String text});

_Span? _spanOf(TextEditingDelta delta) => switch (delta) {
  final TextEditingDeltaInsertion insertion => (
    start: insertion.insertionOffset,
    end: insertion.insertionOffset,
    text: insertion.textInserted,
  ),
  final TextEditingDeltaDeletion deletion => (
    start: deletion.deletedRange.start,
    end: deletion.deletedRange.end,
    text: '',
  ),
  final TextEditingDeltaReplacement replacement => (
    start: replacement.replacedRange.start,
    end: replacement.replacedRange.end,
    text: replacement.replacementText,
  ),
  _ => null,
};

int _unapply(int offset, List<TextEditingDelta> edits) {
  int result = offset;
  for (final TextEditingDelta edit in edits.reversed) {
    final _Span? span = _spanOf(edit);
    if (span == null) {
      continue;
    }
    final int insertedEnd = span.start + span.text.length;
    if (result >= insertedEnd) {
      result = result - span.text.length + (span.end - span.start);
    } else if (result > span.start) {
      result = span.end;
    }
  }
  return result;
}

TextEditingDelta? _equivalentDelta(
  TextEditingDelta delta,
  List<TextEditingDelta> edits,
  String projectionText,
) {
  final _Span? span = _spanOf(delta);
  final int start = span == null ? 0 : _unapply(span.start, edits);
  final int end = span == null ? 0 : _unapply(span.end, edits);
  if (span != null &&
      (start < 0 || end > projectionText.length || end < start)) {
    return null;
  }
  final int length = span == null
      ? projectionText.length
      : projectionText.length + span.text.length - (end - start);
  bool inside(int offset) => offset >= 0 && offset <= length;
  final TextSelection selection = delta.selection;
  final TextSelection mappedSelection = selection.isValid
      ? selection.copyWith(
          baseOffset: _unapply(selection.baseOffset, edits),
          extentOffset: _unapply(selection.extentOffset, edits),
        )
      : selection;
  final TextRange composing = delta.composing;
  final TextRange mappedComposing = composing.isValid && !composing.isCollapsed
      ? TextRange(
          start: _unapply(composing.start, edits),
          end: _unapply(composing.end, edits),
        )
      : TextRange.empty;
  if ((mappedSelection.isValid &&
          (!inside(mappedSelection.baseOffset) ||
              !inside(mappedSelection.extentOffset))) ||
      (mappedComposing.isValid &&
          (!inside(mappedComposing.start) || !inside(mappedComposing.end)))) {
    return null;
  }
  return switch (delta) {
    TextEditingDeltaInsertion() => TextEditingDeltaInsertion(
      oldText: projectionText,
      textInserted: span!.text,
      insertionOffset: start,
      selection: mappedSelection,
      composing: mappedComposing,
    ),
    TextEditingDeltaDeletion() => TextEditingDeltaDeletion(
      oldText: projectionText,
      deletedRange: TextRange(start: start, end: end),
      selection: mappedSelection,
      composing: mappedComposing,
    ),
    TextEditingDeltaReplacement() => TextEditingDeltaReplacement(
      oldText: projectionText,
      replacementText: span!.text,
      replacedRange: TextRange(start: start, end: end),
      selection: mappedSelection,
      composing: mappedComposing,
    ),
    _ => TextEditingDeltaNonTextUpdate(
      oldText: projectionText,
      selection: mappedSelection,
      composing: mappedComposing,
    ),
  };
}

ChangeSet? _chained(List<ChangeSet> logged, int from, int to) {
  if (logged.isEmpty) {
    return from == to ? ChangeSet.empty(from) : null;
  }
  int length = from;
  for (final ChangeSet change in logged) {
    if (change.length != length) {
      return null;
    }
    length = change.newLength;
  }
  if (length != to) {
    return null;
  }
  return logged
      .skip(1)
      .fold<ChangeSet>(
        logged.first,
        (ChangeSet composed, ChangeSet next) => composed.compose(next),
      );
}

MdRange? _nonEmpty(int? start, int? end) =>
    start != null && end != null && end > start ? MdRange(start, end) : null;

(int, int) _minimalRange(
  String before,
  String after,
  List<AtomicObject> atomics,
) {
  final int shorter = before.length < after.length
      ? before.length
      : after.length;
  int prefix = 0;
  while (prefix < shorter &&
      before.codeUnitAt(prefix) == after.codeUnitAt(prefix)) {
    prefix += 1;
  }
  int suffix = 0;
  while (prefix + suffix < shorter &&
      before.codeUnitAt(before.length - 1 - suffix) ==
          after.codeUnitAt(after.length - 1 - suffix)) {
    suffix += 1;
  }
  final int delta = after.length - before.length;
  int start = prefix;
  int end = before.length - suffix;
  while (true) {
    final CharacterRange inBefore = CharacterRange.at(before, start, end);
    final int beforeStart = inBefore.stringBeforeLength;
    final int beforeEnd = before.length - inBefore.stringAfterLength;
    final CharacterRange inAfter = CharacterRange.at(
      after,
      beforeStart,
      beforeEnd + delta,
    );
    final int afterStart = inAfter.stringBeforeLength;
    final int afterEnd = after.length - inAfter.stringAfterLength - delta;
    final (int, int) widened = _widenOverAtomics(atomics, afterStart, afterEnd);
    if (widened.$1 == start && widened.$2 == end) {
      break;
    }
    start = widened.$1;
    end = widened.$2;
  }
  return (start, end);
}

(int, int) _widenOverAtomics(List<AtomicObject> atomics, int start, int end) {
  int low = start;
  int high = end;
  for (final AtomicObject atomic in atomics) {
    final int atomicStart = atomic.visibleOffset;
    final int atomicEnd = atomicStart + atomic.visibleLength;
    if (atomicStart < low && low < atomicEnd) {
      low = atomicStart;
    }
    if (atomicStart < high && high < atomicEnd) {
      high = atomicEnd;
    }
  }
  return (low, high);
}
