import 'dart:math';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/photos/photo_relocation.dart';
import 'package:flutter_test/flutter_test.dart';

const int _seed = 20260923;
const int _iterations = 10000;
const int _minimumCompared = 8000;

const List<String> _words = <String>[
  'harbour',
  'fog',
  'tide',
  'gulls',
  'rope',
  'lantern',
  'moss',
  'pier',
  'salt',
  'kelp',
];

const List<String> _separators = <String>['\n', '\n\n', '\n\n\n', '\n  \n'];

const List<String> _titles = <String>[
  ' "left small"',
  ' "right large"',
  ' "centre full"',
  ' "Left Huge"',
  ' "left left"',
  '',
];

final class _NoteGenerator {
  _NoteGenerator(int seed) : _random = Random(seed);

  final Random _random;

  int nextInt(int max) => _random.nextInt(max);

  String _pick(List<String> values) => values[_random.nextInt(values.length)];

  String _phrase() => <String>[
    for (int i = 0; i <= _random.nextInt(3); i++) _pick(_words),
  ].join(' ');

  String _hex(int length, {bool upper = false}) {
    const String digits = '0123456789abcdef';
    final String value = String.fromCharCodes(<int>[
      for (int i = 0; i < length; i++)
        digits.codeUnitAt(_random.nextInt(digits.length)),
    ]);
    return upper ? value.toUpperCase() : value;
  }

  String _photo() {
    final int shape = _random.nextInt(10);
    final String reference = shape == 0
        ? _hex(12, upper: true)
        : shape == 1
        ? _hex(6)
        : _hex(12);
    final String caption = _random.nextBool() ? _pick(_words) : '';
    final String indent = ' ' * _random.nextInt(4);
    return '$indent![$caption](photo/$reference${_pick(_titles)})';
  }

  String _paragraph() => <String>[
    for (int i = 0; i <= _random.nextInt(3); i++) _phrase(),
  ].join('\n');

  String _bulletList() {
    final String bullet = _pick(<String>['-', '*', '+']);
    final bool task = _random.nextInt(4) == 0;
    final String box = task ? '[ ] ' : '';
    final List<String> lines = <String>[
      for (int i = 0; i <= _random.nextInt(3); i++) '$bullet $box${_phrase()}',
    ];
    return _random.nextInt(3) == 0
        ? <String>[...lines, '  $bullet ${_phrase()}'].join('\n')
        : lines.join('\n');
  }

  String _orderedList() {
    final String delimiter = _random.nextBool() ? '.' : ')';
    return <String>[
      for (int i = 0; i <= _random.nextInt(3); i++)
        '${i + 1}$delimiter ${_phrase()}',
    ].join('\n');
  }

  String _quote() {
    final bool nested = _random.nextInt(3) == 0;
    return <String>[
      '> ${_phrase()}',
      if (nested) '> > ${_phrase()}',
    ].join('\n');
  }

  String _fence() {
    final String fence = _random.nextBool() ? '```' : '~~~';
    return '$fence\n${_phrase()}\n$fence';
  }

  String _table() => <String>[
    '| ${_pick(_words)} | ${_pick(_words)} |',
    '| --- | --- |',
    for (int i = 0; i <= _random.nextInt(2); i++)
      '| ${_pick(_words)} | ${_pick(_words)} |',
  ].join('\n');

  String _textUnit() => switch (_random.nextInt(9)) {
    0 => _paragraph(),
    1 => '${'#' * (1 + _random.nextInt(3))} ${_phrase()}',
    2 => _bulletList(),
    3 => _orderedList(),
    4 => _quote(),
    5 => _fence(),
    6 => _pick(<String>['---', '***']),
    7 => _table(),
    _ => _paragraph(),
  };

  String note() {
    final int unitCount = 2 + _random.nextInt(7);
    final int photoCount = 1 + _random.nextInt(unitCount < 3 ? unitCount : 3);
    final Set<int> photoSlots = <int>{};
    while (photoSlots.length < photoCount) {
      photoSlots.add(_random.nextInt(unitCount));
    }
    final bool unclosedLast =
        !photoSlots.contains(unitCount - 1) && _random.nextInt(6) == 0;
    final List<String> units = <String>[
      for (int i = 0; i < unitCount; i++)
        photoSlots.contains(i)
            ? _photo()
            : unclosedLast && i == unitCount - 1
            ? '```\n${_phrase()}'
            : _textUnit(),
    ];
    final String body = <String>[
      for (int i = 0; i < units.length; i++) ...<String>[
        if (i > 0) _pick(_separators),
        units[i],
      ],
    ].join();
    return _random.nextBool() ? body.replaceAll('\n', '\r\n') : body;
  }
}

List<(MdBlockKind, String)> _nonPhotoUnits(String source, MdTree tree) =>
    <(MdBlockKind, String)>[
      for (final MdBlock block in tree.blocks)
        if (block.kind != MdBlockKind.photoLine)
          (block.kind, block.sourceRange.sliceOf(source)),
    ];

int _photoCount(MdTree tree) =>
    tree.blocks.where((MdBlock b) => b.kind == MdBlockKind.photoLine).length;

String _trimmedLine(String source, MdRange range) =>
    range.sliceOf(source).trim();

