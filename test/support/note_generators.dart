import 'dart:math';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:flutter/widgets.dart' show CharacterRange;

import '../domain/notes/note_fuzz_corpus.dart';

const int noteGeneratorSeed = 20260923;

const String _nbsp = '\u00A0';

const List<String> _nonAsciiSamples = <String>[
  '\u65E5\u672C',
  '\u00E9',
  '\u{1F44D}\u{1F3FD}',
  '\u{1F469}\u200D\u{1F4BB}',
  '\u{1F1EB}\u{1F1F7}',
  _nbsp,
];

const List<String> _plainWords = <String>[
  'fog',
  'harbour',
  'sea',
  'walk',
  'a',
  'the',
  'x',
];

const List<String> _markedWords = <String>[
  '*a*',
  '**b**',
  '~~c~~',
  '==d==',
  '`e`',
  '[f](g "t")',
  '<https://x.y>',
  r'\*',
];

const List<String> _sides = <String>['left', 'centre', 'center', 'right'];

const List<String> _sizes = <String>['small', 'medium', 'large', 'full'];

const List<String> _alignments = <String>[':---', ':---:', '---:', '---'];

const List<String> _tokens = <String>[
  'a',
  'b',
  'z',
  ' ',
  '*',
  '_',
  '#',
  '-',
  '+',
  '>',
  '!',
  '=',
  '~',
  '.',
  ')',
  '1',
  '"',
  ':',
  '\n',
  '\r\n',
  '```',
  '~~~',
  '- ',
  '1. ',
  '> ',
  '# ',
  '|',
  '| --- |',
  '**',
  '==',
  '~~',
  '`',
  '[',
  '](',
  ')',
  '[ ] ',
  r'\',
  '  ',
  '\t',
  '![](photo/0123456789ab "left small")',
  ..._nonAsciiSamples,
];

const List<String> _compositionPieces = <String>[
  'n',
  'i',
  '\u306B',
  '\u307B',
  '\u65E5\u672C',
];

const List<String> _compositionLetters = <String>['n', 'i', 'k', 'a'];

const List<TransactionEvent> _commandEvents = <TransactionEvent>[
  TransactionEvent.format,
  TransactionEvent.list,
  TransactionEvent.table,
  TransactionEvent.photo,
  TransactionEvent.spell,
  TransactionEvent.inputPaste,
  TransactionEvent.inputDrop,
  TransactionEvent.external,
];

T _pick<T>(Random random, List<T> values) =>
    values[random.nextInt(values.length)];

String randomNote(Random random) {
  final int roll = random.nextInt(50);
  if (roll == 0) {
    return '';
  }
  if (roll < 5) {
    return _pick(random, noteFuzzCorpus);
  }
  final int target = 1 + random.nextInt(15);
  final List<String> lines = <String>[];
  while (lines.length < target) {
    if (lines.isNotEmpty && random.nextBool()) {
      lines.add('');
    }
    lines.addAll(_block(random));
  }
  final List<String> kept = lines.sublist(0, target);
  final int endings = random.nextInt(10);
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < kept.length; i++) {
    buffer.write(kept[i]);
    if (i < kept.length - 1 || random.nextBool()) {
      buffer.write(switch (endings) {
        < 7 => '\n',
        < 9 => '\r\n',
        _ => random.nextBool() ? '\r\n' : '\n',
      });
    }
  }
  return buffer.toString();
}

List<String> _block(Random random) => switch (random.nextInt(12)) {
  0 => <String>['${'#' * (1 + random.nextInt(6))} ${_inline(random)}'],
  1 || 2 => _paragraph(random),
  3 => _bullets(random),
  4 => _ordered(random),
  5 => _quote(random),
  6 => _fence(random),
  7 => <String>[
    _pick(random, const <String>['---', '***', '___', '- - -']),
  ],
  8 => _photos(random),
  9 => _table(random),
  10 => <String>[
    _pick(random, const <String>['', ' ', '  ', '\t', ' \t ', _nbsp]),
  ],
  _ => _paragraph(random),
};

String _inline(Random random) {
  final int count = 1 + random.nextInt(6);
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < count; i++) {
    if (i > 0) {
      buffer.write(random.nextInt(8) == 0 ? _nbsp : ' ');
    }
    final int roll = random.nextInt(30);
    buffer.write(switch (roll) {
      0 => 'r\rs',
      < 10 => _pick(random, _markedWords),
      < 15 => _pick(random, _nonAsciiSamples),
      _ => _pick(random, _plainWords),
    });
  }
  return buffer.toString();
}

