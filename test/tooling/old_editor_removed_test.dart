import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _self = 'test/tooling/old_editor_removed_test.dart';

const String _editorDir = 'lib/features/capture/text/editor';

const List<String> _deletedFiles = <String>[
  '$_editorDir/in_place_photo_editor.dart',
  '$_editorDir/markdown_style_controller.dart',
  '$_editorDir/photo_wrap.dart',
  '$_editorDir/photo_bands.dart',
  '$_editorDir/photo_line_keys.dart',
  '$_editorDir/single_field_note_editor.dart',
  '$_editorDir/format_actions.dart',
];

const List<String> _removedNames = <String>[
  'Markdown' 'StyleController',
  'InPlace' 'PhotoEditor',
  'SingleField' 'NoteEditor',
  'Note' 'Editor',
  'inPlace' 'PhotoKey',
  'Render' 'PhotoCanvas',
  'Photo' 'LineGuard',
  'photoAware' 'Delete',
  'photoAware' 'Step',
  'planPhoto' 'Wrap',
  'photoPatches' 'Within',
  'unmergedFrom' 'TheMaterialTextTheme',
  'noteText' 'Field',
  'spellCheckDisabled' 'BecauseItShortCircuitsTheStyledSpan',
  'stylusHandwritingDisabled' 'BecauseItShortCircuitsTheStyledSpan',
];

final RegExp _oldImport = RegExp(
  r"(?:import|export)\s+'[^']*\b(in_place_photo_editor|"
  r'markdown_style_controller|photo_wrap|photo_bands|photo_line_keys|'
  r"single_field_note_editor|format_actions)\.dart'",
);

final RegExp _composerMediaScope = RegExp(r'\bclass\s+ComposerMediaScope\b');

List<File> _dartFilesUnder(String root) {
  final Directory directory = Directory(root);
  if (!directory.existsSync()) {
    return const <File>[];
  }
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .where((File file) => file.path != _self)
      .toList();
}

void main() {
  test('no source references the old editor', () {
    final List<File> scanned = <File>[
      for (final String root in <String>[
        'lib',
        'test',
        'integration_test',
        'tool',
      ])
        ..._dartFilesUnder(root),
    ];
    expect(scanned, isNotEmpty);

    final List<String> present = <String>[
      for (final String path in _deletedFiles)
        if (File(path).existsSync()) path,
    ];
    expect(present, isEmpty, reason: present.join('\n'));

    final List<RegExp> names = <RegExp>[
      for (final String name in _removedNames) RegExp('\\b$name\\b'),
    ];
    final List<String> offences = <String>[
      for (final File file in scanned)
        for (final String line in file.readAsLinesSync())
          if (_oldImport.hasMatch(line) ||
              names.any((RegExp name) => name.hasMatch(line)))
            '${file.path}: $line',
    ];
    expect(offences, isEmpty, reason: offences.join('\n'));

    final List<String> exports = File('$_editorDir/editor.dart')
        .readAsLinesSync()
        .where((String line) => line.startsWith('export '))
        .toList();
    expect(exports, <String>[
      "export 'format_bar.dart';",
      "export 'note_editor.dart';",
      "export 'photo_caption_field.dart';",
      "export 'photo_toolbar.dart';",
    ]);

    final List<String> scopes = <String>[
      for (final File file in _dartFilesUnder('lib'))
        if (_composerMediaScope.hasMatch(file.readAsStringSync())) file.path,
    ];
    expect(scopes, <String>[
      'lib/features/note_engine/editor/composer_media_scope.dart',
    ]);
  });
}
