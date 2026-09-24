import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoColors;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/capabilities.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';

const Duration spellCheckDelay = Duration(milliseconds: 300);
const int spellCheckBatch = 20;
const int spellSuggestionLimit = 5;
const int spellCheckAttempts = 3;

@immutable
final class SpellMark {
  const SpellMark({required this.range, required this.suggestions});

  final MdRange range;
  final List<String> suggestions;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpellMark &&
          range == other.range &&
          listEquals(suggestions, other.suggestions);

  @override
  int get hashCode => Object.hash(range, Object.hashAll(suggestions));

  @override
  String toString() => 'SpellMark($range, $suggestions)';
}

@immutable
final class SpellUnit {
  const SpellUnit({required this.text, required this.sourceOffsets});

  final String text;
  final List<int> sourceOffsets;

  MdRange get sourceRange => MdRange(sourceOffsets.first, sourceOffsets.last);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpellUnit &&
          text == other.text &&
          listEquals(sourceOffsets, other.sourceOffsets);

  @override
  int get hashCode => Object.hash(text, Object.hashAll(sourceOffsets));

  @override
  String toString() => 'SpellUnit(${text.length}, $sourceRange)';
}

List<SpellUnit> spellUnitsOf(String source, MdTree tree) {
  if (tree.sourceLength != source.length) {
    throw ArgumentError.value(
      tree.sourceLength,
      'tree.sourceLength',
      'must equal the source length ${source.length}',
    );
  }
  final List<SpellUnit> units = <SpellUnit>[];
  for (final MdBlock block in tree.blocks) {
    if (block.kind == MdBlockKind.table) {
      units.add(_tableUnit(source, block));
    } else {
      _collectUnits(source, block, const <MdRange>[], units);
    }
  }
  return List<SpellUnit>.unmodifiable(units);
}

void _collectUnits(
  String source,
  MdBlock block,
  List<MdRange> ancestorMarkers,
  List<SpellUnit> units,
) {
  switch (block.kind) {
    case MdBlockKind.heading || MdBlockKind.paragraph:
      units.add(_textUnit(source, block, ancestorMarkers));
    case MdBlockKind.blockQuote ||
        MdBlockKind.bulletList ||
        MdBlockKind.orderedList ||
        MdBlockKind.listItem:
      final List<MdRange> markers = <MdRange>[
        ...ancestorMarkers,
        ...block.markerRanges,
      ];
      for (final MdBlock child in block.blocks) {
        _collectUnits(source, child, markers, units);
      }
    case MdBlockKind.thematicBreak ||
        MdBlockKind.fencedCode ||
        MdBlockKind.blankLine ||
        MdBlockKind.table ||
        MdBlockKind.tableRow ||
        MdBlockKind.tableCell ||
        MdBlockKind.photoLine:
      break;
  }
}

final class _UnitWriter {
  _UnitWriter(this.source);

  final String source;
  final StringBuffer text = StringBuffer();
  final List<int> offsets = <int>[];

  void write(int from, int to, List<MdRange> markers, List<MdRange> blanks) {
    int markerIndex = 0;
    int blankIndex = 0;
    int position = from;
    while (position < to) {
      while (markerIndex < markers.length &&
          markers[markerIndex].end <= position) {
        markerIndex += 1;
      }
      if (markerIndex < markers.length &&
          markers[markerIndex].start <= position) {
        position = markers[markerIndex].end;
        continue;
      }
      while (blankIndex < blanks.length && blanks[blankIndex].end <= position) {
        blankIndex += 1;
      }
      final bool isBlank =
          blankIndex < blanks.length && blanks[blankIndex].start <= position;
      text.write(isBlank ? ' ' : source[position]);
      offsets.add(position);
      position += 1;
    }
  }

  void separate(String separator, int offset) {
    text.write(separator);
    offsets.add(offset);
  }

  SpellUnit finish(int end) {
    final int last = offsets.isEmpty ? end : math.max(end, offsets.last + 1);
    return SpellUnit(
      text: text.toString(),
      sourceOffsets: List<int>.unmodifiable(<int>[...offsets, last]),
    );
  }
}

