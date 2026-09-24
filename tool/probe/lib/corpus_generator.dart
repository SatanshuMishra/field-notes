import 'dart:convert';
import 'dart:io';

const int corpusSeed = 20260923;

final class CorpusNoteSpec {
  const CorpusNoteSpec(this.units, this.photos);

  final int units;
  final int photos;

  String get id => 'c$units-p$photos';

  String get path => 'integration_test/probe/corpus/$id.md';
}

const List<CorpusNoteSpec> corpusNoteSpecs = <CorpusNoteSpec>[
  CorpusNoteSpec(500, 0),
  CorpusNoteSpec(500, 4),
  CorpusNoteSpec(500, 8),
  CorpusNoteSpec(6000, 0),
  CorpusNoteSpec(6000, 4),
  CorpusNoteSpec(6000, 8),
  CorpusNoteSpec(6000, 24),
  CorpusNoteSpec(20000, 0),
  CorpusNoteSpec(20000, 4),
  CorpusNoteSpec(20000, 8),
  CorpusNoteSpec(20000, 24),
  CorpusNoteSpec(50000, 0),
  CorpusNoteSpec(50000, 4),
  CorpusNoteSpec(50000, 8),
  CorpusNoteSpec(50000, 24),
];

final class CorpusMedia {
  const CorpusMedia(this.reference, this.width, this.height);

  final String reference;
  final int width;
  final int height;
}

const String corpusReadmePath = 'integration_test/probe/corpus/README.md';

const List<(int, int)> _mediaSizes = <(int, int)>[
  (1600, 1200),
  (1500, 1000),
  (1000, 1500),
  (800, 2400),
  (3200, 800),
];

const List<String> _sides = <String>['left', 'centre', 'right'];

const List<String> _sizes = <String>['small', 'medium', 'large', 'full'];

const List<String> _nouns = <String>[
  'harbour',
  'fog',
  'tide',
  'gull',
  'pier',
  'boat',
  'rope',
  'net',
  'salt',
  'wind',
  'shore',
  'stone',
  'shell',
  'wave',
  'heron',
  'kelp',
  'lantern',
  'morning',
  'evening',
  'coffee',
  'bread',
  'rain',
  'cloud',
  'sail',
  'anchor',
  'dune',
  'marsh',
  'reed',
  'path',
  'lighthouse',
  'sand',
  'crab',
  'mist',
  'dawn',
  'dusk',
  'water',
  'jetty',
  'ferry',
  'bell',
  'cove',
  'cliff',
  'gorse',
  'plover',
  'tern',
  'oyster',
  'market',
  'window',
  'kettle',
  'letter',
  'map',
];

const List<String> _adjectives = <String>[
  'quiet',
  'grey',
  'blue',
  'cold',
  'warm',
  'slow',
  'bright',
  'low',
  'high',
  'soft',
  'late',
  'early',
  'still',
  'salty',
  'green',
];

const List<String> _verbs = <String>[
  'lifted',
  'drifted',
  'settled',
  'turned',
  'waited',
  'carried',
  'crossed',
  'watched',
  'followed',
  'found',
  'kept',
  'passed',
  'rang',
  'faded',
  'gathered',
];

const List<String> _joiners = <String>[
  'by',
  'on',
  'over',
  'near',
  'with',
  'past',
  'under',
  'along',
  'across',
  'beside',
];

final class _Xorshift32 {
  _Xorshift32(int seed) : _state = _nonZero(seed & 0xFFFFFFFF);

  int _state;

  static int _nonZero(int value) => value == 0 ? 1 : value;

  int next() {
    final int a = _state ^ ((_state << 13) & 0xFFFFFFFF);
    final int b = a ^ (a >> 17);
    final int c = b ^ ((b << 5) & 0xFFFFFFFF);
    _state = c;
    return c;
  }

  int below(int bound) => next() % bound;

  T pick<T>(List<T> values) => values[below(values.length)];
}

