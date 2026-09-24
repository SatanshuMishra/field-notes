import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/photos/photo_commands.dart';
import 'package:field_notes/features/note_engine/photos/photo_relocation.dart';
import 'package:flutter_test/flutter_test.dart';

const String p = '![p](photo/abc123abc123)';

EditorState stateOf(
  String source, [
  NoteSelection selection = const NoteSelection.collapsed(0),
]) => EditorState.create(source, parse: parseNoteTree, selection: selection);

EditorState caretAt(String source, int offset) =>
    stateOf(source, NoteSelection.collapsed(offset));

EditorState selecting(String source, int anchor, int head) =>
    stateOf(source, NoteSelection(anchor: anchor, head: head));

MdBlock photoIn(EditorState state, [int nth = 0]) => <MdBlock>[
  for (final MdBlock block in state.tree.blocks)
    if (block.kind == MdBlockKind.photoLine) block,
][nth];

String applied(EditorState state, Transaction transaction) =>
    transaction.changes.apply(state.source);

void expectPhotoTransaction(EditorState state, Transaction transaction) {
  expect(transaction.event, TransactionEvent.photo);
  expect(transaction.addToHistory, isTrue);
  expect(transaction.composing, isNull);
  final String next = applied(state, transaction);
  final MdTree tree = parseNoteTree(next);
  final MdBlock? unit = tree.blockAt(transaction.selection.start);
  expect(unit?.kind, MdBlockKind.photoLine);
  expect(
    MdRange(transaction.selection.start, transaction.selection.end),
    unit!.sourceRange,
  );
}

Transaction sizeOf(String source, MdPhotoSize size) {
  final EditorState state = stateOf(source);
  final Transaction transaction = setPhotoSize(state, photoIn(state), size)!;
  expectPhotoTransaction(state, transaction);
  return transaction;
}

Transaction sideOf(String source, MdPhotoSide side) {
  final EditorState state = stateOf(source);
  final Transaction transaction = setPhotoSide(state, photoIn(state), side)!;
  expectPhotoTransaction(state, transaction);
  return transaction;
}

String photoWithTitle(String title) => '![](photo/abc123abc123 "$title")';

