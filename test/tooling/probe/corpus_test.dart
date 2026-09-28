import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../../tool/probe/lib/corpus_generator.dart';

const String _folder = 'integration_test/probe/corpus';

const List<(String, int, int)> _terms = <(String, int, int)>[
  ('c500-p0', 500, 0),
  ('c500-p4', 500, 4),
  ('c500-p8', 500, 8),
  ('c6000-p0', 6000, 0),
  ('c6000-p4', 6000, 4),
  ('c6000-p8', 6000, 8),
  ('c6000-p24', 6000, 24),
  ('c20000-p0', 20000, 0),
  ('c20000-p4', 20000, 4),
  ('c20000-p8', 20000, 8),
  ('c20000-p24', 20000, 24),
  ('c50000-p0', 50000, 0),
  ('c50000-p4', 50000, 4),
  ('c50000-p8', 50000, 8),
  ('c50000-p24', 50000, 24),
];

final RegExp _photoLine = RegExp(
  r'^!\[([^\]]*)\]\(photo/([0-9a-f]{12})(?: "([^"]*)")?\)$',
);

final RegExp _photoShape = RegExp(r'!\[[^\]]*\]\(photo/');

String _read(String id) => File('$_folder/$id.md').readAsStringSync();

final class _Line {
  const _Line(this.text, this.start, this.inFence);

  final String text;
  final int start;
  final bool inFence;

  int get end => start + text.length;
}

final class _Fences {
  const _Fences(this.lines, this.backtickPairs, this.tildePairs);

  final List<_Line> lines;
  final int backtickPairs;
  final int tildePairs;
}

_Fences _track(String note) {
  final List<String> raw = note.split('\n');
  final List<_Line> lines = <_Line>[];
  String? open;
  int backticks = 0;
  int tildes = 0;
  int offset = 0;
  for (final String text in raw) {
    final bool fenceLine = text.startsWith('```') || text.startsWith('~~~');
    if (open == null && fenceLine) {
      open = text.substring(0, 3);
      lines.add(_Line(text, offset, true));
    } else if (open != null) {
      lines.add(_Line(text, offset, true));
      if (text == open) {
        if (open == '```') {
          backticks++;
        } else {
          tildes++;
        }
        open = null;
      }
    } else {
      lines.add(_Line(text, offset, false));
    }
    offset += text.length + 1;
  }
  return _Fences(lines, backticks, tildes);
}

List<_Line> _outside(String note) =>
    _track(note).lines.where((_Line line) => !line.inFence).toList();

List<RegExpMatch> _photos(String note) => <RegExpMatch>[
  for (final _Line line in _outside(note)) ?_photoLine.firstMatch(line.text),
];

(String, String)? _placement(String? title) {
  if (title == null || title.trim().isEmpty) {
    return ('right', 'medium');
  }
  final List<String> words = title
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map((String word) => word == 'center' ? 'centre' : word)
      .toList();
  const Set<String> sides = <String>{'left', 'centre', 'right'};
  const Set<String> sizes = <String>{'small', 'medium', 'large', 'full'};
  final List<String> side = words.where(sides.contains).toList();
  final List<String> size = words.where(sizes.contains).toList();
  if (side.length > 1 ||
      size.length > 1 ||
      side.length + size.length != words.length) {
    return null;
  }
  return (
    side.isEmpty ? 'right' : side.single,
    size.isEmpty ? 'medium' : size.single,
  );
}

final RegExp _notPlain = RegExp(
  r'^(#|>|- |\* |\+ |\d+[.)]|\||```|~~~|!\[|---)',
);

bool _isPlainStart(String line) =>
    line.isNotEmpty && line.trim().isNotEmpty && !_notPlain.hasMatch(line);

List<List<_Line>> _paragraphs(String note) {
  final List<List<_Line>> blocks = <List<_Line>>[];
  List<_Line> current = <_Line>[];
  for (final _Line line in _track(note).lines) {
    final bool breaks =
        line.inFence ||
        line.text.trim().isEmpty ||
        _photoLine.hasMatch(line.text);
    if (breaks) {
      if (current.isNotEmpty) {
        blocks.add(current);
      }
      current = <_Line>[];
    } else {
      current = <_Line>[...current, line];
    }
  }
  if (current.isNotEmpty) {
    blocks.add(current);
  }
  return blocks;
}