List<String> _paragraph(Random random) {
  final int count = 1 + random.nextInt(3);
  return <String>[
    for (int i = 0; i < count; i++)
      '${_inline(random)}${_pick(random, const <String>['', '', '', '  ', r'\'])}',
  ];
}

String _task(Random random) =>
    _pick(random, const <String>['', '', '[ ] ', '[x] ']);

List<String> _bullets(Random random) {
  final int count = 1 + random.nextInt(4);
  return <String>[
    for (int i = 0; i < count; i++)
      '${' ' * (i == 0 ? 0 : _pick(random, const <int>[0, 2, 4]))}'
          '${_pick(random, const <String>['-', '*', '+'])} '
          '${_task(random)}${_inline(random)}',
  ];
}

List<String> _ordered(Random random) {
  final int start = random.nextInt(12);
  final String delimiter = random.nextBool() ? '.' : ')';
  final int count = 1 + random.nextInt(3);
  return <String>[
    for (int i = 0; i < count; i++)
      '${' ' * (i == 0 ? 0 : _pick(random, const <int>[0, 3]))}'
          '${start + i}$delimiter ${_task(random)}${_inline(random)}',
  ];
}

List<String> _quote(Random random) {
  final int count = 1 + random.nextInt(3);
  return <String>[
    for (int i = 0; i < count; i++)
      '${random.nextInt(3) == 0 ? '> > ' : '> '}'
          '${switch (random.nextInt(5)) {
            0 => _photoLine(random),
            1 => '- ${_inline(random)}',
            _ => _inline(random),
          }}',
  ];
}

List<String> _fence(Random random) {
  final String fence =
      (random.nextBool() ? '`' : '~') * (3 + random.nextInt(2));
  final String info = _pick(random, const <String>['', '', 'dart', ' md']);
  final int count = random.nextInt(4);
  return <String>[
    '$fence$info',
    for (int i = 0; i < count; i++)
      switch (random.nextInt(4)) {
        0 => _photoLine(random),
        1 => '# not a heading',
        _ => _inline(random),
      },
    if (random.nextInt(10) < 7) fence,
  ];
}

List<String> _photos(Random random) {
  if (random.nextInt(5) == 0) {
    return <String>['- ${_inline(random)}', '  ${_photoLine(random)}'];
  }
  final int count = 1 + random.nextInt(3);
  return <String>[for (int i = 0; i < count; i++) _photoLine(random)];
}

String _photoLine(Random random) {
  final String caption = _pick(random, const <String>[
    '',
    'harbour',
    'fog \u00E9',
  ]);
  final String reference = switch (random.nextInt(8)) {
    0 => 'ABCDEF012345',
    1 => 'abc',
    _ => _hex(random, 12 + 4 * random.nextInt(3)),
  };
  final String title = switch (random.nextInt(8)) {
    0 => '',
    1 => ' "left left"',
    2 => ' "huge"',
    3 => ' ""',
    _ =>
      random.nextBool()
          ? ' "${_pick(random, _sides)} ${_pick(random, _sizes)}"'
          : ' "${_pick(random, _sizes)} ${_pick(random, _sides)}"',
  };
  final String lead = random.nextInt(6) == 0 ? ' ' : '';
  final String trail = random.nextInt(6) == 0 ? ' \t' : '';
  return '$lead![$caption](photo/$reference$title)$trail';
}

String _hex(Random random, int length) {
  const String digits = '0123456789abcdef';
  return String.fromCharCodes(
    List<int>.generate(
      length,
      (_) => digits.codeUnitAt(random.nextInt(digits.length)),
    ),
  );
}

List<String> _table(Random random) {
  final int columns = 1 + random.nextInt(4);
  final int rows = random.nextInt(4);
  String row(int cells) =>
      '|${List<String>.generate(cells, (_) => ' ${_pick(random, const <String>['a', '**b**', 'x y', '', '\u65E5\u672C'])} ').join('|')}|';
  return <String>[
    row(columns),
    '|${List<String>.generate(columns, (_) => ' ${_pick(random, _alignments)} ').join('|')}|',
    for (int i = 0; i < rows; i++)
      row(switch (random.nextInt(4)) {
        0 => columns > 1 ? columns - 1 : columns,
        1 => columns + 1,
        _ => columns,
      }),
  ];
}

