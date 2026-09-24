import 'dart:math';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/input/input_window.dart';
import 'package:field_notes/features/note_engine/projection/active_line.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const NoteVisibleProjector _projector = NoteVisibleProjector();

final class _Note {
  _Note(this.source)
    : tree = parseNoteTree(source),
      plainLength = _projector
          .project(source, parseNoteTree(source), null)
          .text
          .length;

  final String source;
  final MdTree tree;
  final int plainLength;

  VisibleText visibleFor(NoteSelection selection) => _projector.project(
    source,
    tree,
    activeLineAt(source, tree, selection).line,
  );

  InputWindow plan(
    NoteSelection selection, {
    InputWindow? previous,
    bool composing = false,
    bool sending = false,
  }) => planInputWindow(
    visible: visibleFor(selection),
    plainLength: plainLength,
    selection: selection,
    previous: previous,
    composing: composing,
    sending: sending,
  );

  WindowedValue windowed(NoteSelection selection, InputWindow window) {
    final VisibleText visible = visibleFor(selection);
    return windowedValue(
      visible: visible,
      window: window,
      selection: TextSelection(
        baseOffset: visible.map.sourceToVisible(selection.anchor),
        extentOffset: visible.map.sourceToVisible(selection.head),
      ),
    );
  }
}

String _plainLines(int count) => ('${'a' * 99}\n') * count;

String _replaced(String source, int from, int to, String inserted) =>
    source.replaceRange(from, to, inserted);

String _emojiNote(int at) => _replaced(
  _replaced(_plainLines(600), at + 52, at + 53, '\n'),
  at,
  at + 4,
  '\u{1F44D}\u{1F3FD}',
);

final _Note _sixtyThousand = _Note(_plainLines(600));