List<_Line> _typingParagraph(String id, int photos) {
  final String note = _read(id);
  final List<_Line> lines = _track(note).lines;
  if (photos == 0) {
    final int middle = note.length ~/ 2;
    return _paragraphs(note).singleWhere(
      (List<_Line> paragraph) =>
          paragraph.first.start <= middle && middle < paragraph.last.end,
    );
  }
  final int photoIndex = lines.indexWhere((_Line line) {
    final RegExpMatch? match = line.inFence
        ? null
        : _photoLine.firstMatch(line.text);
    final (String, String)? placement = match == null
        ? null
        : _placement(match.group(3));
    return placement != null &&
        (placement.$1 == 'left' || placement.$1 == 'right') &&
        (placement.$2 == 'small' || placement.$2 == 'medium');
  });
  expect(photoIndex, isNonNegative, reason: '$id has no float target');
  final int next = lines.indexWhere(
    (_Line line) => line.text.trim().isNotEmpty,
    photoIndex + 1,
  );
  return _paragraphs(note).singleWhere(
    (List<_Line> paragraph) => paragraph.first.start == lines[next].start,
  );
}

int _paragraphLength(List<_Line> paragraph) =>
    paragraph.last.end - paragraph.first.start;

List<(String, int, int)> _table(String readme, String heading) {
  final List<String> lines = readme.split('\n');
  final int start = lines.indexOf(heading);
  expect(start, isNonNegative, reason: 'README lacks $heading');
  final List<(String, int, int)> rows = <(String, int, int)>[];
  for (final String line in lines.skip(start + 1)) {
    if (line.startsWith('## ')) {
      break;
    }
    if (!line.startsWith('| ') || line.startsWith('| ---')) {
      continue;
    }
    final List<String> cells = line
        .split('|')
        .map((String cell) => cell.trim())
        .where((String cell) => cell.isNotEmpty)
        .toList();
    final int? first = int.tryParse(cells[1]);
    final int? second = int.tryParse(cells[2]);
    if (first != null && second != null) {
      rows.add((cells[0], first, second));
    }
  }
  return rows;
}

final Map<String, RegExp> _constructs = <String, RegExp>{
  'strong': RegExp(r'\*\*[^*\s][^*]*\*\*'),
  'emphasis': RegExp(r'(?<!\*)\*[^*\s][^*]*\*(?!\*)'),
  'strikethrough': RegExp(r'~~[^~\s][^~]*~~'),
  'highlight': RegExp(r'==[^=\s][^=]*=='),
  'code span': RegExp(r'`[^`]+`'),
  'link': RegExp(r'\[[^\]]+\]\(https://example\.com/[^)\s]*\)'),
  'autolink': RegExp(r'<https://example\.com/[^>\s]*>'),
  'task open': RegExp(r'^- \[ \] \S'),
  'task done': RegExp(r'^- \[x\] \S'),
  'quote': RegExp(r'^> \S'),
  'nested quote': RegExp(r'^> > \S'),
};