List<CorpusMedia> corpusMedia() {
  final _Xorshift32 random = _Xorshift32(corpusSeed);
  final List<String> references = <String>[];
  while (references.length < 24) {
    final String high = random.next().toRadixString(16).padLeft(8, '0');
    final String low = random.next().toRadixString(16).padLeft(8, '0');
    final String reference = '$high${low.substring(0, 4)}';
    if (!references.contains(reference)) {
      references.add(reference);
    }
  }
  return <CorpusMedia>[
    for (int index = 0; index < references.length; index++)
      CorpusMedia(
        references[index],
        _mediaSizes[index % _mediaSizes.length].$1,
        _mediaSizes[index % _mediaSizes.length].$2,
      ),
  ];
}

enum _Kind { paragraph, photo, divider, other }

final class _Block {
  const _Block(this.text, this.kind, {this.glued = false});

  final String text;
  final _Kind kind;
  final bool glued;
}

String _sentence(_Xorshift32 random) {
  final int clauses = 1 + random.below(2);
  final List<String> parts = <String>[
    for (int clause = 0; clause < clauses; clause++)
      <String>[
        'the',
        if (random.below(2) == 0) random.pick(_adjectives),
        random.pick(_nouns),
        random.pick(_verbs),
        random.pick(_joiners),
        'the',
        random.pick(_nouns),
      ].join(' '),
  ];
  return '${parts.join(', and ')}.';
}

String _prose(_Xorshift32 random, int length) {
  final StringBuffer buffer = StringBuffer(_sentence(random));
  while (buffer.length < length) {
    buffer
      ..write(' ')
      ..write(_sentence(random));
  }
  return buffer.toString();
}

String _words(_Xorshift32 random, int count) => <String>[
  for (int index = 0; index < count; index++) random.pick(_nouns),
].join(' ');

String _tidemarkParagraph(_Xorshift32 random, int length) {
  final List<String> sentences = <String>[_sentence(random)];
  while (sentences.join(' ').length + ' the tidemark held.'.length < length) {
    sentences.add(_sentence(random));
  }
  final int middle = (sentences.length + 1) ~/ 2;
  return <String>[
    ...sentences.take(middle),
    'the tidemark held.',
    ...sentences.skip(middle),
  ].join(' ');
}

String _inlineParagraph(_Xorshift32 random) =>
    'the ${random.pick(_nouns)} **${random.pick(_nouns)}** '
    '${random.pick(_verbs)} *${random.pick(_adjectives)}* past the '
    '~~${random.pick(_nouns)}~~ and the ==${random.pick(_nouns)}== '
    'while `tide(${random.below(9) + 1})` ran by '
    '[the ${random.pick(_nouns)}](https://example.com/${random.pick(_nouns)}) '
    'and <https://example.com/${random.pick(_nouns)}>.';

List<_Block> _constructSet(_Xorshift32 random) {
  String heading(int level) =>
      '${'#' * level} ${_words(random, 2 + random.below(3))}';
  return <_Block>[
    _Block(heading(1), _Kind.other),
    _Block(_inlineParagraph(random), _Kind.other),
    _Block(heading(2), _Kind.other),
    _Block(
      '- ${random.pick(_nouns)} ${random.pick(_nouns)}\n'
      '  1. ${random.pick(_nouns)} ${random.pick(_nouns)}\n'
      '     - ${random.pick(_nouns)} ${random.pick(_nouns)}',
      _Kind.other,
    ),
    _Block(heading(3), _Kind.other),
    _Block(
      '- [ ] ${_words(random, 2)}\n- [x] ${_words(random, 2)}',
      _Kind.other,
    ),
    _Block('> ${_sentence(random)}\n> > ${_sentence(random)}', _Kind.other),
    _Block(heading(4), _Kind.other),
    _Block(
      '```\nlet ${random.pick(_nouns)} = ${random.below(90) + 10};\n'
      'log(${random.pick(_nouns)});\n```',
      _Kind.other,
    ),
    const _Block('---', _Kind.divider),
    _Block(heading(5), _Kind.other),
    _Block(
      '~~~\n${random.pick(_nouns)}: ${random.below(900) + 100}\n~~~',
      _Kind.other,
    ),
    _Block(heading(6), _Kind.other),
    _Block(
      'we shared a caf\u00e9 by the ${random.pick(_nouns)}, the sign read '
      '\u6e2f\u53e3 and one mark \u{20BB7} under it.',
      _Kind.other,
    ),
  ];
}