int _lineStart(String source, int offset) =>
    offset == 0 ? 0 : source.lastIndexOf('\n', offset - 1) + 1;

int _indentAt(String source, int lineStart) {
  int column = 0;
  int at = lineStart;
  while (at < source.length) {
    final int unit = source.codeUnitAt(at);
    if (unit == 0x20) {
      column += 1;
    } else if (unit == 0x09) {
      column += 4 - column % 4;
    } else {
      break;
    }
    at += 1;
  }
  return column;
}

bool _joinsAcrossRemoval(String source, MdTree tree, int index) {
  if (index == 0 || index == tree.blocks.length - 1) {
    return false;
  }
  final MdBlock before = tree.blocks[index - 1];
  final MdBlock after = tree.blocks[index + 1];
  final MdBlockData? beforeData = before.data;
  final MdBlockData? afterData = after.data;
  if (beforeData is! MdBulletListData && beforeData is! MdOrderedListData) {
    return false;
  }
  if (beforeData is MdBulletListData &&
      afterData is MdBulletListData &&
      beforeData.bullet == afterData.bullet) {
    return true;
  }
  if (beforeData is MdOrderedListData &&
      afterData is MdOrderedListData &&
      beforeData.delimiter == afterData.delimiter) {
    return true;
  }
  final MdRange marker = before.blocks.last.markerRanges.first;
  final int contentColumn = marker.end - _lineStart(source, marker.start);
  final int afterLineStart = _lineStart(source, after.sourceRange.start);
  return _indentAt(source, afterLineStart) >= contentColumn;
}

String _escaped(String source) =>
    source.replaceAll('\r', r'\r').replaceAll('\n', r'\n');

void main() {
  test('relocation never changes non photo blocks', () {
    final _NoteGenerator generator = _NoteGenerator(_seed);
    int compared = 0;
    int skipped = 0;
    for (int iteration = 0; iteration < _iterations; iteration++) {
      final String source = generator.note();
      final MdTree tree = parseNoteTree(source);
      final List<int> photoIndexes = <int>[
        for (int i = 0; i < tree.blocks.length; i++)
          if (tree.blocks[i].kind == MdBlockKind.photoLine) i,
      ];
      if (photoIndexes.isEmpty) {
        skipped += 1;
        continue;
      }
      final int index = photoIndexes[generator.nextInt(photoIndexes.length)];
      final MdBlock photo = tree.blocks[index];
      final int? up = photoMoveUpBoundary(source, tree, photo);
      final int? down = photoMoveDownBoundary(source, tree, photo);
      final List<int> targets = <int>[
        for (final int b in photoBoundaries(source, tree))
          if (photoRelocation(source, tree, photo, b) != null) b,
      ];
      final List<String> operations = <String>[
        'removal',
        if (up != null) 'move up',
        if (down != null) 'move down',
        if (targets.isNotEmpty) 'relocation',
      ];
      final String operation = operations[generator.nextInt(operations.length)];
      final int? boundary = switch (operation) {
        'move up' => up,
        'move down' => down,
        'relocation' => targets[generator.nextInt(targets.length)],
        _ => null,
      };
      final PhotoEdit edit = boundary == null
          ? photoRemoval(source, tree, photo)
          : photoRelocation(source, tree, photo, boundary)!;
      if (_joinsAcrossRemoval(source, tree, index)) {
        skipped += 1;
        continue;
      }
      final String result = edit.changes.apply(source);
      final MdTree resultTree = parseNoteTree(result);
      final String context =
          'iteration $iteration, $operation'
          '${boundary == null ? '' : ' to $boundary'}, '
          "source '${_escaped(source)}', result '${_escaped(result)}'";
      final List<(MdBlockKind, String)> before = _nonPhotoUnits(source, tree);
      final List<(MdBlockKind, String)> after = _nonPhotoUnits(
        result,
        resultTree,
      );
      if (!_sameUnits(before, after)) {
        fail('non-photo units changed at $context: $before -> $after');
      }
      final int expectedPhotos = _photoCount(tree) - (boundary == null ? 1 : 0);
      if (_photoCount(resultTree) != expectedPhotos) {
        fail('photo count changed wrongly at $context');
      }
      if (boundary != null) {
        final MdRange selected = MdRange(
          edit.selection.start,
          edit.selection.end,
        );
        final bool coversPhoto = resultTree.blocks.any(
          (MdBlock b) =>
              b.kind == MdBlockKind.photoLine &&
              b.sourceRange == selected &&
              _trimmedLine(result, b.sourceRange) ==
                  _trimmedLine(source, photo.sourceRange),
        );
        if (!coversPhoto) {
          fail('selection does not cover the moved photo at $context');
        }
      }
      compared += 1;
    }
    expect(compared + skipped, _iterations);
    expect(compared, greaterThanOrEqualTo(_minimumCompared));
  });
}

bool _sameUnits(
  List<(MdBlockKind, String)> before,
  List<(MdBlockKind, String)> after,
) {
  if (before.length != after.length) {
    return false;
  }
  for (int i = 0; i < before.length; i++) {
    if (before[i] != after[i]) {
      return false;
    }
  }
  return true;
}
