import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/widgets.dart';

const int inputWholeTextLimit = 20000;
const int inputWindowReach = 8000;
const int inputWindowLimit = 16000;
const int inputWindowRebaseMargin = 2000;

@immutable
final class InputWindow {
  const InputWindow({required this.start, required this.end}) : whole = false;

  const InputWindow.whole() : start = 0, end = 0, whole = true;

  final int start;
  final int end;
  final bool whole;

  InputWindow mapThrough(ChangeSet changes) => whole
      ? this
      : InputWindow(
          start: changes.mapPosition(start, side: MapSide.before),
          end: changes.mapPosition(end, side: MapSide.after),
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InputWindow &&
          start == other.start &&
          end == other.end &&
          whole == other.whole;

  @override
  int get hashCode => Object.hash(start, end, whole);

  @override
  String toString() =>
      whole ? 'InputWindow.whole()' : 'InputWindow($start, $end)';
}

InputWindow planInputWindow({
  required VisibleText visible,
  required int plainLength,
  required NoteSelection selection,
  InputWindow? previous,
  bool composing = false,
  bool sending = false,
}) {
  if (plainLength <= inputWholeTextLimit) {
    return const InputWindow.whole();
  }
  if (composing && previous != null) {
    return previous;
  }
  final OffsetMap map = visible.map;
  final int length = visible.text.length;
  final int selectionStart = _toVisible(map, selection.start);
  final int selectionEnd = _toVisible(map, selection.end);
  final int caret = _toVisible(map, selection.head);
  if (previous != null && !previous.whole) {
    final int windowStart = _toVisible(map, previous.start);
    final int windowEnd = _toVisible(map, previous.end);
    final bool holdsSelection =
        selectionStart >= windowStart && selectionEnd <= windowEnd;
    final bool clearOfStart =
        windowStart == 0 || caret - windowStart >= inputWindowRebaseMargin;
    final bool clearOfEnd =
        windowEnd == length || windowEnd - caret >= inputWindowRebaseMargin;
    final bool sendable =
        !sending ||
        windowEnd - windowStart <= inputWindowLimit ||
        selectionEnd - selectionStart > inputWindowLimit;
    if (holdsSelection && clearOfStart && clearOfEnd && sendable) {
      return previous;
    }
  }
  final (int, int) range = _rangeAround(caret, selectionStart, selectionEnd);
  final int low = range.$1 < 0 ? 0 : range.$1;
  final int high = range.$2 > length ? length : range.$2;
  final int inwardStart = _snapForward(visible, low);
  final int start = inwardStart > selectionStart
      ? _snapBackward(visible, low)
      : inwardStart;
  final int inwardEnd = _snapBackward(visible, high);
  final int snappedEnd = inwardEnd < selectionEnd
      ? _snapForward(visible, high)
      : inwardEnd;
  final int end = snappedEnd < start ? start : snappedEnd;
  return InputWindow(
    start: map.visibleToSource(start).downstream,
    end: map.visibleToSource(end).upstream,
  );
}

@immutable
final class WindowedValue {
  const WindowedValue({required this.value, required this.base});

  final TextEditingValue value;
  final int base;
}

WindowedValue windowedValue({
  required VisibleText visible,
  required InputWindow window,
  required TextSelection selection,
  TextRange composing = TextRange.empty,
}) {
  final String text = visible.text;
  final int base = window.whole ? 0 : _toVisible(visible.map, window.start);
  final int end = window.whole
      ? text.length
      : _toVisible(visible.map, window.end);
  final TextSelection shiftedSelection = selection.isValid
      ? selection.copyWith(
          baseOffset: selection.baseOffset - base,
          extentOffset: selection.extentOffset - base,
        )
      : selection;
  final TextRange shiftedComposing =
      composing.isValid && composing.start >= base && composing.end <= end
      ? TextRange(start: composing.start - base, end: composing.end - base)
      : TextRange.empty;
  return WindowedValue(
    value: TextEditingValue(
      text: base == 0 && end == text.length ? text : text.substring(base, end),
      selection: shiftedSelection,
      composing: shiftedComposing,
    ),
    base: base,
  );
}

int _toVisible(OffsetMap map, int sourceOffset) => map.sourceToVisible(
  sourceOffset > map.sourceLength ? map.sourceLength : sourceOffset,
);

(int, int) _rangeAround(int caret, int selectionStart, int selectionEnd) {
  final int low = caret - inputWindowReach;
  final int high = caret + inputWindowReach;
  if (selectionStart >= low && selectionEnd <= high) {
    return (low, high);
  }
  if (selectionEnd - selectionStart <= inputWindowLimit) {
    final int middle = (selectionStart + selectionEnd) ~/ 2;
    return (middle - inputWindowReach, middle + inputWindowReach);
  }
  return (selectionStart, selectionEnd);
}

int _snapForward(VisibleText visible, int offset) {
  final int boundary = _clusterEnd(visible.text, offset);
  final AtomicObject? atomic = visible.atomicAtVisible(boundary);
  return atomic != null && atomic.visibleOffset < boundary
      ? _clusterEnd(visible.text, atomic.visibleRange.end)
      : boundary;
}

int _snapBackward(VisibleText visible, int offset) {
  final int boundary = _clusterStart(visible.text, offset);
  final AtomicObject? atomic = visible.atomicAtVisible(boundary);
  return atomic != null && atomic.visibleOffset < boundary
      ? _clusterStart(visible.text, atomic.visibleOffset)
      : boundary;
}

int _clusterStart(String text, int offset) =>
    CharacterRange.at(text, offset).stringBeforeLength;

int _clusterEnd(String text, int offset) {
  final CharacterRange cluster = CharacterRange.at(text, offset);
  return cluster.stringBeforeLength + cluster.current.length;
}
