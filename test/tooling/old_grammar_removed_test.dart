import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:field_notes/domain/notes/notes.dart';

const List<String> _roots = <String>['lib', 'test', 'integration_test', 'tool'];

const String _parityDirectory = 'test/features/note_engine/parity/';

const List<String> _deletedFiles = <String>[
  'lib/domain/notes/note_parser.dart',
  'lib/domain/notes/note_block.dart',
  'test/domain/notes/note_parser_test.dart',
];

const Set<String> _removedSegments = <String>{
  'note_parser.dart',
  'note_block.dart',
};

const List<String> _removedNames = <String>[
  'NoteBlock',
  'InlineBlock',
  'ParagraphBlock',
  'HeadingBlock',
  'BulletBlock',
  'NumberBlock',
  'QuoteBlock',
  'CodeBlock',
  'DividerBlock',
  'PhotoBlock',
  'InlineNode',
  'PlainNode',
  'CodeNode',
  'StyledNode',
  'LinkNode',
  'InlineStyle',
  'SourceRange',
  'plainTextOfNodes',
  'plainBreakBetween',
];

final RegExp _directive = RegExp(
  r'''^\s*(?:import|export)\s+(?:'([^']*)'|"([^"]*)")''',
);

final RegExp _removedName = RegExp(
  '\\bparseNote\\s*\\(|\\b(?:${_removedNames.join('|')})\\b',
);

String _normalised(String path) => p.posix.joinAll(p.split(path));

List<String> _dartFilesUnder(String root) {
  final Directory directory = Directory(root);
  if (!directory.existsSync()) {
    return const <String>[];
  }
  return <String>[
    for (final FileSystemEntity entity in directory.listSync(
      recursive: true,
      followLinks: false,
    ))
      if (entity is File && entity.path.endsWith('.dart'))
        _normalised(entity.path),
  ]..sort();
}

bool _quotesOldNames(String path) =>
    path.startsWith(_parityDirectory) ||
    (path.startsWith('test/tooling/old_') && path.endsWith('.dart'));

String? _directiveUri(String line) {
  final RegExpMatch? match = _directive.firstMatch(line);
  return match == null ? null : match.group(1) ?? match.group(2);
}

void main() {
  test('no source references the old grammar', () {
    final List<String> scanned = <String>[
      for (final String root in _roots)
        for (final String path in _dartFilesUnder(root))
          if (!_quotesOldNames(path)) path,
    ];
    expect(scanned, isNotEmpty);

    final List<String> present = <String>[
      for (final String path in _deletedFiles)
        if (File(path).existsSync()) path,
    ];

    final List<String> barrel = <String>[
      for (final String line in File(
        'lib/domain/notes/notes.dart',
      ).readAsLinesSync())
        if (line.trim().isNotEmpty) line,
    ];

    final List<String> offences = <String>[
      for (final String path in scanned)
        for (final (int index, String line) in File(
          path,
        ).readAsLinesSync().indexed) ...<String>[
          if (_directiveUri(line) case final String uri
              when _removedSegments.contains(uri.split('/').last))
            '$path:${index + 1}: $uri',
          for (final RegExpMatch match in _removedName.allMatches(line))
            '$path:${index + 1}: ${match.group(0)}',
        ],
    ];

    expect(present, isEmpty, reason: present.join('\n'));
    expect(barrel, <String>[
      "export 'markdown/markdown.dart';",
      "export 'note_plain_text.dart';",
    ]);
    expect(offences, isEmpty, reason: offences.join('\n'));
  });

  test('lib/domain/notes holds only the barrel and the plain text', () {
    final List<String> direct = <String>[
      for (final FileSystemEntity entity in Directory(
        'lib/domain/notes',
      ).listSync())
        if (entity is File && entity.path.endsWith('.dart'))
          p.basename(entity.path),
    ]..sort();
    expect(direct, <String>['note_plain_text.dart', 'notes.dart']);
    expect(
      File('test/domain/notes/note_fuzz_corpus.dart').existsSync(),
      isTrue,
    );
  });

  test('notes.dart reaches the grammar and the plain text', () {
    expect(parseNoteTree('# a').blocks.single.kind, MdBlockKind.heading);
    expect(plainTextOf('# a'), 'a');
  });

  test('the engine never imports the notes barrel', () {
    final List<String> offences = <String>[
      for (final String path in _dartFilesUnder('lib/features/note_engine'))
        for (final (int index, String line) in File(
          path,
        ).readAsLinesSync().indexed)
          if (_directiveUri(line) case final String uri
              when uri.endsWith('/domain/notes/notes.dart'))
            '$path:${index + 1}: $uri',
    ];
    expect(offences, isEmpty, reason: offences.join('\n'));
  });
}
