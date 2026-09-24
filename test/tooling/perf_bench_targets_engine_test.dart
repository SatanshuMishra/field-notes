import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _removed = RegExp(
  r'\b(MarkdownStyle\w+|liveStyleLimit|styleLimit|photoWrapF\w+|'
  r'PhotoWrapB\w+|StackedPh\w+|photoLineF\w+|PhotoPlace\w+|'
  r'PhotoSi(?:ze|de))\b|capture/text/editor/editor\.dart|'
  r'controller\.value\s*=',
);

void main() {
  test('the perf bench drives the new editor and engine', () {
    final String bench = File(
      'integration_test/note_perf_bench_test.dart',
    ).readAsStringSync();
    final List<String> imports = bench
        .split('\n')
        .where((String line) => line.startsWith('import '))
        .toList();

    for (final String needed in <String>[
      'NoteEditorController',
      'NoteBody(',
      'PhotoFigure',
      'mdPhotoLine(',
    ]) {
      expect(bench, contains(needed), reason: needed);
    }
    expect(
      imports.any(
        (String line) => line.endsWith("support/text_input_messages.dart';"),
      ),
      isTrue,
    );
    expect(
      imports.any(
        (String line) => line.endsWith("support/photo_line_fixture.dart';"),
      ),
      isTrue,
    );
    final List<String> offences = <String>[
      for (final RegExpMatch match in _removed.allMatches(bench))
        match.group(0)!,
    ];
    expect(offences, isEmpty, reason: offences.join('\n'));
  });
}
