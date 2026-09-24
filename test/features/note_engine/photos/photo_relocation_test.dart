import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/photos/photo_relocation.dart';
import 'package:flutter_test/flutter_test.dart';

const String p = '![p](photo/abc123abc123)';
const String canonical = '![](photo/abc123abc123 "right medium")';

List<MdBlock> photosOf(MdTree tree) => <MdBlock>[
  for (final MdBlock block in tree.blocks)
    if (block.kind == MdBlockKind.photoLine) block,
];

MdBlock onlyPhoto(MdTree tree) => photosOf(tree).single;

void expectCleanEdit(String source, ChangeSet changes) {
  final String after = changes.apply(source);
  int cursor = 0;
  int shift = 0;
  for (final TextReplacement r in changes.replacements) {
    expect(
      after.substring(cursor + shift, r.from + shift),
      source.substring(cursor, r.from),
    );
    for (final int offset in <int>[r.from, r.to]) {
      final bool splitsCrlf =
          offset > 0 &&
          offset < source.length &&
          source.codeUnitAt(offset - 1) == 0x0D &&
          source.codeUnitAt(offset) == 0x0A;
      expect(splitsCrlf, isFalse, reason: 'offset $offset splits a CRLF');
    }
    shift += r.inserted.length - (r.to - r.from);
    cursor = r.to;
  }
  expect(after.substring(cursor + shift), source.substring(cursor));
}

PhotoEdit removeOnly(String source) {
  final MdTree tree = parseNoteTree(source);
  return photoRemoval(source, tree, onlyPhoto(tree));
}

PhotoEdit? moveUp(String source, {int nth = 0}) {
  final MdTree tree = parseNoteTree(source);
  final MdBlock photo = photosOf(tree)[nth];
  final int? boundary = photoMoveUpBoundary(source, tree, photo);
  return boundary == null
      ? null
      : photoRelocation(source, tree, photo, boundary);
}

PhotoEdit? moveDown(String source, {int nth = 0}) {
  final MdTree tree = parseNoteTree(source);
  final MdBlock photo = photosOf(tree)[nth];
  final int? boundary = photoMoveDownBoundary(source, tree, photo);
  return boundary == null
      ? null
      : photoRelocation(source, tree, photo, boundary);
}

String insertAt(String source, int caret, List<String> references) {
  final MdTree tree = parseNoteTree(source);
  final PhotoTarget target = photoTargetAt(source, tree, caret);
  final PhotoEdit edit = photoInsertion(source, target, references);
  expect(edit.changes.replacements, hasLength(1));
  expectCleanEdit(source, edit.changes);
  return edit.changes.apply(source);
}