List<_Block> _smallSet(_Xorshift32 random) => <_Block>[
  _Block('# ${_words(random, 2)}', _Kind.other),
  _Block(
    'the ${random.pick(_nouns)} was *${random.pick(_adjectives)}* today.',
    _Kind.other,
  ),
  _Block('- ${random.pick(_nouns)}\n- ${random.pick(_nouns)}', _Kind.other),
];

List<String> _titles(_Xorshift32 random, int count, int noteIndex) {
  final List<(String, String)> pairs = <(String, String)>[
    for (final String size in _sizes)
      for (final String side in _sides) (side, size),
  ];
  String title((String, String) pair) =>
      random.below(4) == 0 ? '${pair.$2} ${pair.$1}' : '${pair.$1} ${pair.$2}';
  final String first =
      '${noteIndex.isEven ? 'left' : 'right'} ${random.below(2) == 0 ? 'small' : 'medium'}';
  if (count < 24) {
    final int start = random.below(pairs.length);
    return <String>[
      first,
      for (int index = 1; index < count; index++)
        title(pairs[(start + index * 5) % pairs.length]),
    ];
  }
  final List<String> rest = <String>[
    for (final (String, String) pair in pairs) title(pair),
    '',
    'center ${random.pick(_sizes)}',
    for (int index = 0; index < 9; index++) title(random.pick(pairs)),
  ];
  final List<String> shuffled = List<String>.of(rest);
  for (int index = shuffled.length - 1; index > 0; index--) {
    final int other = random.below(index + 1);
    final String held = shuffled[index];
    shuffled[index] = shuffled[other];
    shuffled[other] = held;
  }
  return <String>[first, ...shuffled];
}

List<_Block> _photoBlocks(_Xorshift32 random, CorpusNoteSpec spec, int index) {
  if (spec.photos == 0) {
    return const <_Block>[];
  }
  final List<CorpusMedia> media = corpusMedia();
  final int rotation = index * 5;
  final List<String> references = <String>[
    for (int photo = 0; photo < spec.photos; photo++)
      spec.photos == 24 && photo == 23
          ? media[(rotation + 3) % media.length].reference
          : media[(rotation + photo) % media.length].reference,
  ];
  final List<String> titles = _titles(random, spec.photos, index);
  return <_Block>[
    for (int photo = 0; photo < spec.photos; photo++)
      _Block(
        '![${spec.units > 500 && random.below(3) == 0 ? _words(random, 1 + random.below(2)) : ''}]'
        '(photo/${references[photo]}'
        '${titles[photo].isEmpty ? '' : ' "${titles[photo]}"'})',
        _Kind.photo,
      ),
  ];
}

List<_Block> _merge(List<_Block> constructs, List<_Block> photos) {
  final int total = constructs.length + photos.length;
  final List<_Block> merged = <_Block>[];
  int placedPhotos = 0;
  int placedConstructs = 0;
  for (int slot = 0; slot < total; slot++) {
    final bool photoTurn =
        placedPhotos < photos.length &&
        (placedConstructs >= constructs.length ||
            (placedPhotos + 1) * total <= (slot + 1) * photos.length);
    if (photoTurn) {
      merged.add(photos[placedPhotos]);
      placedPhotos++;
    } else {
      merged.add(constructs[placedConstructs]);
      placedConstructs++;
    }
  }
  return merged;
}