SpellUnit _textUnit(String source, MdBlock block, List<MdRange> ancestors) {
  final MdRange range = block.sourceRange;
  final List<MdRange> markers = <MdRange>[
    for (final MdRange marker in ancestors)
      if (marker.start < range.end && range.start < marker.end) marker,
    ...block.markerRanges,
  ];
  final List<MdRange> blanks = <MdRange>[];
  _collectInlineRanges(block.inlines, markers, blanks);
  final _UnitWriter writer = _UnitWriter(source)
    ..write(range.start, range.end, _merged(markers), _merged(blanks));
  return writer.finish(range.end);
}

SpellUnit _tableUnit(String source, MdBlock table) {
  final _UnitWriter writer = _UnitWriter(source);
  int lastEnd = table.sourceRange.start;
  bool isFirstRow = true;
  for (final MdBlock row in table.blocks) {
    if (!isFirstRow) {
      writer.separate('\n', lastEnd);
    }
    isFirstRow = false;
    bool isFirstCell = true;
    for (final MdBlock cell in row.blocks) {
      if (!isFirstCell) {
        writer.separate('\t', lastEnd);
      }
      isFirstCell = false;
      final List<MdRange> markers = <MdRange>[];
      final List<MdRange> blanks = <MdRange>[];
      _collectInlineRanges(cell.inlines, markers, blanks);
      writer.write(
        cell.contentRange.start,
        cell.contentRange.end,
        _merged(markers),
        _merged(blanks),
      );
      lastEnd = cell.contentRange.end;
    }
  }
  return writer.finish(lastEnd);
}

void _collectInlineRanges(
  List<MdInline> inlines,
  List<MdRange> markers,
  List<MdRange> blanks,
) {
  for (final MdInline inline in inlines) {
    markers.addAll(inline.markerRanges);
    if (inline.kind == MdInlineKind.codeSpan ||
        inline.kind == MdInlineKind.autolink) {
      blanks.add(inline.contentRange);
    }
    _collectInlineRanges(inline.children, markers, blanks);
  }
}

List<MdRange> _merged(List<MdRange> ranges) {
  final List<MdRange> sorted = <MdRange>[
    for (final MdRange range in ranges)
      if (!range.isEmpty) range,
  ]..sort((MdRange a, MdRange b) => a.start.compareTo(b.start));
  final List<MdRange> merged = <MdRange>[];
  for (final MdRange range in sorted) {
    if (merged.isNotEmpty && range.start <= merged.last.end) {
      final MdRange last = merged.removeLast();
      merged.add(MdRange(last.start, math.max(last.end, range.end)));
    } else {
      merged.add(range);
    }
  }
  return merged;
}

typedef _CacheKey = (String, String);

class SpellChecker extends ChangeNotifier {
  SpellChecker({
    required this._service,
    required this._state,
    required this._locale,
    this._enabled = false,
    this._available = spellCheckAvailable,
  }) {
    if (_isActive) {
      _startPass();
    }
  }

  final SpellCheckService? _service;
  final bool _available;
  EditorState _state;
  Locale _locale;
  bool _enabled;
  MdRange? _viewport;
  List<SpellMark> _marks = const <SpellMark>[];
  Map<_CacheKey, List<SuggestionSpan>> _cache =
      const <_CacheKey, List<SuggestionSpan>>{};
  Future<void>? _pending;
  List<SpellUnit> _units = const <SpellUnit>[];
  List<_CacheKey> _unitKeys = const <_CacheKey>[];
  List<int> _queue = const <int>[];
  Timer? _timer;
  int _revision = 0;
  int _unitsRevision = -1;
  int _passToken = 0;
  int _session = 0;
  int _failures = 0;
  bool _disposed = false;

  bool get _isActive =>
      !_disposed && _enabled && _available && _service != null;

  bool get enabled => _enabled;

  set enabled(bool value) {
    if (value == _enabled) {
      return;
    }
    final bool wasActive = _isActive;
    _enabled = value;
    if (value) {
      if (_isActive) {
        _startPass();
      }
      return;
    }
    if (wasActive) {
      _stop();
      _notify();
    }
  }