void main() {
  test('a size press on an invalid placement writes centre and the size', () {
    final List<(String, String)> sizeCases = <(String, String)>[
      ('right huge', 'centre large'),
      ('left small nofloat', 'centre large'),
    ];
    for (final (String before, String after) in sizeCases) {
      final String source = photoWithTitle(before);
      expect(
        sizeOf(source, MdPhotoSize.large).changes.apply(source),
        photoWithTitle(after),
      );
    }
    final String leftLeft = photoWithTitle('left left');
    expect(
      sizeOf(leftLeft, MdPhotoSize.small).changes.apply(leftLeft),
      photoWithTitle('centre small'),
    );
    final String huge = photoWithTitle('right huge');
    expect(
      sideOf(huge, MdPhotoSide.left).changes.apply(huge),
      photoWithTitle('left medium'),
    );
  });

  test('typing with a photo selected starts a new line after it', () {
    final EditorState state = selecting('A\n$p\nB', 2, 26);
    final Transaction typed = typeOverSelectedPhoto(state, 'h')!;
    expect(applied(state, typed), 'A\n$p\nh\nB');
    expect(typed.selection, const NoteSelection.collapsed(28));
    expect(typed.event, TransactionEvent.inputType);

    final Transaction enter = typeOverSelectedPhoto(state, '')!;
    expect(applied(state, enter), 'A\n$p\n\nB');
    expect(enter.selection, const NoteSelection.collapsed(27));

    final EditorState crlf = selecting('A\r\n$p\r\nB', 3, 27);
    final Transaction crlfTyped = typeOverSelectedPhoto(crlf, 'h')!;
    expect(applied(crlf, crlfTyped), 'A\r\n$p\r\nh\r\nB');
    expect(crlfTyped.selection, const NoteSelection.collapsed(30));

    final EditorState alone = selecting(p, 0, 24);
    final Transaction aloneTyped = typeOverSelectedPhoto(alone, 'h')!;
    expect(applied(alone, aloneTyped), '$p\nh');
    expect(aloneTyped.selection, const NoteSelection.collapsed(26));

    expect(typeOverSelectedPhoto(caretAt('A\n$p\nB', 0), 'h'), isNull);
  });

  test('the first backspace selects the photo and the second removes it', () {
    const String source = 'A\n$p\nB';
    final PhotoKeyResult? first = photoBackspace(caretAt(source, 27));
    expect(first, isA<PhotoKeySelect>());
    final NoteSelection selection = (first! as PhotoKeySelect).selection;
    expect(selection, const NoteSelection(anchor: 2, head: 26));
    final EditorState selected = stateOf(source, selection);
    final PhotoKeyResult? second = photoBackspace(selected);
    expect(second, isA<PhotoKeyEdit>());
    final Transaction removal = (second! as PhotoKeyEdit).transaction;
    expect(applied(selected, removal), 'A\n\nB');
    expect(removal.selection, const NoteSelection.collapsed(3));
    expect(removal.event, TransactionEvent.photo);

    final PhotoKeyResult? forward = photoDelete(caretAt(source, 1));
    expect(forward, isA<PhotoKeySelect>());
    final NoteSelection forwardSelection =
        (forward! as PhotoKeySelect).selection;
    expect(forwardSelection, const NoteSelection(anchor: 2, head: 26));
    final EditorState forwardSelected = stateOf(source, forwardSelection);
    final PhotoKeyResult? forwardSecond = photoDelete(forwardSelected);
    expect(forwardSecond, isA<PhotoKeyEdit>());
    final Transaction forwardRemoval =
        (forwardSecond! as PhotoKeyEdit).transaction;
    expect(applied(forwardSelected, forwardRemoval), 'A\n\nB');
    expect(forwardRemoval.selection, const NoteSelection.collapsed(3));
    expect(forwardRemoval.event, TransactionEvent.photo);

    for (final Object? result in <Object?>[
      first,
      second,
      forward,
      forwardSecond,
    ]) {
      expect(result, isNot(isA<PhotoCommandResult>()));
    }
  });

  test('cut takes the photo line under the removal rule', () {
    final EditorState state = selecting('A\n\n$p\nB', 3, 27);
    final ({String text, Transaction transaction}) cut = cutSelectedPhoto(
      state,
    )!;
    expect(cut.text, p);
    expect(applied(state, cut.transaction), 'A\n\nB');
    expect(cut.transaction.event, TransactionEvent.photo);
    expect(copySelectedPhoto(state), p);
    expect(state.source, 'A\n\n$p\nB');

    final EditorState onText = caretAt('A\n\n$p\nB', 0);
    expect(cutSelectedPhoto(onText), isNull);
    expect(copySelectedPhoto(onText), isNull);
  });

  test('caption and replace keep the title bytes', () {
    void expectSlot(
      String source,
      Transaction? Function(EditorState, MdBlock) command,
      String expected,
      MdRange Function(MdPhotoLine) slot,
    ) {
      final EditorState state = stateOf(source);
      final MdBlock photo = photoIn(state);
      final Transaction transaction = command(state, photo)!;
      expect(applied(state, transaction), expected);
      final TextReplacement replacement =
          transaction.changes.replacements.single;
      final MdRange range = slot(MdPhotoLine.ofBlock(photo, source));
      expect(replacement.from, range.start);
      expect(replacement.to, range.end);
      expectPhotoTransaction(state, transaction);
    }

    MdRange caption(MdPhotoLine line) => line.captionRange;
    MdRange reference(MdPhotoLine line) => line.referenceRange;

    expectSlot(
      '![](photo/4fef9c2c3c9a "left medium")',
      (EditorState s, MdBlock b) => setPhotoCaption(s, b, 'Low tide'),
      '![Low tide](photo/4fef9c2c3c9a "left medium")',
      caption,
    );
    expectSlot(
      '![Old](photo/abc123abc123 "Right   HUGE")',
      (EditorState s, MdBlock b) =>
          setPhotoCaption(s, b, '  the [old] porch\nat dusk  '),
      '![the [old porch at dusk](photo/abc123abc123 "Right   HUGE")',
      caption,
    );
    expectSlot(
      '![Old](photo/abc123abc123 "left large")',
      (EditorState s, MdBlock b) => setPhotoCaption(s, b, ''),
      '![](photo/abc123abc123 "left large")',
      caption,
    );
    expectSlot(
      '![Porch](photo/abc123abc123 "right large")',
      (EditorState s, MdBlock b) => replacePhotoReference(s, b, 'def456def456'),
      '![Porch](photo/def456def456 "right large")',
      reference,
    );
    expectSlot(
      '![Porch](photo/abc123abc123)',
      (EditorState s, MdBlock b) => replacePhotoReference(s, b, 'def456def456'),
      '![Porch](photo/def456def456)',
      reference,
    );
  });

  test('size and side rewrites change only the title', () {
    void expectTitleOnly(
      String source,
      Transaction transaction,
      String expected,
    ) {
      expect(transaction.changes.apply(source), expected);
      final EditorState state = stateOf(source);
      final MdPhotoLine line = MdPhotoLine.ofBlock(photoIn(state), source);
      final MdRange slot =
          line.titleRange ??
          MdRange(line.referenceRange.end, line.referenceRange.end);
      final TextReplacement replacement =
          transaction.changes.replacements.single;
      expect(replacement.from, slot.start);
      expect(replacement.to, slot.end);
      final int after = photoIn(state).sourceRange.end;
      final int delta = expected.length - source.length;
      expect(
        transaction.changes.mapPosition(after, side: MapSide.after),
        after + delta,
      );
      expect(
        transaction.changes.mapPosition(source.length, side: MapSide.after),
        source.length + delta,
      );
    }

    const String spaced = '  ![Porch](photo/ABC123 "LEFT small")  \r\nnext';
    expectTitleOnly(
      spaced,
      sizeOf(spaced, MdPhotoSize.large),
      '  ![Porch](photo/ABC123 "left large")  \r\nnext',
    );
    expectTitleOnly(
      p,
      sizeOf(p, MdPhotoSize.small),
      '![p](photo/abc123abc123 "right small")',
    );
    final String center = photoWithTitle('center large');
    expectTitleOnly(
      center,
      sideOf(center, MdPhotoSide.right),
      photoWithTitle('right large'),
    );
    final String leftSmall = photoWithTitle('left small');
    expectTitleOnly(
      leftSmall,
      sideOf(leftSmall, MdPhotoSide.centre),
      photoWithTitle('centre small'),
    );

    final EditorState full = stateOf(photoWithTitle('left full'));
    expect(setPhotoSide(full, photoIn(full), MdPhotoSide.right), isNull);
    final EditorState small = stateOf(leftSmall);
    expect(setPhotoSize(small, photoIn(small), MdPhotoSize.small), isNull);
  });

  test('token rewrites keep the other slots', () {
    final String leftSmall = photoWithTitle('left small');
    expect(
      sizeOf(leftSmall, MdPhotoSize.large).changes.apply(leftSmall),
      photoWithTitle('left large'),
    );
    expect(
      sideOf(leftSmall, MdPhotoSide.right).changes.apply(leftSmall),
      photoWithTitle('right small'),
    );
    const String captioned = '![Porch](photo/abc123abc123 "right large")';
    final EditorState state = stateOf(captioned);
    final Transaction replaced = replacePhotoReference(
      state,
      photoIn(state),
      'def456def456',
    )!;
    final MdPhotoLine line = MdPhotoLine.ofBlock(
      parseNoteTree(applied(state, replaced)).blocks.single,
      applied(state, replaced),
    );
    expect(line.caption, 'Porch');
    expect(line.placement, const MdPhotoPlacement(size: MdPhotoSize.large));
    expect(
      photoSelection(captioned, photoIn(state)),
      NoteSelection(anchor: 0, head: captioned.length),
    );
  });

  test('a press on a marked control writes nothing', () {
    final EditorState plain = stateOf(p);
    expect(setPhotoSize(plain, photoIn(plain), MdPhotoSize.medium), isNull);
    expect(setPhotoSide(plain, photoIn(plain), MdPhotoSide.right), isNull);
    final EditorState upper = stateOf(photoWithTitle('LEFT small'));
    expect(setPhotoSize(upper, photoIn(upper), MdPhotoSize.small), isNull);
    expect(upper.source, photoWithTitle('LEFT small'));
    final String invalid = photoWithTitle('centre centre');
    expect(
      sideOf(invalid, MdPhotoSide.centre).changes.apply(invalid),
      photoWithTitle('centre medium'),
    );
  });

  test('moves keep the photo selected and stop at the ends', () {
    final EditorState middle = stateOf('A\n\n$p\n\nB');
    final Transaction up = movePhotoUp(middle, photoIn(middle))!;
    expect(applied(middle, up), '$p\nA\n\nB');
    expectPhotoTransaction(middle, up);

    final EditorState down = stateOf('A\n$p\n\nB');
    final Transaction moved = movePhotoDown(down, photoIn(down))!;
    expect(applied(down, moved), 'A\n\nB\n$p');
    expectPhotoTransaction(down, moved);

    final EditorState first = stateOf('$p\n\nA');
    expect(canMovePhotoUp(first, photoIn(first)), isFalse);
    expect(movePhotoUp(first, photoIn(first)), isNull);
    expect(canMovePhotoDown(first, photoIn(first)), isTrue);
    final EditorState last = stateOf('A\n\n$p');
    expect(canMovePhotoDown(last, photoIn(last)), isFalse);
    expect(movePhotoDown(last, photoIn(last)), isNull);
    final EditorState fenced = stateOf('A\n$p\n~~~\ncode');
    expect(canMovePhotoDown(fenced, photoIn(fenced)), isFalse);
    expect(movePhotoDown(fenced, photoIn(fenced)), isNull);
  });

  test('remove shows the removal toast and inverts byte for byte', () {
    const String source = 'A\n$p\nB';
    final EditorState state = stateOf(source);
    final PhotoCommandResult result = removePhoto(state, photoIn(state));
    expect(applied(state, result.transaction), 'A\n\nB');
    expect(result.toast, PhotoToast.removed);
    expect(result.transaction.event, TransactionEvent.photo);
    expect(
      result.transaction.changes
          .invert(source)
          .apply(applied(state, result.transaction)),
      source,
    );
    expect(photoRemovedToastMessage, 'Photo removed');
    expect(photoRemovedToastActionLabel, 'Undo');
  });

  test('selectedPhoto follows the selection rule', () {
    const String source = 'A\n$p\nB';
    final MdBlock photo = photoIn(stateOf(source));
    expect(selectedPhoto(selecting(source, 2, 26)), photo);
    expect(selectedPhoto(selecting(source, 26, 2)), photo);
    expect(selectedPhoto(selecting(source, 2, 27)), photo);
    expect(selectedPhoto(selecting(source, 27, 2)), photo);
    expect(selectedPhoto(caretAt(source, 2)), photo);
    expect(selectedPhoto(caretAt(source, 10)), photo);
    expect(selectedPhoto(caretAt(source, 26)), photo);
    expect(selectedPhoto(selecting(source, 2, 28)), isNull);
    expect(selectedPhoto(caretAt(source, 1)), isNull);
    expect(selectedPhoto(caretAt(source, 27)), isNull);

    const String crlf = 'A\r\n$p\r\nB';
    final MdBlock crlfPhoto = photoIn(stateOf(crlf));
    expect(selectedPhoto(selecting(crlf, 3, 29)), crlfPhoto);
    expect(selectedPhoto(selecting(crlf, 3, 28)), isNull);

    expect(selectedPhoto(caretAt('> $p', 5)), isNull);

    final EditorState withBreak = selecting(source, 2, 27);
    final PhotoKeyResult? result = photoBackspace(withBreak);
    expect(result, isA<PhotoKeyEdit>());
    expect(applied(withBreak, (result! as PhotoKeyEdit).transaction), 'A\n\nB');
  });

  test('a composition over a selected photo composes on the new line', () {
    final EditorState state = selecting('A\n$p\nB', 2, 26);
    final Transaction composed = typeOverSelectedPhoto(
      state,
      'n',
      composing: true,
    )!;
    expect(applied(state, composed), 'A\n$p\nn\nB');
    expect(composed.event, TransactionEvent.inputIme);
    expect(composed.addToHistory, isTrue);
    expect(composed.composing, const MdRange(27, 28));
    expect(composed.selection, const NoteSelection.collapsed(28));
    expect(
      () => typeOverSelectedPhoto(state, '', composing: true),
      throwsArgumentError,
    );
    expect(typeOverSelectedPhoto(state, ''), isNotNull);
  });

  test('keys away from the photo line do nothing', () {
    const String source = 'A\n$p\nBcd';
    expect(photoBackspace(caretAt(source, 28)), isNull);
    expect(photoDelete(caretAt('Abc\n$p', 1)), isNull);
    expect(photoBackspace(caretAt('> $p\nB', 27)), isNull);
    expect(photoDelete(caretAt('A\n> $p', 1)), isNull);
  });

  test('an upper-case reference and an invalid title survive', () {
    const String odd = '![x](photo/ABC123 "Left Huge")';
    final EditorState state = stateOf('A\n\n$odd\n\nB');
    final Transaction captioned = setPhotoCaption(
      state,
      photoIn(state),
      'Dusk',
    )!;
    expect(
      applied(state, captioned),
      'A\n\n![Dusk](photo/ABC123 "Left Huge")\n\nB',
    );
    final Transaction replaced = replacePhotoReference(
      state,
      photoIn(state),
      'DEF456',
    )!;
    expect(
      applied(state, replaced),
      'A\n\n![x](photo/DEF456 "Left Huge")\n\nB',
    );
    expect(applied(state, movePhotoUp(state, photoIn(state))!), '$odd\nA\n\nB');
    expect(
      () => replacePhotoReference(state, photoIn(state), 'xyz'),
      throwsArgumentError,
    );
    expect(
      () => replacePhotoReference(state, photoIn(state), ''),
      throwsArgumentError,
    );
    final EditorState other = stateOf('xy\n\n$p');
    expect(
      () => setPhotoSize(state, photoIn(other), MdPhotoSize.small),
      throwsArgumentError,
    );
    expect(
      () => setPhotoSize(state, state.tree.blocks.first, MdPhotoSize.small),
      throwsArgumentError,
    );
  });
}
