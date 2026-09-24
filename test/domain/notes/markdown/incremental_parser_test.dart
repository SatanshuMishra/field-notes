import 'dart:math';

import 'package:field_notes/domain/notes/markdown/incremental_parser.dart';
import 'package:field_notes/domain/notes/markdown/note_tree.dart';
import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';
import 'package:flutter_test/flutter_test.dart';

import '../note_fuzz_corpus.dart';

const int _incrementalSeed = 20260923;
const int _sequenceCount = 1200;

const List<String> _tokens = <String>[
  '',
  'a',
  ' ',
  '  ',
  '\t',
  '\n',
  '\n\n',
  '\r\n',
  '\r',
  '# ',
  '- ',
  '1. ',
  '2) ',
  '> ',
  '```',
  '~~~',
  '---',
  '|',
  '| a | b |',
  '| - | - |',
  '![p](photo/abc123abc123)',
  '**',
  '*',
  '_',
  '~~',
  '==',
  '`',
  '[',
  '](u)',
  '<https://x>',
  r'\',
  '[ ] ',
  '[x] ',
  'word',
];

const List<String> _joiners = <String>['\n', '\n\n', '\r\n'];

String _escaped(String text) => text
    .replaceAll(r'\', r'\\')
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\r')
    .replaceAll('\t', r'\t');

String _masked(String source, MdRange composing) => String.fromCharCodes(<int>[
  for (int at = 0; at < source.length; at++)
    if (composing.contains(at) &&
        source.codeUnitAt(at) != 0x0A &&
        source.codeUnitAt(at) != 0x0D)
      0xE000
    else
      source.codeUnitAt(at),
]);

String _baseNote(Random random) {
  if (random.nextBool()) {
    return noteFuzzCorpus[random.nextInt(noteFuzzCorpus.length)];
  }
  final int count = 5 + random.nextInt(36);
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < count; i++) {
    if (i > 0) {
      buffer.write(_joiners[random.nextInt(_joiners.length)]);
    }
    buffer.write(noteFuzzCorpus[random.nextInt(noteFuzzCorpus.length)]);
  }
  return buffer.toString();
}

MdEdit _randomEdit(Random random, String source) {
  final int start = random.nextInt(source.length + 1);
  final int span = random.nextInt(9);
  final int end = start + span > source.length ? source.length : start + span;
  final int tokenCount = random.nextInt(4);
  final StringBuffer inserted = StringBuffer();
  for (int i = 0; i < tokenCount; i++) {
    inserted.write(_tokens[random.nextInt(_tokens.length)]);
  }
  return MdEdit(start: start, end: end, inserted: inserted.toString());
}

String _apply(String source, MdEdit edit) =>
    source.replaceRange(edit.start, edit.end, edit.inserted);

MdReparse _type(
  String oldSource,
  MdEdit edit, {
  MdRange? composing,
  MdRange? previousComposing,
  MdTree? old,
}) => const MdIncrementalParser().reparse(
  old ?? parseNoteTree(oldSource),
  oldSource,
  _apply(oldSource, edit),
  edit,
  composing: composing,
  previousComposing: previousComposing,
);

void _expectFullParse(MdTree actual, String source, {bool tables = true}) {
  final MdTree expected = parseNoteTree(source, tables: tables);
  expect(
    actual == expected,
    isTrue,
    reason:
        'source: ${_escaped(source)}\n'
        'incremental: $actual\n'
        'full: $expected',
  );
}

Iterable<MdNode> _nodes(List<MdNode> roots) sync* {
  for (final MdNode node in roots) {
    yield node;
    yield* _nodes(node.children);
  }
}

String _paragraphs(int count) =>
    <String>[for (int i = 1; i <= count; i++) 'paragraph $i'].join('\n\n');