  set locale(Locale value) {
    if (value == _locale) {
      return;
    }
    _locale = value;
    if (_isActive) {
      _startPass();
    }
  }

  set viewport(MdRange sourceRange) {
    _viewport = sourceRange;
  }

  List<SpellMark> get marks => _isActive ? _marks : const <SpellMark>[];

  void didChange(EditorState state, ChangeSet changes) {
    _state = state;
    _revision += 1;
    if (!_isActive) {
      return;
    }
    _passToken += 1;
    _queue = const <int>[];
    final List<SpellMark> mapped = List<SpellMark>.unmodifiable(<SpellMark>[
      for (final SpellMark mark in _marks)
        if (!_isTouched(mark.range, changes))
          SpellMark(
            range: MdRange(
              changes.mapPosition(mark.range.start, side: MapSide.after),
              changes.mapPosition(mark.range.end, side: MapSide.before),
            ),
            suggestions: mark.suggestions,
          ),
    ]);
    _timer?.cancel();
    _timer = state.composing == null ? Timer(spellCheckDelay, _onTimer) : null;
    _setMarks(mapped);
  }

  SpellMark? markAt(int sourceOffset) {
    for (final SpellMark mark in marks) {
      if (mark.range.start <= sourceOffset && sourceOffset <= mark.range.end) {
        return mark;
      }
    }
    return null;
  }

  Transaction? replacement(
    EditorState state,
    SpellMark mark,
    String suggestion,
  ) {
    if (!marks.contains(mark) || mark.range.end > state.source.length) {
      return null;
    }
    return Transaction(
      changes: ChangeSet.single(
        state.source.length,
        mark.range.start,
        mark.range.end,
        suggestion,
      ),
      selection: NoteSelection.collapsed(mark.range.start + suggestion.length),
      event: TransactionEvent.spell,
    );
  }

  List<ContextMenuButtonItem> suggestionItems({
    required EditorState state,
    required int sourceOffset,
    required void Function(Transaction? Function(EditorState state) command)
    onCommand,
  }) {
    final SpellMark? mark = markAt(sourceOffset);
    if (mark == null) {
      return const <ContextMenuButtonItem>[];
    }
    return List<ContextMenuButtonItem>.unmodifiable(<ContextMenuButtonItem>[
      for (final String suggestion in mark.suggestions.take(
        spellSuggestionLimit,
      ))
        ContextMenuButtonItem(
          label: suggestion,
          onPressed: () => onCommand(
            (EditorState s) => replacement(s, mark, suggestion),
          ),
        ),
    ]);
  }