void main() {
  test('removal keeps the longer separator or an empty line', () {
    final List<(String, String, int?)> cases = <(String, String, int?)>[
      ('A\n$p\nB', 'A\n\nB', 3),
      ('A\n\n$p\nB', 'A\n\nB', 3),
      ('A\n$p\n\nB', 'A\n\nB', 2),
      ('A\n\n$p\n\n\nB', 'A\n\n\nB', null),
      ('$p\n\nA', 'A', 0),
      ('A\n\n$p', 'A', 1),
      (p, '', 0),
      ('A\r\n$p\r\nB', 'A\r\n\r\nB', null),
      ('A\r\n\r\n$p\nB', 'A\r\n\r\nB', null),
    ];
    for (final (String source, String expected, int? caret) in cases) {
      final PhotoEdit edit = removeOnly(source);
      expect(edit.changes.replacements, hasLength(1), reason: source);
      expect(edit.changes.apply(source), expected, reason: source);
      expectCleanEdit(source, edit.changes);
      if (caret != null) {
        expect(edit.selection, NoteSelection.collapsed(caret), reason: source);
      }
    }
  });

  test('move up and move down reproduce the spec examples', () {
    final PhotoEdit up = moveUp('A\n\n$p\n\nB')!;
    expect(up.changes.apply('A\n\n$p\n\nB'), '$p\nA\n\nB');
    expect(up.selection, const NoteSelection(anchor: 0, head: 24));

    const String downSource = 'A\n$p\n\nB';
    final PhotoEdit down = moveDown(downSource)!;
    final String moved = down.changes.apply(downSource);
    expect(moved, 'A\n\nB\n$p');
    expect(down.selection, const NoteSelection(anchor: 5, head: 29));
    final PhotoEdit back = moveUp(moved)!;
    expect(back.changes.apply(moved), downSource);
    expect(back.selection, const NoteSelection(anchor: 2, head: 26));

    final PhotoEdit joined = moveUp('A\n$p\nB')!;
    expect(joined.changes.apply('A\n$p\nB'), '$p\nA\n\nB');
    expect(joined.selection, const NoteSelection(anchor: 0, head: 24));

    const String tableSource = '$p\n| a |\n| --- |';
    final PhotoEdit table = moveDown(tableSource)!;
    final String tabled = table.changes.apply(tableSource);
    expect(tabled, '| a |\n| --- |\n$p');
    expect(table.selection, const NoteSelection(anchor: 14, head: 38));
    final MdTree tableTree = parseNoteTree(tabled);
    expect(tableTree.blocks, hasLength(2));
    expect(tableTree.blocks.first.kind, MdBlockKind.table);
    expect(
      tableTree.blocks.first.sourceRange.sliceOf(tabled),
      '| a |\n| --- |',
    );
    expect(tableTree.blocks.last.kind, MdBlockKind.photoLine);

    for (final String source in <String>[
      'A\n\n$p\n\nB',
      downSource,
      moved,
      'A\n$p\nB',
      tableSource,
    ]) {
      final PhotoEdit edit = moveUp(source) ?? moveDown(source)!;
      expectCleanEdit(source, edit.changes);
    }

    final MdTree firstTree = parseNoteTree(tableSource);
    expect(
      photoMoveUpBoundary(tableSource, firstTree, onlyPhoto(firstTree)),
      isNull,
    );
    final MdTree lastTree = parseNoteTree(tabled);
    expect(
      photoMoveDownBoundary(tabled, lastTree, onlyPhoto(lastTree)),
      isNull,
    );
  });

  test('two lists that commonmark joins stay joined after removal', () {
    const String bullets = '- a\n$p\n- b';
    final String removed = removeOnly(bullets).changes.apply(bullets);
    expect(removed, '- a\n\n- b');
    final MdTree tree = parseNoteTree(removed);
    expect(tree.blocks, hasLength(1));
    expect(tree.blocks.single.kind, MdBlockKind.bulletList);
    expect(tree.blocks.single.blocks, hasLength(2));

    expect(moveDown(bullets)!.changes.apply(bullets), '- a\n\n- b\n$p');
    expect(moveUp(bullets)!.changes.apply(bullets), '$p\n- a\n\n- b');

    const String ordered = '1. a\n$p\n2. b';
    final String orderedRemoved = removeOnly(ordered).changes.apply(ordered);
    expect(orderedRemoved, '1. a\n\n2. b');
    final MdTree orderedTree = parseNoteTree(orderedRemoved);
    expect(orderedTree.blocks, hasLength(1));
    expect(orderedTree.blocks.single.kind, MdBlockKind.orderedList);
    expect(orderedTree.blocks.single.blocks, hasLength(2));

    const String continued = '- a\n$p\n  b';
    final String continuedRemoved = removeOnly(
      continued,
    ).changes.apply(continued);
    expect(continuedRemoved, '- a\n\n  b');
    final MdTree continuedTree = parseNoteTree(continuedRemoved);
    expect(continuedTree.blocks, hasLength(1));
    expect(continuedTree.blocks.single.kind, MdBlockKind.bulletList);
    final MdBlock item = continuedTree.blocks.single.blocks.single;
    expect(item.blocks, hasLength(2));
    expect(
      item.blocks.every((MdBlock b) => b.kind == MdBlockKind.paragraph),
      isTrue,
    );
  });

  test('there is no boundary after an unclosed fence', () {
    const String fenced = '$p\nA\n\n~~~\ncode';
    expect(photoBoundaries(fenced, parseNoteTree(fenced)), <int>[0, 24, 26]);

    const String source = 'A\n$p\n~~~\ncode';
    final MdTree tree = parseNoteTree(source);
    final MdBlock photo = onlyPhoto(tree);
    expect(photoMoveDownBoundary(source, tree, photo), isNull);
    expect(photoMoveUpBoundary(source, tree, photo), 0);
    expect(source.length, 35);
    expect(photoRelocation(source, tree, photo, 35), isNull);

    const String plain = 'A\n\n~~~\ncode';
    expect(
      photoTargetAt(plain, parseNoteTree(plain), 8),
      const PhotoBoundaryTarget(1),
    );

    const String closed = 'A\n$p\n~~~\ncode\n~~~';
    expect(moveDown(closed)!.changes.apply(closed), 'A\n\n~~~\ncode\n~~~\n$p');
  });

  group('insertion', () {
    test('goes after the block holding the caret', () {
      expect(
        insertAt('A\n\nB\n\nC', 0, <String>['abc123abc123']),
        'A\n$canonical\n\nB\n\nC',
      );
      expect(
        insertAt('one\ntwo\n\nB', 1, <String>['abc123abc123']),
        'one\ntwo\n$canonical\n\nB',
      );
      expect(insertAt('', 0, <String>['abc123abc123']), '$canonical\n');
      expect(insertAt('A\n', 2, <String>['abc123abc123']), 'A\n$canonical\n');
      expect(insertAt('A', 1, <String>['abc123abc123']), 'A\n$canonical\n');
      expect(
        insertAt('A\n\nB', 2, <String>['abc123abc123']),
        'A\n$canonical\nB',
      );
      expect(
        insertAt('A\n  \nB', 3, <String>['abc123abc123']),
        'A\n$canonical\nB',
      );
      expect(
        insertAt('- a\n\n- b', 4, <String>['abc123abc123']),
        '- a\n\n- b\n$canonical\n',
      );
      expect(
        insertAt('A\n$p\n\nB', 10, <String>['abc123abc123']),
        'A\n$p\n$canonical\n\nB',
      );
    });

    test('reads the targets of empty lines and unclosed fences', () {
      const String source = 'A\n  \nB';
      expect(
        photoTargetAt(source, parseNoteTree(source), 3),
        const PhotoEmptyLineTarget(2, 4),
      );
      const String list = '- a\n\n- b';
      expect(
        photoTargetAt(list, parseNoteTree(list), 4),
        const PhotoBoundaryTarget(8),
      );
      expect(canonical.length, 38);
    });

    test('several references go in order and the last is selected', () {
      const String source = 'A\n\nB';
      final PhotoEdit edit = photoInsertion(
        source,
        photoTargetAt(source, parseNoteTree(source), 0),
        <String>['aaa111aaa111', 'bbb222bbb222'],
      );
      const String first = '![](photo/aaa111aaa111 "right medium")';
      const String second = '![](photo/bbb222bbb222 "right medium")';
      expect(edit.changes.apply(source), 'A\n$first\n$second\n\nB');
      expect(
        edit.selection,
        NoteSelection(anchor: 3 + first.length, head: 3 + first.length + 38),
      );

      const String crlf = 'A\r\n\r\nB';
      final PhotoEdit crlfEdit = photoInsertion(
        crlf,
        photoTargetAt(crlf, parseNoteTree(crlf), 0),
        <String>['aaa111aaa111', 'bbb222bbb222'],
      );
      expect(crlfEdit.changes.apply(crlf), 'A\r\n$first\r\n$second\r\n\r\nB');
      expect(
        crlfEdit.selection,
        NoteSelection(anchor: 5 + first.length, head: 5 + first.length + 38),
      );
    });

    test('a boundary target at 0 writes the line break after the photo', () {
      final PhotoEdit edit = photoInsertion(
        'A',
        const PhotoBoundaryTarget(0),
        <String>['abc123abc123'],
      );
      expect(edit.changes.apply('A'), '$canonical\nA');
      expect(edit.selection, const NoteSelection(anchor: 0, head: 38));
    });
  });

  test('several photo lines in a row are separate units', () {
    const String p1 = '![p](photo/aaa111aaa111)';
    const String p2 = '![p](photo/bbb222bbb222)';
    const String p3 = '![p](photo/ccc333ccc333)';
    const String source = '$p1\n$p2\n$p3';
    final MdTree tree = parseNoteTree(source);
    final PhotoEdit edit = photoRemoval(source, tree, photosOf(tree)[1]);
    expect(edit.changes.apply(source), '$p1\n\n$p3');
  });

  test('an upper-case reference with an invalid title keeps its bytes', () {
    const String odd = '![x](photo/ABC123 "Left Huge")';
    const String source = 'A\n\n$odd\n\nB';
    expect(removeOnly(source).changes.apply(source), 'A\n\nB');
    expect(moveUp(source)!.changes.apply(source), '$odd\nA\n\nB');
    expect(moveDown(source)!.changes.apply(source), 'A\n\nB\n$odd');
  });

  test('photo lines inside containers are not units', () {
    for (final String source in <String>[
      '> a\n> $p\n\nB',
      '```\n$p\n```\n\nB',
      '- a\n  $p\n\nB',
    ]) {
      final MdTree tree = parseNoteTree(source);
      expect(photosOf(tree), isEmpty, reason: source);
      final MdBlock container = tree.blocks.first;
      for (final int boundary in photoBoundaries(source, tree)) {
        expect(
          boundary > container.sourceRange.start &&
              boundary < container.sourceRange.end,
          isFalse,
          reason: source,
        );
      }
      expect(() => photoRemoval(source, tree, container), throwsArgumentError);
    }
  });

  test('a moved photo line loses the spaces and tabs around it', () {
    const String indented = 'A\n\n   $p\n\n- x';
    final String moved = moveDown(indented)!.changes.apply(indented);
    expect(moved, 'A\n\n- x\n$p');
    expect(parseNoteTree(moved).blocks.last.kind, MdBlockKind.photoLine);

    const String trailing = 'A\n$p  \n\nB';
    expect(moveDown(trailing)!.changes.apply(trailing), 'A\n\nB\n$p');
  });

  test('crlf moves keep crlf', () {
    const String source = 'A\r\n$p\r\n\r\nB';
    final PhotoEdit edit = moveDown(source)!;
    expect(edit.changes.apply(source), 'A\r\n\r\nB\r\n$p');
    expectCleanEdit(source, edit.changes);
  });

  test('a lone cr is content', () {
    expect(noteLineBreak('A\rB\nC'), '\n');
    expect(noteLineBreak('A\r\nB'), '\r\n');
    expect(noteLineBreak('AB'), '\n');
    const String source = 'A\rx\n$p\nB';
    expect(removeOnly(source).changes.apply(source), 'A\rx\n\nB');
  });

  test('photo line range and selection cover the whole line', () {
    const String source = 'A\n  $p  \nB';
    final MdTree tree = parseNoteTree(source);
    final MdBlock photo = onlyPhoto(tree);
    expect(photoLineRange(source, photo), const MdRange(2, 30));
    expect(
      photoSelection(source, photo),
      const NoteSelection(anchor: 2, head: 30),
    );
    expect(photoRelocationUnits(tree), tree.blocks);
    expect(photoBoundaries('', parseNoteTree('')), <int>[0]);
  });

  test('relocation refuses the boundaries next to the photo', () {
    const String source = 'A\n\n$p\n\nB';
    final MdTree tree = parseNoteTree(source);
    final MdBlock photo = onlyPhoto(tree);
    expect(photoRelocation(source, tree, photo, 1), isNull);
    expect(photoRelocation(source, tree, photo, photo.sourceRange.end), isNull);
    expect(photoRelocation(source, tree, photo, 2), isNull);
    expect(photoRelocation(source, tree, photo, 0), isNotNull);
    expect(photoRelocation(source, tree, photo, source.length), isNotNull);
  });

  test('arguments that do not fit throw', () {
    const String source = 'A\n\n$p\n\nB';
    final MdTree tree = parseNoteTree(source);
    final MdBlock photo = onlyPhoto(tree);
    final MdTree other = parseNoteTree('xy\n\n$p');
    expect(
      () => photoRemoval(source, tree, tree.blocks.first),
      throwsArgumentError,
    );
    expect(
      () => photoRemoval(source, tree, onlyPhoto(other)),
      throwsArgumentError,
    );
    expect(
      () => photoLineRange(source, tree.blocks.first),
      throwsArgumentError,
    );
    expect(
      () => photoTargetAt(source, tree, source.length + 1),
      throwsArgumentError,
    );
    expect(() => photoRelocation(source, tree, photo, -1), throwsArgumentError);
    expect(
      () => photoInsertion(source, const PhotoBoundaryTarget(0), <String>[]),
      throwsArgumentError,
    );
    expect(
      () => photoInsertion(source, const PhotoBoundaryTarget(99), <String>[
        'abc123abc123',
      ]),
      throwsArgumentError,
    );
    expect(() => photoBoundaries('${source}x', tree), throwsArgumentError);
    expect(
      () => photoMoveUpBoundary('${source}x', tree, photo),
      throwsArgumentError,
    );
  });
}
