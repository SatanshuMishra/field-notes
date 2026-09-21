import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _editorDirectory = 'lib/features/capture/text/editor';

const List<String> _bannedSpanConstructs = <String>[
  'recognizer:',
  'WidgetSpan',
];

List<File> _editorSources() {
  final Directory directory = Directory(_editorDirectory);
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .toList();
}

void main() {
  group('the editor never hands a span a gesture recognizer', () {
    test('the editor directory exists and holds sources to inspect', () {
      expect(Directory(_editorDirectory).existsSync(), isTrue);
      expect(_editorSources(), isNotEmpty);
    });

    test('no editor source mentions a banned span construct', () {
      for (final File source in _editorSources()) {
        final String contents = source.readAsStringSync();
        for (final String banned in _bannedSpanConstructs) {
          expect(
            contents.contains(banned),
            isFalse,
            reason: '${source.path} contains "$banned": a recognizer or a '
                'placeholder span breaks the length-preserving contract and '
                'is invisible on macOS while it throws on Android',
          );
        }
      }
    });
  });
}