int _clusterStart(String source, int offset) =>
    CharacterRange.at(source, offset).stringBeforeLength;

int randomBoundary(Random random, String source) =>
    _clusterStart(source, random.nextInt(source.length + 1));

NoteSelection randomSelection(Random random, String source) {
  final int anchor = randomBoundary(random, source);
  return random.nextInt(10) < 7
      ? NoteSelection.collapsed(anchor)
      : NoteSelection(anchor: anchor, head: randomBoundary(random, source));
}

ChangeSet randomEdit(Random random, String source) {
  final int count = 1 + random.nextInt(3);
  final List<int> points = List<int>.generate(
    2 * count,
    (_) => randomBoundary(random, source),
  )..sort();
  return ChangeSet(
    length: source.length,
    replacements: <TextReplacement>[
      for (int i = 0; i < count; i++)
        TextReplacement(
          points[2 * i],
          random.nextInt(3) == 0 ? points[2 * i] : points[2 * i + 1],
          random.nextInt(8) == 0 ? '' : _pick(random, _tokens),
        ),
    ],
  );
}

Transaction randomTransaction(
  Random random,
  EditorState state, {
  required Duration time,
}) {
  final String source = state.source;
  final int length = source.length;
  final MdRange? composing = state.composing;
  if (composing != null) {
    final String text = _pieces(random, _compositionPieces);
    final int end = composing.start + text.length;
    return Transaction(
      changes: ChangeSet.single(length, composing.start, composing.end, text),
      selection: NoteSelection.collapsed(end),
      event: TransactionEvent.inputIme,
      addToHistory: false,
      composing: random.nextInt(10) < 6 ? MdRange(composing.start, end) : null,
      time: time,
    );
  }
  final int start = _clusterStart(source, state.selection.start);
  final int end = _clusterStart(source, state.selection.end);
  final int roll = random.nextInt(100);
  if (roll < 45) {
    return _typed(source, start, end, _typedToken(random), time);
  }
  if (roll < 60) {
    return _deletion(random, source, start, end, time) ??
        _typed(source, start, end, _typedToken(random), time);
  }
  if (roll < 68) {
    return _typed(source, start, end, random.nextBool() ? '\n' : '\r\n', time);
  }
  if (roll < 74) {
    final String letters = _pieces(random, _compositionLetters, maximum: 2);
    return Transaction(
      changes: ChangeSet.single(length, start, end, letters),
      selection: NoteSelection.collapsed(start + letters.length),
      event: TransactionEvent.inputIme,
      addToHistory: false,
      composing: MdRange(start, start + letters.length),
      time: time,
    );
  }
  final ChangeSet changes = randomEdit(random, source);
  return Transaction(
    changes: changes,
    selection: state.selection.mapped(changes, side: MapSide.after),
    event: _pick(random, _commandEvents),
    time: time,
  );
}

String _pieces(Random random, List<String> from, {int maximum = 3}) {
  final int count = 1 + random.nextInt(maximum);
  return List<String>.generate(count, (_) => _pick(random, from)).join();
}

String _typedToken(Random random) {
  while (true) {
    final String token = _pick(random, _tokens);
    if (token.isNotEmpty) {
      return token;
    }
  }
}

Transaction _typed(
  String source,
  int start,
  int end,
  String text,
  Duration time,
) => Transaction(
  changes: ChangeSet.single(source.length, start, end, text),
  selection: NoteSelection.collapsed(start + text.length),
  event: TransactionEvent.inputType,
  time: time,
);

Transaction? _deletion(
  Random random,
  String source,
  int start,
  int end,
  Duration time,
) {
  if (start != end) {
    return _deleted(source, start, end, time);
  }
  final CharacterRange before = CharacterRange.at(source, start);
  final CharacterRange after = CharacterRange.at(source, start);
  final bool hasBefore = before.moveBack();
  final bool hasAfter = after.moveNext();
  final bool backward = hasBefore && (!hasAfter || random.nextBool());
  if (backward) {
    return _deleted(source, before.stringBeforeLength, start, time);
  }
  if (hasAfter) {
    return _deleted(
      source,
      start,
      source.length - after.stringAfterLength,
      time,
    );
  }
  return null;
}

Transaction _deleted(String source, int from, int to, Duration time) =>
    Transaction(
      changes: ChangeSet.single(source.length, from, to, ''),
      selection: NoteSelection.collapsed(from),
      event: TransactionEvent.inputDelete,
      time: time,
    );
