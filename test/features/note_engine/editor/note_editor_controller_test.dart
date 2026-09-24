import 'dart:math';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/capabilities.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/history.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingController extends TextEditingController {
  _CountingController();

  int listenerCount = 0;

  @override
  void addListener(VoidCallback listener) {
    listenerCount += 1;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listenerCount -= 1;
    super.removeListener(listener);
  }
}

class _FakeSurface implements NoteEditorSurface {
  _FakeSurface(this.log);

  final List<String> log;
  final List<Future<List<String>> Function()> importers =
      <Future<List<String>> Function()>[];

  @override
  void commitComposition() {
    log.add('commit');
  }

  @override
  Future<void> addPhotos(Future<List<String>> Function() importer) {
    importers.add(importer);
    return Future<void>.value();
  }
}

Transaction _typed(EditorState state, String inserted) => Transaction(
  changes: ChangeSet.single(
    state.source.length,
    state.selection.head,
    state.selection.head,
    inserted,
  ),
  selection: NoteSelection.collapsed(state.selection.head + inserted.length),
  event: TransactionEvent.inputType,
);

Transaction _composing(EditorState state, String inserted) {
  final int at = state.source.length;
  return Transaction(
    changes: ChangeSet.single(at, at, at, inserted),
    selection: NoteSelection.collapsed(at + inserted.length),
    event: TransactionEvent.inputIme,
    composing: MdRange(at, at + inserted.length),
  );
}

int _undoDepth(NoteEditorController controller) =>
    (controller.state.history as NoteHistory).undoDepth;

const String _photo = '![p](photo/abc123abc123)';