String generateCorpusNote(CorpusNoteSpec spec) {
  final int index = corpusNoteSpecs.indexWhere(
    (CorpusNoteSpec candidate) =>
        candidate.units == spec.units && candidate.photos == spec.photos,
  );
  if (index < 0) {
    throw ArgumentError.value(spec.id, 'spec', 'is not a corpus note');
  }
  final _Xorshift32 random = _Xorshift32(corpusSeed + index);
  final bool large = spec.units >= 6000;
  final List<_Block> constructs = large
      ? <_Block>[
          for (int set = 0; set < spec.units ~/ 6000; set++)
            ..._constructSet(random),
        ]
      : _smallSet(random);
  final List<_Block> photos = _photoBlocks(random, spec, index);
  final List<_Block> plan = photos.isEmpty
      ? constructs
      : <_Block>[
          constructs.first,
          photos.first,
          _Block(
            _tidemarkParagraph(random, large ? 320 + random.below(120) : 40),
            _Kind.paragraph,
            glued: true,
          ),
          ..._merge(constructs.skip(1).toList(), photos.skip(1).toList()),
        ];
  return _layOut(random, spec, plan, tidemarkAtMiddle: photos.isEmpty);
}

String _layOut(
  _Xorshift32 random,
  CorpusNoteSpec spec,
  List<_Block> plan, {
  required bool tidemarkAtMiddle,
}) {
  final bool large = spec.units >= 6000;
  final int middle = spec.units ~/ 2;
  final int finalReserve = large ? 160 : 60;
  final StringBuffer buffer = StringBuffer();
  _Block? previous;
  bool firstPhotoSeen = false;
  bool placed = !tidemarkAtMiddle;
  bool afterFirstPhoto = false;

  String separator(_Block next) {
    if (previous == null) {
      return '';
    }
    if (next.kind == _Kind.divider) {
      return '\n\n';
    }
    if (previous!.kind == _Kind.photo && afterFirstPhoto) {
      return '\n';
    }
    if (next.kind == _Kind.photo && !firstPhotoSeen) {
      return '\n\n';
    }
    if (previous!.kind == _Kind.photo || next.kind == _Kind.photo) {
      return random.below(2) == 0 ? '\n' : '\n\n';
    }
    return '\n\n';
  }

  void emit(_Block block) {
    final String gap = separator(block);
    buffer
      ..write(gap)
      ..write(block.text);
    afterFirstPhoto = block.kind == _Kind.photo && !firstPhotoSeen;
    if (block.kind == _Kind.photo) {
      firstPhotoSeen = true;
    }
    previous = block;
  }

  void emitChecked(_Block block) {
    if (!placed) {
      final int end =
          buffer.length + separator(block).length + block.text.length;
      if (end + 4 >= middle) {
        final int start = buffer.length + (previous == null ? 0 : 2);
        final int length = (middle - start + 40) > (large ? 300 : 40)
            ? middle - start + 40
            : (large ? 300 : 40);
        emit(_Block(_tidemarkParagraph(random, length), _Kind.paragraph));
        placed = true;
      }
    }
    emit(block);
  }

  for (int item = 0; item < plan.length; item++) {
    final _Block block = plan[item];
    if (item > 0 && !block.glued) {
      final int remaining = plan
          .skip(item)
          .fold<int>(0, (int sum, _Block next) => sum + next.text.length + 2);
      final int gaps =
          plan.skip(item).where((_Block next) => !next.glued).length + 1;
      final int pending = placed ? 0 : (large ? 400 : 160);
      int budget =
          (spec.units - buffer.length - remaining - finalReserve - pending) ~/
          gaps;
      while (budget >= 80) {
        final int target = budget < 600 ? budget : 200 + random.below(400);
        final _Block filler = _Block(
          _prose(random, target - 40 > 40 ? target - 40 : 40),
          _Kind.paragraph,
        );
        emitChecked(filler);
        budget -= filler.text.length + 2;
      }
    }
    emitChecked(block);
  }

  if (!placed) {
    final int start = buffer.length + 2;
    final int length = (middle - start + 40) > (large ? 300 : 40)
        ? middle - start + 40
        : (large ? 300 : 40);
    emit(_Block(_tidemarkParagraph(random, length), _Kind.paragraph));
    placed = true;
  }
  final String gap = separator(const _Block('', _Kind.paragraph));
  final int finalLength = spec.units - buffer.length - gap.length;
  if (finalLength < 20) {
    throw StateError('${spec.id} leaves $finalLength units for its last line');
  }
  final String closing = _prose(
    random,
    finalLength + 1,
  ).substring(0, finalLength);
  buffer
    ..write(gap)
    ..write(closing);
  final String note = buffer.toString();
  if (note.length != spec.units) {
    throw StateError('${spec.id} has ${note.length} units');
  }
  return note;
}