void main() {
  test('notes up to twenty thousand visible units are sent whole', () {
    final _Note twenty = _Note(_plainLines(200));
    expect(twenty.plainLength, 20000);
    const NoteSelection caret = NoteSelection.collapsed(19000);
    final InputWindow window = twenty.plan(caret);
    expect(window, const InputWindow.whole());
    final WindowedValue value = twenty.windowed(caret, window);
    expect(value.base, 0);
    expect(value.value.text, twenty.visibleFor(caret).text);

    final String emphasis = '${'*a* ' * 15}${'a' * 69}\n';
    expect(emphasis.length, 130);
    final _Note marked = _Note(emphasis + _plainLines(199));
    expect(marked.plainLength, 20000);
    const NoteSelection onLineZero = NoteSelection.collapsed(3);
    expect(marked.visibleFor(onLineZero).text.length, 20030);
    expect(marked.plan(onLineZero), const InputWindow.whole());

    final _Note over = _Note('${_plainLines(200)}a');
    expect(over.plainLength, 20001);
    const NoteSelection middle = NoteSelection.collapsed(10000);
    final InputWindow overWindow = over.plan(middle);
    expect(overWindow, const InputWindow(start: 2000, end: 18000));
    expect(over.windowed(middle, overWindow).value.text.length, 16000);
  });

  test('longer notes send at most sixteen thousand units around the caret', () {
    const NoteSelection middle = NoteSelection.collapsed(30000);
    final InputWindow window = _sixtyThousand.plan(middle);
    expect(window, const InputWindow(start: 22000, end: 38000));
    final WindowedValue value = _sixtyThousand.windowed(middle, window);
    expect(value.base, 22000);
    expect(value.value.text.length, 16000);
    expect(value.value.selection, const TextSelection.collapsed(offset: 8000));

    final Random random = Random(3);
    for (int i = 0; i < 1000; i++) {
      final NoteSelection caret = NoteSelection.collapsed(
        random.nextInt(60001),
      );
      final WindowedValue drawn = _sixtyThousand.windowed(
        caret,
        _sixtyThousand.plan(caret),
      );
      expect(drawn.value.text.length, lessThanOrEqualTo(16000));
      expect(drawn.value.selection.isCollapsed, isTrue);
      expect(drawn.value.selection.baseOffset, inInclusiveRange(0, 16000));
      expect(
        drawn.value.selection.baseOffset,
        lessThanOrEqualTo(drawn.value.text.length),
      );
    }

    final _Note startEmoji = _Note(_emojiNote(21998));
    expect(startEmoji.source.length, 60000);
    expect(startEmoji.plan(middle).start, 22002);

    final _Note endEmoji = _Note(_emojiNote(37998));
    expect(endEmoji.source.length, 60000);
    expect(endEmoji.plan(middle).end, 37998);
  });

  test('the window grows to hold a long selection', () {
    const NoteSelection long = NoteSelection(anchor: 10000, head: 40000);
    final InputWindow grown = _sixtyThousand.plan(long);
    expect(grown, const InputWindow(start: 10000, end: 40000));
    final WindowedValue value = _sixtyThousand.windowed(long, grown);
    expect(value.value.text.length, 30000);
    expect(
      value.value.selection,
      const TextSelection(baseOffset: 0, extentOffset: 30000),
    );

    expect(
      _sixtyThousand.plan(
        const NoteSelection.collapsed(40000),
        previous: grown,
      ),
      const InputWindow(start: 32000, end: 48000),
    );

    expect(
      _sixtyThousand.plan(const NoteSelection(anchor: 32000, head: 20000)),
      const InputWindow(start: 18000, end: 34000),
    );
  });

  test('the window does not re-base at the start or end of the text', () {
    final InputWindow nearStart = _sixtyThousand.plan(
      const NoteSelection.collapsed(500),
    );
    expect(nearStart, const InputWindow(start: 0, end: 8500));
    expect(
      _sixtyThousand.plan(
        const NoteSelection.collapsed(300),
        previous: nearStart,
      ),
      nearStart,
    );
    expect(
      _sixtyThousand.plan(
        const NoteSelection.collapsed(7000),
        previous: nearStart,
      ),
      const InputWindow(start: 0, end: 15000),
    );

    final InputWindow nearEnd = _sixtyThousand.plan(
      const NoteSelection.collapsed(59500),
    );
    expect(nearEnd, const InputWindow(start: 51500, end: 60000));
    expect(
      _sixtyThousand.plan(
        const NoteSelection.collapsed(59800),
        previous: nearEnd,
      ),
      nearEnd,
    );

    expect(
      _sixtyThousand.plan(
        const NoteSelection.collapsed(7000),
        previous: const InputWindow(start: 0, end: 8500),
        composing: true,
      ),
      const InputWindow(start: 0, end: 8500),
    );
  });

  test('a single thirty thousand unit line is windowed around the caret', () {
    final _Note line = _Note('a' * 30000);
    expect(
      line.plan(const NoteSelection.collapsed(15000)),
      const InputWindow(start: 7000, end: 23000),
    );
  });

  test('mapThrough moves the window with the text', () {
    const InputWindow window = InputWindow(start: 22000, end: 38000);
    expect(
      window.mapThrough(ChangeSet.single(60000, 22000, 22000, 'xy')),
      const InputWindow(start: 22000, end: 38002),
    );
    expect(
      window.mapThrough(ChangeSet.single(60000, 38000, 38000, 'xy')),
      const InputWindow(start: 22000, end: 38002),
    );
    expect(
      window.mapThrough(ChangeSet.single(60000, 100, 100, 'xyz')),
      const InputWindow(start: 22003, end: 38003),
    );
    expect(
      const InputWindow.whole().mapThrough(
        ChangeSet.single(60000, 100, 100, 'xyz'),
      ),
      const InputWindow.whole(),
    );
  });

  test('a grown window is re-trimmed only when a value is sent', () {
    final _Note typed = _Note(
      _replaced(_plainLines(600), 25000, 25000, 'aaaaa'),
    );
    expect(typed.source.length, 60005);
    const InputWindow grown = InputWindow(start: 22000, end: 38005);
    const NoteSelection caret = NoteSelection.collapsed(30000);
    expect(typed.plan(caret, previous: grown), grown);
    expect(
      typed.plan(caret, previous: grown, sending: true),
      const InputWindow(start: 22000, end: 38000),
    );
  });

  test('a checkbox object at a cut is not split', () {
    final _Note boxed = _Note(
      _replaced(_plainLines(600), 22000, 22099, '- [ ] ${'a' * 93}'),
    );
    const NoteSelection caret = NoteSelection.collapsed(30005);
    final VisibleText visible = boxed.visibleFor(caret);
    expect(visible.map.sourceToVisible(30005), 30001);
    expect(
      visible.atomics.any(
        (AtomicObject atomic) =>
            atomic.kind == AtomicKind.checkbox &&
            atomic.visibleRange == const MdRange(22000, 22002),
      ),
      isTrue,
    );
    final InputWindow window = boxed.plan(caret);
    expect(window, const InputWindow(start: 22006, end: 38005));
    expect(boxed.windowed(caret, window).base, 22002);
  });

  test('windowedValue shifts selection and composing by the base', () {
    const NoteSelection caret = NoteSelection.collapsed(30000);
    final VisibleText visible = _sixtyThousand.visibleFor(caret);
    const InputWindow window = InputWindow(start: 22000, end: 38000);
    final WindowedValue inside = windowedValue(
      visible: visible,
      window: window,
      selection: const TextSelection(baseOffset: 30010, extentOffset: 30000),
      composing: const TextRange(start: 29995, end: 30005),
    );
    expect(
      inside.value.selection,
      const TextSelection(baseOffset: 8010, extentOffset: 8000),
    );
    expect(inside.value.composing, const TextRange(start: 7995, end: 8005));

    final WindowedValue crossing = windowedValue(
      visible: visible,
      window: window,
      selection: const TextSelection.collapsed(offset: 22001),
      composing: const TextRange(start: 21995, end: 22005),
    );
    expect(crossing.value.composing, TextRange.empty);
    expect(crossing.value.selection, const TextSelection.collapsed(offset: 1));
  });

  test('a selection covering the whole note gives the whole note', () {
    expect(
      _sixtyThousand.plan(const NoteSelection(anchor: 0, head: 60000)),
      const InputWindow(start: 0, end: 60000),
    );
  });

  test('whole mode ignores previous and composing', () {
    final _Note twenty = _Note(_plainLines(200));
    expect(
      twenty.plan(
        const NoteSelection.collapsed(100),
        previous: const InputWindow(start: 0, end: 8500),
        composing: true,
      ),
      const InputWindow.whole(),
    );
  });

  test('InputWindow equality and hashCode', () {
    const InputWindow a = InputWindow(start: 1, end: 2);
    const InputWindow b = InputWindow(start: 1, end: 2);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(const InputWindow(start: 1, end: 3)));
    expect(a, isNot(const InputWindow(start: 0, end: 2)));
    expect(
      const InputWindow(start: 0, end: 0),
      isNot(const InputWindow.whole()),
    );
    expect(const InputWindow.whole(), const InputWindow.whole());
    expect(
      const InputWindow.whole().hashCode,
      const InputWindow.whole().hashCode,
    );
    expect(a.toString(), 'InputWindow(1, 2)');
  });
}