void main() {
  test(
    'incremental parsing equals a full parse over random edits',
    () {
      final Random random = Random(_incrementalSeed);
      for (int sequence = 0; sequence < _sequenceCount; sequence++) {
        final bool tables = random.nextInt(4) != 0;
        final MdIncrementalParser parser = MdIncrementalParser(tables: tables);
        final String base = _baseNote(random);
        final int editCount = 1 + random.nextInt(12);
        final List<String> history = <String>[];
        String source = base;
        MdTree tree = parseNoteTree(source, tables: tables);
        MdRange? previousComposing;
        for (int step = 0; step < editCount; step++) {
          final MdEdit edit = _randomEdit(random, source);
          final String next = _apply(source, edit);
          final MdRange? composing = random.nextInt(5) == 0
              ? MdRange(edit.start, edit.newEnd)
              : null;
          history.add('$edit composing: $composing');
          final MdReparse result = parser.reparse(
            tree,
            source,
            next,
            edit,
            composing: composing,
            previousComposing: previousComposing,
          );
          final MdTree expected = parseNoteTree(
            composing == null ? next : _masked(next, composing),
            tables: tables,
          );
          if (result.tree != expected) {
            fail(
              'seed: $_incrementalSeed, sequence: $sequence, step: $step, '
              'tables: $tables\n'
              'base: ${_escaped(base)}\n'
              'edits:\n  ${history.join('\n  ')}\n'
              'old source: ${_escaped(source)}\n'
              'new source: ${_escaped(next)}\n'
              'incremental: ${result.tree}\n'
              'full: $expected',
            );
          }
          source = next;
          tree = result.tree;
          previousComposing = composing;
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'typing in paragraph forty of four hundred re-parses paragraphs thirty nine and forty',
    () {
      final String source = _paragraphs(400);
      final int e = source.indexOf('paragraph 40\n') + 'paragraph 40'.length;
      final MdEdit edit = MdEdit(start: e, end: e, inserted: 'x');
      final String next = _apply(source, edit);
      final MdReparse result = _type(source, edit);
      _expectFullParse(result.tree, next);
      expect(result.reparsedFrom, source.indexOf('paragraph 39\n'));
      expect(result.reparsedTo, next.indexOf('paragraph 41\n'));
      expect(
        <String>[
          for (final MdBlock block in result.reparsedBlocks)
            block.sourceRange.sliceOf(next),
        ],
        <String>['paragraph 39', 'paragraph 40x'],
      );
    },
  );

  test(
    'typing a closing fence re-parses from the block before it to the end',
    () {
      const String source = 'first\n\nintro\n\n```\ncode\n``\nafter\n\nmore';
      expect(source.length, 37);
      const MdEdit edit = MdEdit(start: 25, end: 25, inserted: '`');
      final String next = _apply(source, edit);
      final MdReparse result = _type(source, edit);
      _expectFullParse(result.tree, next);
      expect(
        <MdBlockKind>[
          for (final MdBlock block in result.tree.blocks) block.kind,
        ],
        <MdBlockKind>[
          MdBlockKind.paragraph,
          MdBlockKind.paragraph,
          MdBlockKind.fencedCode,
          MdBlockKind.paragraph,
          MdBlockKind.paragraph,
        ],
      );
      final MdBlock fence = result.tree.blocks[2];
      expect((fence.data! as MdFenceData).isClosed, isTrue);
      expect(fence.contentRange.sliceOf(next), 'code');
      expect(result.reparsedFrom, 7);
      expect(result.reparsedTo, 38);
    },
  );

  test('composing text is treated as plain text of its block', () {
    const MdEdit typeStars = MdEdit(start: 0, end: 0, inserted: '**');
    final MdReparse composed = _type(
      'fog** lifted',
      typeStars,
      composing: const MdRange(0, 2),
    );
    expect(composed.tree.blocks, hasLength(1));
    final MdBlock paragraph = composed.tree.blocks.single;
    expect(paragraph.kind, MdBlockKind.paragraph);
    expect(paragraph.sourceRange, const MdRange(0, 14));
    final List<MdNode> nodes = _nodes(composed.tree.blocks).toList();
    expect(
      nodes.whereType<MdInline>().where(
        (MdInline i) =>
            i.kind == MdInlineKind.strong || i.kind == MdInlineKind.emphasis,
      ),
      isEmpty,
    );
    expect(<MdRange>[
      for (final MdNode node in nodes)
        for (final MdRange marker in node.markerRanges)
          if (marker.start < 2) marker,
    ], isEmpty);
    const MdEdit commit = MdEdit(start: 2, end: 2, inserted: '');
    final MdReparse committed = _type(
      '**fog** lifted',
      commit,
      old: composed.tree,
      previousComposing: const MdRange(0, 2),
    );
    expect(committed.tree, parseNoteTree('**fog** lifted'));
    final MdInline strong = _nodes(committed.tree.blocks)
        .whereType<MdInline>()
        .singleWhere((MdInline i) => i.kind == MdInlineKind.strong);
    expect(strong.sourceRange, const MdRange(0, 7));

    for (final (String base, MdBlockKind expected) in <(String, MdBlockKind)>[
      ('Title', MdBlockKind.heading),
      ('eggs', MdBlockKind.bulletList),
    ]) {
      final String marker = expected == MdBlockKind.heading ? '# ' : '- ';
      final MdReparse typing = _type(
        base,
        MdEdit(start: 0, end: 0, inserted: marker),
        composing: const MdRange(0, 2),
      );
      expect(
        typing.tree.blocks.single.kind,
        MdBlockKind.paragraph,
        reason: base,
      );
      final MdReparse done = _type(
        '$marker$base',
        commit,
        old: typing.tree,
        previousComposing: const MdRange(0, 2),
      );
      expect(done.tree.blocks.single.kind, expected, reason: base);
      _expectFullParse(done.tree, '$marker$base');
      final MdBlockData? data = done.tree.blocks.single.data;
      if (data is MdHeadingData) {
        expect(data.level, 1);
      }
    }
  });

  test('an opening fence with no closing re-parses to the end', () {
    const String source = 'a\n\nb\n\nc';
    const MdEdit edit = MdEdit(start: 3, end: 3, inserted: '```\n');
    final String next = _apply(source, edit);
    final MdReparse result = _type(source, edit);
    _expectFullParse(result.tree, next);
    expect(result.reparsedFrom, 0);
    expect(result.reparsedTo, next.length);
    expect(result.tree.blocks.last.kind, MdBlockKind.fencedCode);
  });

  test('an opening fence inside a list item realigns at the next block', () {
    const String source = 'p\n\nq\n\ns\n\nt';
    const MdEdit edit = MdEdit(start: 3, end: 3, inserted: '- ```\n');
    final String next = _apply(source, edit);
    final MdReparse result = _type(source, edit);
    _expectFullParse(result.tree, next);
    expect(result.reparsedFrom, 0);
    expect(result.reparsedTo, 12);
    expect(next.substring(12, 13), 's');
  });

  test(
    'a delimiter row under a paragraph re-parses from the block before it',
    () {
      const String source = 'w\n\nx\n\nA\n| B |\n\nC';
      const MdEdit edit = MdEdit(start: 13, end: 13, inserted: '\n| - |');
      final String next = _apply(source, edit);
      final MdReparse result = _type(source, edit);
      _expectFullParse(result.tree, next);
      expect(result.reparsedFrom, 3);
      expect(result.reparsedTo, 21);
      expect(next.substring(21), 'C');
      final List<MdBlock> blocks = result.tree.blocks;
      expect(blocks[2].kind, MdBlockKind.paragraph);
      expect(blocks[2].sourceRange.sliceOf(next), 'A');
      expect(blocks[3].kind, MdBlockKind.table);
      expect(blocks[3].blocks.first.blocks, hasLength(1));
    },
  );

  test('an edit in the first block starts at offset zero', () {
    const String source = 'one\n\ntwo\n\nthree';
    const MdEdit edit = MdEdit(start: 1, end: 2, inserted: 'N');
    final MdReparse result = _type(source, edit);
    _expectFullParse(result.tree, _apply(source, edit));
    expect(result.reparsedFrom, 0);
    expect(result.reparsedTo, 5);
  });

  test('an edit on a blank line before the first block starts at zero', () {
    const String source = '\n\na';
    const MdEdit edit = MdEdit(start: 0, end: 0, inserted: 'x');
    final MdReparse result = _type(source, edit);
    _expectFullParse(result.tree, _apply(source, edit));
    expect(result.reparsedFrom, 0);
    expect(result.reparsedTo, 3);
    expect(result.tree.blocks.first.sourceRange, const MdRange(0, 1));
  });

  test('an edit after the last block re-parses to the end', () {
    const String source = 'a\n\nb\n\n';
    const MdEdit edit = MdEdit(start: 6, end: 6, inserted: '# c');
    final String next = _apply(source, edit);
    final MdReparse result = _type(source, edit);
    _expectFullParse(result.tree, next);
    expect(result.reparsedFrom, 0);
    expect(result.reparsedTo, next.length);
    expect(result.tree.blocks.last.kind, MdBlockKind.heading);
  });

  test('an empty old tree parses the new text', () {
    const MdEdit edit = MdEdit(start: 0, end: 0, inserted: 'a');
    final MdReparse result = _type('', edit);
    _expectFullParse(result.tree, 'a');
    expect(result.reparsedFrom, 0);
    expect(result.reparsedTo, 1);
  });

  test('a CRLF note re-parses only near the edit', () {
    const String source = 'a\r\n\r\nb\r\n\r\nc\r\n\r\nd';
    const MdEdit edit = MdEdit(start: 10, end: 10, inserted: '*x*');
    final String next = _apply(source, edit);
    final MdReparse result = _type(source, edit);
    _expectFullParse(result.tree, next);
    expect(result.reparsedFrom, 5);
    expect(result.reparsedTo, next.indexOf('d'));
  });

  test('an edit that splits a CRLF equals a full parse', () {
    const String source = 'a\r\nb';
    const MdEdit edit = MdEdit(start: 2, end: 2, inserted: 'x');
    final String next = _apply(source, edit);
    expect(next, 'a\rx\nb');
    _expectFullParse(_type(source, edit).tree, next);
  });

  test('a composition continuing across two calls re-parses its text', () {
    const String source = 'hi ';
    const MdEdit first = MdEdit(start: 3, end: 3, inserted: '*');
    final MdReparse one = _type(source, first, composing: const MdRange(3, 4));
    expect(one.tree, parseNoteTree(_masked('hi *', const MdRange(3, 4))));
    const MdEdit second = MdEdit(start: 3, end: 4, inserted: '*x*');
    final MdReparse two = _type(
      'hi *',
      second,
      old: one.tree,
      composing: const MdRange(3, 6),
      previousComposing: const MdRange(3, 4),
    );
    expect(two.tree, parseNoteTree(_masked('hi *x*', const MdRange(3, 6))));
    final MdReparse done = _type(
      'hi *x*',
      const MdEdit(start: 3, end: 3, inserted: ''),
      old: two.tree,
      previousComposing: const MdRange(3, 6),
    );
    _expectFullParse(done.tree, 'hi *x*');
    expect(
      _nodes(done.tree.blocks).whereType<MdInline>().any(
        (MdInline i) => i.kind == MdInlineKind.emphasis,
      ),
      isTrue,
    );
  });

  test('a composition overlapping the replaced range is re-parsed', () {
    const String source = 'a\n\n**b** c\n\nd';
    final MdReparse composed = _type(
      source,
      const MdEdit(start: 5, end: 5, inserted: 'bb'),
      composing: const MdRange(3, 7),
    );
    const String composedSource = 'a\n\n**bbb** c\n\nd';
    expect(
      composed.tree,
      parseNoteTree(_masked(composedSource, const MdRange(3, 7))),
    );
    const MdEdit edit = MdEdit(start: 6, end: 9, inserted: 'y');
    final String next = _apply(composedSource, edit);
    final MdReparse result = _type(
      composedSource,
      edit,
      old: composed.tree,
      previousComposing: const MdRange(3, 7),
    );
    _expectFullParse(result.tree, next);
  });

  test('reparse rejects each contract violation', () {
    const MdIncrementalParser parser = MdIncrementalParser();
    final MdTree tree = parseNoteTree('abc');
    const MdEdit edit = MdEdit(start: 1, end: 1, inserted: 'x');
    final List<void Function()> calls = <void Function()>[
      () => parser.reparse(parseNoteTree('ab'), 'abc', 'axbc', edit),
      () => parser.reparse(
        tree,
        'abc',
        'xabc',
        const MdEdit(start: -1, end: 0, inserted: 'x'),
      ),
      () => parser.reparse(
        tree,
        'abc',
        'ac',
        const MdEdit(start: 2, end: 1, inserted: ''),
      ),
      () => parser.reparse(
        tree,
        'abc',
        'ab',
        const MdEdit(start: 2, end: 4, inserted: ''),
      ),
      () => parser.reparse(tree, 'abc', 'axbcd', edit),
      () => parser.reparse(tree, 'abc', 'aybc', edit),
      () => parser.reparse(
        tree,
        'abc',
        'axbc',
        edit,
        composing: const MdRange(1, 5),
      ),
      () => parser.reparse(
        tree,
        'abc',
        'axbc',
        edit,
        previousComposing: const MdRange(2, 4),
      ),
    ];
    for (final void Function() call in calls) {
      expect(call, throwsArgumentError);
    }
  });

  test('an edit value derives its new end and length change', () {
    const MdEdit edit = MdEdit(start: 3, end: 5, inserted: 'abc');
    expect(edit.newEnd, 6);
    expect(edit.lengthDelta, 1);
    expect(edit, const MdEdit(start: 3, end: 5, inserted: 'abc'));
    expect(
      edit.hashCode,
      const MdEdit(start: 3, end: 5, inserted: 'abc').hashCode,
    );
    expect(edit == const MdEdit(start: 3, end: 5, inserted: 'abd'), isFalse);
    expect(edit.toString(), contains('abc'));
  });

  test(
    'typing mid-note in fifty thousand units re-parses at most three blocks',
    () {
      final String source = _paragraphs(4000).substring(0, 50000);
      expect(source.length, 50000);
      final int e = source.indexOf('\n\n', 25000);
      final MdEdit edit = MdEdit(start: e, end: e, inserted: 'x');
      final String next = _apply(source, edit);
      final MdReparse result = _type(source, edit);
      _expectFullParse(result.tree, next);
      expect(result.reparsedBlocks.length, lessThanOrEqualTo(3));
    },
  );

  test('parsing without tables keeps a delimiter row as text', () {
    const String source = 'x\n\nA\n| B |';
    const MdEdit edit = MdEdit(start: 9, end: 9, inserted: '\n| - |');
    final String next = _apply(source, edit);
    final MdReparse result = const MdIncrementalParser(
      tables: false,
    ).reparse(parseNoteTree(source, tables: false), source, next, edit);
    _expectFullParse(result.tree, next, tables: false);
    expect(
      result.tree.blocks.any((MdBlock b) => b.kind == MdBlockKind.table),
      isFalse,
    );
  });
}