  @override
  void dispose() {
    _stop();
    _disposed = true;
    super.dispose();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _session += 1;
    _passToken += 1;
    _units = const <SpellUnit>[];
    _unitKeys = const <_CacheKey>[];
    _queue = const <int>[];
    _unitsRevision = -1;
    _marks = const <SpellMark>[];
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _setMarks(List<SpellMark> next) {
    if (listEquals(next, _marks)) {
      return;
    }
    _marks = next;
    _notify();
  }

  void _onTimer() {
    _timer = null;
    if (_isActive && _state.composing == null) {
      _startPass();
    }
  }

  void _startPass() {
    _timer?.cancel();
    _timer = null;
    if (_state.composing != null) {
      return;
    }
    _passToken += 1;
    _failures = 0;
    final EditorState state = _state;
    final String language = _locale.toLanguageTag();
    final List<SpellUnit> units = spellUnitsOf(state.source, state.tree);
    final List<_CacheKey> keys = List<_CacheKey>.unmodifiable(<_CacheKey>[
      for (final SpellUnit unit in units) (unit.text, language),
    ]);
    final List<SpellMark> next = <SpellMark>[];
    final List<int> queue = <int>[];
    for (int i = 0; i < units.length; i++) {
      final List<SuggestionSpan>? spans = _cache[keys[i]];
      if (spans != null) {
        next.addAll(_marksOf(units[i], spans));
      } else {
        final MdRange range = units[i].sourceRange;
        next.addAll(
          _marks.where(
            (SpellMark mark) =>
                mark.range.start >= range.start && mark.range.end <= range.end,
          ),
        );
        queue.add(i);
      }
    }
    _units = units;
    _unitKeys = keys;
    _unitsRevision = _revision;
    _queue = List<int>.unmodifiable(queue);
    _setMarks(List<SpellMark>.unmodifiable(next));
    if (queue.isNotEmpty) {
      _scheduleBatch(_passToken);
    }
  }

  void _scheduleBatch(int token) {
    SchedulerBinding.instance.scheduleTask<void>(
      () => _runBatch(token),
      Priority.idle,
    );
  }

  Future<void> _runBatch(int token) async {
    if (_pending != null) {
      await _settled();
    }
    if (token != _passToken || !_isActive) {
      return;
    }
    final SpellCheckService service = _service!;
    final List<int> ordered = _ordered(_queue);
    final Locale locale = _locale;
    final int session = _session;
    int calls = 0;
    int taken = 0;
    while (taken < ordered.length && calls < spellCheckBatch) {
      final int index = ordered[taken];
      taken += 1;
      final _CacheKey key = _unitKeys[index];
      final SpellUnit unit = _units[index];
      final List<SuggestionSpan>? cached = _cache[key];
      if (cached != null) {
        _setMarks(_replacedIn(_marks, unit, cached));
      } else if (unit.text.isEmpty) {
        _cache = <_CacheKey, List<SuggestionSpan>>{
          ..._cache,
          key: const <SuggestionSpan>[],
        };
      } else {
        calls += 1;
        final bool answered = await _request(service, locale, key, session);
        if (token != _passToken || !_isActive) {
          return;
        }
        if (!answered) {
          _retryLater(token, <int>[...ordered.skip(taken), index]);
          return;
        }
        _failures = 0;
      }
    }
    _queue = List<int>.unmodifiable(ordered.skip(taken));
    if (_queue.isNotEmpty) {
      _scheduleBatch(token);
    }
  }

  Future<void> _settled() async {
    for (
      Future<void>? pending = _pending;
      pending != null;
      pending = _pending
    ) {
      await pending;
    }
  }

  void _retryLater(int token, List<int> queue) {
    _failures += 1;
    if (_failures >= spellCheckAttempts) {
      _queue = const <int>[];
      return;
    }
    _queue = List<int>.unmodifiable(queue);
    _timer?.cancel();
    _timer = Timer(spellCheckDelay, () => _onRetry(token));
  }

  void _onRetry(int token) {
    _timer = null;
    if (token == _passToken && _isActive) {
      _scheduleBatch(token);
    }
  }

  Future<bool> _request(
    SpellCheckService service,
    Locale locale,
    _CacheKey key,
    int session,
  ) async {
    final Completer<void> settled = Completer<void>();
    _pending = settled.future;
    final List<SuggestionSpan>? spans = await _fetched(service, locale, key.$1);
    _pending = null;
    settled.complete();
    if (_disposed || session != _session || spans == null) {
      return false;
    }
    final List<SuggestionSpan> stored = List<SuggestionSpan>.unmodifiable(
      spans,
    );
    _cache = <_CacheKey, List<SuggestionSpan>>{..._cache, key: stored};
    if (_unitsRevision != _revision || !_isActive) {
      return true;
    }
    List<SpellMark> marks = _marks;
    for (int i = 0; i < _units.length; i++) {
      if (_unitKeys[i] == key) {
        marks = _replacedIn(marks, _units[i], stored);
      }
    }
    _setMarks(marks);
    return true;
  }

  List<int> _ordered(List<int> queue) {
    final MdRange? viewport = _viewport;
    if (viewport == null) {
      return queue;
    }
    final List<int> inView = <int>[];
    final List<int> rest = <int>[];
    for (final int index in queue) {
      if (_intersects(_units[index].sourceRange, viewport)) {
        inView.add(index);
      } else {
        rest.add(index);
      }
    }
    return <int>[...inView, ...rest];
  }
}

Future<List<SuggestionSpan>?> _fetched(
  SpellCheckService service,
  Locale locale,
  String text,
) async {
  try {
    return await service.fetchSpellCheckSuggestions(locale, text);
  } on Object {
    return null;
  }
}

bool _intersects(MdRange unit, MdRange viewport) => viewport.isEmpty
    ? unit.start <= viewport.start && viewport.start <= unit.end
    : unit.start < viewport.end && viewport.start < unit.end;

bool _isTouched(MdRange range, ChangeSet changes) {
  for (final TextReplacement r in changes.replacements) {
    if (r.from <= range.end && range.start <= r.to) {
      return true;
    }
  }
  return false;
}

List<SpellMark> _marksOf(SpellUnit unit, List<SuggestionSpan> spans) {
  final int length = unit.text.length;
  return <SpellMark>[
    for (final SuggestionSpan span in spans)
      if (span.range.start >= 0 &&
          span.range.start < span.range.end &&
          span.range.end <= length)
        SpellMark(
          range: MdRange(
            unit.sourceOffsets[span.range.start],
            unit.sourceOffsets[span.range.end - 1] + 1,
          ),
          suggestions: List<String>.unmodifiable(
            span.suggestions.take(spellSuggestionLimit),
          ),
        ),
  ];
}

List<SpellMark> _replacedIn(
  List<SpellMark> marks,
  SpellUnit unit,
  List<SuggestionSpan> spans,
) {
  final MdRange range = unit.sourceRange;
  final List<SpellMark> next =
      <SpellMark>[
        for (final SpellMark mark in marks)
          if (mark.range.start < range.start || mark.range.end > range.end)
            mark,
        ..._marksOf(unit, spans),
      ]..sort(
        (SpellMark a, SpellMark b) => a.range.start.compareTo(b.range.start),
      );
  return List<SpellMark>.unmodifiable(next);
}

const double _dotRadius = 0.75;
const double _dotSpacing = 3;
const double _dotLift = 1.75;
const double _zigzagStep = 2;
const double _zigzagHigh = 3;
const double _zigzagLow = 1;

void paintSpellUnderlines(
  Canvas canvas,
  Iterable<Rect> glyphBoxes,
  TargetPlatform platform,
) {
  if (platform == TargetPlatform.macOS) {
    final Paint dot = Paint()
      ..color = CupertinoColors.systemRed
      ..style = PaintingStyle.fill;
    for (final Rect box in glyphBoxes) {
      final double y = box.bottom - _dotLift;
      for (
        double x = box.left + _dotRadius;
        x <= box.right - _dotRadius;
        x += _dotSpacing
      ) {
        canvas.drawCircle(Offset(x, y), _dotRadius, dot);
      }
    }
    return;
  }
  final Paint stroke = Paint()
    ..color = Colors.red
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  for (final Rect box in glyphBoxes) {
    final double low = box.bottom - _zigzagLow;
    final double high = box.bottom - _zigzagHigh;
    final Path path = Path()..moveTo(box.left, low);
    double x = box.left;
    double y = low;
    bool rising = true;
    while (x < box.right) {
      final double target = rising ? high : low;
      final double nextX = math.min(x + _zigzagStep, box.right);
      final double nextY = y + (target - y) * (nextX - x) / _zigzagStep;
      path.lineTo(nextX, nextY);
      x = nextX;
      y = nextY;
      rising = !rising;
    }
    canvas.drawPath(path, stroke);
  }
}

final class SpellUnderlineDecoration extends NoteViewDecoration {
  const SpellUnderlineDecoration({required this.marks, required this.platform});

  final List<SpellMark> marks;
  final TargetPlatform platform;

  @override
  void paint(
    Canvas canvas,
    NoteLayout layout,
    Rect? Function(Rect contentRect) place,
  ) {
    final Rect clip = canvas.getLocalClipBounds();
    for (final SpellMark mark in marks) {
      final List<Rect> boxes = <Rect>[
        for (final Rect box in layout.selectionBoxes(
          NoteSelection(anchor: mark.range.start, head: mark.range.end),
        ))
          ?place(box),
      ].where((Rect box) => box.overlaps(clip)).toList();
      if (boxes.isNotEmpty) {
        paintSpellUnderlines(canvas, boxes, platform);
      }
    }
  }

  @override
  bool shouldRepaint(SpellUnderlineDecoration oldDecoration) =>
      platform != oldDecoration.platform ||
      !listEquals(marks, oldDecoration.marks);
}
