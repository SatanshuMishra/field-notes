import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const List<String> _composerTests = <String>[
  'test/features/capture/core/text_composer_test.dart',
  'test/features/capture/text/text_composer_geometry_test.dart',
  'test/features/capture/text/text_composer_short_screen_test.dart',
  'test/features/capture/text/text_composer_save_hang_test.dart',
  'test/features/capture/text/text_composer_timeout_dedupe_test.dart',
  'test/features/capture/text/composer_header_test.dart',
];

const List<String> _flowTests = <String>[
  'test/features/day_detail/day_detail_edit_note_test.dart',
  'test/features/day_detail/edit_note_flow_test.dart',
  'test/features/day_detail/day_detail_panel_test.dart',
  'test/features/log_viewer/log_viewer_test.dart',
  'test/features/today/today_feed_parity_test.dart',
  'integration_test/capture_ui_flow_test.dart',
];

final RegExp _driverImport = RegExp(
  r"^import\s+'[^']*support/note_editor_driver\.dart';",
);

final RegExp _editorAccess = RegExp(
  r'\b(EditableText\w*|RenderEditable|TextField|testTextInput|'
  r'MarkdownStyle\w+|[Ii]nPlace\w+|SingleField\w+|unmergedFrom\w+|'
  r'noteTextF\w+)\b|\btester\.(enterText|showKeyboard)\(',
);

List<String> _offencesIn(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    return <String>['$path:0: missing'];
  }
  final List<String> lines = file.readAsLinesSync();
  return <String>[
    if (!lines.any(_driverImport.hasMatch))
      '$path:0: no import of support/note_editor_driver.dart',
    if (!lines.join('\n').contains('NoteEditorDriver('))
      '$path:0: never constructs the note editor driver',
    for (int i = 0; i < lines.length; i++)
      for (final RegExpMatch match in _editorAccess.allMatches(lines[i]))
        '$path:${i + 1}: ${match.group(0)}',
  ];
}

void main() {
  test('composer tests drive the editor only through the note editor driver',
      () {
    final List<String> offences = <String>[
      for (final String path in _composerTests) ..._offencesIn(path),
    ];

    expect(offences, isEmpty, reason: offences.join('\n'));
  });

  test('edit and feed flow tests drive the editor only through the note editor '
      'driver', () {
    final List<String> offences = <String>[
      for (final String path in _flowTests) ..._offencesIn(path),
    ];

    expect(offences, isEmpty, reason: offences.join('\n'));
  });
}