void main() {
  test('the fifteen corpus notes have their sizes and photo counts', () {
    for (final (String, int, int) term in _terms) {
      final File file = File('$_folder/${term.$1}.md');
      expect(file.existsSync(), isTrue, reason: '${term.$1} is missing');
      final String note = file.readAsStringSync();
      expect(note.length, term.$2, reason: '${term.$1} units');
      expect(_photos(note), hasLength(term.$3), reason: '${term.$1} photos');
      expect(note.contains('\r'), isFalse, reason: term.$1);
      expect(note.endsWith('\n'), isFalse, reason: term.$1);
    }
    final String readme = File('$_folder/README.md').readAsStringSync();
    expect(_table(readme, '## Index'), _terms);
    final Map<String, (int, int)> media = <String, (int, int)>{
      for (final (String, int, int) row in _table(readme, '## Media'))
        row.$1: (row.$2, row.$3),
    };
    for (final (String, int, int) term in _terms) {
      for (final RegExpMatch photo in _photos(_read(term.$1))) {
        final (int, int)? size = media[photo.group(2)];
        expect(size, isNotNull, reason: '${photo.group(2)} in ${term.$1}');
        expect(size!.$1, isPositive);
        expect(size.$2, isPositive);
      }
    }
    final List<String> markdown =
        Directory(_folder)
            .listSync()
            .whereType<File>()
            .map((File file) => file.uri.pathSegments.last)
            .where((String name) => name.endsWith('.md'))
            .toList()
          ..sort();
    expect(
      markdown,
      <String>[
        for (final (String, int, int) term in _terms) '${term.$1}.md',
        'README.md',
      ]..sort(),
    );
  });

  test('the corpus mixes every blocking construct', () {
    final Set<int> headingLevels = <int>{};
    for (final (String, int, int) term in _terms) {
      final String id = term.$1;
      final String note = _read(id);
      final _Fences fences = _track(note);
      final List<_Line> outside = _outside(note);
      for (int level = 1; level <= 6; level++) {
        final RegExp heading = RegExp('^${'#' * level} \\S');
        if (outside.any((_Line line) => heading.hasMatch(line.text))) {
          headingLevels.add(level);
        }
      }
      if (term.$2 >= 6000) {
        for (int level = 1; level <= 6; level++) {
          final RegExp heading = RegExp('^${'#' * level} \\S');
          expect(
            outside.any((_Line line) => heading.hasMatch(line.text)),
            isTrue,
            reason: '$id lacks H$level',
          );
        }
        for (final MapEntry<String, RegExp> construct in _constructs.entries) {
          expect(
            outside.any((_Line line) => construct.value.hasMatch(line.text)),
            isTrue,
            reason: '$id lacks ${construct.key}',
          );
        }
        final List<String> texts = <String>[
          for (final _Line line in fences.lines) line.inFence ? '' : line.text,
        ];
        bool nested = false;
        for (int index = 0; index + 2 < texts.length; index++) {
          nested =
              nested ||
              (RegExp(r'^- \S').hasMatch(texts[index]) &&
                  RegExp(r'^  1\. \S').hasMatch(texts[index + 1]) &&
                  RegExp(r'^     - \S').hasMatch(texts[index + 2]));
        }
        expect(nested, isTrue, reason: '$id lacks a three-level list');
        expect(fences.backtickPairs, isPositive, reason: '$id backtick fence');
        expect(fences.tildePairs, isPositive, reason: '$id tilde fence');
        bool divider = false;
        for (int index = 1; index < texts.length; index++) {
          divider =
              divider ||
              (texts[index] == '---' &&
                  !fences.lines[index].inFence &&
                  texts[index - 1].isEmpty &&
                  !fences.lines[index - 1].inFence);
        }
        expect(divider, isTrue, reason: '$id lacks a divider');
        expect(
          outside.any(
            (_Line line) =>
                line.text.contains('caf\u00e9') &&
                RegExp('[\u4e00-\u9fff]').hasMatch(line.text) &&
                RegExp('[\ud800-\udbff][\udc00-\udfff]').hasMatch(line.text),
          ),
          isTrue,
          reason: '$id lacks the grapheme line',
        );
      }
      if (term.$3 == 24) {
        final List<RegExpMatch> photos = _photos(note);
        final Set<(String, String)> pairs = <(String, String)>{
          for (final RegExpMatch photo in photos) ?_placement(photo.group(3)),
        };
        expect(
          photos.every(
            (RegExpMatch photo) => _placement(photo.group(3)) != null,
          ),
          isTrue,
          reason: '$id has an invalid placement',
        );
        expect(pairs, hasLength(12), reason: '$id placements');
        expect(
          photos.any((RegExpMatch photo) => photo.group(3) == null),
          isTrue,
          reason: '$id lacks an untitled photo',
        );
        expect(
          photos.any(
            (RegExpMatch photo) =>
                (photo.group(3) ?? '').toLowerCase().contains('center'),
          ),
          isTrue,
          reason: '$id lacks a center title',
        );
        final List<String> references = photos
            .map((RegExpMatch photo) => photo.group(2)!)
            .toList();
        expect(
          references.toSet().length,
          lessThan(references.length),
          reason: '$id repeats no reference',
        );
      }
      expect(
        'tidemark'.allMatches(note).length,
        1,
        reason: '$id tidemark count',
      );
      final List<_Line> typing = _typingParagraph(id, term.$3);
      expect(
        typing.map((_Line line) => line.text).join('\n'),
        contains('tidemark'),
        reason: '$id typing paragraph',
      );
      expect(_isPlainStart(typing.first.text), isTrue, reason: id);
      final String last = note.split('\n').last;
      expect(_isPlainStart(last), isTrue, reason: '$id last line');
      expect(last.length, greaterThanOrEqualTo(20), reason: '$id last line');
      expect(
        last.codeUnits.every((int unit) => unit < 128),
        isTrue,
        reason: '$id last line is ASCII',
      );
    }
    expect(headingLevels, <int>{1, 2, 3, 4, 5, 6});
  });

  test('the committed files are the generator output', () {
    final Map<String, String> first = generateCorpus();
    final Map<String, String> second = generateCorpus();
    expect(first, second);
    expect(first.keys.toList(), <String>[
      for (final (String, int, int) term in _terms) '$_folder/${term.$1}.md',
      '$_folder/README.md',
    ]);
    for (final MapEntry<String, String> entry in first.entries) {
      expect(
        File(entry.key).readAsBytesSync(),
        utf8.encode(entry.value),
        reason: entry.key,
      );
      expect(
        File(entry.key).readAsStringSync(),
        entry.value,
        reason: entry.key,
      );
    }
    expect(
      corpusNoteSpecs.map((CorpusNoteSpec spec) => spec.id).toList(),
      <String>[for (final (String, int, int) term in _terms) term.$1],
    );
    expect(
      _terms.fold<int>(0, (int sum, (String, int, int) term) => sum + term.$2),
      305500,
    );
    expect(corpusReadme().endsWith('\n'), isTrue);
    expect(corpusReadme().endsWith('\n\n'), isFalse);
  });

  test('media, photo lines and placements follow the note rules', () {
    final String readme = File('$_folder/README.md').readAsStringSync();
    final List<(String, int, int)> media = _table(readme, '## Media');
    expect(media, hasLength(24));
    expect(
      media.map(((String, int, int) row) => row.$1).toSet(),
      hasLength(24),
    );
    expect(
      media.map(((String, int, int) row) => (row.$2, row.$3)).toSet(),
      <(int, int)>{
        (1600, 1200),
        (1500, 1000),
        (1000, 1500),
        (800, 2400),
        (3200, 800),
      },
    );
    final Set<String> used = <String>{};
    for (final (String, int, int) term in _terms) {
      final String note = _read(term.$1);
      final List<RegExpMatch> photos = _photos(note);
      used.addAll(photos.map((RegExpMatch photo) => photo.group(2)!));
      for (final _Line line in _track(note).lines) {
        if (!_photoShape.hasMatch(line.text)) {
          continue;
        }
        expect(line.inFence, isFalse, reason: '${term.$1}: ${line.text}');
        expect(
          _photoLine.hasMatch(line.text),
          isTrue,
          reason: '${term.$1}: ${line.text}',
        );
      }
      if (term.$2 == 500) {
        final List<String> lines = note.split('\n');
        expect(lines.any((String line) => line.startsWith('# ')), isTrue);
        expect(_constructs['emphasis']!.hasMatch(note), isTrue);
        bool list = false;
        for (int index = 0; index + 1 < lines.length; index++) {
          list =
              list ||
              (lines[index].startsWith('- ') &&
                  lines[index + 1].startsWith('- '));
        }
        expect(list, isTrue, reason: '${term.$1} lacks a two-item list');
      }
      if (term.$3 > 0) {
        final Set<(String, String)?> placements = <(String, String)?>{
          for (final RegExpMatch photo in photos) _placement(photo.group(3)),
        };
        expect(placements.contains(null), isFalse, reason: term.$1);
        expect(
          placements.any(
            ((String, String)? placement) =>
                (placement!.$1 == 'left' || placement.$1 == 'right') &&
                (placement.$2 == 'small' || placement.$2 == 'medium'),
          ),
          isTrue,
          reason: term.$1,
        );
        expect(
          placements
              .map(((String, String)? placement) => placement!.$1)
              .toSet(),
          hasLength(greaterThan(1)),
          reason: '${term.$1} mixes sides',
        );
        expect(
          placements
              .map(((String, String)? placement) => placement!.$2)
              .toSet(),
          hasLength(greaterThan(1)),
          reason: '${term.$1} mixes sizes',
        );
        final List<String> lines = note.split('\n');
        final Set<String> photoSeparators = <String>{};
        for (int index = 0; index < lines.length; index++) {
          if (!_photoLine.hasMatch(lines[index])) {
            continue;
          }
          if (index > 0) {
            photoSeparators.add(lines[index - 1].isEmpty ? '\n\n' : '\n');
          }
          if (index + 1 < lines.length) {
            photoSeparators.add(lines[index + 1].isEmpty ? '\n\n' : '\n');
          }
        }
        expect(photoSeparators, <String>{'\n', '\n\n'}, reason: term.$1);
      }
      if (term.$2 >= 6000) {
        expect(
          _paragraphLength(_typingParagraph(term.$1, term.$3)),
          greaterThanOrEqualTo(300),
          reason: '${term.$1} typing paragraph',
        );
      }
      for (final List<_Line> paragraph in _paragraphs(note)) {
        final String first = paragraph.first.text;
        if (_isPlainStart(first) &&
            !first.contains('caf\u00e9') &&
            !RegExp(
              r'[*~=`\[<]',
            ).hasMatch(paragraph.map((_Line l) => l.text).join())) {
          expect(
            RegExp(
              r'^[a-z ,.]+$',
            ).hasMatch(paragraph.map((_Line line) => line.text).join(' ')),
            isTrue,
            reason: '${term.$1}: $first',
          );
        }
      }
      expect(RegExp(r'\n\n\n').hasMatch(note), isFalse, reason: term.$1);
    }
    expect(used, media.map(((String, int, int) row) => row.$1).toSet());
  });
}