String corpusReadme() {
  final StringBuffer buffer = StringBuffer()
    ..writeln('# Probe corpus')
    ..writeln()
    ..writeln(
      'These are the corpus notes of the composer editor core spec: the notes '
      'the live harness opens for the 6.14 gate rows (typing latency, janky '
      'frames, caret, selection, click and vertical sweeps, reader parity and '
      'the styling ceiling).',
    )
    ..writeln()
    ..writeln(
      'Each note is sized exactly in source UTF-16 units, photo lines '
      'included, uses LF line breaks and ends without a line break on a plain '
      'paragraph line. Notes of 6,000 units or more mix every blocking '
      'construct: headings H1 to H6, strong, emphasis, strikethrough, '
      'highlight, code spans, links, autolinks, a three-level nested list, '
      'task items, nested quotes, backtick and tilde fences, dividers and a '
      'line with accented, CJK and supplementary characters. Photo lines use '
      'every size and side. The word tidemark appears once per note and marks '
      'the typing target: the paragraph after the first left or right small '
      'or medium photo, or the middle paragraph of a note without photos.',
    )
    ..writeln()
    ..writeln(
      'The notes are invented journal prose with no personal data. They are '
      'generated by a seeded generator; regenerate them from the repository '
      'root with `dart run tool/probe/lib/corpus_generator.dart`, check them '
      'with `dart run tool/probe/lib/corpus_generator.dart --check`, and never '
      'edit them by hand.',
    )
    ..writeln()
    ..writeln('## Index')
    ..writeln()
    ..writeln('| id | units | photos |')
    ..writeln('| --- | --- | --- |');
  for (final CorpusNoteSpec spec in corpusNoteSpecs) {
    buffer.writeln('| ${spec.id} | ${spec.units} | ${spec.photos} |');
  }
  buffer
    ..writeln()
    ..writeln('## Media')
    ..writeln()
    ..writeln('| reference | width | height |')
    ..writeln('| --- | --- | --- |');
  for (final CorpusMedia media in corpusMedia()) {
    buffer.writeln('| ${media.reference} | ${media.width} | ${media.height} |');
  }
  return buffer.toString();
}

Map<String, String> generateCorpus() => <String, String>{
  for (final CorpusNoteSpec spec in corpusNoteSpecs)
    spec.path: generateCorpusNote(spec),
  corpusReadmePath: corpusReadme(),
};

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int index = 0; index < a.length; index++) {
    if (a[index] != b[index]) {
      return false;
    }
  }
  return true;
}

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    for (final MapEntry<String, String> entry in generateCorpus().entries) {
      final File file = File(entry.key);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(entry.value);
      stdout.writeln('wrote ${entry.key}');
    }
    exitCode = 0;
    return;
  }
  if (arguments.length == 1 && arguments.first == '--check') {
    final List<String> differing = <String>[
      for (final MapEntry<String, String> entry in generateCorpus().entries)
        if (!File(entry.key).existsSync() ||
            !_sameBytes(
              File(entry.key).readAsBytesSync(),
              utf8.encode(entry.value),
            ))
          entry.key,
    ];
    for (final String path in differing) {
      stderr.writeln('differs or is missing: $path');
    }
    exitCode = differing.isEmpty ? 0 : 1;
    return;
  }
  stderr.writeln(
    'usage: dart run tool/probe/lib/corpus_generator.dart [--check]',
  );
  exitCode = 2;
}