void main() {
  test('the controller reads and writes through an attached source', () {
    final TextEditingController source = TextEditingController(text: 'hello');
    final NoteEditorController controller = NoteEditorController.attachedTo(
      source,
    );
    addTearDown(controller.dispose);

    expect(controller.text, 'hello');
    expect(controller.selection, const TextSelection.collapsed(offset: 5));

    controller.value = const TextEditingValue(
      text: 'hello world',
      selection: TextSelection.collapsed(offset: 11),
    );
    expect(source.text, 'hello world');
    expect(source.selection, const TextSelection.collapsed(offset: 11));

    source.value = const TextEditingValue(
      text: 'hello there world',
      selection: TextSelection.collapsed(offset: 11),
    );
    expect(controller.text, 'hello there world');
    expect(controller.selection, const TextSelection.collapsed(offset: 11));
    expect(controller.canUndo, isTrue);

    controller.dispatch(
      Transaction(
        changes: ChangeSet.single(17, 17, 17, '!'),
        selection: const NoteSelection.collapsed(18),
        event: TransactionEvent.inputType,
      ),
    );
    expect(source.text, 'hello there world!');
  });

  test('external writes become transactions and a restore clears history', () {
    final NoteEditorController controller = NoteEditorController();
    addTearDown(controller.dispose);

    controller.value = const TextEditingValue(
      text: 'fog',
      selection: TextSelection.collapsed(offset: 3),
    );
    expect(controller.canUndo, isTrue);

    controller.value = const TextEditingValue(
      text: 'the fog',
      selection: TextSelection.collapsed(offset: 7),
    );
    controller.undo();
    expect(controller.text, 'fog');
    expect(controller.selection, const TextSelection.collapsed(offset: 3));

    controller.text = 'draft body';
    expect(controller.text, 'draft body');
    expect(controller.canUndo, isFalse);
    expect(controller.canRedo, isFalse);
    expect(controller.selection, const TextSelection.collapsed(offset: 10));
  });

  test('dispose detaches from the source', () {
    final _CountingController counting = _CountingController();
    addTearDown(counting.dispose);
    final NoteEditorController controller = NoteEditorController.attachedTo(
      counting,
    );
    expect(counting.listenerCount, 1);

    controller.dispose();
    expect(counting.listenerCount, 0);

    counting.text = 'later';
    expect(counting.text, 'later');
  });

  test('construction starts from the source without writing to it', () {
    final NoteEditorController empty = NoteEditorController();
    addTearDown(empty.dispose);
    expect(empty.text, '');
    expect(empty.selection, const TextSelection.collapsed(offset: 0));

    final NoteEditorController seeded = NoteEditorController(text: 'fog');
    addTearDown(seeded.dispose);
    expect(seeded.selection, const TextSelection.collapsed(offset: 3));
    expect(seeded.canUndo, isFalse);

    final TextEditingController source = TextEditingController.fromValue(
      const TextEditingValue(
        text: 'morning fog',
        selection: TextSelection(baseOffset: 2, extentOffset: 7),
      ),
    );
    addTearDown(source.dispose);
    int sourceNotifications = 0;
    source.addListener(() => sourceNotifications += 1);
    final NoteEditorController attached = NoteEditorController.attachedTo(
      source,
    );
    addTearDown(attached.dispose);
    expect(
      attached.selection,
      const TextSelection(baseOffset: 2, extentOffset: 7),
    );
    expect(sourceNotifications, 0);
  });

  test('listeners run once per write, dispatch and source change', () {
    final TextEditingController source = TextEditingController(text: 'a');
    addTearDown(source.dispose);
    final NoteEditorController controller = NoteEditorController.attachedTo(
      source,
    );
    addTearDown(controller.dispose);
    int notifications = 0;
    final List<Transaction> received = <Transaction>[];
    controller
      ..addListener(() => notifications += 1)
      ..addTransactionListener(received.add);

    controller.value = const TextEditingValue(
      text: 'ab',
      selection: TextSelection.collapsed(offset: 2),
    );
    expect(notifications, 1);
    expect(received, hasLength(1));
    expect(received.single.event, TransactionEvent.external);

    controller.dispatch(_typed(controller.state, 'c'));
    expect(notifications, 2);
    expect(received, hasLength(2));

    source.value = const TextEditingValue(
      text: 'abcd',
      selection: TextSelection.collapsed(offset: 4),
    );
    expect(notifications, 3);
    expect(received, hasLength(3));
    expect(controller.text, 'abcd');

    controller.value = controller.value;
    expect(notifications, 3);
    expect(received, hasLength(3));

    controller.removeTransactionListener(received.add);
    controller.dispatch(_typed(controller.state, 'e'));
    expect(received, hasLength(3));
    expect(notifications, 4);
  });

  test('a selection-only write adds no history entry', () {
    final NoteEditorController controller = NoteEditorController(text: 'fog');
    addTearDown(controller.dispose);
    final List<Transaction> received = <Transaction>[];
    controller.addTransactionListener(received.add);

    controller.selection = const TextSelection.collapsed(offset: 1);
    expect(controller.canUndo, isFalse);
    expect(controller.selection, const TextSelection.collapsed(offset: 1));
    expect(received.single.changes.isEmpty, isTrue);
    expect(received.single.event, TransactionEvent.external);
    expect(received.single.addToHistory, isFalse);
  });

  test('two external writes make two history entries', () {
    final NoteEditorController controller = NoteEditorController();
    addTearDown(controller.dispose);
    controller
      ..value = const TextEditingValue(
        text: 'a',
        selection: TextSelection.collapsed(offset: 1),
      )
      ..value = const TextEditingValue(
        text: 'ab',
        selection: TextSelection.collapsed(offset: 2),
      );
    expect(_undoDepth(controller), 2);
  });

  test('the clock splits typing groups after a 500 ms pause', () {
    Duration now = Duration.zero;
    final NoteEditorController paused = NoteEditorController(clock: () => now);
    addTearDown(paused.dispose);
    paused.dispatch(_typed(paused.state, 'a'));
    now = const Duration(milliseconds: 600);
    paused.dispatch(_typed(paused.state, 'b'));
    expect(_undoDepth(paused), 2);

    now = Duration.zero;
    final NoteEditorController quick = NoteEditorController(clock: () => now);
    addTearDown(quick.dispose);
    quick.dispatch(_typed(quick.state, 'a'));
    now = const Duration(milliseconds: 400);
    quick.dispatch(_typed(quick.state, 'b'));
    expect(_undoDepth(quick), 1);
  });

  test('a transaction dispatched with a time keeps it', () {
    final NoteEditorController controller = NoteEditorController(
      clock: () => const Duration(seconds: 1),
    );
    addTearDown(controller.dispose);
    final List<Transaction> received = <Transaction>[];
    controller.addTransactionListener(received.add);

    controller.dispatch(
      Transaction(
        changes: ChangeSet.single(0, 0, 0, 'a'),
        selection: const NoteSelection.collapsed(1),
        event: TransactionEvent.inputType,
        time: const Duration(seconds: 5),
      ),
    );
    controller.dispatch(_typed(controller.state, 'b'));
    expect(received[0].time, const Duration(seconds: 5));
    expect(received[1].time, const Duration(seconds: 1));
  });

  test('a restore places the caret per C8', () {
    final NoteEditorController controller = NoteEditorController();
    addTearDown(controller.dispose);
    final Map<String, int> cases = <String, int>{
      'A\n$_photo': 1,
      _photo: 0,
      'Walk\n\n$_photo': 4,
      'A\n$_photo\n': 27,
      '   ': 3,
    };
    for (final MapEntry<String, int> entry in cases.entries) {
      controller.text = entry.key;
      expect(controller.text, entry.key);
      expect(
        controller.selection,
        TextSelection.collapsed(offset: entry.value),
        reason: entry.key,
      );
      expect(controller.canUndo, isFalse);
    }
  });

  test('a draft restore during typing clears the history', () {
    final TextEditingController source = TextEditingController();
    addTearDown(source.dispose);
    final NoteEditorController controller = NoteEditorController.attachedTo(
      source,
    );
    addTearDown(controller.dispose);
    controller
      ..dispatch(_typed(controller.state, 'typ'))
      ..dispatch(_typed(controller.state, 'ing'));
    expect(controller.canUndo, isTrue);

    source.text = 'Walk\n\n$_photo';
    expect(controller.text, 'Walk\n\n$_photo');
    expect(controller.canUndo, isFalse);
    expect(controller.canRedo, isFalse);
    expect(controller.selection, const TextSelection.collapsed(offset: 4));
    expect(source.selection, const TextSelection.collapsed(offset: -1));
  });

  test('an interior CRLF survives an external write elsewhere', () {
    const String original = 'one\r\ntwo\r\nthree';
    final NoteEditorController controller = NoteEditorController(
      text: original,
    );
    addTearDown(controller.dispose);
    final List<Transaction> received = <Transaction>[];
    controller.addTransactionListener(received.add);

    controller.value = const TextEditingValue(
      text: '$original!',
      selection: TextSelection.collapsed(offset: 16),
    );
    expect(controller.text.codeUnits, '$original!'.codeUnits);
    expect(received.single.changes, ChangeSet.single(15, 15, 15, '!'));
  });

  test('the tree equals a full parse after typing, deleting and Enter', () {
    final Random random = Random(44);
    const String alphabet = 'ab #*-_`|>=[]()!1.\n ';
    final NoteEditorController controller = NoteEditorController(
      text: '# Title\n\nSome *fog* here\n\n- a\n- b\n',
    );
    addTearDown(controller.dispose);
    for (int step = 0; step < 400; step++) {
      final EditorState state = controller.state;
      final int caret = state.selection.head;
      final int roll = random.nextInt(10);
      if (roll < 6) {
        final String char = alphabet[random.nextInt(alphabet.length)];
        controller.dispatch(_typed(state, char));
      } else if (roll < 8 && caret > 0) {
        controller.dispatch(
          Transaction(
            changes: ChangeSet.single(
              state.source.length,
              caret - 1,
              caret,
              '',
            ),
            selection: NoteSelection.collapsed(caret - 1),
            event: TransactionEvent.inputDelete,
          ),
        );
      } else if (roll < 9) {
        controller.dispatch(_typed(state, '\n'));
      } else {
        controller.selection = TextSelection.collapsed(
          offset: random.nextInt(state.source.length + 1),
        );
      }
      expect(
        controller.state.tree,
        parseNoteTree(controller.text, tables: tablesEnabled),
        reason: 'step $step: ${controller.text}',
      );
    }
    while (controller.canUndo) {
      controller.undo();
      expect(
        controller.state.tree,
        parseNoteTree(controller.text, tables: tablesEnabled),
      );
    }
    expect(controller.text, '# Title\n\nSome *fog* here\n\n- a\n- b\n');
  });

  test('mdEditFromChangeSet spans the change set', () {
    expect(
      mdEditFromChangeSet(
        ChangeSet(
          length: 10,
          replacements: const <TextReplacement>[TextReplacement(2, 5, 'xy')],
        ),
        '01xy56789',
        emptyAt: 0,
      ),
      const MdEdit(start: 2, end: 5, inserted: 'xy'),
    );
    expect(
      mdEditFromChangeSet(
        ChangeSet(
          length: 11,
          replacements: const <TextReplacement>[
            TextReplacement(0, 1, 'H'),
            TextReplacement(5, 6, 'abc_'),
          ],
        ),
        'Helloabc_world',
        emptyAt: 0,
      ),
      const MdEdit(start: 0, end: 6, inserted: 'Helloabc_'),
    );
    expect(
      mdEditFromChangeSet(ChangeSet.empty(7), 'unmoved', emptyAt: 4),
      const MdEdit(start: 4, end: 4, inserted: ''),
    );
  });

  test('framework edits ask the surface to commit the composition first', () {
    final List<String> log = <String>[];
    final NoteEditorController controller = NoteEditorController(text: 'fog');
    addTearDown(controller.dispose);
    controller
      ..attachSurface(_FakeSurface(log))
      ..addTransactionListener(
        (Transaction transaction) => log.add(transaction.event.label),
      )
      ..dispatch(_typed(controller.state, ' a'));

    controller.dispatch(_composing(controller.state, 'k'));
    log.clear();
    controller.value = TextEditingValue(
      text: '${controller.text}!',
      selection: TextSelection.collapsed(offset: controller.text.length + 1),
    );
    expect(log, <String>['commit', 'external']);

    controller.dispatch(_composing(controller.state, 'k'));
    log.clear();
    controller.undo();
    expect(log.first, 'commit');
    expect(log.where((String entry) => entry == 'commit'), hasLength(1));
    expect(log, hasLength(2));

    controller.dispatch(_composing(controller.state, 'k'));
    log.clear();
    controller.applyCommand(
      (EditorState state) => Transaction(
        changes: ChangeSet.single(state.source.length, 0, 0, '*'),
        selection: const NoteSelection.collapsed(1),
        event: TransactionEvent.format,
      ),
    );
    expect(log, <String>['commit', 'format']);
  });

  test('with no surface the controller commits the composition itself', () {
    final NoteEditorController controller = NoteEditorController(text: 'fog');
    addTearDown(controller.dispose);
    controller.dispatch(
      Transaction(
        changes: ChangeSet.single(3, 3, 3, 'x'),
        selection: const NoteSelection.collapsed(4),
        event: TransactionEvent.inputIme,
        composing: const MdRange(3, 4),
      ),
    );
    expect(controller.value.composing, const TextRange(start: 3, end: 4));

    controller.selection = const TextSelection.collapsed(offset: 0);
    expect(controller.state.composing, isNull);
    expect(controller.text, 'fogx');
    expect(
      controller.state.tree,
      parseNoteTree(controller.text, tables: tablesEnabled),
    );

    controller.undo();
    expect(controller.text, 'fog');
    expect(controller.selection, const TextSelection.collapsed(offset: 3));
    expect(controller.canUndo, isFalse);
  });

  test('addPhotos forwards to the attached surface', () {
    final NoteEditorController controller = NoteEditorController();
    addTearDown(controller.dispose);
    Future<List<String>> importer() async => const <String>[];

    expect(() => controller.addPhotos(importer), throwsStateError);

    final _FakeSurface surface = _FakeSurface(<String>[]);
    controller
      ..attachSurface(surface)
      ..detachSurface(_FakeSurface(<String>[]));
    controller.addPhotos(importer);
    expect(surface.importers, hasLength(1));

    controller.detachSurface(surface);
    expect(() => controller.addPhotos(importer), throwsStateError);
  });
}
